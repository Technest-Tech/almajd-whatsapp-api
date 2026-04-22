import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/lesson_model.dart';

class LessonCard extends StatelessWidget {
  final LessonModel lesson;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const LessonCard({
    super.key,
    required this.lesson,
    this.onEdit,
    this.onDelete,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'present':
        return Colors.blue;
      case 'cancelled':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'مكتمل';
      case 'present':
        return 'حاضر';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes دقيقة';
    } else if (minutes == 60) {
      return '1 ساعة';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins == 0) {
        return '$hours ساعة';
      } else {
        return '$hours ساعة و $mins دقيقة';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(lesson.status);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Header section with status indicator
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Status indicator dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Status (replacing course name)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _getStatusText(lesson.status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Action menu
                if (onEdit != null || onDelete != null)
                  PopupMenuButton(
                    icon: Icon(
                      Icons.more_vert,
                              color: Theme.of(context).hintColor,
                              size: 20,
                            ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    itemBuilder: (context) => [
                      if (onEdit != null)
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 12),
                              Text(AppLocalizations.of(context)!.edit),
                            ],
                          ),
                        ),
                      if (onDelete != null)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete, color: Colors.red, size: 20),
                              const SizedBox(width: 12),
                            Text(
                                AppLocalizations.of(context)!.delete,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit' && onEdit != null) {
                        onEdit!();
                      } else if (value == 'delete' && onDelete != null) {
                        onDelete!();
                      }
                    },
                  ),
              ],
            ),
          ),
          
          // Content section
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date and Duration info cards
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        context,
                        icon: Icons.calendar_today_outlined,
                        label: 'التاريخ',
                        value: DateFormat('yyyy-MM-dd').format(lesson.date),
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        context,
                        icon: Icons.access_time_rounded,
                        label: 'المدة',
                        value: _formatDuration(lesson.duration),
                        color: Colors.purple,
                      ),
                        ),
                      ],
                    ),
                
                // Notes section
                if (lesson.notes != null && lesson.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.note_outlined,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ملاحظات',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context).hintColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                              const SizedBox(height: 3),
                              Text(
                                lesson.notes!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                    ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                    ),
                  ],
                          ),
                        ),
                ],
              ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
                ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
                Row(
                  children: [
                    Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).hintColor,
                      fontSize: 10,
                          ),
                    ),
                  ],
                ),
          const SizedBox(height: 5),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontSize: 13,
          ),
        ),
        ],
      ),
    );
  }
}

