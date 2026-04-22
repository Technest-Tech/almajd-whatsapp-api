import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../widgets/modern_sidebar.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage>
    with SingleTickerProviderStateMixin {
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _selectedDay;
  DateTime? _selectedDate;
  String? _generatedMessage;
  bool _isDailyReminder = true; // Track if message is from daily or exceptional reminder
  bool _isSidebarOpen = false;
  late AnimationController _animationController;
  late Animation<double> _sidebarAnimation;
  late Animation<double> _blurAnimation;

  final List<String> _days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sidebarAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _blurAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
      if (_isSidebarOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = '/calendar/reminders';
    
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content
            Column(
              children: [
                // Header with menu button
                Container(
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
                      IconButton(
                        icon: const Icon(Icons.menu_rounded),
                        onPressed: _toggleSidebar,
                        color: AppColors.primary,
                      ),
                      const Expanded(
                        child: Text(
                          'التذكيرات',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48), // Balance the menu button
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: BlocListener<CalendarBloc, CalendarState>(
        listener: (context, state) {
          if (state is DailyReminderGenerated) {
            setState(() {
              _generatedMessage = state.message;
              _isDailyReminder = true;
            });
          } else if (state is ExceptionalRemindersLoaded) {
            setState(() {
              _generatedMessage = state.message;
              _isDailyReminder = false;
            });
          } else if (state is CalendarError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Daily Reminder Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.spaceLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        const Text(
                          'تذكير يومي',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSizes.spaceLg),
                        // Start Time Picker
                        InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _startTime ?? TimeOfDay.now(),
                              builder: (context, child) {
                                return MediaQuery(
                                  data: MediaQuery.of(context).copyWith(
                                    alwaysUse24HourFormat: false,
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (time != null) {
                              setState(() {
                                _startTime = time;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'من الساعة',
                              hintText: 'اختر وقت البداية',
                              border: const OutlineInputBorder(),
                              suffixIcon: const Icon(Icons.access_time),
                            ),
                            child: Text(
                              _startTime != null
                                  ? _formatTimeOfDay(_startTime!)
                                  : 'اختر وقت البداية',
                              style: TextStyle(
                                color: _startTime != null
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSizes.spaceMd),
                        // End Time Picker
                        InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _endTime ?? TimeOfDay.now(),
                              builder: (context, child) {
                                return MediaQuery(
                                  data: MediaQuery.of(context).copyWith(
                                    alwaysUse24HourFormat: false,
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (time != null) {
                              setState(() {
                                _endTime = time;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'إلى الساعة',
                              hintText: 'اختر وقت النهاية',
                              border: const OutlineInputBorder(),
                              suffixIcon: const Icon(Icons.access_time),
                            ),
                            child: Text(
                              _endTime != null
                                  ? _formatTimeOfDay(_endTime!)
                                  : 'اختر وقت النهاية',
                              style: TextStyle(
                                color: _endTime != null
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSizes.spaceMd),
                        // Day Selector
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'اليوم',
                            border: OutlineInputBorder(),
                          ),
                          value: _selectedDay,
                          items: _days.map((day) {
                            return DropdownMenuItem(
                              value: day,
                              child: Text(_getArabicDayName(day)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDay = value;
                            });
                          },
                        ),
                        const SizedBox(height: AppSizes.spaceLg),
                        ElevatedButton(
                          onPressed: _generateDailyReminder,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSizes.spaceMd,
                            ),
                          ),
                          child: const Text('إنشاء التذكير'),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: AppSizes.spaceLg),

              // Exceptional Reminder Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.spaceLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'تذكير الحصص الاستثنائية',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSizes.spaceLg),
                      // Date Picker
                      ElevatedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() {
                              _selectedDate = date;
                            });
                            context.read<CalendarBloc>().add(
                                  GetExceptionalReminders(date),
                                );
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _selectedDate != null
                              ? 'التاريخ: ${_selectedDate!.toLocal().toString().split(' ')[0]}'
                              : 'اختر التاريخ',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Generated Message
              if (_generatedMessage != null) ...[
                const SizedBox(height: AppSizes.spaceLg),
                Card(
                  color: Theme.of(context).cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.spaceLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'التذكير المُنشأ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Theme.of(context).textTheme.titleLarge?.color,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              onPressed: () {
                                setState(() {
                                  _generatedMessage = null;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.spaceMd),
                        Container(
                          constraints: const BoxConstraints(
                            maxHeight: 300,
                          ),
                          padding: const EdgeInsets.all(AppSizes.spaceMd),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _generatedMessage!,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                height: 1.5,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSizes.spaceMd),
                        ElevatedButton.icon(
                          onPressed: () => _sendToWhatsApp(_generatedMessage!),
                          icon: const Icon(Icons.send),
                          label: const Text('إرسال إلى واتساب'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
                    ),
                  ),
                ),
              ],
            ),

            // Blur overlay when sidebar is open
            AnimatedBuilder(
              animation: _blurAnimation,
              builder: (context, child) {
                return Visibility(
                  visible: _isSidebarOpen,
                  child: GestureDetector(
                    onTap: _toggleSidebar,
                    child: Container(
                      color: Colors.black.withOpacity(0.3 * _blurAnimation.value),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 5.0 * _blurAnimation.value,
                          sigmaY: 5.0 * _blurAnimation.value,
                        ),
                        child: Container(
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Sidebar overlay
            AnimatedBuilder(
              animation: _sidebarAnimation,
              builder: (context, child) {
                return Positioned(
                  right: -280 * (1 - _sidebarAnimation.value),
                  top: 0,
                  bottom: 0,
                  child: ModernSidebar(
                    currentRoute: currentRoute,
                    onClose: _toggleSidebar,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _generateDailyReminder() {
    if (_startTime == null || _endTime == null || _selectedDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال جميع الحقول')),
      );
      return;
    }
    
    // Convert TimeOfDay to 24-hour format string (HH:mm)
    final startTime24 = _convertTo24Hour(_startTime!);
    final endTime24 = _convertTo24Hour(_endTime!);
    
    context.read<CalendarBloc>().add(
          GenerateDailyReminder(
            startTime: startTime24,
            endTime: endTime24,
            day: _selectedDay!,
          ),
        );
  }
  
  String _convertTo24Hour(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
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

  Future<void> _sendToWhatsApp(String message) async {
    // Use the correct phone numbers from the old system
    // Daily reminders: +201554134201
    // Exceptional reminders: +201207220414
    final phoneNumber = _isDailyReminder ? '+201554134201' : '+201207220414';
    final encodedMessage = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$phoneNumber?text=$encodedMessage');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يمكن فتح واتساب')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في فتح واتساب: $e')),
        );
      }
    }
  }
}
