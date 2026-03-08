import 'package:flutter/material.dart';
import '../../data/models/template_model.dart';
import '../../data/template_repository.dart';
import '../../../../core/di/injection.dart';

/// Admin screen to manage WhatsApp Message Templates.
/// Allows creating templates, submitting for Meta approval, syncing statuses, and deleting.
class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final _repo = getIt<TemplateRepository>();
  List<TemplateModel> _templates = [];
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.getTemplates();
      if (mounted) setState(() => _templates = list);
    } catch (e) {
      if (mounted) _showError('فشل تحميل القوالب');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      final count = await _repo.syncTemplates();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث $count قالب من Twilio'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) _showError('فشل المزامنة');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _submit(TemplateModel template) async {
    try {
      await _repo.submitTemplate(template.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال القالب للمراجعة'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) _showError('فشل الإرسال: $e');
    }
  }

  Future<void> _delete(TemplateModel template) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1F2C34),
        title: const Text('حذف القالب؟', style: TextStyle(color: Colors.white)),
        content: Text('سيتم حذف "${template.name}" نهائياً.', style: const TextStyle(color: Color(0xFF8696A0))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _repo.deleteTemplate(template.id);
      await _load();
    } catch (e) {
      if (mounted) _showError('فشل الحذف');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B141A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2C34),
        elevation: 0,
        title: const Text('قوالب واتساب', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync_rounded),
              tooltip: 'مزامنة الحالات من Twilio',
              onPressed: _sync,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A884)))
          : _templates.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFF00A884),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _templates.length,
                    itemBuilder: (_, i) => _TemplateCard(
                      key: ValueKey(_templates[i].id),
                      template: _templates[i],
                      onSubmit: () => _submit(_templates[i]),
                      onDelete: () => _delete(_templates[i]),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00A884),
        icon: const Icon(Icons.add),
        label: const Text('قالب جديد'),
        onPressed: () => _showCreateSheet(context),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            const Text('لا توجد قوالب بعد', style: TextStyle(color: Color(0xFF8696A0), fontSize: 16)),
            const SizedBox(height: 8),
            const Text('أنشئ قالباً وأرسله للمراجعة من Meta', style: TextStyle(color: Color(0xFF8696A0), fontSize: 13)),
          ],
        ),
      );

  Future<void> _showCreateSheet(BuildContext context) async {
    final result = await showModalBottomSheet<TemplateModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1F2C34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateTemplateSheet(repo: _repo),
    );
    if (result != null) await _load();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Template Card
// ─────────────────────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final TemplateModel template;
  final VoidCallback onSubmit;
  final VoidCallback onDelete;

  const _TemplateCard({super.key, required this.template, required this.onSubmit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2C34),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(template.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('${template.category} • ${template.language}',
                          style: const TextStyle(color: Color(0xFF8696A0), fontSize: 12)),
                    ],
                  ),
                ),
                _StatusChip(status: template.status),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  color: const Color(0xFF2A3942),
                  icon: const Icon(Icons.more_vert, color: Color(0xFF8696A0)),
                  onSelected: (v) {
                    if (v == 'submit') onSubmit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    if (template.isDraft || template.isRejected)
                      const PopupMenuItem(value: 'submit', child: Text('إرسال للمراجعة', style: TextStyle(color: Colors.white))),
                    const PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
          ),
          // Body preview
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0B141A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                template.bodyTemplate,
                style: const TextStyle(color: Color(0xFFD1D7DB), fontSize: 13),
                textDirection: TextDirection.rtl,
              ),
            ),
          ),
          // Rejection reason
          if (template.isRejected && template.rejectionReason != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                'سبب الرفض: ${template.rejectionReason}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Chip
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'approved' => ('✅ معتمد', Colors.green),
      'pending'  => ('⏳ بانتظار', Colors.orange),
      'rejected' => ('❌ مرفوض', Colors.red),
      _          => ('📝 مسودة', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create Template Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreateTemplateSheet extends StatefulWidget {
  final TemplateRepository repo;
  const _CreateTemplateSheet({required this.repo});

  @override
  State<_CreateTemplateSheet> createState() => _CreateTemplateSheetState();
}

class _CreateTemplateSheetState extends State<_CreateTemplateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _bodyCtrl   = TextEditingController();
  final _footerCtrl = TextEditingController();
  String _category  = 'UTILITY';
  String _language  = 'ar';
  bool _saving      = false;

  // Variables detected from body ({{1}}, {{2}}, ...)
  List<String> get _detectedVars {
    final regex = RegExp(r'\{\{(\d+)\}\}');
    final matches = regex.allMatches(_bodyCtrl.text);
    if (matches.isEmpty) return [];
    final max = matches.map((m) => int.parse(m.group(1)!)).reduce((a, b) => a > b ? a : b);
    return List.generate(max, (i) => 'متغير ${i + 1}');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final template = await widget.repo.createTemplate(
        name:             _nameCtrl.text.trim(),
        bodyTemplate:     _bodyCtrl.text.trim(),
        category:         _category,
        language:         _language,
        footerText:       _footerCtrl.text.trim().isEmpty ? null : _footerCtrl.text.trim(),
        variablesSchema:  _detectedVars,
      );
      if (mounted) Navigator.pop(context, template);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الإنشاء: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bodyCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text('قالب جديد', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Name field
              _Field(
                controller: _nameCtrl,
                label: 'اسم القالب (بالإنجليزية، أحرف صغيرة وشرطة سفلية)',
                hint: 'welcome_message',
                validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
              ),

              const SizedBox(height: 12),

              // Category + Language row
              Row(children: [
                Expanded(
                  child: _Dropdown(
                    label: 'التصنيف',
                    value: _category,
                    items: const {'UTILITY': 'خدمية', 'MARKETING': 'تسويقية', 'AUTHENTICATION': 'مصادقة'},
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Dropdown(
                    label: 'اللغة',
                    value: _language,
                    items: const {'ar': 'عربي', 'en': 'إنجليزي'},
                    onChanged: (v) => setState(() => _language = v!),
                  ),
                ),
              ]),

              const SizedBox(height: 12),

              // Body
              _Field(
                controller: _bodyCtrl,
                label: 'نص القالب',
                hint: 'مرحباً {{1}}، أنت تتواصل مع أكاديمية المجد ...',
                maxLines: 5,
                validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
                onChanged: (_) => setState(() {}),
              ),

              if (_detectedVars.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'متغيرات مُكتشفة: ${_detectedVars.length} (${_detectedVars.join(", ")})',
                  style: const TextStyle(color: Color(0xFF00A884), fontSize: 12),
                ),
              ],

              const SizedBox(height: 12),

              // Footer (optional)
              _Field(
                controller: _footerCtrl,
                label: 'ذيل الرسالة (اختياري)',
                hint: 'أكاديمية المجد',
              ),

              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A884),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('إنشاء القالب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared form helpers
// ─────────────────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int? maxLines;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF8696A0), fontSize: 12)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            validator: validator,
            onChanged: onChanged,
            textDirection: TextDirection.rtl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF8696A0)),
              filled: true,
              fillColor: const Color(0xFF0B141A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      );
}

class _Dropdown extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> items;
  final void Function(String?) onChanged;

  const _Dropdown({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF8696A0), fontSize: 12)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B141A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                dropdownColor: const Color(0xFF1F2C34),
                style: const TextStyle(color: Colors.white),
                isExpanded: true,
                onChanged: onChanged,
                items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              ),
            ),
          ),
        ],
      );
}
