import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class TeacherFormScreen extends StatefulWidget {
  final int? teacherId; // null = create, not null = edit

  const TeacherFormScreen({super.key, this.teacherId});

  bool get isEditing => teacherId != null;

  @override
  State<TeacherFormScreen> createState() => _TeacherFormScreenState();
}

class _TeacherFormScreenState extends State<TeacherFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  final _subjectInputController = TextEditingController();
  final List<String> _subjects = [];
  String _availability = 'available';
  bool _isSaving = false;

  static const _availabilityOptions = [
    {'key': 'available', 'label': 'متاح'},
    {'key': 'busy', 'label': 'مشغول'},
    {'key': 'offline', 'label': 'غير متصل'},
  ];

  static const _suggestedSubjects = [
    'القرآن الكريم',
    'التجويد',
    'الرياضيات',
    'العلوم',
    'اللغة العربية',
    'النحو والصرف',
    'اللغة الإنجليزية',
    'الحاسب الآلي',
    'البرمجة',
    'التربية الإسلامية',
    'الفيزياء',
    'الكيمياء',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    _subjectInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'تعديل المعلم' : 'إضافة معلم'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Section: Teacher Info ──
            _buildSectionHeader('معلومات المعلم', Icons.person),
            const SizedBox(height: 12),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم المعلم *',
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
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '+966XXXXXXXXX',
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

            // Email
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v != null && v.isNotEmpty && !v.contains('@')) {
                  return 'البريد الإلكتروني غير صالح';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Availability
            DropdownButtonFormField<String>(
              initialValue: _availability,
              decoration: const InputDecoration(
                labelText: 'الحالة',
                prefixIcon: Icon(Icons.circle_outlined),
              ),
              dropdownColor: AppColors.darkCard,
              items: _availabilityOptions.map((opt) {
                return DropdownMenuItem(value: opt['key'], child: Text(opt['label']!));
              }).toList(),
              onChanged: (v) => setState(() => _availability = v!),
            ),

            const SizedBox(height: 28),

            // ── Section: Subjects ──
            _buildSectionHeader('المواد الدراسية', Icons.menu_book),
            const SizedBox(height: 12),

            // Current subjects
            if (_subjects.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _subjects.map((subject) {
                  return Chip(
                    label: Text(subject),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setState(() => _subjects.remove(subject)),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    labelStyle: const TextStyle(color: AppColors.primaryLight, fontSize: 13),
                    deleteIconColor: AppColors.primaryLight,
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Subject input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subjectInputController,
                    decoration: const InputDecoration(
                      hintText: 'أضف مادة...',
                      prefixIcon: Icon(Icons.add_circle_outline),
                    ),
                    onSubmitted: _addSubject,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _addSubject(_subjectInputController.text),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Suggested subjects
            const Text('اقتراحات:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _suggestedSubjects
                  .where((s) => !_subjects.contains(s))
                  .take(6)
                  .map((subject) {
                return ActionChip(
                  label: Text(subject, style: const TextStyle(fontSize: 12)),
                  onPressed: () => setState(() => _subjects.add(subject)),
                  backgroundColor: AppColors.darkCardElevated,
                  side: BorderSide.none,
                );
              }).toList(),
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
                label: Text(widget.isEditing ? 'حفظ التعديلات' : 'إضافة المعلم'),
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

  void _addSubject(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty && !_subjects.contains(trimmed)) {
      setState(() {
        _subjects.add(trimmed);
        _subjectInputController.clear();
      });
    }
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    // Simulate save delay
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.isEditing ? 'تم تحديث بيانات المعلم' : 'تم إضافة المعلم بنجاح'),
        backgroundColor: AppColors.success,
      ),
    );

    Navigator.pop(context);
  }
}
