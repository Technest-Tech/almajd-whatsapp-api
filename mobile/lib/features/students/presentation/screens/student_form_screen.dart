import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../data/student_repository.dart';
import '../../data/models/student_model.dart';

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
  final _whatsappController = TextEditingController();
  final _notesController = TextEditingController();
  String _status = 'active';
  bool _isSaving = false;
  bool _isLoadingStudent = false;

  String? _selectedCountry;
  String? _selectedCurrency;

  static const _statusOptions = [
    {'key': 'active', 'label': 'نشط'},
    {'key': 'inactive', 'label': 'غير نشط'},
    {'key': 'suspended', 'label': 'موقوف'},
  ];

  static const _countries = [
    'السعودية', 'الإمارات', 'مصر', 'الكويت', 'قطر', 'البحرين', 'عُمان',
    'الأردن', 'لبنان', 'سوريا', 'العراق', 'اليمن', 'ليبيا', 'تونس',
    'الجزائر', 'المغرب', 'السودان', 'موريتانيا', 'الصومال', 'جيبوتي',
    'فلسطين', 'تركيا', 'باكستان', 'أفغانستان', 'إيران', 'إندونيسيا',
    'ماليزيا', 'نيجيريا', 'السنغال', 'المملكة المتحدة', 'أمريكا', 'كندا',
    'أستراليا', 'ألمانيا', 'فرنسا', 'هولندا', 'السويد', 'النرويج',
    'الدنمارك', 'بلجيكا', 'سويسرا', 'النمسا', 'إسبانيا', 'إيطاليا',
  ];

  static const _currencies = [
    'SAR - ريال سعودي', 'AED - درهم إماراتي', 'EGP - جنيه مصري',
    'KWD - دينار كويتي', 'QAR - ريال قطري', 'BHD - دينار بحريني',
    'OMR - ريال عُماني', 'JOD - دينار أردني', 'LBP - ليرة لبنانية',
    'USD - دولار أمريكي', 'GBP - جنيه إسترليني', 'EUR - يورو',
    'CAD - دولار كندي', 'AUD - دولار أسترالي', 'TRY - ليرة تركية',
    'IQD - دينار عراقي', 'DZD - دينار جزائري', 'MAD - درهم مغربي',
    'TND - دينار تونسي', 'SDG - جنيه سوداني', 'PKR - روبية باكستانية',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadStudentForEdit();
    }
  }

  Future<void> _loadStudentForEdit() async {
    setState(() => _isLoadingStudent = true);
    try {
      final student = await getIt<StudentRepository>().getStudent(widget.studentId!);
      if (mounted) {
        setState(() {
          _nameController.text = student.name;
          _whatsappController.text = student.whatsappNumber ?? '';
          _notesController.text = student.notes ?? '';
          _status = student.status;
          _selectedCountry = student.country;
          // Match stored code (e.g. "SAR") with the full dropdown label
          if (student.currency != null) {
            _selectedCurrency = _currencies.firstWhere(
              (c) => c.startsWith(student.currency!),
              orElse: () => student.currency!,
            );
          }
          _isLoadingStudent = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStudent = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStudent) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.isEditing ? 'تعديل الطالب' : 'إضافة طالب')),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

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

            // Whatsapp
            TextFormField(
              controller: _whatsappController,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رقم واتساب',
                prefixIcon: Icon(Icons.chat_outlined),
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

            // Country (Searchable DropdownMenu)
            _buildLabel('البلد', Icons.public_outlined),
            const SizedBox(height: 6),
            DropdownMenu<String>(
              key: ValueKey('country_$_selectedCountry'),
              width: MediaQuery.of(context).size.width - 32,
              initialSelection: _selectedCountry,
              hintText: 'ابحث واختر البلد',
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: AppColors.darkCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              dropdownMenuEntries: _countries
                  .map((c) => DropdownMenuEntry(value: c, label: c))
                  .toList(),
              onSelected: (v) => setState(() => _selectedCountry = v),
            ),
            const SizedBox(height: 12),

            // Currency (Searchable DropdownMenu)
            _buildLabel('العملة', Icons.payments_outlined),
            const SizedBox(height: 6),
            DropdownMenu<String>(
              key: ValueKey('currency_$_selectedCurrency'),
              width: MediaQuery.of(context).size.width - 32,
              initialSelection: _selectedCurrency,
              hintText: 'ابحث واختر العملة',
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: AppColors.darkCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              dropdownMenuEntries: _currencies
                  .map((c) => DropdownMenuEntry(value: c, label: c))
                  .toList(),
              onSelected: (v) => setState(() => _selectedCurrency = v),
            ),
            const SizedBox(height: 12),

            // Status
            DropdownButtonFormField<String>(
              value: _status,
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

  Widget _buildLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      ],
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
      // Extract just the currency code (e.g. "SAR" from "SAR - ريال سعودي")
      final currencyCode = _selectedCurrency?.split(' - ').first;
      final data = {
        'name': _nameController.text.trim(),
        'whatsapp_number': _whatsappController.text.trim(),
        'country': _selectedCountry ?? '',
        'currency': currencyCode ?? '',
        'status': _status,
        'notes': _notesController.text.trim(),
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
