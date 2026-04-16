import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'dart:ui';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/message_model.dart';
import '../../data/models/ticket_model.dart';
import '../../data/ticket_repository.dart';
import '../bloc/ticket_list_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../core/di/injection.dart';
import '../widgets/message_bubble.dart';
import '../widgets/ticket_card.dart';
import '../../../../core/api/websockets_client.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';

class TicketDetailScreen extends StatefulWidget {
  final int ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen>
    with TickerProviderStateMixin {
  static const int _chatPageSize = 15;

  // ── Controllers ──
  final _messageController = TextEditingController();
  final _itemScrollController = ItemScrollController();
  final _positionsListener = ItemPositionsListener.create();
  final _focusNode = FocusNode();

  // ── State ──
  final List<MessageModel> _messages = [];
  TicketModel? _ticket;
  bool _isLoading = true;
  bool _isAutoScrolling = false;
  MessageModel? _replyingTo;
  bool _showScrollToBottom = false;
  int? _highlightedMessageId;

  // ── Pagination ──
  int _currentPage = 1;
  int _lastPage = 1;
  bool _isLoadingMore = false;
  bool _loadOlderInFlight = false;

  // ── Audio Recording ──
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  bool _isRecordLocked = false;

  // ── WebSocket Channel ──
  Channel? _channel;

  // ── Animation ──
  late final AnimationController _sendBtnController;
  late final Animation<double> _sendBtnAnimation;

  @override
  void initState() {
    super.initState();

    _markTicketAsRead();

    _sendBtnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _sendBtnAnimation = CurvedAnimation(
      parent: _sendBtnController,
      curve: Curves.easeInOut,
    );

    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (hasText && !_sendBtnController.isCompleted) {
        _sendBtnController.forward();
      } else if (!hasText && _sendBtnController.isCompleted) {
        _sendBtnController.reverse();
      }
    });

    // Track scroll position to show/hide the scroll-to-bottom FAB
    // and trigger loading older messages when near top
    _positionsListener.itemPositions.addListener(() {
      if (!mounted) return;
      final positions = _positionsListener.itemPositions.value;
      if (positions.isEmpty) return;
      final lastVisible = positions.map((p) => p.index).reduce((a, b) => a > b ? a : b);
      final firstVisible = positions.map((p) => p.index).reduce((a, b) => a < b ? a : b);
      final show = lastVisible < _messages.length - 1;
      if (show != _showScrollToBottom) {
        setState(() => _showScrollToBottom = show);
      }
      // Load older messages when scrolling near the top (not during initial open scroll)
      if (!_isLoading &&
          firstVisible <= 3 &&
          !_loadOlderInFlight &&
          !_isLoadingMore &&
          _currentPage < _lastPage) {
        _loadOlderMessages();
      }
    });

