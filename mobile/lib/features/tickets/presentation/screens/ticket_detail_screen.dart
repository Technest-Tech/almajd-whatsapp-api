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

import '../../../../core/theme/app_theme.dart';
import '../../data/models/message_model.dart';
import '../../data/models/ticket_model.dart';
import '../../data/ticket_repository.dart';
import '../bloc/ticket_list_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../core/di/injection.dart';
import '../widgets/message_bubble.dart';
import '../../../../core/api/websockets_client.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';

class TicketDetailScreen extends StatefulWidget {
  final int ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen>
    with SingleTickerProviderStateMixin {
  static const int _chatPageSize = 10;

  // ── Controllers ──
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  // ── State ──
  final List<MessageModel> _messages = [];
  TicketModel? _ticket;
  bool _isLoading = true;
  MessageModel? _replyingTo;
  bool _showScrollToBottom = false;

  // ── Pagination ──
  int _currentPage = 1;
  int _lastPage = 1;
  bool _isLoadingMore = false;

  // ── Audio Recording ──
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  bool _isRecordLocked = false;

  // ── WebSocket Channel ──
  Channel? _channel;

  // ── Polling fallback ──
  Timer? _pollTimer;

  // ── Send button animation ──
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

    // Scroll listener: show/hide scroll-to-bottom FAB & load older messages
    _scrollController.addListener(_onScroll);

    _loadData();
  }

