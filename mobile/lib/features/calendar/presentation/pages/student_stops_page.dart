import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../widgets/modern_sidebar.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/calendar_student_stop_model.dart';
import '../../data/repositories/calendar_repository_impl.dart';
import '../../data/datasources/calendar_remote_datasource.dart';
import '../../../../core/utils/api_service.dart';

class StudentStopsPage extends StatefulWidget {
  const StudentStopsPage({super.key});

  @override
  State<StudentStopsPage> createState() => _StudentStopsPageState();
}

class _StudentStopsPageState extends State<StudentStopsPage>
    with SingleTickerProviderStateMixin {
  bool _isSidebarOpen = false;
  late AnimationController _animationController;
  late Animation<double> _sidebarAnimation;
  late Animation<double> _blurAnimation;
  List<String> _studentsList = [];
  bool _isLoadingStudents = false;

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
    
    // Load student stops
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CalendarBloc>().add(const LoadStudentStops());
        _loadStudentsList();
      }
    });
  }

  Future<void> _loadStudentsList() async {
    setState(() {
      _isLoadingStudents = true;
    });
    try {
      final apiService = ApiService();
      final remoteDataSource = CalendarRemoteDataSourceImpl(apiService);
      final students = await remoteDataSource.getStudentsList();
      if (mounted) {
        setState(() {
          _studentsList = students;
          _isLoadingStudents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStudents = false;
        });
      }
    }
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

  void _showAddStudentStopDialog() async {
    // Show loading dialog immediately if students need to be loaded
    if (_studentsList.isEmpty && !_isLoadingStudents) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
      
      await _loadStudentsList();
      
      // Close loading dialog
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }

    if (!mounted) return;

    // Also show loading if students are currently being loaded
    if (_isLoadingStudents) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
      // Wait for loading to complete
      while (_isLoadingStudents && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      // Close loading dialog
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }

    if (!mounted) return;

    // Capture the bloc before showing the dialog
    final bloc = context.read<CalendarBloc>();

    final _formKey = GlobalKey<FormState>();
    String? _selectedStudent;
    DateTime? _dateFrom;
    DateTime? _dateTo;
    final _reasonController = TextEditingController();
    bool _isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {

          return AlertDialog(
            title: const Text('إضافة توقف طالب'),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Student Name Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedStudent,
                      decoration: const InputDecoration(
                        labelText: 'اسم الطالب *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                      isExpanded: true,
                      items: _studentsList.map((student) {
                        return DropdownMenuItem<String>(
                          value: student,
                          child: Text(
                            student,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      selectedItemBuilder: (BuildContext context) {
                        return _studentsList.map((student) {
                          return Text(
                            student,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          );
                        }).toList();
                      },
                      onChanged: (value) {
                        setDialogState(() {
                          _selectedStudent = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى اختيار اسم الطالب';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: AppSizes.spaceMd),
                  // Date From
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setDialogState(() {
                          _dateFrom = date;
                          if (_dateTo != null && _dateTo!.isBefore(_dateFrom!)) {
                            _dateTo = null;
                          }
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'من تاريخ *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today_rounded),
                      ),
                      child: Text(
                        _dateFrom != null
                            ? '${_dateFrom!.year}-${_dateFrom!.month.toString().padLeft(2, '0')}-${_dateFrom!.day.toString().padLeft(2, '0')}'
                            : 'اختر التاريخ',
                        style: TextStyle(
                          color: _dateFrom != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceMd),
                  // Date To
                  InkWell(
                    onTap: _dateFrom == null
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _dateFrom ?? DateTime.now(),
                              firstDate: _dateFrom ?? DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setDialogState(() {
                                _dateTo = date;
                              });
                            }
                          },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'إلى تاريخ *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today_rounded),
                      ),
                      child: Text(
                        _dateTo != null
                            ? '${_dateTo!.year}-${_dateTo!.month.toString().padLeft(2, '0')}-${_dateTo!.day.toString().padLeft(2, '0')}'
                            : 'اختر التاريخ',
                        style: TextStyle(
                          color: _dateTo != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceMd),
                  // Reason
                  TextFormField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: 'السبب (اختياري)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note_rounded),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      if (_formKey.currentState!.validate() &&
                          _selectedStudent != null &&
                          _dateFrom != null &&
                          _dateTo != null) {
                        if (_dateTo!.isBefore(_dateFrom!)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تاريخ النهاية يجب أن يكون بعد تاريخ البداية'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setDialogState(() {
                          _isSubmitting = true;
                        });

                        final stop = CalendarStudentStopModel(
                          id: 0,
                          studentName: _selectedStudent!,
                          dateFrom: _dateFrom!,
                          dateTo: _dateTo!,
                          reason: _reasonController.text.isEmpty
                              ? null
                              : _reasonController.text,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );

                        bloc.add(CreateStudentStop(stop));
                        // Dialog will be closed by the listener when operation succeeds
                      }
                    },
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('إضافة'),
            ),
          ],
          );
        },
      ),
    );
  }

  void _showEditStudentStopDialog(CalendarStudentStopModel stop) {
    // Capture the bloc before showing the dialog
    final bloc = context.read<CalendarBloc>();
    
    final _formKey = GlobalKey<FormState>();
    String? _selectedStudent = stop.studentName;
    DateTime? _dateFrom = stop.dateFrom;
    DateTime? _dateTo = stop.dateTo;
    final _reasonController = TextEditingController(text: stop.reason);
    bool _isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تعديل توقف طالب'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Student Name Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedStudent,
                    decoration: const InputDecoration(
                      labelText: 'اسم الطالب *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                    isExpanded: true,
                    items: _studentsList.map((student) {
                      return DropdownMenuItem<String>(
                        value: student,
                        child: Text(
                          student,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    selectedItemBuilder: (BuildContext context) {
                      return _studentsList.map((student) {
                        return Text(
                          student,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        );
                      }).toList();
                    },
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedStudent = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى اختيار اسم الطالب';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSizes.spaceMd),
                  // Date From
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dateFrom ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setDialogState(() {
                          _dateFrom = date;
                          if (_dateTo != null && _dateTo!.isBefore(_dateFrom!)) {
                            _dateTo = null;
                          }
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'من تاريخ *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today_rounded),
                      ),
                      child: Text(
                        _dateFrom != null
                            ? '${_dateFrom!.year}-${_dateFrom!.month.toString().padLeft(2, '0')}-${_dateFrom!.day.toString().padLeft(2, '0')}'
                            : 'اختر التاريخ',
                        style: TextStyle(
                          color: _dateFrom != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceMd),
                  // Date To
                  InkWell(
                    onTap: _dateFrom == null
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _dateTo ?? _dateFrom ?? DateTime.now(),
                              firstDate: _dateFrom ?? DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setDialogState(() {
                                _dateTo = date;
                              });
                            }
                          },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'إلى تاريخ *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today_rounded),
                      ),
                      child: Text(
                        _dateTo != null
                            ? '${_dateTo!.year}-${_dateTo!.month.toString().padLeft(2, '0')}-${_dateTo!.day.toString().padLeft(2, '0')}'
                            : 'اختر التاريخ',
                        style: TextStyle(
                          color: _dateTo != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceMd),
                  // Reason
                  TextFormField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: 'السبب (اختياري)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note_rounded),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      if (_formKey.currentState!.validate() &&
                          _selectedStudent != null &&
                          _dateFrom != null &&
                          _dateTo != null) {
                        if (_dateTo!.isBefore(_dateFrom!)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تاريخ النهاية يجب أن يكون بعد تاريخ البداية'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setDialogState(() {
                          _isSubmitting = true;
                        });

                        final updatedStop = stop.copyWith(
                          studentName: _selectedStudent!,
                          dateFrom: _dateFrom!,
                          dateTo: _dateTo!,
                          reason: _reasonController.text.isEmpty
                              ? null
                              : _reasonController.text,
                        );

                        bloc.add(UpdateStudentStop(stop.id, updatedStop));
                        // Dialog will be closed by the listener when operation succeeds
                      }
                    },
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('تحديث'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(CalendarStudentStopModel stop) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف توقف ${stop.studentName}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<CalendarBloc>().add(DeleteStudentStop(stop.id));
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = '/v1/calendar/student-stops';

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content
            Column(
              children: [
                // Header
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
                      IconButton(
                        onPressed: () {
                          context.read<AuthBloc>().add(AuthLogoutRequested());
                          context.go('/login');
                        },
                        icon: const Icon(Icons.logout_rounded, size: 24, color: AppColors.error),
                        tooltip: 'تسجيل الخروج',
                      ),
                      const Expanded(
                        child: Text(
                          'توقفات الطلاب',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_rounded),
                        onPressed: _showAddStudentStopDialog,
                        color: AppColors.primary,
                        tooltip: 'إضافة توقف طالب',
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: BlocConsumer<CalendarBloc, CalendarState>(
                    listener: (context, state) {
                      if (state is CalendarOperationSuccess) {
                        // Close any open dialogs
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تمت العملية بنجاح'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        context.read<CalendarBloc>().add(const LoadStudentStops());
                      } else if (state is CalendarError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    builder: (context, state) {
                      if (state is CalendarLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (state is StudentStopsLoaded) {
                        final stops = state.stops;

                        if (stops.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.pause_circle_outline_rounded,
                                  size: 64,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(height: AppSizes.spaceMd),
                                Text(
                                  'لا توجد توقفات',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(AppColors.primary),
                            headingTextStyle: const TextStyle(color: Colors.white),
                            columns: const [
                              DataColumn(label: Text('اسم الطالب')),
                              DataColumn(label: Text('من تاريخ')),
                              DataColumn(label: Text('إلى تاريخ')),
                              DataColumn(label: Text('السبب')),
                              DataColumn(label: Text('تاريخ الإنشاء')),
                              DataColumn(label: Text('الإجراءات')),
                            ],
                            rows: stops.map((stop) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(stop.studentName)),
                                  DataCell(Text(_formatDate(stop.dateFrom))),
                                  DataCell(Text(_formatDate(stop.dateTo))),
                                  DataCell(Text(stop.reason ?? 'N/A')),
                                  DataCell(Text(_formatDateTime(stop.createdAt))),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_rounded, size: 18),
                                          color: AppColors.primary,
                                          onPressed: () => _showEditStudentStopDialog(stop),
                                          tooltip: 'تعديل',
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_rounded, size: 18),
                                          color: Colors.red,
                                          onPressed: () => _showDeleteConfirmation(stop),
                                          tooltip: 'حذف',
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        );
                      }

                      if (state is CalendarError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: AppColors.accentOrange,
                              ),
                              const SizedBox(height: AppSizes.spaceMd),
                              Text(
                                state.message,
                                style: const TextStyle(color: AppColors.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSizes.spaceMd),
                              ElevatedButton(
                                onPressed: () {
                                  context.read<CalendarBloc>().add(const LoadStudentStops());
                                },
                                child: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        );
                      }

                      return const Center(child: CircularProgressIndicator());
                    },
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
}
