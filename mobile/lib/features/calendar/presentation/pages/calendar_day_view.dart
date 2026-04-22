import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../data/models/calendar_event_model.dart';
import '../../data/models/calendar_teacher_model.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';

class CalendarDayView extends StatefulWidget {
  final List<CalendarEventModel> events;
  final DateTime selectedDate;
  final Function(DateTime)? onDateChanged;

  const CalendarDayView({
    super.key,
    required this.events,
    required this.selectedDate,
    this.onDateChanged,
  });

  @override
  State<CalendarDayView> createState() => _CalendarDayViewState();
}

class _CalendarDayViewState extends State<CalendarDayView> {
  String? _selectedStudent;
  int? _selectedTeacherId;
  String? _selectedTeacherName;
  List<CalendarTeacherModel> _teachers = [];
  final TextEditingController _studentSearchController = TextEditingController();
  final TextEditingController _teacherSearchController = TextEditingController();
  String _studentSearchQuery = '';
  String _teacherSearchQuery = '';
  bool _isDateChanging = false;
  
  // Memoize time slots - only generate once
  late final List<Map<String, dynamic>> _timeSlots = _generateTimeSlots();
  
  // Memoize filtered events
  List<CalendarEventModel>? _cachedFilteredEvents;
  String? _cachedStudentFilter;
  int? _cachedTeacherFilter;
  
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

  // Get filtered events with memoization
  List<CalendarEventModel> get _filteredEvents {
    if (_cachedFilteredEvents != null && 
        _cachedStudentFilter == _selectedStudent &&
        _cachedTeacherFilter == _selectedTeacherId) {
      return _cachedFilteredEvents!;
    }
    
    final filtered = widget.events.where((event) {
      if (_selectedStudent != null && event.studentName != _selectedStudent) {
        return false;
      }
      if (_selectedTeacherId != null && event.teacherId != _selectedTeacherId) {
        return false;
      }
      return true;
    }).toList();
    
    _cachedFilteredEvents = filtered;
    _cachedStudentFilter = _selectedStudent;
    _cachedTeacherFilter = _selectedTeacherId;
    
    return filtered;
  }
  
  // Memoize events for time slots
  final Map<String, List<CalendarEventModel>> _eventsCache = {};

  // Color palette for teachers
  static const List<Color> _teacherColors = [
    Color(0xFFE3F2FD), // Light Blue
    Color(0xFFF3E5F5), // Light Purple
    Color(0xFFE8F5E9), // Light Green
    Color(0xFFFFF3E0), // Light Orange
    Color(0xFFFCE4EC), // Light Pink
    Color(0xFFE0F2F1), // Light Teal
    Color(0xFFFFF9C4), // Light Yellow
    Color(0xFFE1BEE7), // Light Purple 2
    Color(0xFFBBDEFB), // Light Blue 2
    Color(0xFFC8E6C9), // Light Green 2
    Color(0xFFFFCCBC), // Light Orange 2
    Color(0xFFF8BBD0), // Light Pink 2
  ];

  static const List<Color> _teacherBorderColors = [
    Color(0xFF2196F3), // Blue
    Color(0xFF9C27B0), // Purple
    Color(0xFF4CAF50), // Green
    Color(0xFFFF9800), // Orange
    Color(0xFFE91E63), // Pink
    Color(0xFF009688), // Teal
    Color(0xFFFBC02D), // Yellow
    Color(0xFF7B1FA2), // Purple 2
    Color(0xFF1976D2), // Blue 2
    Color(0xFF388E3C), // Green 2
    Color(0xFFF57C00), // Orange 2
    Color(0xFFC2185B), // Pink 2
  ];

  // Get color for a teacher based on their ID
  Map<String, Color> _getTeacherColor(int teacherId) {
    final colorIndex = teacherId % _teacherColors.length;
    return {
      'background': _teacherColors[colorIndex],
      'border': _teacherBorderColors[colorIndex],
    };
  }

