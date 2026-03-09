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
    final isNote = message.isInternal;

    final alignment = isInbound ? Alignment.centerRight : Alignment.centerLeft;
    final bgColor = isNote
        ? AppColors.amber.withValues(alpha: 0.12)
        : isInbound
            ? const Color(0xFF1A2C34) // WhatsApp dark inbound
            : const Color(0xFF005C4B); // WhatsApp dark outbound (teal)

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
              border: isNote ? Border.all(color: AppColors.amber.withValues(alpha: 0.3)) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Internal note badge
                if (isNote)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline, size: 11, color: AppColors.amber),
                        const SizedBox(width: 3),
                        Text(
                          'ملاحظة داخلية',
                          style: TextStyle(
                            color: AppColors.amber.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

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

                // Message body + time in one flow
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
// Audio Message Widget (WhatsApp-style)
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
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _audioPlayer.setSourceUrl(widget.url);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(1, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final maxSecs = _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0;
    final currentSecs = _position.inSeconds.toDouble().clamp(0.0, maxSecs);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play/Pause button
        GestureDetector(
          onTap: () {
            if (_isPlaying) {
              _audioPlayer.pause();
            } else {
              _audioPlayer.play(UrlSource(widget.url));
            }
          },
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF53BDEB),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 6),

        // Waveform-style bars + time
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Waveform bars
              SizedBox(
                height: 28,
                child: CustomPaint(
                  painter: _WaveformPainter(
                    progress: maxSecs > 0 ? currentSecs / maxSecs : 0,
                    activeColor: const Color(0xFF53BDEB),
                    inactiveColor: Colors.white.withValues(alpha: 0.2),
                  ),
                  size: Size.infinite,
                ),
              ),
              const SizedBox(height: 2),
              // Duration
              Text(
                _isPlaying ? _formatDuration(_position) : _formatDuration(_duration),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
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
    const barWidth = 3.0;
    const gap = 2.0;
    final totalBars = ((size.width + gap) / (barWidth + gap)).floor();
    final rng = Random(42); // deterministic bars

    for (int i = 0; i < totalBars; i++) {
      final h = 6.0 + rng.nextDouble() * (size.height - 8);
      final x = i * (barWidth + gap);
      final y = (size.height - h) / 2;
      final filled = i / totalBars <= progress;

      final paint = Paint()
        ..color = filled ? activeColor : inactiveColor
        ..strokeCap = StrokeCap.round;

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barWidth, h), const Radius.circular(1.5)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) => old.progress != progress;
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
