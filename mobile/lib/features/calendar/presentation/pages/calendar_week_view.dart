import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../data/models/calendar_event_model.dart';

class CalendarWeekView extends StatefulWidget {
  final List<CalendarEventModel> events;
  final DateTime? selectedDate;
  final Function(DateTime)? onDateChanged;

  const CalendarWeekView({
    Key? key,
    required this.events,
    this.selectedDate,
    this.onDateChanged,
  }) : super(key: key);

  @override
  State<CalendarWeekView> createState() => _CalendarWeekViewState();
}

class _CalendarWeekViewState extends State<CalendarWeekView> {
  late DateTime _currentWeekStart;
  final ScrollController _scrollController = ScrollController();
  
  // Memoize week days
  List<DateTime>? _cachedWeekDays;
  DateTime? _cachedWeekStart;
  
  // Memoize events for each day
  final Map<String, List<CalendarEventModel>> _dayEventsCache = {};

  @override
  void initState() {
    super.initState();
    // Set the start of the current week (Sunday)
    DateTime now = widget.selectedDate ?? DateTime.now();
    _currentWeekStart = now.subtract(Duration(days: now.weekday % 7));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _previousWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
    });
  }

  void _nextWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
    });
  }

  void _goToToday() {
    setState(() {
      DateTime now = DateTime.now();
      _currentWeekStart = now.subtract(Duration(days: now.weekday % 7));
    });
  }

  List<DateTime> _getWeekDays() {
    if (_cachedWeekDays != null && _cachedWeekStart == _currentWeekStart) {
      return _cachedWeekDays!;
    }
    _cachedWeekDays = List.generate(7, (index) => _currentWeekStart.add(Duration(days: index)));
    _cachedWeekStart = _currentWeekStart;
    return _cachedWeekDays!;
  }

  List<CalendarEventModel> _getEventsForDay(DateTime day) {
    final cacheKey = '${day.millisecondsSinceEpoch}';
    if (_dayEventsCache.containsKey(cacheKey)) {
      return _dayEventsCache[cacheKey]!;
    }
    
    final dayOfWeek = day.weekday % 7; // Convert to 0=Sunday format
    final dayString = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final events = widget.events.where((event) {
      // For exceptional classes, check if the start date matches the target date
      if (event.isExceptional && event.start != null) {
        return event.start == dayString;
      }
      // For recurring events, check if the day of week matches
      return event.daysOfWeek.contains(dayOfWeek);
    }).toList();
    
    // Sort events by start time
    events.sort((a, b) {
      final timeA = a.startTime;
      final timeB = b.startTime;
      return timeA.compareTo(timeB);
    });
    
    _dayEventsCache[cacheKey] = events;
    return events;
  }
  
  @override
  void didUpdateWidget(CalendarWeekView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events) {
      _dayEventsCache.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = _getWeekDays();
    final dateFormat = DateFormat('MMM d', 'ar');

    return Column(
      children: [
        // Week navigation header
        RepaintBoundary(
          child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spaceMd,
            vertical: AppSizes.spaceSm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            border: Border(
              bottom: BorderSide(
                color: AppColors.textTertiary.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _previousWeek,
                color: AppColors.primary,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${dateFormat.format(_currentWeekStart)} - ${dateFormat.format(_currentWeekStart.add(const Duration(days: 6)))}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: _goToToday,
                      child: const Text('اليوم', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _nextWeek,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
        ),

        // Week view with horizontal scrolling
        Expanded(
          child: RepaintBoundary(
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: weekDays.map((day) {
                  return RepaintBoundary(
                    key: ValueKey(day.millisecondsSinceEpoch),
                    child: _buildDayColumn(day),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayColumn(DateTime day) {
    final isToday = DateTime.now().year == day.year &&
        DateTime.now().month == day.month &&
        DateTime.now().day == day.day;
    final dayEvents = _getEventsForDay(day);

    return Container(
      width: 320, // Fixed comfortable width for each day
      margin: const EdgeInsets.only(right: 2),
      decoration: BoxDecoration(
        color: isToday ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
        border: Border(
          right: BorderSide(
            color: AppColors.textTertiary.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Day header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: isToday ? AppColors.primary : AppColors.surfaceLight,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.textTertiary.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('EEEE', 'ar').format(day),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isToday ? Colors.white : AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('d MMM', 'ar').format(day),
                  style: TextStyle(
                    fontSize: 13,
                    color: isToday ? Colors.white70 : AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Events list (scrollable)
          Expanded(
            child: dayEvents.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'لا توجد أحداث',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                : RepaintBoundary(
                    child: ListView.builder(
                      key: ValueKey('${day.millisecondsSinceEpoch}-events'),
                      padding: const EdgeInsets.all(12),
                      itemCount: dayEvents.length,
                      itemBuilder: (context, index) {
                        return RepaintBoundary(
                          key: ValueKey(dayEvents[index].id),
                          child: _buildEventCard(dayEvents[index]),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(CalendarEventModel event) {
    final isExceptional = event.isExceptional;
    return GestureDetector(
      onTap: () => _showEventDetails(event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isExceptional
              ? Colors.orange.withOpacity(0.9)
              : AppColors.primary.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isExceptional ? Colors.orange : AppColors.primary,
            width: isExceptional ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student name
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.studentName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isExceptional)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'استثنائية',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Time
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  event.endTime != null
                      ? '${event.startTime.substring(0, 5)} - ${event.endTime!.substring(0, 5)}'
                      : event.startTime.substring(0, 5),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            
            // Teacher name
            if (event.teacherName.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.person,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      event.teacherName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            
            // Country
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.flag,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  event.country == 'uk' ? 'المملكة المتحدة' : 'كندا',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEventDetails(CalendarEventModel event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.studentName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('المعلم', event.teacherName),
            _buildDetailRow('الوقت', '${event.startTime.substring(0, 5)} - ${event.endTime?.substring(0, 5) ?? ''}'),
            _buildDetailRow('اليوم', event.day),
            _buildDetailRow('الدولة', event.country),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
