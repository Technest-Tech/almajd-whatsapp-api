import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';

class StudentInfoPage extends StatefulWidget {
  final String studentName;
  final String currentStatus;
  final DateTime? reactiveDate;

  const StudentInfoPage({
    super.key,
    required this.studentName,
    required this.currentStatus,
    this.reactiveDate,
  });

  @override
  State<StudentInfoPage> createState() => _StudentInfoPageState();
}

class _StudentInfoPageState extends State<StudentInfoPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedStatus;
  DateTime? _selectedReactiveDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus;
    _selectedReactiveDate = widget.reactiveDate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('معلومات الطالب - ${widget.studentName}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocConsumer<CalendarBloc, CalendarState>(
        listener: (context, state) {
          if (state is CalendarOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم تحديث حالة الطالب بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop();
          } else if (state is CalendarError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
            setState(() {
              _isSubmitting = false;
            });
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.spaceLg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Student Name Display
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.spaceMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'اسم الطالب',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSizes.spaceXs),
                          Text(
                            widget.studentName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceLg),
                  
                  // Status Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'الحالة *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.info_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('نشط'),
                      ),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('غير نشط'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value;
                        if (value == 'active') {
                          _selectedReactiveDate = null;
                        }
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى اختيار الحالة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSizes.spaceLg),
                  
                  // Reactive Date (only if status is inactive)
                  if (_selectedStatus == 'inactive')
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedReactiveDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            _selectedReactiveDate = date;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'تاريخ إعادة التفعيل (اختياري)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today_rounded),
                        ),
                        child: Text(
                          _selectedReactiveDate != null
                              ? '${_selectedReactiveDate!.year}-${_selectedReactiveDate!.month.toString().padLeft(2, '0')}-${_selectedReactiveDate!.day.toString().padLeft(2, '0')}'
                              : 'اختر التاريخ',
                          style: TextStyle(
                            color: _selectedReactiveDate != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSizes.spaceLg),
                  
                  // Submit Button
                  ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            if (_formKey.currentState!.validate() &&
                                _selectedStatus != null) {
                              setState(() {
                                _isSubmitting = true;
                              });
                              
                              context.read<CalendarBloc>().add(
                                    UpdateStudentStatus(
                                      studentName: widget.studentName,
                                      status: _selectedStatus!,
                                      reactiveDate: _selectedReactiveDate,
                                    ),
                                  );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceMd),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('حفظ التغييرات'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
