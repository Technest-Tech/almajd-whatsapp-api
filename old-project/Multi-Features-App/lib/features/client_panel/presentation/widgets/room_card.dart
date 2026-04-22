import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../data/models/room_model.dart';

class RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onCopyHostLink;
  final VoidCallback? onCopyGuestLink;
  final VoidCallback? onCopyObserverLink;

  const RoomCard({
    super.key,
    required this.room,
    required this.onEdit,
    required this.onDelete,
    this.onCopyHostLink,
    this.onCopyGuestLink,
    this.onCopyObserverLink,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: AppSizes.spaceMd),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (room.description != null) ...[
                        const SizedBox(height: AppSizes.spaceXs),
                        Text(
                          room.description!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.spaceSm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: room.isActive
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.textSecondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    border: Border.all(
                      color: room.isActive
                          ? AppColors.success
                          : AppColors.textSecondary,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    room.isActive ? 'نشط' : 'غير نشط',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: room.isActive
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSizes.spaceMd),

            // Links
            _buildLinkSection(
              label: 'رابط المضيف',
              link: room.hostLink,
              onCopy: onCopyHostLink ?? () => _copyLink(context, room.hostLink, '/h'),
            ),
            const SizedBox(height: AppSizes.spaceSm),
            _buildLinkSection(
              label: 'رابط الضيف',
              link: room.guestLink,
              onCopy: onCopyGuestLink ?? () => _copyLink(context, room.guestLink, '/g'),
            ),
            if (room.observerLink != null) ...[
              const SizedBox(height: AppSizes.spaceSm),
              _buildLinkSection(
                label: 'رابط المراقب',
                link: room.observerLink!,
                onCopy: onCopyObserverLink ?? () => _copyLink(context, room.observerLink!, '/o'),
                isObserver: true,
              ),
            ],

            const SizedBox(height: AppSizes.spaceMd),
            const Divider(),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${room.count.participants} مشارك • ${room.count.files} ملف',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded),
                      color: AppColors.primary,
                      onPressed: onEdit,
                      tooltip: 'تعديل',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_rounded),
                      color: AppColors.error,
                      onPressed: onDelete,
                      tooltip: 'حذف',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkSection({
    required String label,
    required String link,
    required VoidCallback onCopy,
    bool isObserver = false,
  }) {
    final baseUrl = 'https://almajdmeet.org';
    String suffix = '';
    if (isObserver) {
      suffix = '/o';
    } else if (label.contains('مضيف')) {
      suffix = '/h';
    } else {
      suffix = '/g';
    }
    final fullLink = '$baseUrl/$link$suffix';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (isObserver) const Text('👁️ '),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isObserver ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
                if (isObserver)
                  const Text(
                    ' (سري)',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: AppSizes.iconSm),
              color: isObserver ? AppColors.error : AppColors.primary,
              onPressed: onCopy,
              tooltip: 'نسخ الرابط',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spaceXs),
        Container(
          padding: const EdgeInsets.all(AppSizes.spaceSm),
          decoration: BoxDecoration(
            color: isObserver
                ? AppColors.error.withOpacity(0.05)
                : AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            border: Border.all(
              color: isObserver
                  ? AppColors.error.withOpacity(0.3)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  fullLink,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: isObserver ? AppColors.error : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (isObserver)
          const Padding(
            padding: EdgeInsets.only(top: AppSizes.spaceXs),
            child: Text(
              '💡 المراقب غير مرئي تماماً لجميع المشاركين',
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  void _copyLink(BuildContext context, String link, String suffix) {
    final baseUrl = 'https://almajdmeet.org';
    final fullLink = '$baseUrl/$link$suffix';
    Clipboard.setData(ClipboardData(text: fullLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ الرابط'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
