import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Form for adding a SINGLE, non-repeating class session for a specific date.
class SingleClassSessionForm extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onSave;

  const SingleClassSessionForm({super.key, required this.onSave});

  @override
  State<SingleClassSessionForm> createState() => _SingleClassSessionFormState();
}

class _SingleClassSessionFormState extends State<SingleClassSessionForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _teacherController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 16, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  @override
  void dispose() {
    _titleController.dispose();
    _teacherController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onSave({
        'title': _titleController.text.trim(),
        'teacher_name': _teacherController.text.trim().isEmpty ? null : _teacherController.text.trim(),
        'session_date': _selectedDate,
        'start_time': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
        'end_time': '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
      });
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.event_available, color: AppColors.primary),
                SizedBox(width: 8),
                Text('إضافة حصة مفردة (يوم واحد)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 24),

            // Date Picker
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) setState(() => _selectedDate = date);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.darkCardElevated),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('تاريخ الحصة', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(
                            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Time Pickers
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: _startTime);
                      if (t != null) setState(() => _startTime = t);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.darkCardElevated)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('من الساعة', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: _endTime);
                      if (t != null) setState(() => _endTime = t);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.darkCardElevated)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('إلى الساعة', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'المادة / عنوان الحصة',
                prefixIcon: const Icon(Icons.book_outlined),
                filled: true,
                fillColor: AppColors.darkCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),

            // Teacher
            TextFormField(
              controller: _teacherController,
              decoration: InputDecoration(
                labelText: 'اسم المعلم (اختياري)',
                prefixIcon: const Icon(Icons.person_outline),
                filled: true,
                fillColor: AppColors.darkCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),

            // Save
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('إضافة الحصة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
