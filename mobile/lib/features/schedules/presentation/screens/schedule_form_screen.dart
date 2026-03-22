import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../data/schedule_repository.dart';
import '../../data/models/schedule_model.dart';

class ScheduleFormScreen extends StatefulWidget {
  final int? scheduleId; // null = create new
  const ScheduleFormScreen({super.key, this.scheduleId});

  @override
  State<ScheduleFormScreen> createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends State<ScheduleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isActive = true;
  DateTime? _startDate;
  DateTime? _endDate;

  bool _loading = false;
  bool _saving = false;
  ScheduleModel? _loadedSchedule;

  @override
  void initState() {
    super.initState();
    if (widget.scheduleId != null) {
      _loadSchedule();
    } else {
      final now = DateTime.now();
      _startDate = now;
      _endDate = now.add(const Duration(days: 90));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _loading = true;
    });
    try {
      final repo = getIt<ScheduleRepository>();
      final schedule = await repo.getSchedule(widget.scheduleId!);
      if (!mounted) return;
      _loadedSchedule = schedule;
      _nameController.text = schedule.name;
      _descriptionController.text = schedule.description ?? '';
      _isActive = schedule.isActive;
      _startDate = schedule.startDate ?? DateTime.now();
      _endDate = schedule.endDate ?? _startDate!.add(const Duration(days: 90));
      setState(() {
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل تحميل بيانات الجدول'),
          backgroundColor: AppColors.coral,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار تاريخ البداية والنهاية'),
          backgroundColor: AppColors.coral,
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      'start_date':
          '${_startDate!.year.toString().padLeft(4, '0')}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}',
      'end_date':
          '${_endDate!.year.toString().padLeft(4, '0')}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}',
      'is_active': _isActive,
    };

    final repo = getIt<ScheduleRepository>();
    final isEditing = widget.scheduleId != null;

    try {
      if (isEditing) {
        await repo.updateSchedule(widget.scheduleId!, payload);
      } else {
        await repo.createSchedule(payload);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'تم تحديث الجدول بنجاح' : 'تم إنشاء الجدول بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل حفظ الجدول'),
          backgroundColor: AppColors.coral,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final initialDate = isStart 
        ? (_startDate ?? DateTime.now()) 
        : (_endDate ?? (_startDate ?? DateTime.now()).add(const Duration(days: 90)));
        
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.darkCard,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.scheduleId != null;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'تعديل الجدول' : 'إضافة جدول جديد'),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'تعديل الجدول' : 'إضافة جدول جديد'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Active Toggle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: const Text('حالة الجدول', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(_isActive ? 'نشط' : 'متوقف', style: TextStyle(color: _isActive ? AppColors.success : AppColors.textSecondary)),
                value: _isActive,
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                onChanged: (val) => setState(() => _isActive = val),
              ),
            ),
            const SizedBox(height: 20),

            // Name
            const Text('اسم الجدول', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'مثال: جدول الفصل الدراسي الأول',
                filled: true,
                fillColor: AppColors.darkCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 20),

            // Date Range
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تاريخ البداية', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _selectDate(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.darkCard,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                _startDate != null ? '${_startDate!.year}/${_startDate!.month}/${_startDate!.day}' : 'اختر التاريخ',
                                style: TextStyle(color: _startDate != null ? AppColors.textPrimary : AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تاريخ النهاية', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _selectDate(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.darkCard,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                _endDate != null ? '${_endDate!.year}/${_endDate!.month}/${_endDate!.day}' : 'اختر التاريخ',
                                style: TextStyle(color: _endDate != null ? AppColors.textPrimary : AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Description
            const Text('وصف الجدول (اختياري)', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'أضف وصفاً للجدول...',
                filled: true,
                fillColor: AppColors.darkCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isEditing ? 'تحديث الجدول' : 'حفظ الجدول',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