  // Generate time slots for full day (24 hours) with 30-minute intervals
  List<Map<String, dynamic>> _generateTimeSlots() {
    final List<Map<String, dynamic>> slots = [];
    
    for (int hour = 0; hour < 24; hour++) {
      for (int minute = 0; minute < 60; minute += 30) {
        // Convert to 12-hour format with AM/PM
        String displayTime;
        if (hour == 0) {
          displayTime = '12:${minute.toString().padLeft(2, '0')} AM';
        } else if (hour < 12) {
          displayTime = '$hour:${minute.toString().padLeft(2, '0')} AM';
        } else if (hour == 12) {
          displayTime = '12:${minute.toString().padLeft(2, '0')} PM';
        } else {
          displayTime = '${hour - 12}:${minute.toString().padLeft(2, '0')} PM';
        }
        
        // Create time for comparison
        final timeValue = hour * 60 + minute;
        
        slots.add({
          'hour': hour,
          'minute': minute,
          'display': displayTime,
          'timeValue': timeValue,
        });
      }
    }
    
    return slots;
  }

  // Get events for a specific time slot with memoization
  List<CalendarEventModel> _getEventsForTimeSlot(int hour, int minute) {
    final cacheKey = '$hour:$minute:${widget.selectedDate.millisecondsSinceEpoch}:$_selectedStudent:$_selectedTeacherId';
    if (_eventsCache.containsKey(cacheKey)) {
      return _eventsCache[cacheKey]!;
    }
    
    final dayOfWeek = widget.selectedDate.weekday % 7; // Convert to Sunday=0 format
    final selectedDateString = '${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}';
    final filteredEvents = _filteredEvents;
    
    final events = filteredEvents.where((event) {
      // For exceptional classes, check if the start date matches the selected date
      if (event.isExceptional && event.start != null) {
        if (event.start != selectedDateString) {
          return false;
        }
      } else {
        // For recurring events, check if event occurs on this day of week
        if (!event.daysOfWeek.contains(dayOfWeek)) {
          return false;
        }
      }
      
      // Parse event start time
      try {
        final timeParts = event.startTime.split(':');
        final eventHour = int.parse(timeParts[0]);
        final eventMinute = int.parse(timeParts[1]);
        final eventTimeValue = eventHour * 60 + eventMinute;
        
        // Check if event starts at this time slot
        final slotTimeValue = hour * 60 + minute;
        return eventTimeValue == slotTimeValue;
      } catch (e) {
        return false;
      }
    }).toList();
    
    _eventsCache[cacheKey] = events;
    return events;
  }

