import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../data/teacher_repository.dart';
import '../../data/models/teacher_model.dart';
import 'package:dio/dio.dart';

class TeacherFormScreen extends StatefulWidget {
  final int? teacherId;

  const TeacherFormScreen({super.key, this.teacherId});

  bool get isEditing => teacherId != null;

  @override
  State<TeacherFormScreen> createState() => _TeacherFormScreenState();
}

class _TeacherFormScreenState extends State<TeacherFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _zoomLinkController = TextEditingController();
  bool _isSaving = false;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadTeacher();
    }
  }

  Future<void> _loadTeacher() async {
    setState(() => _isLoading = true);
    try {
      final teacher = await getIt<TeacherRepository>().getTeacher(widget.teacherId!);
      if (mounted) {
        setState(() {
          _nameController.text = teacher.name;
          _whatsappController.text = teacher.whatsappNumber ?? '';
          _zoomLinkController.text = teacher.zoomLink ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تحميل بيانات المعلم')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    _zoomLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'تعديل المعلم' : 'إضافة معلم'),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Form(
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

            // Whatsapp Number
            TextFormField(
              controller: _whatsappController,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رقم الواتساب *',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '+966XXXXXXXXX',
              ),
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'رقم الواتساب مطلوب';
                }
                if (v.length < 10) {
                  return 'رقم الواتساب غير صالح';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Zoom Link
            TextFormField(
              controller: _zoomLinkController,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رابط الزوم (اختياري)',
                prefixIcon: Icon(Icons.video_call_outlined),
                hintText: 'https://zoom.us/j/1234567890',
              ),
              keyboardType: TextInputType.url,
              validator: (v) {
                if (v != null && v.trim().isNotEmpty) {
                  final uri = Uri.tryParse(v.trim());
                  if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
                    return 'رابط غير صالح';
                  }
                }
                return null;
              },
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
      final repo = getIt<TeacherRepository>();
      final payload = {
        'name': _nameController.text.trim(),
        'whatsapp_number': _whatsappController.text.trim(),
        if (_zoomLinkController.text.trim().isNotEmpty)
          'zoom_link': _zoomLinkController.text.trim(),
      };

      if (widget.isEditing) {
        await repo.updateTeacher(widget.teacherId!, payload);
      } else {
        await repo.createTeacher(payload);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditing ? 'تم تحديث بيانات المعلم' : 'تم إضافة المعلم بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pop(context, true); // Return true to signal a refresh is needed
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ أثناء حفظ بيانات المعلم'),
          backgroundColor: AppColors.coral,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
