import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../data/student_repository.dart';

class StudentFormScreen extends StatefulWidget {
  final int? studentId; // null = create, not null = edit

  const StudentFormScreen({super.key, this.studentId});

  bool get isEditing => studentId != null;

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  String _status = 'active';
  String _guardianRelation = 'أب';
  bool _isSaving = false;

  static const _statusOptions = [
    {'key': 'active', 'label': 'نشط'},
    {'key': 'inactive', 'label': 'غير نشط'},
    {'key': 'suspended', 'label': 'موقوف'},
  ];

  static const _relationOptions = ['أب', 'أم', 'أخ', 'أخت', 'عم', 'خال', 'جد', 'جدة', 'أخرى'];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'تعديل الطالب' : 'إضافة طالب'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Section: Student Info ──
            _buildSectionHeader('معلومات الطالب', Icons.person),
            const SizedBox(height: 12),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم الطالب *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'الاسم مطلوب';
                if (v.trim().length < 3) return 'الاسم قصير جداً';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Phone
            TextFormField(
              controller: _phoneController,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '+966XXXXXXXXX',
                hintTextDirection: TextDirection.ltr,
              ),
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v != null && v.isNotEmpty && v.length < 10) {
                  return 'رقم الهاتف غير صالح';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Status
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'الحالة',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              dropdownColor: AppColors.darkCard,
              items: _statusOptions.map((opt) {
                return DropdownMenuItem(value: opt['key'], child: Text(opt['label']!));
              }).toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),

            const SizedBox(height: 28),

            // ── Section: Guardian Info ──
            _buildSectionHeader('ولي الأمر', Icons.family_restroom),
            const SizedBox(height: 12),

            // Guardian Name
            TextFormField(
              controller: _guardianNameController,
              decoration: const InputDecoration(
                labelText: 'اسم ولي الأمر',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),

            // Guardian Phone
            TextFormField(
              controller: _guardianPhoneController,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'هاتف ولي الأمر',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '+966XXXXXXXXX',
                hintTextDirection: TextDirection.ltr,
              ),
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v != null && v.isNotEmpty && v.length < 10) {
                  return 'رقم الهاتف غير صالح';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Relation
            DropdownButtonFormField<String>(
              initialValue: _guardianRelation,
              decoration: const InputDecoration(
                labelText: 'صلة القرابة',
                prefixIcon: Icon(Icons.people_outline),
              ),
              dropdownColor: AppColors.darkCard,
              items: _relationOptions.map((r) {
                return DropdownMenuItem(value: r, child: Text(r));
              }).toList(),
              onChanged: (v) => setState(() => _guardianRelation = v!),
            ),

            const SizedBox(height: 28),

            // ── Section: Notes ──
            _buildSectionHeader('ملاحظات', Icons.note_alt_outlined),
            const SizedBox(height: 12),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                prefixIcon: Icon(Icons.note_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 32),

            // ── Save Button ──
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _onSave,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(widget.isEditing ? 'حفظ التعديلات' : 'إضافة الطالب'),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 1, color: AppColors.darkCardElevated),
        ),
      ],
    );
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repo = getIt<StudentRepository>();
      final data = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'status': _status,
        'guardian_name': _guardianNameController.text.trim(),
        'guardian_phone': _guardianPhoneController.text.trim(),
        'notes': _notesController.text.trim(),
        // Note: Relation is not passed yet if the backend doesn't support it directly in store, 
        // but it can be handled via notes or an expanded API later.
      };

      if (widget.isEditing) {
        await repo.updateStudent(widget.studentId!, data);
      } else {
        await repo.createStudent(data);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditing ? 'تم تحديث بيانات الطالب' : 'تم إضافة الطالب بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pop(context, true); // Return true to signal success
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء الحفظ: ${e.toString()}'),
          backgroundColor: AppColors.coral,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