  String _formatTime(String time) {
    try {
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

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void didUpdateWidget(CalendarDayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear cache when date or events change
    if (oldWidget.selectedDate != widget.selectedDate || 
        oldWidget.events != widget.events) {
      _eventsCache.clear();
      _cachedFilteredEvents = null;
    }
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
    _teacherSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = '${widget.selectedDate.day}/${widget.selectedDate.month}/${widget.selectedDate.year}';
    final filteredEvents = _filteredEvents;
    
    return BlocListener<CalendarBloc, CalendarState>(
      listenWhen: (previous, current) {
        // Listen to teachers loaded state or when events are loaded (to get cached teachers)
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
      child: Stack(
        children: [
          GestureDetector(
            onTap: () {
              // Unfocus any focused field when tapping outside
              FocusScope.of(context).unfocus();
            },
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
          // Filters Row
          RepaintBoundary(
            child: Container(
            padding: const EdgeInsets.all(AppSizes.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.textTertiary.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Student Filter with Search
                Expanded(
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
                            horizontal: AppSizes.spaceMd,
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
                const SizedBox(width: AppSizes.spaceMd),
                // Teacher Filter with Search
                Expanded(
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
                      
                      return BlocBuilder<CalendarBloc, CalendarState>(
                        buildWhen: (previous, current) {
                          return current is CalendarTeachersLoaded || 
                                 (current is CalendarEventsLoaded && _teachers.isEmpty);
                        },
                        builder: (context, state) {
                          if (state is CalendarTeachersLoaded) {
                            _teachers = state.teachers;
                          } else if (state is CalendarEventsLoaded && _teachers.isEmpty) {
                            // Try to get cached teachers
                            final bloc = context.read<CalendarBloc>();
                            final cachedTeachers = bloc.cachedTeachers;
                            if (cachedTeachers != null && cachedTeachers.isNotEmpty) {
                              _teachers = cachedTeachers;
                            }
                          }
                          
                          if (_teachers.isEmpty) {
                            return TextFormField(
                              controller: _teacherSearchController,
                              decoration: const InputDecoration(
                                labelText: 'المعلم',
                                hintText: 'جاري التحميل...',
                                prefixIcon: Icon(Icons.search, size: 20),
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: AppSizes.spaceMd,
                                  vertical: AppSizes.spaceSm,
                                ),
                                isDense: true,
                              ),
                              enabled: false,
                            );
                          }
                          return Autocomplete<CalendarTeacherModel>(
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
                                    horizontal: AppSizes.spaceMd,
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          ),
          
          // Date Header with Navigation
          RepaintBoundary(
            child: Container(
            padding: const EdgeInsets.all(AppSizes.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.textTertiary.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Previous Day Button
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _isDateChanging ? null : () {
                    setState(() {
                      _isDateChanging = true;
                    });
                    final previousDay = widget.selectedDate.subtract(const Duration(days: 1));
                    widget.onDateChanged?.call(previousDay);
                    Future.delayed(const Duration(milliseconds: 150), () {
                      if (mounted) {
                        setState(() {
                          _isDateChanging = false;
                        });
                      }
                    });
                  },
                  tooltip: 'اليوم السابق',
                  color: AppColors.primary,
                ),
                
                // Date Display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSizes.spaceSm),
                    Text(
                      dateFormat,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                
                // Next Day Button
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _isDateChanging ? null : () {
                    setState(() {
                      _isDateChanging = true;
                    });
                    final nextDay = widget.selectedDate.add(const Duration(days: 1));
                    widget.onDateChanged?.call(nextDay);
                    Future.delayed(const Duration(milliseconds: 150), () {
                      if (mounted) {
                        setState(() {
                          _isDateChanging = false;
                        });
                      }
                    });
                  },
                  tooltip: 'اليوم التالي',
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
          ),
        
        // Time Slots List
        Expanded(
          child: RepaintBoundary(
            child: ListView.builder(
              cacheExtent: 500, // Cache more items
              itemCount: _timeSlots.length,
            itemBuilder: (context, index) {
              final slot = _timeSlots[index];
              final hour = slot['hour'] as int;
              final minute = slot['minute'] as int;
              final displayTime = slot['display'] as String;
              final events = _getEventsForTimeSlot(hour, minute);
              
              return RepaintBoundary(
                key: ValueKey('$hour:$minute'),
                child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.textTertiary.withOpacity(0.1),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time Label
                    Container(
                      width: 100,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.spaceSm,
                        horizontal: AppSizes.spaceMd,
                      ),
                      child: Text(
                        displayTime,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    
                    // Events Grid (2 columns)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.spaceXs,
                          horizontal: AppSizes.spaceXs,
                        ),
                        child: events.isEmpty
                            ? const SizedBox(height: 40)
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  // Calculate item width for 2 columns with spacing
                                  final itemWidth = (constraints.maxWidth - AppSizes.spaceXs) / 2;
                                  
                                  return Wrap(
                                    spacing: AppSizes.spaceXs,
                                    runSpacing: AppSizes.spaceXs,
                                    children: events.map((event) {
                                      final teacherColors = _getTeacherColor(event.teacherId);
                                      
                                      return SizedBox(
                                        width: itemWidth,
                                        child: InkWell(
                                          onTap: () => _showEventDetails(context, event),
                                          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                                          child: Container(
                                            padding: const EdgeInsets.all(AppSizes.spaceSm),
                                            decoration: BoxDecoration(
                                              color: teacherColors['background'],
                                              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                                              border: Border.all(
                                                color: teacherColors['border']!,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  event.studentName,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.access_time_rounded,
                                                      size: 11,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(
                                                        event.endTime != null && event.endTime!.isNotEmpty
                                                            ? '${_formatTime(event.startTime)}-${_formatTime(event.endTime!)}'
                                                            : _formatTime(event.startTime),
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: AppColors.textSecondary,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (event.teacherName.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.school_rounded,
                                                        size: 11,
                                                        color: AppColors.textSecondary,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          event.teacherName,
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: AppColors.textSecondary,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              );
            },
            ),
          ),
        ),
        ],
            ),
          ),
          if (_isDateChanging)
            Container(
              color: Colors.black.withOpacity(0.2),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
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
