import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../data/models/calendar_event_model.dart';

class CalendarEventCard extends StatelessWidget {
  final CalendarEventModel event;
  final VoidCallback? onTap;

  const CalendarEventCard({
    super.key,
    required this.event,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isExceptional = event.isExceptional;
    
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSizes.spaceSm,
        vertical: AppSizes.spaceXs,
      ),
      elevation: isExceptional ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        side: isExceptional
            ? BorderSide(color: Colors.orange, width: 2)
            : BorderSide.none,
      ),
      color: isExceptional ? Colors.orange.withOpacity(0.1) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spaceMd),
          child: Row(
            children: [
              // Time indicator
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: isExceptional ? Colors.orange : AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSizes.spaceMd),

              // Event details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                      event.studentName,
                            style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                              color: isExceptional ? Colors.orange.shade900 : null,
                            ),
                          ),
                        ),
                        if (isExceptional)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'حصة استثنائية',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.spaceXs),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSizes.spaceXs),
                        Text(
                          event.startTime,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (event.endTime != null) ...[
                          const Text(' - ', style: TextStyle(color: AppColors.textSecondary)),
                          Text(
                            event.endTime!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSizes.spaceXs),
                    Row(
                      children: [
                        Icon(
                          Icons.person_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSizes.spaceXs),
                        Text(
                          event.teacherName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: AppSizes.spaceMd),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.spaceSm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: event.country == 'canada'
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppSizes.radiusXs),
                          ),
                          child: Text(
                            event.country == 'canada' ? 'كندا' : 'المملكة المتحدة',
                            style: TextStyle(
                              fontSize: 10,
                              color: event.country == 'canada'
                                  ? Colors.blue
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }
}
