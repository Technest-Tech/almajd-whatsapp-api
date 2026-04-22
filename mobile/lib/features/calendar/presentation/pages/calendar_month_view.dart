import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../data/models/calendar_event_model.dart';
import '../../data/models/calendar_teacher_model.dart';
import '../widgets/calendar_event_card.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';

class CalendarMonthView extends StatefulWidget {
  final List<CalendarEventModel> events;
  final List<int>? selectedTeacherIds;

  const CalendarMonthView({
    super.key,
    required this.events,
    this.selectedTeacherIds,
  });

  @override
  State<CalendarMonthView> createState() => _CalendarMonthViewState();
}

class _CalendarMonthViewState extends State<CalendarMonthView> {
  late DateTime _currentMonth;
  final DateFormat _monthYearFormat = DateFormat('MMMM yyyy', 'ar');
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _headerScrollController = ScrollController();
  bool _isSyncingScroll = false;
  String? _selectedStudent;
  int? _selectedTeacherId;
  String? _selectedTeacherName;
  List<CalendarTeacherModel> _teachers = [];
  final TextEditingController _studentSearchController = TextEditingController();
  final TextEditingController _teacherSearchController = TextEditingController();
  String _studentSearchQuery = '';
  String _teacherSearchQuery = '';

  // Get unique students from events
  List<String> get _uniqueStudents {
    final students = widget.events
        .map((e) => e.studentName)
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    students.sort();
    return students;
  }

  // Memoize events for days
  final Map<String, List<CalendarEventModel>> _dayEventsCache = {};
  
  // Get filtered events based on selected filters
  List<CalendarEventModel> get _filteredEvents {
    return widget.events.where((event) {
      // Filter by student
      if (_selectedStudent != null && event.studentName != _selectedStudent) {
        return false;
      }
      // Filter by teacher
      if (_selectedTeacherId != null && event.teacherId != _selectedTeacherId) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
    
    // Load teachers when view is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final bloc = context.read<CalendarBloc>();
        // Check if teachers are already cached
        final cachedTeachers = bloc.cachedTeachers;
        if (cachedTeachers != null && cachedTeachers.isNotEmpty) {
          setState(() {
            _teachers = cachedTeachers;
          });
        } else {
          // Load teachers if not cached
          bloc.add(const LoadCalendarTeachers());
        }
      }
    });
    
    // Sync header scroll with grid scroll
    _horizontalScrollController.addListener(() {
      if (!_isSyncingScroll && _headerScrollController.hasClients) {
        _isSyncingScroll = true;
        if ((_headerScrollController.offset - _horizontalScrollController.offset).abs() > 1.0) {
          _headerScrollController.jumpTo(_horizontalScrollController.offset);
        }
        _isSyncingScroll = false;
      }
    });
    
