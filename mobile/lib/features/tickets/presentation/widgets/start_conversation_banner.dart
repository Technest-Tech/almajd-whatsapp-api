import 'package:flutter/material.dart';
import '../../../templates/data/models/template_model.dart';
import '../../../templates/data/template_repository.dart';
import '../../../../core/di/injection.dart';

/// Shown in the chat input area when there is NO active session window
/// (i.e. the contact has never messaged or it was more than 24h ago).
/// The agent must send a pre-approved template to open a conversation.
class StartConversationBanner extends StatelessWidget {
  final int ticketId;
  final VoidCallback onTemplateSent;

  const StartConversationBanner({
    super.key,
    required this.ticketId,
    required this.onTemplateSent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      color: const Color(0xFF1F2C34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3942),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, color: Color(0xFF8696A0), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'جلسة واتساب منتهية — يجب إرسال قالب مُعتمد لبدء محادثة جديدة.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A884),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('بدء محادثة بقالب', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showTemplatePicker(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTemplatePicker(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1F2C34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TemplatePickerSheet(
        ticketId: ticketId,
        onSent: onTemplateSent,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Template Picker Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _TemplatePickerSheet extends StatefulWidget {
  final int ticketId;
  final VoidCallback onSent;

  const _TemplatePickerSheet({required this.ticketId, required this.onSent});

  @override
  State<_TemplatePickerSheet> createState() => _TemplatePickerSheetState();
}

class _TemplatePickerSheetState extends State<_TemplatePickerSheet> {
  final _repo = getIt<TemplateRepository>();
  List<TemplateModel> _templates = [];
  bool _loading = true;

  TemplateModel? _selected;
  final List<TextEditingController> _varControllers = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final list = await _repo.getApprovedTemplates();
      if (mounted) setState(() => _templates = list);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectTemplate(TemplateModel t) {
    for (final c in _varControllers) { c.dispose(); }
    _varControllers.clear();
    for (int i = 0; i < t.variablesSchema.length; i++) {
      _varControllers.add(TextEditingController());
    }
    setState(() => _selected = t);
  }

  Future<void> _send() async {
    if (_selected == null) return;
    setState(() => _sending = true);
    try {
      final vars = _varControllers.map((c) => c.text.trim()).toList();
      await _repo.sendTemplate(
        ticketId:   widget.ticketId,
        templateId: _selected!.id,
        variables:  vars,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSent();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الإرسال: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    for (final c in _varControllers) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('اختر قالباً', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_selected != null)
                    TextButton(
                      onPressed: () => setState(() { _selected = null; _varControllers.clear(); }),
                      child: const Text('تغيير'),
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A884)))
                  : _templates.isEmpty
                      ? const Center(
                          child: Text('لا توجد قوالب معتمدة.\nأنشئ قالباً من شاشة الإعدادات.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF8696A0))),
                        )
                      : _selected == null
                          ? _buildTemplateList()
                          : _buildVariablesForm(),
            ),
            if (_selected != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A884),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('إرسال القالب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateList() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _templates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final t = _templates[i];
        return InkWell(
          onTap: () => _selectTemplate(t),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3942),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(t.bodyTemplate,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(color: Color(0xFF8696A0), fontSize: 12)),
                if (t.variablesSchema.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('متغيرات: ${t.variablesSchema.length}',
                      style: const TextStyle(color: Color(0xFF00A884), fontSize: 11)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVariablesForm() {
    final t = _selected!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3942),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              t.bodyTemplate,
              textDirection: TextDirection.rtl,
              style: const TextStyle(color: Color(0xFFD1D7DB), fontSize: 13),
            ),
          ),
          if (t.variablesSchema.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('أدخل قيم المتغيرات:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            for (int i = 0; i < t.variablesSchema.length; i++) ...[
              Text('المتغير {{${i + 1}}}', style: const TextStyle(color: Color(0xFF8696A0), fontSize: 12)),
              const SizedBox(height: 4),
              TextField(
                controller: _varControllers[i],
                textDirection: TextDirection.rtl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: t.variablesSchema[i],
                  hintStyle: const TextStyle(color: Color(0xFF8696A0)),
                  filled: true,
                  fillColor: const Color(0xFF0B141A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}
