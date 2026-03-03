import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/message_model.dart';

/// WhatsApp-style message bubble.
///
/// RTL layout:
///  • Inbound (from guardian) → aligned right, light surface bg
///  • Outbound (from staff)  → aligned left, teal-tinted bg
///  • System messages        → centered, grey pill
class MessageBubble extends StatelessWidget {
  final MessageModel message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return _buildSystemMessage();
    }
    return _buildChatBubble(context);
  }

  Widget _buildSystemMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(BuildContext context) {
    final isInbound = message.isInbound;

    // RTL: inbound on right, outbound on left
    final alignment = isInbound ? Alignment.centerRight : Alignment.centerLeft;
    final bgColor = isInbound
        ? AppColors.darkCardElevated
        : AppColors.primary.withValues(alpha: 0.2);
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isInbound ? const Radius.circular(16) : const Radius.circular(4),
      bottomRight: isInbound ? const Radius.circular(4) : const Radius.circular(16),
    );

    // Internal note styling
    final isNote = message.isInternal;

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: isNote ? AppColors.amber.withValues(alpha: 0.12) : bgColor,
          borderRadius: borderRadius,
          border: isNote
              ? Border.all(color: AppColors.amber.withValues(alpha: 0.3))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Internal note label
            if (isNote)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 12, color: AppColors.amber),
                    const SizedBox(width: 4),
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
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName!,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

            // Message body
            Text(
              message.body,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),

            // Time + delivery status row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.timeFormatted,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (!isInbound) ...[
                  const SizedBox(width: 4),
                  _deliveryIcon(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _deliveryIcon() {
    switch (message.deliveryStatus) {
      case 'read':
        return const Icon(Icons.done_all, size: 14, color: AppColors.primaryLight);
      case 'delivered':
        return Icon(Icons.done_all, size: 14, color: Colors.white.withValues(alpha: 0.4));
      case 'sent':
        return Icon(Icons.done, size: 14, color: Colors.white.withValues(alpha: 0.4));
      case 'failed':
        return const Icon(Icons.error_outline, size: 14, color: AppColors.coral);
      default:
        return Icon(Icons.done, size: 14, color: Colors.white.withValues(alpha: 0.4));
    }
  }
}