    _headerScrollController.addListener(() {
      if (!_isSyncingScroll && _horizontalScrollController.hasClients) {
        _isSyncingScroll = true;
        if ((_horizontalScrollController.offset - _headerScrollController.offset).abs() > 1.0) {
          _horizontalScrollController.jumpTo(_headerScrollController.offset);
        }
        _isSyncingScroll = false;
      }
    });
  }

  @override
  void didUpdateWidget(CalendarMonthView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events || 
        oldWidget.selectedTeacherIds != widget.selectedTeacherIds) {
      _dayEventsCache.clear();
    }
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _headerScrollController.dispose();
    _studentSearchController.dispose();
    _teacherSearchController.dispose();
    super.dispose();
  }

  // Get filtered students based on search
  List<String> get _filteredStudents {
    if (_studentSearchQuery.isEmpty) {
      return _uniqueStudents;
    }
    final query = _studentSearchQuery.toLowerCase();
    return _uniqueStudents.where((student) {
      return student.toLowerCase().contains(query);
    }).toList();
  }

  // Get filtered teachers based on search
  List<CalendarTeacherModel> get _filteredTeachers {
    if (_teacherSearchQuery.isEmpty) {
      return _teachers;
    }
    final query = _teacherSearchQuery.toLowerCase();
    return _teachers.where((teacher) {
      return teacher.name.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spaceMd),
      child: Column(
        children: [
          // Month Navigation
          _buildMonthNavigation(),

          const SizedBox(height: AppSizes.spaceMd),
          
          // Filters Row
          _buildFilters(),
          
          const SizedBox(height: AppSizes.spaceMd),

          // Calendar Grid - Scrollable
          Expanded(
            child: _buildCalendarGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthNavigation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () {
            setState(() {
              _currentMonth = DateTime(
                _currentMonth.year,
                _currentMonth.month - 1,
              );
            });
          },
        ),
        Text(
          _monthYearFormat.format(_currentMonth),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () {
            setState(() {
              _currentMonth = DateTime(
                _currentMonth.year,
                _currentMonth.month + 1,
              );
            });
          },
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    );

    // Get first day of week (Sunday = 0)
    final firstDayOfWeek = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;

    // Arabic day names
    const dayNames = ['أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate card dimensions - make them bigger
        final minCardWidth = 120.0; // Minimum card width
        final cardWidth = constraints.maxWidth > minCardWidth * 7 
            ? constraints.maxWidth / 7 
            : minCardWidth;
        final cardHeight = cardWidth * 1.6; // Make cards taller (60% taller)
        
        return Column(
          children: [
            // Day headers - Scrollable horizontally, synced with grid
            RepaintBoundary(
              child: SingleChildScrollView(
                controller: _headerScrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: cardWidth * 7,
                  child: Row(
                    children: dayNames.map((day) {
                      return SizedBox(
                        width: cardWidth,
                        child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.spaceMd,
                          horizontal: AppSizes.spaceSm,
                        ),
                        child: Text(
                          day,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            ),

            const Divider(),

            // Calendar days - Scrollable grid with synchronized horizontal scroll
            Expanded(
              child: RepaintBoundary(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: cardWidth * 7, // Full width for 7 columns
                      height: cardHeight * 6, // 6 weeks
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(), // Disable GridView scroll, use parent scroll
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: cardWidth / cardHeight,
                          crossAxisSpacing: AppSizes.spaceSm,
                          mainAxisSpacing: AppSizes.spaceSm,
                        ),
                        itemCount: 42, // 6 weeks * 7 days
                        itemBuilder: (context, index) {
                        final dayIndex = index - firstDayOfWeek;
                        final isCurrentMonth = dayIndex >= 0 && dayIndex < daysInMonth;
                        final day = isCurrentMonth ? dayIndex + 1 : null;
                        final isToday = day != null &&
                            DateTime(_currentMonth.year, _currentMonth.month, day)
                                .isAtSameMomentAs(DateTime.now().copyWith(
                                    hour: 0, minute: 0, second: 0, millisecond: 0));

                        // Get events for this day
                        final dayEvents = _getEventsForDay(day);

                        return RepaintBoundary(
                          key: ValueKey('$day-$index'),
                          child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: isToday
                                ? AppColors.primary.withOpacity(0.1)
                                : Colors.transparent,
                            border: isToday
                                ? Border.all(color: AppColors.primary, width: 2)
                                : Border.all(
                                    color: AppColors.textTertiary.withOpacity(0.2),
                                    width: 1,
                                  ),
                            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                          ),
                          child: day != null
                              ? ClipRect(
                                  child: Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Day number
                                        Text(
                                          '$day',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isToday
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            color: isToday
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        // Events list - Scrollable inside card
                                        if (dayEvents.isNotEmpty)
                                          Flexible(
                                            fit: FlexFit.loose,
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              physics: const ClampingScrollPhysics(),
                                              itemCount: dayEvents.length,
                                              itemBuilder: (context, i) {
                                                final event = dayEvents[i];
                                                final isExceptional = event.isExceptional;
                                                return RepaintBoundary(
                                                  key: ValueKey(event.id),
                                                  child: InkWell(
                                                onTap: () => _showEventDetails(context, event),
                                                child: Container(
                                                  margin: const EdgeInsets.only(
                                                    bottom: 3,
                                                  ),
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 2,
                                                    vertical: 2,
                                                  ),
                                                  constraints: const BoxConstraints(
                                                    maxWidth: double.infinity,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isExceptional
                                                        ? Colors.orange.withOpacity(0.3)
                                                        : (event.country == 'canada'
                                                            ? Colors.blue.withOpacity(0.2)
                                                            : Colors.red.withOpacity(0.2)),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: isExceptional
                                                          ? Colors.orange
                                                          : (event.country == 'canada'
                                                              ? Colors.blue
                                                              : Colors.red),
                                                      width: isExceptional ? 2 : 1.5,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          if (isExceptional)
                                                            const Icon(
                                                              Icons.star_rounded,
                                                              size: 8,
                                                              color: Colors.orange,
                                                            ),
                                                          Flexible(
                                                            child: Text(
                                                              event.studentName,
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                                color: isExceptional ? Colors.orange.shade900 : null,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                              maxLines: 1,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 2),
                                                      ClipRect(
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.max,
                                                          mainAxisAlignment: MainAxisAlignment.start,
                                                          crossAxisAlignment: CrossAxisAlignment.center,
                                                          children: [
                                                            Icon(
                                                              Icons.access_time_rounded,
                                                              size: 5,
                                                              color: AppColors.textSecondary,
                                                            ),
                                                            const SizedBox(width: 1),
                                                            Expanded(
                                                              child: Text(
                                                                event.endTime != null && event.endTime!.isNotEmpty
                                                                    ? '${_formatTime(event.startTime)}-${_formatTime(event.endTime!)}'
                                                                    : _formatTime(event.startTime),
                                                                style: TextStyle(
                                                                  fontSize: 5.5,
                                                                  color: AppColors.textSecondary,
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                softWrap: false,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        )
                                      else
                                        const SizedBox.shrink(),
                                      ],
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilters() {
    return GestureDetector(
      onTap: () {
        // Unfocus any focused field when tapping outside
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.opaque,
      child: BlocListener<CalendarBloc, CalendarState>(
        listenWhen: (previous, current) {
          // Listen to teachers loaded state or events loaded (to get cached teachers)
          return current is CalendarTeachersLoaded || 
                 (current is CalendarEventsLoaded && _teachers.isEmpty);
        },
        listener: (context, state) {
        if (state is CalendarTeachersLoaded) {
          setState(() {
            _teachers = state.teachers;
          });
        } else if (state is CalendarEventsLoaded) {
          // Try to get cached teachers from bloc
          final bloc = context.read<CalendarBloc>();
          final cachedTeachers = bloc.cachedTeachers;
          if (cachedTeachers != null && cachedTeachers.isNotEmpty) {
            setState(() {
              _teachers = cachedTeachers;
            });
          } else {
            // Load teachers if not cached
            bloc.add(const LoadCalendarTeachers());
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceMd),
        child: Row(
          children: [
            // Student Filter with Search
            Expanded(
              flex: 1,
              child: Autocomplete<String>(
                displayStringForOption: (option) => option,
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return ['جميع الطلاب', ..._uniqueStudents];
                  }
                  final query = textEditingValue.text.toLowerCase();
                  final filtered = _uniqueStudents.where((student) {
                    return student.toLowerCase().contains(query);
                  }).toList();
                  return ['جميع الطلاب', ...filtered];
                },
                onSelected: (value) {
                  setState(() {
                    _selectedStudent = value == 'جميع الطلاب' ? null : value;
                    _studentSearchController.text = value == 'جميع الطلاب' ? '' : value;
                  });
                },
                fieldViewBuilder: (
                  context,
                  textEditingController,
                  focusNode,
                  onFieldSubmitted,
                ) {
                  if (_studentSearchController.text != textEditingController.text) {
                    _studentSearchController.text = textEditingController.text;
                  }
                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'الطالب',
                      hintText: 'ابحث عن طالب...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.spaceSm,
                        vertical: AppSizes.spaceSm,
                      ),
                      isDense: true,
                      suffixIcon: textEditingController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                textEditingController.clear();
                                setState(() {
                                  _selectedStudent = null;
                                  _studentSearchQuery = '';
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _studentSearchQuery = value;
                      });
                    },
                    onFieldSubmitted: (value) => onFieldSubmitted(),
                  );
                },
              ),
            ),
            const SizedBox(width: AppSizes.spaceSm),
            // Teacher Filter with Search
            Expanded(
              flex: 1,
              child: Builder(
                builder: (context) {
                  // Try to get cached teachers from bloc if local list is empty
                  if (_teachers.isEmpty) {
                    final bloc = context.read<CalendarBloc>();
                    final cachedTeachers = bloc.cachedTeachers;
                    if (cachedTeachers != null && cachedTeachers.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _teachers = cachedTeachers;
                          });
                        }
                      });
                    }
                  }
                  
                  return _teachers.isEmpty
                      ? TextFormField(
                          controller: _teacherSearchController,
                          decoration: const InputDecoration(
                            labelText: 'المعلم',
                            hintText: 'جاري التحميل...',
                            prefixIcon: Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: AppSizes.spaceSm,
                              vertical: AppSizes.spaceSm,
                            ),
                            isDense: true,
                          ),
                          enabled: false,
                        )
                      : Autocomplete<CalendarTeacherModel>(
                      displayStringForOption: (option) => option.name,
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _teachers;
                        }
                        final query = textEditingValue.text.toLowerCase();
                        return _teachers.where((teacher) {
                          return teacher.name.toLowerCase().contains(query);
                        }).toList();
                      },
                      onSelected: (teacher) {
                        setState(() {
                          _selectedTeacherId = teacher.id;
                          _selectedTeacherName = teacher.name;
                          _teacherSearchController.text = teacher.name;
                        });
                      },
                      fieldViewBuilder: (
                        context,
                        textEditingController,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        if (_teacherSearchController.text != textEditingController.text &&
                            textEditingController.text != _selectedTeacherName) {
                          _teacherSearchController.text = textEditingController.text;
                        }
                        return TextFormField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'المعلم',
                            hintText: 'ابحث عن معلم...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.spaceSm,
                              vertical: AppSizes.spaceSm,
                            ),
                            isDense: true,
                            suffixIcon: textEditingController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      textEditingController.clear();
                                      setState(() {
                                        _selectedTeacherId = null;
                                        _selectedTeacherName = null;
                                        _teacherSearchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _teacherSearchQuery = value;
                            });
                          },
                          onFieldSubmitted: (value) => onFieldSubmitted(),
                        );
                      },
                    );
                },
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  List<CalendarEventModel> _getEventsForDay(int? day) {
    if (day == null) return [];

    final cacheKey = '${_currentMonth.year}-${_currentMonth.month}-$day-$_selectedStudent-$_selectedTeacherId';
    if (_dayEventsCache.containsKey(cacheKey)) {
      return _dayEventsCache[cacheKey]!;
    }

    final targetDate = DateTime(_currentMonth.year, _currentMonth.month, day);
    final dayOfWeek = targetDate.weekday % 7; // Convert to Sunday=0 format
    final targetDateString = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
    final filteredEvents = _filteredEvents;

    final events = filteredEvents.where((event) {
      // For exceptional classes, check if the start date matches the target date
      if (event.isExceptional && event.start != null) {
        return event.start == targetDateString;
      }
      // For recurring events, check if the day of week matches
      return event.daysOfWeek.contains(dayOfWeek);
    }).toList();
    
    _dayEventsCache[cacheKey] = events;
    return events;
  }

  String _formatTime(String time) {
    try {
      // Handle both "HH:MM:SS" and "HH:MM" formats
      final parts = time.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        
        if (hour == 0) {
          return '12:$minute AM';
        } else if (hour < 12) {
          return '$hour:$minute AM';
        } else if (hour == 12) {
          return '12:$minute PM';
        } else {
          return '${hour - 12}:$minute PM';
        }
      }
      return time;
    } catch (e) {
      return time;
    }
  }

  void _showEventDetails(BuildContext context, CalendarEventModel event) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _EventDetailsDialog(
        event: event,
        formatTime: _formatTime,
        getArabicDayName: _getArabicDayName,
        buildDetailRow: _buildDetailRow,
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    String? value,
    Widget? valueWidget,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(width: AppSizes.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              valueWidget ??
                  Text(
                    value ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  String _getArabicDayName(String englishDay) {
    const dayNames = {
      'Sunday': 'الأحد',
      'Monday': 'الاثنين',
      'Tuesday': 'الثلاثاء',
      'Wednesday': 'الأربعاء',
      'Thursday': 'الخميس',
      'Friday': 'الجمعة',
      'Saturday': 'السبت',
    };
    return dayNames[englishDay] ?? englishDay;
  }
}

class _EventDetailsDialog extends StatefulWidget {
  final CalendarEventModel event;
  final String Function(String) formatTime;
  final String Function(String) getArabicDayName;
  final Widget Function({
    required IconData icon,
    required String label,
    String? value,
    Widget? valueWidget,
  }) buildDetailRow;

  const _EventDetailsDialog({
    required this.event,
    required this.formatTime,
    required this.getArabicDayName,
    required this.buildDetailRow,
  });

  @override
  State<_EventDetailsDialog> createState() => _EventDetailsDialogState();
}

class _EventDetailsDialogState extends State<_EventDetailsDialog> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Show loading spinner for a brief moment
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'تفاصيل الحصة',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const Divider(height: AppSizes.spaceXl),
                  
                  // Event Details
                  widget.buildDetailRow(
                    icon: Icons.person_rounded,
                    label: 'الطالب',
                    value: widget.event.studentName,
                  ),
                  const SizedBox(height: AppSizes.spaceMd),
                  widget.buildDetailRow(
                    icon: Icons.school_rounded,
                    label: 'المعلم',
                    value: widget.event.teacherName.isNotEmpty ? widget.event.teacherName : 'غير محدد',
                  ),
                  const SizedBox(height: AppSizes.spaceMd),
                  widget.buildDetailRow(
                    icon: Icons.access_time_rounded,
                    label: 'الوقت',
                    value: widget.event.endTime != null && widget.event.endTime!.isNotEmpty
                        ? '${widget.formatTime(widget.event.startTime)} - ${widget.formatTime(widget.event.endTime!)}'
                        : widget.formatTime(widget.event.startTime),
                  ),
                  const SizedBox(height: AppSizes.spaceMd),
                  widget.buildDetailRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'اليوم',
                    value: widget.getArabicDayName(widget.event.day),
                  ),
                  const SizedBox(height: AppSizes.spaceMd),
                  widget.buildDetailRow(
                    icon: Icons.public_rounded,
                    label: 'البلد',
                    value: widget.event.country == 'canada' ? 'كندا' : 'المملكة المتحدة',
                    valueWidget: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.event.country == 'canada'
                            ? Colors.blue.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: widget.event.country == 'canada'
                              ? Colors.blue
                              : Colors.red,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.event.country == 'canada' ? 'كندا' : 'المملكة المتحدة',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: widget.event.country == 'canada'
                              ? Colors.blue
                              : Colors.red,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceLg),
                  
                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceMd),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        ),
                      ),
                      child: const Text('إغلاق'),
                    ),
                  ),
                ],
                ),
              ),
      ),
    );
  }
}
