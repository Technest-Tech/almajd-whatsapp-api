import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/message_model.dart';
import '../../data/models/ticket_model.dart';
import '../widgets/message_bubble.dart';
import '../widgets/ticket_card.dart';

class TicketDetailScreen extends StatefulWidget {
  final int ticketId;

  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late List<MessageModel> _messages;
  late TicketModel _ticket;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadData() {
    if (AuthBloc.demoMode) {
      _ticket = _demoTicket();
      _messages = _demoMessages();
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── Chat Messages ──
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                image: DecorationImage(
                  image: const AssetImage('assets/chat_bg.png'),
                  fit: BoxFit.cover,
                  opacity: 0.03,
                  onError: (_, __) {},
                ),
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return MessageBubble(message: _messages[index]);
                },
              ),
            ),
          ),

          // ── Input Bar ──
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_forward_ios, size: 20),
        onPressed: () => context.pop(),
      ),
      title: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _ticket.ticketNumber,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: _ticket.status, label: _ticket.statusDisplay),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _ticket.guardianName ?? 'ولي أمر',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      actions: [
        // SLA timer
        if (_ticket.slaDeadline != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SlaTimerPill(deadline: _ticket.slaDeadline!),
          ),
        // Actions menu
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showActionsSheet(context),
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        8, 8, 8,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        border: Border(
          top: BorderSide(color: AppColors.darkCard, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Attachment button
          IconButton(
            icon: const Icon(Icons.attach_file_rounded, color: AppColors.textSecondary),
            onPressed: () => _showAttachmentOptions(context),
          ),

          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: 4,
                minLines: 1,
                textDirection: TextDirection.rtl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'اكتب رسالة...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: _messageController.text.trim().isEmpty
                  ? AppColors.darkCard
                  : AppColors.primary,
              child: IconButton(
                icon: const Icon(Icons.send_rounded, size: 20),
                color: Colors.white,
                onPressed: _messageController.text.trim().isEmpty
                    ? null
                    : _onSendMessage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onSendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(MessageModel(
        id: _messages.length + 100,
        ticketId: widget.ticketId,
        body: text,
        direction: 'outbound',
        deliveryStatus: 'sent',
        createdAt: DateTime.now(),
      ));
    });
    _messageController.clear();
    _scrollToBottom();
    HapticFeedback.lightImpact();

    // Simulate delivery status update
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          final idx = _messages.length - 1;
          _messages[idx] = MessageModel(
            id: _messages[idx].id,
            ticketId: _messages[idx].ticketId,
            body: _messages[idx].body,
            direction: 'outbound',
            deliveryStatus: 'delivered',
            createdAt: _messages[idx].createdAt,
          );
        });
      }
    });
  }

  void _showActionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Text(
              'إجراءات التذكرة',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),

            _ActionTile(
              icon: Icons.person_add_rounded,
              label: 'تعيين مشرف',
              subtitle: 'تعيين التذكرة لمشرف آخر',
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(ctx);
                _showSnackBar('تم التعيين بنجاح');
              },
            ),
            _ActionTile(
              icon: Icons.trending_up_rounded,
              label: 'تصعيد',
              subtitle: 'تصعيد التذكرة للمشرف الأول',
              color: AppColors.coral,
              onTap: () {
                Navigator.pop(ctx);
                _showSnackBar('تم التصعيد بنجاح');
              },
            ),
            _ActionTile(
              icon: Icons.swap_horiz_rounded,
              label: 'تغيير الحالة',
              subtitle: 'تغيير حالة التذكرة',
              color: AppColors.amber,
              onTap: () {
                Navigator.pop(ctx);
                _showStatusPicker();
              },
            ),
            _ActionTile(
              icon: Icons.note_add_rounded,
              label: 'إضافة ملاحظة داخلية',
              subtitle: 'ملاحظة مرئية فقط للموظفين',
              color: AppColors.primaryLight,
              onTap: () {
                Navigator.pop(ctx);
                _showNoteDialog();
              },
            ),
            _ActionTile(
              icon: Icons.schedule_rounded,
              label: 'تعيين متابعة',
              subtitle: 'تذكير للمتابعة لاحقاً',
              color: AppColors.statusOpen,
              onTap: () {
                Navigator.pop(ctx);
                _showSnackBar('تم تعيين المتابعة');
              },
            ),

            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  void _showStatusPicker() {
    final statuses = [
      {'key': 'open', 'label': 'مفتوح', 'color': AppColors.statusOpen},
      {'key': 'assigned', 'label': 'معين', 'color': AppColors.primary},
      {'key': 'pending', 'label': 'معلق', 'color': AppColors.statusPending},
      {'key': 'resolved', 'label': 'محلول', 'color': AppColors.statusResolved},
      {'key': 'closed', 'label': 'مغلق', 'color': AppColors.statusClosed},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('تغيير الحالة', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 16),
            ...statuses.map((s) => ListTile(
              leading: CircleAvatar(
                radius: 6,
                backgroundColor: s['color'] as Color,
              ),
              title: Text(s['label'] as String),
              selected: _ticket.status == s['key'],
              selectedTileColor: (s['color'] as Color).withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  // Add system message about status change
                  _messages.add(MessageModel(
                    id: _messages.length + 200,
                    ticketId: widget.ticketId,
                    body: 'تم تغيير الحالة إلى ${s['label']}',
                    direction: 'outbound',
                    type: 'system',
                    createdAt: DateTime.now(),
                  ));
                });
                _scrollToBottom();
                _showSnackBar('تم تغيير الحالة إلى ${s['label']}');
              },
            )),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  void _showNoteDialog() {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.amber, size: 20),
            SizedBox(width: 8),
            Text('ملاحظة داخلية', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
            hintText: 'اكتب ملاحظة للفريق...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final note = noteController.text.trim();
              if (note.isNotEmpty) {
                setState(() {
                  _messages.add(MessageModel(
                    id: _messages.length + 300,
                    ticketId: widget.ticketId,
                    body: note,
                    direction: 'outbound',
                    isInternal: true,
                    senderName: 'أحمد المشرف',
                    createdAt: DateTime.now(),
                  ));
                });
                _scrollToBottom();
              }
              Navigator.pop(ctx);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachmentOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'كاميرا',
                  color: AppColors.coral,
                  onTap: () { Navigator.pop(ctx); _showSnackBar('الكاميرا غير متاحة في الوضع التجريبي'); },
                ),
                _AttachmentOption(
                  icon: Icons.photo_library_rounded,
                  label: 'معرض الصور',
                  color: AppColors.primary,
                  onTap: () { Navigator.pop(ctx); _showSnackBar('المعرض غير متاح في الوضع التجريبي'); },
                ),
                _AttachmentOption(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'مستند',
                  color: AppColors.amber,
                  onTap: () { Navigator.pop(ctx); _showSnackBar('المستندات غير متاحة في الوضع التجريبي'); },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Demo Data ──────────────────────────────────────

  TicketModel _demoTicket() {
    final now = DateTime.now();
    return TicketModel(
      id: widget.ticketId,
      ticketNumber: '#TK-${1000 + widget.ticketId}',
      status: 'assigned',
      priority: 'high',
      guardianName: 'فاطمة الزهراء',
      guardianPhone: '+966501112233',
      studentName: 'يوسف أحمد',
      lastMessage: 'السلام عليكم',
      unreadCount: 0,
      assignedToName: 'أحمد المشرف',
      assignedToId: 1,
      createdAt: now.subtract(const Duration(hours: 3)),
      updatedAt: now.subtract(const Duration(minutes: 5)),
      slaDeadline: now.add(const Duration(hours: 2)),
      tags: ['استفسار'],
    );
  }

  List<MessageModel> _demoMessages() {
    final now = DateTime.now();
    return [
      MessageModel(
        id: 1,
        ticketId: widget.ticketId,
        body: 'تم إنشاء التذكرة وتعيينها تلقائياً',
        direction: 'outbound',
        type: 'system',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      MessageModel(
        id: 2,
        ticketId: widget.ticketId,
        body: 'السلام عليكم ورحمة الله وبركاته\nأريد الاستفسار عن مواعيد اختبارات نهاية الفصل لابني يوسف',
        direction: 'inbound',
        senderName: 'فاطمة الزهراء',
        deliveryStatus: 'read',
        createdAt: now.subtract(const Duration(hours: 2, minutes: 50)),
      ),
      MessageModel(
        id: 3,
        ticketId: widget.ticketId,
        body: 'وعليكم السلام ورحمة الله\nأهلاً بكِ أم يوسف، دعيني أتحقق من جدول الاختبارات',
        direction: 'outbound',
        senderName: 'أحمد المشرف',
        deliveryStatus: 'read',
        createdAt: now.subtract(const Duration(hours: 2, minutes: 45)),
      ),
      MessageModel(
        id: 4,
        ticketId: widget.ticketId,
        body: 'تم تغيير الحالة إلى "معين" — أحمد المشرف',
        direction: 'outbound',
        type: 'system',
        createdAt: now.subtract(const Duration(hours: 2, minutes: 44)),
      ),
      MessageModel(
        id: 5,
        ticketId: widget.ticketId,
        body: 'شكراً لكم، هل يمكن معرفة الموعد المحدد لمادة الرياضيات؟',
        direction: 'inbound',
        senderName: 'فاطمة الزهراء',
        deliveryStatus: 'read',
        createdAt: now.subtract(const Duration(hours: 2, minutes: 30)),
      ),
      MessageModel(
        id: 6,
        ticketId: widget.ticketId,
        body: 'يجب التنسيق مع المعلم أولاً بخصوص جدول الاختبارات',
        direction: 'outbound',
        isInternal: true,
        senderName: 'أحمد المشرف',
        createdAt: now.subtract(const Duration(hours: 2, minutes: 20)),
      ),
      MessageModel(
        id: 7,
        ticketId: widget.ticketId,
        body: 'اختبار مادة الرياضيات يوم الأحد القادم الساعة 9 صباحاً\nواختبار اللغة العربية يوم الاثنين الساعة 10 صباحاً',
        direction: 'outbound',
        senderName: 'أحمد المشرف',
        deliveryStatus: 'delivered',
        createdAt: now.subtract(const Duration(hours: 1, minutes: 45)),
      ),
      MessageModel(
        id: 8,
        ticketId: widget.ticketId,
        body: 'جزاكم الله خيراً، هل في اختبارات تانية؟',
        direction: 'inbound',
        senderName: 'فاطمة الزهراء',
        deliveryStatus: 'read',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      MessageModel(
        id: 9,
        ticketId: widget.ticketId,
        body: 'نعم، سأرسل لكِ الجدول الكامل بعد تأكيده مع إدارة المدرسة',
        direction: 'outbound',
        senderName: 'أحمد المشرف',
        deliveryStatus: 'delivered',
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
    ];
  }
}

// ── Reusable Action Tile ──

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}

// ── Attachment Option ──

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