    _markTicketAsRead();
    _loadData();
  }

  Future<void> _markTicketAsRead() async {
    try {
      final repo = getIt<TicketRepository>();
      await repo.markAsRead(widget.ticketId);
      if (mounted) {
        context.read<TicketListBloc>().add(TicketReadStatusUpdated(widget.ticketId));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _messageController.dispose();
    _focusNode.dispose();
    _audioRecorder.dispose();
    _sendBtnController.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // WebSocket
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  void _setupWebSocket() async {
    final pusher = WebSocketsClient.instance.pusher;
    if (pusher == null) return;

    final token = await const FlutterSecureStorage().read(key: 'access_token');

    final channel = pusher.privateChannel(
      'private-ticket.${widget.ticketId}',
      authorizationDelegate:
          EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
            authorizationEndpoint: Uri.parse(
              'https://cloud.almajd.info/api/broadcasting/auth',
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          ),
    );
    _channel = channel;

    channel.bind('TicketMessageCreated').listen((event) {
      if (mounted && event.data != null) {
        try {
          final Map<String, dynamic> payload = event.data is String
              ? jsonDecode(event.data)
              : event.data;

          final messageData = payload['data'] is Map<String, dynamic>
              ? payload['data'] as Map<String, dynamic>
              : payload;

          final newMessage = MessageModel.fromJson(messageData);

          if (!_messages.any((m) => m.id == newMessage.id)) {
            setState(() {
              _messages.add(newMessage);
            });
            _scrollToBottom();
          }

          // Also update the global inbox list so badges + previews update
          context.read<TicketListBloc>().add(
            TicketListMessageReceived(
              ticketId: widget.ticketId,
              messagePreview: newMessage.body ?? '',
            ),
          );
        } catch (e) {
          debugPrint("WebSocket Parse Error: $e");
        }
      }
    });

    // Listen for delivery status changes (sent → delivered → read)
    // so tick icons update in real time without a page reload
    channel.bind('TicketMessageStatusUpdated').listen((event) {
      if (mounted && event.data != null) {
        try {
          final Map<String, dynamic> payload = event.data is String
              ? jsonDecode(event.data)
              : event.data;

          final data = payload['data'] is Map<String, dynamic>
              ? payload['data'] as Map<String, dynamic>
              : payload;

          final int? msgId = data['id'];
          final String? newStatus = data['delivery_status'];
          if (msgId == null || newStatus == null) return;

          final idx = _messages.indexWhere((m) => m.id == msgId);
          if (idx != -1) {
            setState(() {
              _messages[idx] = _messages[idx].copyWith(deliveryStatus: newStatus);
            });
          }
        } catch (e) {
          debugPrint("WebSocket Status Update Error: $e");
        }
      }
    });

    channel.subscribe();
  }


  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Data Loading
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  void _loadData() async {
    try {
      final repo = getIt<TicketRepository>();
      // Load ticket metadata (for app bar: name, phone, status)
      final ticket = await repo.getTicket(widget.ticketId);
      // First page: latest messages only
      final result = await repo.getMessages(
        widget.ticketId,
        page: 1,
        perPage: _chatPageSize,
      );
      final messages = result['messages'] as List<MessageModel>;

      if (mounted) {
        setState(() {
          _ticket = ticket;
          _messages
            ..clear()
            ..addAll(messages);
          _currentPage = result['current_page'] as int;
          _lastPage = result['last_page'] as int;
        });
        _setupWebSocket();

        // Show content immediately, scroll to bottom, then hide loader
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(
            onComplete: () {
              if (mounted) setState(() => _isLoading = false);
            },
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تحميل بيانات التذكرة')),
        );
      }
    }
  }

  /// Load older messages when scrolling up (15 per page, same as initial load)
  Future<void> _loadOlderMessages() async {
    if (_loadOlderInFlight || _isLoadingMore || _currentPage >= _lastPage) {
      return;
    }

    final positions = _positionsListener.itemPositions.value;
    int? anchorIndex;
    var anchorLeading = 0.0;
    if (positions.isNotEmpty) {
      final top = positions.reduce((a, b) => a.index < b.index ? a : b);
      anchorIndex = top.index;
      anchorLeading = top.itemLeadingEdge;
    }

    _loadOlderInFlight = true;
    if (mounted) setState(() => _isLoadingMore = true);

    try {
      final repo = getIt<TicketRepository>();
      final result = await repo.getMessages(
        widget.ticketId,
        page: _currentPage + 1,
        perPage: _chatPageSize,
      );
      final olderMessages = result['messages'] as List<MessageModel>;

      if (!mounted) return;

      if (olderMessages.isEmpty) {
        setState(() {
          _isLoadingMore = false;
          _currentPage = result['current_page'] as int;
          _lastPage = result['last_page'] as int;
        });
        return;
      }

      final added = olderMessages.length;
      setState(() {
        _messages.insertAll(0, olderMessages);
        _currentPage = result['current_page'] as int;
        _lastPage = result['last_page'] as int;
        _isLoadingMore = false;
      });

      // Keep the same messages in view after prepending (indices shift by [added])
      if (anchorIndex != null && added > 0 && _itemScrollController.isAttached) {
        final newIndex = anchorIndex + added;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_itemScrollController.isAttached) return;
          _itemScrollController.scrollTo(
            index: newIndex,
            duration: Duration.zero,
            curve: Curves.linear,
            alignment: anchorLeading,
          );
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    } finally {
      _loadOlderInFlight = false;
    }
  }

  bool _isImageUrl(String url, String? type) {
    if (type == 'image') return true;
    final lowerUrl = url.toLowerCase();
    return lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.contains('image');
  }

  void _scrollToBottom({VoidCallback? onComplete}) {
    if (_messages.isEmpty) {
      onComplete?.call();
      return;
    }
    setState(() => _isAutoScrolling = true);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      if (_itemScrollController.isAttached) {
        _itemScrollController
            .scrollTo(
              index: _messages.length - 1,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            )
            .then((_) {
              if (mounted) {
                setState(() => _isAutoScrolling = false);
                onComplete?.call();
              }
            });
      } else {
        if (mounted) setState(() => _isAutoScrolling = false);
        onComplete?.call();
      }
    });
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // BUILD
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B141A),
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Chat wallpaper
          Positioned.fill(child: CustomPaint(painter: _ChatWallpaperPainter())),

          // Main column
          Column(
            children: [
              Expanded(child: _buildMessageList()),
              _buildInputArea(),
            ],
          ),

          // Scroll-to-bottom FAB
          if (_showScrollToBottom && !_isLoading && !_isAutoScrolling)
            Positioned(
              right: 12,
              bottom: 100,
              child: GestureDetector(
                onTap: _scrollToBottom,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2C34),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF8696A0),
                    size: 24,
                  ),
                ),
              ),
            ),

        ],
      ),
    );
  }

  // ── Message List with Date Separators ──
  Widget _buildMessageList() {
    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      itemPositionsListener: _positionsListener,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final showDate =
            index == 0 ||
            !_isSameDay(msg.createdAt, _messages[index - 1].createdAt);

        final isHighlighted = _highlightedMessageId == msg.id;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: isHighlighted
                ? const Color(0xFF00A884).withValues(alpha: 0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              if (showDate) DateSeparator(date: msg.createdAt),
              MessageBubble(
                message: msg,
                onSwipeReply: (m) {
                  setState(() => _replyingTo = m);
                  _focusNode.requestFocus();
                },
                onLongPress: (m) {},
                onQuoteReplyTap: _scrollToMessage,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Scrolls to the message with [targetId] and flashes a highlight.
  Future<void> _scrollToMessage(int targetId) async {
    final index = _messages.indexWhere((m) => m.id == targetId);
    if (index == -1) return;

    await _itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.15,
    );

    // Flash highlight
    setState(() => _highlightedMessageId = targetId);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _highlightedMessageId = null);
  }



  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // APP BAR
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PreferredSizeWidget _buildAppBar() {
    if (_ticket == null) {
      return AppBar(
        backgroundColor: const Color(0xFF1F2C34),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'جاري التحميل...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final authState = context.read<AuthBloc>().state;
    final isAdmin = authState is AuthAuthenticated && authState.user.roles.contains('admin');

    final displayName = (_ticket!.guardianName?.isNotEmpty == true && _ticket!.guardianName != 'Unknown Contact')
        ? _ticket!.guardianName!
        : (isAdmin && _ticket!.guardianPhone != null ? '\u200E${_ticket!.guardianPhone}' : 'جهة اتصال غير معروفة');

    return AppBar(
      backgroundColor: const Color(0xFF1F2C34),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, size: 22),
        onPressed: () => context.pop(),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF2A3942),
            backgroundImage: const AssetImage('assets/images/default_avatar.png'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'اضغط للمزيد',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (_ticket?.slaDeadline != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SlaTimerPill(deadline: _ticket!.slaDeadline!),
          ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showActionsSheet(context),
        ),
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // INPUT AREA
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildInputArea() {
    // WasenderAPI has no 24-hour session window — the text input is always available.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply preview
        if (_replyingTo != null) _buildReplyPreview(),
        // Input bar
        Container(
          padding: EdgeInsets.fromLTRB(
            6,
            6,
            6,
            6 + MediaQuery.of(context).padding.bottom,
          ),
          color: const Color(0xFF1F2C34),
          child: _isRecording && !_isRecordLocked
              ? _buildRecordingSlider()
              : _isRecordLocked
              ? _buildLockedRecordingUI()
              : _buildStandardInputRow(),
        ),
      ],
    );
  }

  // ── Reply Preview ──
  Widget _buildReplyPreview() {
    final msg = _replyingTo!;
    final isMe = msg.direction == 'outbound';
    final sender = isMe ? 'أنت' : (msg.senderName ?? 'المستخدم');

    String preview = msg.body;
    if (preview.isEmpty) {
      if (msg.type == 'image') {
        preview = '📷 صورة';
      } else if (msg.type == 'audio') {
        preview = '🎵 صوت';
      } else if (msg.type == 'document') {
        preview = '📄 مستند';
      } else {
        preview = 'مرفق';
      }
    }

    return Container(
      color: const Color(0xFF1F2C34),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0B141A),
          borderRadius: BorderRadius.circular(8),
          border: const Border(
            right: BorderSide(color: Color(0xFF53BDEB), width: 3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sender,
                    style: const TextStyle(
                      color: Color(0xFF53BDEB),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    preview,
                    style: const TextStyle(
                      color: Color(0xFF8696A0),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _replyingTo = null),
              child: const Icon(
                Icons.close,
                size: 18,
                color: Color(0xFF8696A0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Standard Input Row ──
  Widget _buildStandardInputRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Text field container
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3942),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attachment
                Padding(
                  padding: const EdgeInsets.only(bottom: 2, left: 4),
                  child: IconButton(
                    icon: const Icon(
                      Icons.attach_file_rounded,
                      color: Color(0xFF8696A0),
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: _showAttachmentOptions,
                  ),
                ),
                // Text field
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    maxLines: 6,
                    minLines: 1,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'رسالة',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Mic / Send button
        _buildMicSendButton(),
      ],
    );
  }

  // ── Animated Mic ↔ Send Button ──
  Widget _buildMicSendButton() {
    return AnimatedBuilder(
      animation: _sendBtnAnimation,
      builder: (context, _) {
        final showSend = _sendBtnAnimation.value > 0.5;
        return GestureDetector(
          onTap: showSend ? _onSendMessage : null,
          onLongPressStart: showSend ? null : (_) => _startRecording(),
          onLongPressMoveUpdate: showSend
              ? null
              : (details) {
                  // Slide left to cancel
                  if (details.localOffsetFromOrigin.dx < -80) {
                    _cancelRecording();
                  }
                  // Slide up to lock
                  if (details.localOffsetFromOrigin.dy < -60 && _isRecording) {
                    setState(() => _isRecordLocked = true);
                  }
                },
          onLongPressEnd: showSend
              ? null
              : (_) {
                  if (_isRecording && !_isRecordLocked) _stopRecording();
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: showSend
                  ? const Color(0xFF00A884)
                  : (_isRecording ? AppColors.coral : const Color(0xFF00A884)),
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: showSend
                  ? const Icon(
                      Icons.send_rounded,
                      key: ValueKey('send'),
                      color: Colors.white,
                      size: 20,
                    )
                  : const Icon(
                      Icons.mic,
                      key: ValueKey('mic'),
                      color: Colors.white,
                      size: 22,
                    ),
            ),
          ),
        );
      },
    );
  }

  // ── WhatsApp-style Recording Bar ──
  Widget _buildRecordingSlider() {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          // Trash (cancel)
          GestureDetector(
            onTap: _cancelRecording,
            child: const _CircleBtn(
              color: Color(0xFF2A3942),
              child: Icon(Icons.delete_outline_rounded,
                  color: AppColors.coral, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          // Pulsing dot + timer
          const _PulsingDot(),
          const SizedBox(width: 8),
          Text(
            _formatRecordDuration(_recordDuration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          // Slide-to-cancel hint
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chevron_left_rounded,
                    color: Colors.white.withValues(alpha: 0.35), size: 20),
                Icon(Icons.chevron_left_rounded,
                    color: Colors.white.withValues(alpha: 0.2), size: 20),
                Text(
                  'اسحب للإلغاء',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Lock button
          GestureDetector(
            onTap: () => setState(() => _isRecordLocked = true),
            child: const _CircleBtn(
              color: Color(0xFF2A3942),
              child: Icon(Icons.lock_outline_rounded,
                  color: Color(0xFF8696A0), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── Locked Recording UI ──
  Widget _buildLockedRecordingUI() {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          // Trash (cancel)
          GestureDetector(
            onTap: _cancelRecording,
            child: const _CircleBtn(
              color: Color(0xFF2A3942),
              child: Icon(Icons.delete_outline_rounded,
                  color: AppColors.coral, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          const _PulsingDot(),
          const SizedBox(width: 8),
          Text(
            _formatRecordDuration(_recordDuration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          // Send
          GestureDetector(
            onTap: _stopRecording,
            child: const _CircleBtn(
              color: Color(0xFF00A884),
              child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }


  String _formatRecordDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ATTACHMENTS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2C34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AttachmentOption(
                    icon: Icons.image_rounded,
                    label: 'معرض',
                    color: const Color(0xFF7C5BF1),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage();
                    },
                  ),
                  _AttachmentOption(
                    icon: Icons.insert_drive_file_rounded,
                    label: 'مستند',
                    color: const Color(0xFF5169E4),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickDocument();
                    },
                  ),
                  _AttachmentOption(
                    icon: Icons.headphones_rounded,
                    label: 'صوت',
                    color: const Color(0xFFEE7C30),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAudioFile();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),

    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // MEDIA PICKING
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) _uploadAndSendMedia(File(picked.path));
  }


  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      _uploadAndSendMedia(File(result.files.single.path!));
    }
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      _uploadAndSendMedia(File(result.files.single.path!));
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // AUDIO RECORDING
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final p =
          '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: p);
      setState(() {
        _isRecording = true;
        _recordDuration = Duration.zero;
      });
      HapticFeedback.heavyImpact();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _recordDuration += const Duration(seconds: 1));
        }
      });
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _isRecordLocked = false;
      _recordDuration = Duration.zero;
    });
    HapticFeedback.lightImpact();
    if (path != null) _uploadAndSendMedia(File(path));
  }

  void _cancelRecording() async {
    _recordTimer?.cancel();
    await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _isRecordLocked = false;
      _recordDuration = Duration.zero;
    });
    HapticFeedback.lightImpact();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SEND & UPLOAD
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<void> _uploadAndSendMedia(File file) async {
    int? replyToId;
    String? replyToBody;
    String? replyToSender;
    String? replyToType;

    if (_replyingTo != null) {
      replyToId = _replyingTo!.id;
      replyToBody = _replyingTo!.body.isNotEmpty
          ? _replyingTo!.body
          : (_replyingTo!.type == 'image'
                ? '📷 صورة'
                : (_replyingTo!.type == 'audio' ? '🎵 صوت' : '📄 مستند'));
      replyToSender = _replyingTo!.isInbound
          ? (_replyingTo!.senderName ?? 'المستخدم')
          : 'أنت';
      replyToType = _replyingTo!.type;
      setState(() => _replyingTo = null);
    }

    final tempId = -(DateTime.now().millisecondsSinceEpoch);
    setState(() {
      _messages.add(
        MessageModel(
          id: tempId,
          ticketId: widget.ticketId,
          body: '⏳ جاري الإرسال...',
          direction: 'outbound',
          deliveryStatus: 'sending',
          createdAt: DateTime.now(),
          replyToId: replyToId,
          replyToBody: replyToBody,
          replyToSender: replyToSender,
          replyToType: replyToType,
        ),
      );
    });
    _scrollToBottom();

    try {
      final repo = getIt<TicketRepository>();
      final uploadRes = await repo.uploadTicketMedia(widget.ticketId, file);
      final mediaUrl = uploadRes['media_url'];
      final realMessage = await repo.replyToTicket(
        widget.ticketId,
        '',
        mediaUrl: mediaUrl,
        replyToMessageId: replyToId,
      );

      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == tempId);
          if (idx != -1) _messages[idx] = realMessage;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _messages.removeWhere((m) => m.id == tempId));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('فشل إرسال المرفق')));
      }
    }
  }

  void _onSendMessage() async {
    String text = _messageController.text.trim();
    if (text.isEmpty && _replyingTo == null) return;

    // Build reply metadata
    int? replyToId;
    String? replyToBody;
    String? replyToSender;
    String? replyToType;

    if (_replyingTo != null) {
      replyToId = _replyingTo!.id;
      replyToBody = _replyingTo!.body.isNotEmpty
          ? _replyingTo!.body
          : (_replyingTo!.type == 'image'
                ? '📷 صورة'
                : (_replyingTo!.type == 'audio' ? '🎵 صوت' : '📄 مستند'));
      replyToSender = _replyingTo!.isInbound
          ? (_replyingTo!.senderName ?? 'المستخدم')
          : 'أنت';
      replyToType = _replyingTo!.type;
      setState(() => _replyingTo = null);
    }

    if (text.isEmpty) return;

    final tempId = -(DateTime.now().millisecondsSinceEpoch);
    setState(() {
      _messages.add(
        MessageModel(
          id: tempId,
          ticketId: widget.ticketId,
          body: text,
          direction: 'outbound',
          deliveryStatus: 'sending',
          createdAt: DateTime.now(),
          replyToId: replyToId,
          replyToBody: replyToBody,
          replyToSender: replyToSender,
          replyToType: replyToType,
        ),
      );
    });
    _messageController.clear();
    _scrollToBottom();
    HapticFeedback.lightImpact();

    // ── Isolated Background Send ──
    Future.microtask(() async {
      try {
        final repo = getIt<TicketRepository>();
        final realMessage = await repo.replyToTicket(
          widget.ticketId,
          text,
          replyToMessageId: replyToId,
        );

        if (mounted) {
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == tempId);
            if (idx != -1) _messages[idx] = realMessage;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == tempId);
            if (idx != -1) {
              final oldMsg = _messages[idx];
              _messages[idx] = oldMsg.copyWith(deliveryStatus: 'failed');
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل إرسال الرسالة'))
          );
        }
      }
    });
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ACTIONS SHEET
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  void _showActionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2C34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'إجراءات التذكرة',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _ActionTile(
                icon: Icons.person_add_rounded,
                label: 'تعيين مشرف',
                subtitle: 'تعيين التذكرة لمشرف آخر',
                color: AppColors.primary,
                onTap: () {
                  Navigator.pop(ctx);
                  _showSnackBar('تم التعيين بنجاح');
                },
              ),
              _ActionTile(
                icon: Icons.trending_up_rounded,
                label: 'تصعيد',
                subtitle: 'تصعيد التذكرة للمشرف الأول',
                color: AppColors.coral,
                onTap: () {
                  Navigator.pop(ctx);
                  _showSnackBar('تم التصعيد بنجاح');
                },
              ),
              _ActionTile(
                icon: Icons.swap_horiz_rounded,
                label: 'تغيير الحالة',
                subtitle: 'تغيير حالة التذكرة',
                color: AppColors.amber,
                onTap: () {
                  Navigator.pop(ctx);
                  _showStatusPicker();
                },
              ),
              _ActionTile(
                icon: Icons.note_add_rounded,
                label: 'إضافة ملاحظة داخلية',
                subtitle: 'ملاحظة مرئية فقط للموظفين',
                color: AppColors.primaryLight,
                onTap: () {
                  Navigator.pop(ctx);
                  _showNoteDialog();
                },
              ),
              _ActionTile(
                icon: Icons.schedule_rounded,
                label: 'تعيين متابعة',
                subtitle: 'تذكير للمتابعة لاحقاً',
                color: AppColors.statusOpen,
                onTap: () {
                  Navigator.pop(ctx);
                  _showSnackBar('تم تعيين المتابعة');
                },
              ),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatusPicker() {
    final statuses = [
      {'key': 'open', 'label': 'مفتوح', 'color': AppColors.statusOpen},
      {'key': 'assigned', 'label': 'معين', 'color': AppColors.primary},
      {'key': 'pending', 'label': 'معلق', 'color': AppColors.statusPending},
      {'key': 'resolved', 'label': 'محلول', 'color': AppColors.statusResolved},
      {'key': 'closed', 'label': 'مغلق', 'color': AppColors.statusClosed},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2C34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'تغيير الحالة',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ...statuses.map(
              (s) => ListTile(
                leading: CircleAvatar(
                  radius: 6,
                  backgroundColor: s['color'] as Color,
                ),
                title: Text(s['label'] as String),
                selected: _ticket?.status == s['key'],
                selectedTileColor: (s['color'] as Color).withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  if (mounted) {
                    setState(() {
                      _messages.add(
                        MessageModel(
                          id: _messages.length + 200,
                          ticketId: widget.ticketId,
                          body: 'تم تغيير الحالة إلى ${s['label']}',
                          direction: 'outbound',
                          type: 'system',
                          createdAt: DateTime.now(),
                        ),
                      );
                    });
                    _scrollToBottom();
                  }
                  _showSnackBar('تم تغيير الحالة إلى ${s['label']}');
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  void _showNoteDialog() {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2C34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.amber, size: 20),
            SizedBox(width: 8),
            Text('ملاحظة داخلية', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(hintText: 'اكتب ملاحظة للفريق...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: Color(0xFF8696A0)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final note = noteController.text.trim();
              if (note.isNotEmpty) {
                setState(() {
                  _messages.add(
                    MessageModel(
                      id: _messages.length + 300,
                      ticketId: widget.ticketId,
                      body: note,
                      direction: 'outbound',
                      isInternal: true,
                      senderName: 'أحمد المشرف',
                      createdAt: DateTime.now(),
                    ),
                  );
                });
                _scrollToBottom();
              }
              Navigator.pop(ctx);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: const Color(0xFF00A884),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
} // End of _TicketDetailScreenState

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Chat Wallpaper Painter
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _ChatWallpaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0D1418)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Subtle doodle pattern
    final patternPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 28.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        final offset = (y ~/ spacing) % 2 == 0 ? spacing / 2 : 0.0;
        // Small icons: circles, lines, dots
        final idx = ((x + y) ~/ spacing) % 4;
        final cx = x + offset;
        switch (idx) {
          case 0:
            canvas.drawCircle(Offset(cx, y), 3, patternPaint);
            break;
          case 1:
            canvas.drawLine(
              Offset(cx - 3, y - 3),
              Offset(cx + 3, y + 3),
              patternPaint,
            );
            break;
          case 2:
            canvas.drawRect(
              Rect.fromCenter(center: Offset(cx, y), width: 5, height: 5),
              patternPaint,
            );
            break;
          case 3:
            canvas.drawCircle(
              Offset(cx, y),
              1.5,
              patternPaint..style = PaintingStyle.fill,
            );
            patternPaint.style = PaintingStyle.stroke;
            break;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Reusable Widgets
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: Color(0xFF8696A0)),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8696A0)),
          ),
        ],
      ),
    );
  }
}

// ── Simple circular icon button ──
class _CircleBtn extends StatelessWidget {
  final Color color;
  final Widget child;
  const _CircleBtn({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(child: child),
    );
  }
}

// ── Animated pulsing red dot for voice recording ──
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _scale = Tween(begin: 0.7, end: 1.3).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 11,
        height: 11,
        decoration: const BoxDecoration(
          color: AppColors.coral,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