  void _onScroll() {
    if (!mounted) return;

    // Show scroll-to-bottom button when scrolled away from bottom
    final atBottom = _scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 80;
    if (_showScrollToBottom == atBottom) {
      setState(() => _showScrollToBottom = !atBottom);
    }

    // Load older messages when user scrolls near the top (200px threshold)
    if (_scrollController.hasClients &&
        _scrollController.position.pixels <=
            _scrollController.position.minScrollExtent + 200 &&
        !_isLoadingMore &&
        _currentPage < _lastPage) {
      _loadOlderMessages();
    }
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
    _pollTimer?.cancel();
    _channel?.unsubscribe();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
            setState(() => _messages.add(newMessage));
            _scrollToBottom();
          }

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
  // Polling Fallback
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_isLoading) _pollForNewMessages();
    });
  }

  Future<void> _pollForNewMessages() async {
    try {
      final repo = getIt<TicketRepository>();
      final result = await repo.getMessages(
        widget.ticketId,
        page: 1,
        perPage: 10, // always poll latest 10
      );
      final latestMessages = result['messages'] as List<MessageModel>;

      if (!mounted) return;

      final existingIds = _messages.map((m) => m.id).toSet();
      final newMessages = latestMessages.where((m) => !existingIds.contains(m.id)).toList();

      if (newMessages.isEmpty) return;

      setState(() => _messages.addAll(newMessages));
      _scrollToBottom();

      final newest = newMessages.last;
      context.read<TicketListBloc>().add(
        TicketListMessageReceived(
          ticketId: widget.ticketId,
          messagePreview: newest.body ?? '',
        ),
      );
    } catch (_) {}
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Data Loading
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<void> _loadData() async {
    try {
      final repo = getIt<TicketRepository>();

      // Parallel load: ticket info + latest messages simultaneously
      final results = await Future.wait([
        repo.getTicket(widget.ticketId),
        repo.getMessages(widget.ticketId, page: 1, perPage: _chatPageSize),
      ]);

      if (mounted) {
        final ticket = results[0] as TicketModel;
        final result = results[1] as Map<String, dynamic>;
        setState(() {
          _ticket = ticket;
          _messages
            ..clear()
            ..addAll(result['messages'] as List<MessageModel>);
          _currentPage = result['current_page'] as int;
          _lastPage = result['last_page'] as int;
          _isLoading = false;
        });
        _setupWebSocket();
        _startPolling();

        // Instant scroll to bottom — use two frames for reliability
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom(instant: true);
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تحميل المحادثة')),
        );
      }
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Load older messages (scroll-up pagination)
  // Backend: page 1 = latest, page 2 = older, page N = oldest
  // So "load older" means incrementing the page number.
  // Guard: stop when currentPage == lastPage (no more older pages).
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<void> _loadOlderMessages() async {
    if (_isLoadingMore || _currentPage >= _lastPage) return;

    setState(() => _isLoadingMore = true);

    // Remember scroll offset before prepending so position is preserved
    final oldExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;

    try {
      final repo = getIt<TicketRepository>();
      final nextPage = _currentPage + 1;
      final result = await repo.getMessages(
        widget.ticketId,
        page: nextPage,
        perPage: _chatPageSize,
      );
      final olderMessages = result['messages'] as List<MessageModel>;

      if (!mounted) return;

      if (olderMessages.isEmpty) {
        setState(() {
          _isLoadingMore = false;
          _currentPage = result['current_page'] as int;
          _lastPage    = result['last_page'] as int;
        });
        return;
      }

      // Deduplicate before inserting
      final existingIds = _messages.map((m) => m.id).toSet();
      final freshOlder = olderMessages.where((m) => !existingIds.contains(m.id)).toList();

      setState(() {
        _messages.insertAll(0, freshOlder);
        _currentPage = result['current_page'] as int;
        _lastPage    = result['last_page'] as int;
        _isLoadingMore = false;
      });

      // Keep the user's scroll position steady after the prepend
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final diff = _scrollController.position.maxScrollExtent - oldExtent;
        _scrollController.jumpTo(_scrollController.offset + diff);
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _scrollToBottom({bool instant = false}) {
    if (_messages.isEmpty || !_scrollController.hasClients) return;
    if (instant) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    } else {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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
          // Main column
          Column(
            children: [
              Expanded(child: _buildMessageList()),
              _buildInputArea(),
            ],
          ),

          // Scroll-to-bottom FAB
          if (_showScrollToBottom && !_isLoading)
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

  // ── Message List ──
  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00A884)),
      );
    }

    // Total items = messages + optional top loader + optional top end-marker
    final hasMoreOlder = _currentPage < _lastPage;
    // Slots: [0] = loader/end-banner (if applicable), then messages
    final showTopSlot = _isLoadingMore || (!hasMoreOlder && _messages.isNotEmpty);
    final itemCount = _messages.length + (showTopSlot ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // ── Top slot: loading spinner or end-of-history banner ──
        if (showTopSlot && index == 0) {
          if (_isLoadingMore) {
            return Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2C34),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF00A884),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'جاري تحميل الرسائل...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            // End of history reached
            return Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2C34),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'بداية المحادثة',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }
        }

        final msgIndex = showTopSlot ? index - 1 : index;
        if (msgIndex < 0 || msgIndex >= _messages.length) {
          return const SizedBox.shrink();
        }

        final msg = _messages[msgIndex];
        final showDate = msgIndex == 0 ||
            !_isSameDay(msg.createdAt, _messages[msgIndex - 1].createdAt);

        return RepaintBoundary(
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

  Future<void> _scrollToMessage(int targetId) async {
    final index = _messages.indexWhere((m) => m.id == targetId);
    if (index == -1 || !_scrollController.hasClients) return;
    // Approximate scroll — each message ~70px
    final offset = index * 70.0;
    await _scrollController.animateTo(
      offset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // APP BAR (simplified — just back, avatar, name)
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
            Text(
              'جاري التحميل...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
              ),
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
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFF2A3942),
            backgroundImage: AssetImage('assets/images/default_avatar.png'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (_ticket!.guardianPhone != null && displayName != '\u200E${_ticket!.guardianPhone}')
                  Text(
                    '\u200E${_ticket!.guardianPhone}',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // INPUT AREA
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildInputArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyingTo != null) _buildReplyPreview(),
        Container(
          padding: EdgeInsets.fromLTRB(6, 6, 6, 6 + MediaQuery.of(context).padding.bottom),
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

  Widget _buildReplyPreview() {
    final msg = _replyingTo!;
    final isMe = msg.direction == 'outbound';
    final sender = isMe ? 'أنت' : (msg.senderName ?? 'المستخدم');

    String preview = msg.body;
    if (preview.isEmpty) {
      if (msg.type == 'image') preview = '📷 صورة';
      else if (msg.type == 'audio') preview = '🎵 صوت';
      else if (msg.type == 'document') preview = '📄 مستند';
      else preview = 'مرفق';
    }

    return Container(
      color: const Color(0xFF1F2C34),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0B141A),
          borderRadius: BorderRadius.circular(8),
          border: const Border(right: BorderSide(color: Color(0xFF53BDEB), width: 3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(sender, style: const TextStyle(color: Color(0xFF53BDEB), fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(preview, style: const TextStyle(color: Color(0xFF8696A0), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _replyingTo = null),
              child: const Icon(Icons.close, size: 18, color: Color(0xFF8696A0)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardInputRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 2, left: 4),
                  child: IconButton(
                    icon: const Icon(Icons.attach_file_rounded, color: Color(0xFF8696A0), size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: _showAttachmentOptions,
                  ),
                ),
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
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 15),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        _buildMicSendButton(),
      ],
    );
  }

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
                  if (details.localOffsetFromOrigin.dx < -80) _cancelRecording();
                  if (details.localOffsetFromOrigin.dy < -60 && _isRecording) {
                    setState(() => _isRecordLocked = true);
                  }
                },
          onLongPressEnd: showSend
              ? null
              : (_) { if (_isRecording && !_isRecordLocked) _stopRecording(); },
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
                  ? const Icon(Icons.send_rounded, key: ValueKey('send'), color: Colors.white, size: 20)
                  : const Icon(Icons.mic, key: ValueKey('mic'), color: Colors.white, size: 22),
            ),
          ),
        );
      },
    );
  }

  // ── Recording UI ──
  Widget _buildRecordingSlider() {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2C34),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          // Delete button
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(left: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF2A3942),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF5350), size: 22),
            ),
          ),
          const SizedBox(width: 8),

          // Pulsing red dot
          const _PulsingDot(),
          const SizedBox(width: 8),

          // Duration counter
          SizedBox(
            width: 44,
            child: Text(
              _formatDuration(_recordDuration),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Swipe-to-cancel animated hint
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AnimatedChevron(delay: 0),
                _AnimatedChevron(delay: 150),
                _AnimatedChevron(delay: 300),
                const SizedBox(width: 4),
                Text(
                  'اسحب للإلغاء',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),

          // Lock button
          GestureDetector(
            onTap: () => setState(() => _isRecordLocked = true),
            child: Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2A3942),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF00A884).withValues(alpha: 0.4), width: 1.5),
              ),
              child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF00A884), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedRecordingUI() {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2C34),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          // Delete / cancel
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(left: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF2A3942),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF5350), size: 22),
            ),
          ),
          const SizedBox(width: 8),

          // Pulsing dot
          const _PulsingDot(),
          const SizedBox(width: 8),

          // Duration
          Text(
            _formatDuration(_recordDuration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),

          const Spacer(),

          // Locked badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00A884).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00A884).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 12, color: Color(0xFF00A884)),
                const SizedBox(width: 4),
                Text('مقفل', style: TextStyle(color: const Color(0xFF00A884), fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          // Send button
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              width: 46,
              height: 46,
              margin: const EdgeInsets.only(right: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF00A884),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
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
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AttachmentOption(icon: Icons.image_rounded, label: 'معرض', color: const Color(0xFF7C5BF1), onTap: () { Navigator.pop(ctx); _pickImage(); }),
                  _AttachmentOption(icon: Icons.insert_drive_file_rounded, label: 'مستند', color: const Color(0xFF5169E4), onTap: () { Navigator.pop(ctx); _pickDocument(); }),
                  _AttachmentOption(icon: Icons.headphones_rounded, label: 'صوت', color: const Color(0xFFEE7C30), onTap: () { Navigator.pop(ctx); _pickAudioFile(); }),
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
      final p = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: p);
      setState(() { _isRecording = true; _recordDuration = Duration.zero; });
      HapticFeedback.heavyImpact();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordDuration += const Duration(seconds: 1));
      });
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() { _isRecording = false; _isRecordLocked = false; _recordDuration = Duration.zero; });
    HapticFeedback.lightImpact();
    if (path != null) _uploadAndSendMedia(File(path));
  }

  void _cancelRecording() async {
    _recordTimer?.cancel();
    await _audioRecorder.stop();
    setState(() { _isRecording = false; _isRecordLocked = false; _recordDuration = Duration.zero; });
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
          : (_replyingTo!.type == 'image' ? '📷 صورة' : (_replyingTo!.type == 'audio' ? '🎵 صوت' : '📄 مستند'));
      replyToSender = _replyingTo!.isInbound ? (_replyingTo!.senderName ?? 'المستخدم') : 'أنت';
      replyToType = _replyingTo!.type;
      setState(() => _replyingTo = null);
    }

    final tempId = -(DateTime.now().millisecondsSinceEpoch);
    setState(() {
      _messages.add(MessageModel(
        id: tempId, ticketId: widget.ticketId, body: '⏳ جاري الإرسال...', direction: 'outbound',
        deliveryStatus: 'sending', createdAt: DateTime.now(),
        replyToId: replyToId, replyToBody: replyToBody, replyToSender: replyToSender, replyToType: replyToType,
      ));
    });
    _scrollToBottom();

    try {
      final repo = getIt<TicketRepository>();
      final uploadRes = await repo.uploadTicketMedia(widget.ticketId, file);
      final mediaUrl = uploadRes['media_url'];
      final realMessage = await repo.replyToTicket(widget.ticketId, '', mediaUrl: mediaUrl, replyToMessageId: replyToId);

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إرسال المرفق')));
      }
    }
  }

  void _onSendMessage() async {
    String text = _messageController.text.trim();
    if (text.isEmpty) return;

    int? replyToId;
    String? replyToBody;
    String? replyToSender;
    String? replyToType;

    if (_replyingTo != null) {
      replyToId = _replyingTo!.id;
      replyToBody = _replyingTo!.body.isNotEmpty
          ? _replyingTo!.body
          : (_replyingTo!.type == 'image' ? '📷 صورة' : (_replyingTo!.type == 'audio' ? '🎵 صوت' : '📄 مستند'));
      replyToSender = _replyingTo!.isInbound ? (_replyingTo!.senderName ?? 'المستخدم') : 'أنت';
      replyToType = _replyingTo!.type;
      setState(() => _replyingTo = null);
    }

    final tempId = -(DateTime.now().millisecondsSinceEpoch);
    setState(() {
      _messages.add(MessageModel(
        id: tempId, ticketId: widget.ticketId, body: text, direction: 'outbound',
        deliveryStatus: 'sending', createdAt: DateTime.now(),
        replyToId: replyToId, replyToBody: replyToBody, replyToSender: replyToSender, replyToType: replyToType,
      ));
    });
    _messageController.clear();
    _scrollToBottom();
    HapticFeedback.lightImpact();

    Future.microtask(() async {
      try {
        final repo = getIt<TicketRepository>();
        final realMessage = await repo.replyToTicket(widget.ticketId, text, replyToMessageId: replyToId);
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
            if (idx != -1) _messages[idx] = _messages[idx].copyWith(deliveryStatus: 'failed');
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل إرسال الرسالة')),
          );
        }
      }
    });
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Reusable Widgets
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8696A0))),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final Color color;
  final Widget child;
  const _CircleBtn({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(child: child),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _scale = Tween(begin: 0.7, end: 1.3).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 11, height: 11,
        decoration: const BoxDecoration(color: AppColors.coral, shape: BoxShape.circle),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Animated chevron for swipe-to-cancel hint
// ─────────────────────────────────────────────────────────────
class _AnimatedChevron extends StatefulWidget {
  final int delay;
  const _AnimatedChevron({required this.delay});
  @override
  State<_AnimatedChevron> createState() => _AnimatedChevronState();
}

class _AnimatedChevronState extends State<_AnimatedChevron>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _opacity = Tween(begin: 0.15, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 18),
    );
  }
}
