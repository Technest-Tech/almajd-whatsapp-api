import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/admin_repository.dart';

class SupervisorFormScreen extends StatefulWidget {
  final int? supervisorId;
  const SupervisorFormScreen({super.key, this.supervisorId});

  @override
  State<SupervisorFormScreen> createState() => _SupervisorFormScreenState();
}

class _SupervisorFormScreenState extends State<SupervisorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  bool _loading = false;
  bool _saving = false;
  
  String? _name;
  String? _email;
  String? _phone;
  String? _password;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadData();
      });
    }
  }

  bool get isEditing => widget.supervisorId != null && widget.supervisorId! > 0;

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await getIt<AdminRepository>().getSupervisor(widget.supervisorId!);
      if (mounted) {
        setState(() {
          _name = data['name'];
          _email = data['email'];
          _phone = data['phone'];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل في جلب بيانات المشرف')),
        );
        context.pop();
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _saving = true);

    try {
      final repo = getIt<AdminRepository>();
      final payload = {
        'name': _name,
        'email': _email,
        'phone': _phone,
        if (_password != null && _password!.isNotEmpty) 'password': _password,
      };

      if (isEditing) {
        await repo.updateSupervisor(widget.supervisorId!, payload);
      } else {
        await repo.createSupervisor(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? 'تم تحديث المشرف بنجاح' : 'تم إضافة المشرف بنجاح')),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء الحفظ. تأكد من صحة البيانات.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text(isEditing ? 'تعديل بيانات المشرف' : 'إضافة مشرف جديد'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('معلومات الحساب', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'الاسم بالكامل',
                      initialValue: _name,
                      icon: Icons.person_outline,
                      validator: (v) => v == null || v.isEmpty ? 'الاسم مطلوب' : null,
                      onSaved: (v) => _name = v,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'البريد الإلكتروني',
                      initialValue: _email,
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'الإيميل مطلوب';
                        if (!v.contains('@')) return 'إيميل غير صالح';
                        return null;
                      },
                      onSaved: (v) => _email = v,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'رقم الهاتف (اختياري)',
                      initialValue: _phone,
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      onSaved: (v) => _phone = v,
                    ),
                    const SizedBox(height: 32),
                    const Text('كلمة المرور', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (isEditing)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text('اترك الحقل فارغاً إذا لم تكن ترغب بتغيير كلمة المرور', style: TextStyle(color: AppColors.amber, fontSize: 12)),
                      ),
                    _buildTextField(
                      label: 'كلمة السر',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      validator: (v) {
                        if (!isEditing && (v == null || v.isEmpty)) return 'كلمة المرور مطلوبة';
                        if (v != null && v.isNotEmpty && v.length < 8) return 'يجب أن لا تقل عن 8 أحرف';
                        return null;
                      },
                      onSaved: (v) => _password = v,
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _saving
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(isEditing ? 'حفظ التعديلات' : 'إضافة المشرف', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    String? initialValue,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
    void Function(String?)? onSaved,
  }) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.primary.withValues(alpha: 0.7)),
        filled: true,
        fillColor: AppColors.darkCardElevated,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1)),
      ),
      validator: validator,
      onSaved: onSaved,
    );
  }
}
