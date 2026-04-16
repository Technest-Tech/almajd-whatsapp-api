import 'dart:io';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/message_model.dart';

// ─────────────────────────────────────────────
// Date Separator Widget
// ─────────────────────────────────────────────
class DateSeparator extends StatelessWidget {
  final DateTime date;
  const DateSeparator({super.key, required this.date});

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'اليوم';
    if (d == today.subtract(const Duration(days: 1))) return 'أمس';
    final months = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2C34),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          _label(),
          style: const TextStyle(
            color: Color(0xFF8696A0),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Message Bubble Widget
// ─────────────────────────────────────────────
class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final ValueChanged<MessageModel>? onSwipeReply;
  final ValueChanged<MessageModel>? onLongPress;
  final ValueChanged<int>? onQuoteReplyTap; // tapped the quoted preview → scroll to that msg id

  const MessageBubble({
    super.key,
    required this.message,
    this.onSwipeReply,
    this.onLongPress,
    this.onQuoteReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) return _buildSystemMessage();
    if (message.isEmojiOnly) return _buildEmojiMessage(context);
    return _buildChatBubble(context);
  }

  // ── System Message ──
  Widget _buildSystemMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2C34),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 1,
              ),
            ],
          ),
          child: Text(
            message.body,
            style: const TextStyle(
              color: Color(0xFF8696A0),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  // ── Emoji-Only (No Bubble) ──
  Widget _buildEmojiMessage(BuildContext context) {
    final isInbound = message.isInbound;
    final alignment = isInbound ? Alignment.centerRight : Alignment.centerLeft;

    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: Dismissible(
        key: ValueKey('msg_${message.id}'),
        direction: isInbound ? DismissDirection.startToEnd : DismissDirection.endToStart,
        confirmDismiss: (_) async { onSwipeReply?.call(message); return false; },
        background: Container(
          alignment: isInbound ? Alignment.centerLeft : Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.reply, color: Colors.white70, size: 20),
          ),
        ),
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Column(
              crossAxisAlignment: isInbound ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(message.body, style: const TextStyle(fontSize: 40)),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.timeFormatted,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
                      ),
                      if (!isInbound) ...[
                        const SizedBox(width: 3),
                        _deliveryIcon(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Main Chat Bubble ──
  Widget _buildChatBubble(BuildContext context) {
    final isInbound = message.isInbound;

    final alignment = isInbound ? Alignment.centerRight : Alignment.centerLeft;
    final bgColor = isInbound
        ? const Color(0xFF1A2C34)
        : const Color(0xFF005C4B);

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: isInbound ? const Radius.circular(12) : const Radius.circular(4),
      bottomRight: isInbound ? const Radius.circular(4) : const Radius.circular(12),
    );

    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: Dismissible(
        key: ValueKey('msg_${message.id}'),
        direction: isInbound ? DismissDirection.startToEnd : DismissDirection.endToStart,
        confirmDismiss: (_) async {
          HapticFeedback.mediumImpact();
          onSwipeReply?.call(message);
          return false;
        },
        background: Container(
          alignment: isInbound ? Alignment.centerLeft : Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.reply, color: Colors.white70, size: 20),
          ),
        ),
        child: Align(
          alignment: alignment,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            margin: EdgeInsets.only(
              left: isInbound ? 50 : 8,
              right: isInbound ? 8 : 50,
              top: 1,
              bottom: 1,
            ),
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: borderRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sender name (for inbound)
                if (isInbound && message.senderName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      message.senderName!,
                      style: const TextStyle(
                        color: Color(0xFF53BDEB),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                // Quoted reply block
                if (message.replyToBody != null || message.replyToSender != null)
                  _buildQuotedReply(),

                // Media content
                if (message.mediaUrl != null) ...[
                  _buildMediaContent(context),
                  const SizedBox(height: 4),
                ],

                // Message body + time
                if (message.body.isNotEmpty)
                  _buildBodyWithTime(isInbound)
                else
                  _buildTimeRow(isInbound),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Quoted Reply Block ──
  Widget _buildQuotedReply() {
    final isReplyImage = message.replyToType == 'image';
    final isReplyAudio = message.replyToType == 'audio';
    String preview = message.replyToBody ?? '';
    if (preview.isEmpty) {
      if (isReplyImage) preview = '📷 صورة';
      else if (isReplyAudio) preview = '🎵 صوت';
      else preview = '📄 مستند';
    }

    return GestureDetector(
      onTap: message.replyToId != null
          ? () => onQuoteReplyTap?.call(message.replyToId!)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: const Border(
            right: BorderSide(color: Color(0xFF53BDEB), width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.replyToSender ?? 'المستخدم',
              style: const TextStyle(
                color: Color(0xFF53BDEB),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              preview,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Body Text with Time Below ──
  Widget _buildBodyWithTime(bool isInbound) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.body,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.93),
            fontSize: 14.5,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              message.timeFormatted,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10.5,
              ),
            ),
            if (!isInbound) ...[
              const SizedBox(width: 3),
              _deliveryIcon(),
            ],
          ],
        ),
      ],
    );
  }

  // ── Time-only Row (for media-only messages) ──
  Widget _buildTimeRow(bool isInbound) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          message.timeFormatted,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 10.5,
          ),
        ),
        if (!isInbound) ...[
          const SizedBox(width: 3),
          _deliveryIcon(),
        ],
      ],
    );
  }

  // ── Media Content ──
  Widget _buildMediaContent(BuildContext context) {
    final url = message.mediaUrl!;

    final type = message.type != 'text'
        ? message.type
        : (url.endsWith('.png') || url.endsWith('.jpg') || url.endsWith('.jpeg') || url.contains('image'))
            ? 'image'
            : url.contains('audio') || url.endsWith('.m4a') || url.endsWith('.mp3')
                ? 'audio'
                : 'document';

    if (type == 'image') {
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FullScreenImageScreen(url: url)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280, maxWidth: 280),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF53BDEB),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: Icon(Icons.broken_image, color: Colors.white38, size: 40)),
              ),
            ),
          ),
        ),
      );
    } else if (type == 'audio') {
      return AudioMessageWidget(url: url, isInbound: message.isInbound);
    } else {
      return _DocumentTile(url: url);
    }
  }

  // ── Context Menu (Long Press) ──
  void _showContextMenu(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2C34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _contextMenuItem(ctx, Icons.reply_rounded, 'رد', () {
                Navigator.pop(ctx);
                onSwipeReply?.call(message);
              }),
              _contextMenuItem(ctx, Icons.copy_rounded, 'نسخ', () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: message.body));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم نسخ النص', textAlign: TextAlign.center),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }),
              _contextMenuItem(ctx, Icons.shortcut_rounded, 'إعادة توجيه', () {
                Navigator.pop(ctx);
                // Forward placeholder
              }),
              if (!message.isInbound)
                _contextMenuItem(ctx, Icons.delete_outline_rounded, 'حذف', () {
                  Navigator.pop(ctx);
                  // Delete placeholder
                }, color: AppColors.coral),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contextMenuItem(BuildContext ctx, IconData icon, String label, VoidCallback onTap, {Color? color}) {
    final c = color ?? Colors.white;
    return ListTile(
      leading: Icon(icon, color: c, size: 22),
      title: Text(label, style: TextStyle(color: c, fontSize: 15)),
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  // ── Delivery Status Icon ──
  Widget _deliveryIcon() {
    switch (message.deliveryStatus) {
      case 'read':
        return const Icon(Icons.done_all, size: 15, color: Color(0xFF53BDEB));
      case 'delivered':
        return Icon(Icons.done_all, size: 15, color: Colors.white.withValues(alpha: 0.5));
      case 'sent':
        return Icon(Icons.done, size: 15, color: Colors.white.withValues(alpha: 0.5));
      case 'sending':
        return Icon(Icons.access_time, size: 13, color: Colors.white.withValues(alpha: 0.4));
      case 'failed':
        return const Icon(Icons.error_outline, size: 15, color: AppColors.coral);
      default:
        return Icon(Icons.done, size: 15, color: Colors.white.withValues(alpha: 0.5));
    }
  }
}

// ─────────────────────────────────────────────
// Audio Message Widget (Premium Telegram/WhatsApp style)
// ─────────────────────────────────────────────
class AudioMessageWidget extends StatefulWidget {
  final String url;
  final bool isInbound;
  const AudioMessageWidget({super.key, required this.url, this.isInbound = true});

  @override
  State<AudioMessageWidget> createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<AudioMessageWidget> {
  final _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _speed = 1.0;

  // Cycle: 1.0 → 1.5 → 2.0 → 1.0
  static const List<double> _speeds = [1.0, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _position = Duration.zero; _isPlaying = false; });
    });
  }

  @override
  void dispose() { _audioPlayer.dispose(); super.dispose(); }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      setState(() => _isLoading = true);
      try {
        await _audioPlayer.play(UrlSource(widget.url));
        await _audioPlayer.setPlaybackRate(_speed);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _seekTo(double fraction) async {
    final target = Duration(milliseconds: (_duration.inMilliseconds * fraction).round());
    await _audioPlayer.seek(target);
  }

  Future<void> _cycleSpeed() async {
    final next = _speeds[(_speeds.indexOf(_speed) + 1) % _speeds.length];
    setState(() => _speed = next);
    await _audioPlayer.setPlaybackRate(next);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(1, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final maxSecs = _duration.inSeconds.toDouble().clamp(1.0, double.infinity);
    final progress = (_position.inSeconds.toDouble() / maxSecs).clamp(0.0, 1.0);
    final timeStr = _isPlaying ? _fmt(_position) : _fmt(_duration);
    final speedLabel = _speed == 1.0 ? '1×' : (_speed == 1.5 ? '1.5×' : '2×');

    return SizedBox(
      width: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Play/Pause circle ──
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: widget.isInbound
                    ? const Color(0xFF00A884)
                    : Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.isInbound ? Colors.white : const Color(0xFF005C4B),
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: widget.isInbound ? Colors.white : const Color(0xFF005C4B),
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(width: 10),

          // ── Waveform + time ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform (tap to seek)
                GestureDetector(
                  onTapDown: (d) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    final local = box.globalToLocal(d.globalPosition);
                    final waveStart = 52.0; // approx play btn + gap
                    final waveWidth = box.size.width - waveStart - 36;
                    final fraction = ((local.dx - waveStart) / waveWidth).clamp(0.0, 1.0);
                    _seekTo(fraction);
                  },
                  child: SizedBox(
                    height: 30,
                    child: CustomPaint(
                      painter: _WaveformPainter(
                        progress: progress,
                        activeColor: widget.isInbound
                            ? const Color(0xFF00A884)
                            : Colors.white.withValues(alpha: 0.9),
                        inactiveColor: widget.isInbound
                            ? Colors.white.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),

                // Time + speed
                Row(
                  children: [
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: widget.isInbound
                            ? Colors.white.withValues(alpha: 0.55)
                            : Colors.white.withValues(alpha: 0.6),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _cycleSpeed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: (widget.isInbound
                                  ? const Color(0xFF00A884)
                                  : Colors.white)
                              .withValues(alpha: _speed != 1.0 ? 0.2 : 0.0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          speedLabel,
                          style: TextStyle(
                            color: widget.isInbound
                                ? Colors.white.withValues(alpha: _speed != 1.0 ? 0.9 : 0.4)
                                : Colors.white.withValues(alpha: _speed != 1.0 ? 1.0 : 0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Waveform Painter ──
class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  _WaveformPainter({required this.progress, required this.activeColor, required this.inactiveColor});

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 2.5;
    const gap = 1.8;
    final totalBars = ((size.width + gap) / (barWidth + gap)).floor();
    final rng = Random(42);

    for (int i = 0; i < totalBars; i++) {
      final heightFraction = 0.25 + rng.nextDouble() * 0.75;
      final h = size.height * heightFraction;
      final x = i * (barWidth + gap);
      final y = (size.height - h) / 2;
      final filled = i / totalBars <= progress;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, h),
          const Radius.circular(1.5),
        ),
        Paint()..color = filled ? activeColor : inactiveColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.progress != progress || old.activeColor != activeColor;
}

// ─────────────────────────────────────────────
// Full Screen Image Viewer
// ─────────────────────────────────────────────
class FullScreenImageScreen extends StatelessWidget {
  final String url;

  const FullScreenImageScreen({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () async {
              final fileName = Uri.parse(url).pathSegments.last;
              final dir = await getTemporaryDirectory();
              final savePath = '${dir.path}/$fileName';
              await Dio().download(url, savePath);
              await OpenFilex.open(savePath);
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Color(0xFF53BDEB))),
            errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white38, size: 60),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Document Tile — download & open in-app
// ─────────────────────────────────────────────
class _DocumentTile extends StatefulWidget {
  final String url;
  const _DocumentTile({required this.url});

  @override
  State<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends State<_DocumentTile> {
  bool _downloading = false;
  double _progress = 0;
  String? _localPath;

  String get _fileName {
    final seg = Uri.parse(widget.url).pathSegments;
    return seg.isNotEmpty ? seg.last : 'file';
  }

  String get _ext {
    final parts = _fileName.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : 'FILE';
  }

  Future<void> _handleTap() async {
    if (_localPath != null && File(_localPath!).existsSync()) {
      await OpenFilex.open(_localPath!);
      return;
    }
    setState(() { _downloading = true; _progress = 0; });
    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/$_fileName';
      await Dio().download(
        widget.url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
      );
      if (mounted) setState(() { _localPath = savePath; _downloading = false; });
      await OpenFilex.open(savePath);
    } catch (_) {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloaded = _localPath != null && File(_localPath!).existsSync();
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF53BDEB).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.insert_drive_file_rounded,
                color: Color(0xFF53BDEB),
                size: 26,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fileName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _downloading
                        ? '${(_progress * 100).toInt()}%  جاري التحميل...'
                        : downloaded
                            ? 'تم التحميل • اضغط للفتح · $_ext'
                            : 'اضغط للتحميل · $_ext',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _downloading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      strokeWidth: 2.5,
                      color: const Color(0xFF53BDEB),
                    ),
                  )
                : Icon(
                    downloaded ? Icons.open_in_new_rounded : Icons.download_rounded,
                    color: downloaded
                        ? const Color(0xFF53BDEB)
                        : Colors.white.withValues(alpha: 0.5),
                    size: 20,
                  ),
          ],
        ),
      ),
    );
  }
}
