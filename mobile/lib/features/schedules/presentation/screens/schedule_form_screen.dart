import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

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

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      if (_startDate == null || _endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء اختيار تاريخ البداية والنهاية'), backgroundColor: AppColors.coral),
        );
        return;
      }
      
      // Navigate back and show success
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحفظ بنجاح'), backgroundColor: AppColors.success),
      );
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
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('حفظ الجدول', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
