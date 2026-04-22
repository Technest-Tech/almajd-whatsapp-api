import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/course_model.dart';

class CourseCard extends StatelessWidget {
  final CourseModel course;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CourseCard({
    super.key,
    required this.course,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                        ),
                        const SizedBox(height: 8),
                        if (course.student != null)
                          Row(
                            children: [
                              Icon(
                                Icons.school,
                                size: 16,
                                color: Theme.of(context).hintColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${AppLocalizations.of(context)!.student}: ${course.student!.name}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                    ),
                              ),
                            ],
                          ),
                        if (course.teacher != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 16,
                                color: Theme.of(context).hintColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${AppLocalizations.of(context)!.teacher}: ${course.teacher!.name}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onEdit != null || onDelete != null)
                    PopupMenuButton(
                      icon: const Icon(Icons.more_vert),
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(Icons.edit, size: 20),
                                const SizedBox(width: 8),
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
                                const SizedBox(width: 8),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(
                    avatar: const Icon(Icons.book, size: 16),
                    label: Text(
                      '${course.lessonsCount} دروس',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

