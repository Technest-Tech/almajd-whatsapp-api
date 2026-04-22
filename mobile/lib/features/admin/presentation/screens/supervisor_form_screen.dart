import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/admin_repository.dart';

// ── Shift state for one day ───────────────────────────────────────────────────
class _ShiftDay {
  final int dayOfWeek;
  bool isActive;
  TimeOfDay startTime;
  TimeOfDay endTime;

  _ShiftDay({
    required this.dayOfWeek,
    required this.isActive,
    required this.startTime,
    required this.endTime,
  });

  static _ShiftDay defaultFor(int day) => _ShiftDay(
        dayOfWeek: day,
        isActive: false,
        startTime: const TimeOfDay(hour: 8, minute: 0),
        endTime: const TimeOfDay(hour: 16, minute: 0),
      );

  Map<String, dynamic> toPayload() => {
        'day_of_week': dayOfWeek,
        'start_time': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
        'end_time': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
        'is_active': isActive,
      };
}

// ── Screen ────────────────────────────────────────────────────────────────────
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

  final List<_ShiftDay> _shifts = List.generate(7, _ShiftDay.defaultFor);

  static const _dayNames = [
    'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء',
    'الخميس', 'الجمعة', 'السبت',
  ];

  bool get isEditing => widget.supervisorId != null && widget.supervisorId! > 0;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final repo = getIt<AdminRepository>();
      final results = await Future.wait([
        repo.getSupervisor(widget.supervisorId!),
        repo.getShifts(widget.supervisorId!),
      ]);

      final data = results[0] as Map<String, dynamic>;
      final shiftsRaw = results[1] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _name = data['name'];
          _email = data['email'];
          _phone = data['phone'];

          for (final s in shiftsRaw) {
            final day = (s['day_of_week'] as num).toInt();
            if (day < 0 || day > 6) continue;
            final start = _parseTime(s['start_time'] as String? ?? '08:00');
            final end   = _parseTime(s['end_time']   as String? ?? '16:00');
            _shifts[day] = _ShiftDay(
              dayOfWeek: day,
              isActive: s['is_active'] == true,
              startTime: start,
              endTime: end,
            );
          }

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

  TimeOfDay _parseTime(String t) {
    final parts = t.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  Future<void> _pickTime(int dayIndex, bool isStart) async {
    // Dismiss keyboard and unfocus any text field before opening the picker
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 50));

    final current = isStart ? _shifts[dayIndex].startTime : _shifts[dayIndex].endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
        child: Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _shifts[dayIndex].startTime = picked;
        // Auto-fix: if end is now <= start, push end forward by 1 hour (cap at 23:59)
        final endMinutes   = _shifts[dayIndex].endTime.hour * 60 + _shifts[dayIndex].endTime.minute;
        final startMinutes = picked.hour * 60 + picked.minute;
        if (endMinutes <= startMinutes) {
          final newHour = picked.hour + 1;
          _shifts[dayIndex].endTime = newHour >= 24
              ? const TimeOfDay(hour: 23, minute: 59)
              : TimeOfDay(hour: newHour, minute: picked.minute);
        }
      } else {
        _shifts[dayIndex].endTime = picked;
      }
    });
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

      int supervisorId;
      if (isEditing) {
        await repo.updateSupervisor(widget.supervisorId!, payload);
        supervisorId = widget.supervisorId!;
      } else {
        final created = await repo.createSupervisor(payload);
        supervisorId = (created['id'] as num).toInt();
      }

      await repo.updateShifts(supervisorId, _shifts.map((s) => s.toPayload()).toList());

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
                    // ── Account Info ──────────────────────────────
                    const Text('معلومات الحساب',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
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

                    // ── Password ──────────────────────────────────
                    const SizedBox(height: 32),
                    const Text('كلمة المرور',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (isEditing)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'اترك الحقل فارغاً إذا لم تكن ترغب بتغيير كلمة المرور',
                          style: TextStyle(color: AppColors.amber, fontSize: 12),
                        ),
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

                    // ── Work Shifts ───────────────────────────────
                    const SizedBox(height: 32),
                    const Text('أوقات العمل',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text(
                      'حدد الأيام وساعات العمل للمشرف',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.darkCardElevated,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: List.generate(7, (i) => _buildShiftRow(i)),
                      ),
                    ),

                    // ── Save Button ───────────────────────────────
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
                            ? const SizedBox(
                                height: 24, width: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                isEditing ? 'حفظ التعديلات' : 'إضافة المشرف',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildShiftRow(int i) {
    final shift = _shifts[i];
    final isLast = i == 6;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: day name + toggle
              Row(
                children: [
                  Text(
                    _dayNames[i],
                    style: TextStyle(
                      color: shift.isActive ? Colors.white : AppColors.textSecondary,
                      fontWeight: shift.isActive ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: shift.isActive,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _shifts[i].isActive = v),
                  ),
                ],
              ),
              // Time row — only shown when active
              if (shift.isActive)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTimeTap(i, isStart: true),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('–', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ),
                      _buildTimeTap(i, isStart: false),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, color: Color(0xFF2A2A3A), indent: 16, endIndent: 16),
      ],
    );
  }

  String _formatTime12(TimeOfDay time) {
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  Widget _buildTimeTap(int dayIndex, {required bool isStart}) {
    final time = isStart ? _shifts[dayIndex].startTime : _shifts[dayIndex].endTime;
    final label = _formatTime12(time);

    return GestureDetector(
      onTap: () => _pickTime(dayIndex, isStart),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.darkBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Text(label, style: const TextStyle(color: AppColors.primary, fontSize: 12)),
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
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1)),
      ),
      validator: validator,
      onSaved: onSaved,
    );
  }
}
