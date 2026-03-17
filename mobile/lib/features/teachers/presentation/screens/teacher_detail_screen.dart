import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/teacher_model.dart';
import '../../data/teacher_repository.dart';
import '../../../tickets/data/ticket_repository.dart';

class TeacherDetailScreen extends StatefulWidget {
  final int teacherId;

  const TeacherDetailScreen({super.key, required this.teacherId});

  @override
  State<TeacherDetailScreen> createState() => _TeacherDetailScreenState();
}

class _TeacherDetailScreenState extends State<TeacherDetailScreen> {
  TeacherModel? _teacher;
  bool _isLoading = true;
  String? _errorMessage;

  // Grouped classes: Map<StudentId, Map<String, dynamic>>
  // where the map contains the student info and a list of their classes
  Map<int, Map<String, dynamic>> _groupedClasses = {};

  bool _isStartingChat = false;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = getIt<TeacherRepository>();
      
      // Fetch teacher
      _teacher = await repo.getTeacher(widget.teacherId);
      
      // Fetch classes
      final sessions = await repo.getTeacherSessions(widget.teacherId);
      
      // Group classes by student
      _groupedClasses = {};
      
      for (var session in sessions) {
        final student = session['student'];
        if (student == null) continue;
        
        final studentId = student['id'] as int;
        
        if (!_groupedClasses.containsKey(studentId)) {
          _groupedClasses[studentId] = {
            'student_name': student['name'] ?? 'طالب غير محدد',
            'phone': student['phone'],
            'classes': [],
          };
        }
        
        _groupedClasses[studentId]!['classes'].add(session);
      }
      
    } catch (e) {
      _errorMessage = 'فشل تحميل تفاصيل المعلم';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmDelete(TeacherModel teacher) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        title: const Text('حذف المعلم', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('هل أنت متأكد من حذف ${teacher.name}؟', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      
      try {
        await getIt<TeacherRepository>().deleteTeacher(teacher.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف المعلم بنجاح')),
          );
          context.pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل في حذف المعلم')),
          );
        }
      }
    }
  }

  Future<void> _startChat(TeacherModel teacher) async {
    if (teacher.whatsappNumber == null || teacher.whatsappNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد رقم واتساب لهذا المعلم'), backgroundColor: AppColors.coral),
      );
      return;
    }
    setState(() => _isStartingChat = true);
    try {
      final ticketId = await getIt<TicketRepository>().createTicketForTeacher(
        teacher.whatsappNumber!,
      );
      if (mounted) context.push('/tickets/$ticketId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل فتح المحادثة: $e'), backgroundColor: AppColors.coral),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل المعلم')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _teacher == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('خطأ')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.coral),
              const SizedBox(height: 16),
              Text(_errorMessage ?? 'المعلم غير موجود', style: const TextStyle(color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchDetails,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final teacher = _teacher!;

    return Scaffold(
      appBar: AppBar(
        title: Text(teacher.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final result = await context.push('/teachers/${teacher.id}/edit');
              if (result == true) {
                _fetchDetails();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.coral),
            onPressed: () => _confirmDelete(teacher),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDetails,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Teacher Summary Card
            _buildTeacherSummaryCard(teacher),
            
            const SizedBox(height: 24),
            
            // Classes by Student
            Row(
              children: [
                const Icon(Icons.people_alt_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'الطلاب والفصول المخصصة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_groupedClasses.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('لا يوجد دروس مخصصة', style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              ..._groupedClasses.values.map((group) => _buildStudentGroupCard(group)),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherSummaryCard(TeacherModel teacher) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primaryDark.withValues(alpha: 0.3),
            child: Text(
              teacher.name.isNotEmpty ? teacher.name[0] : '?',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            teacher.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (teacher.whatsappNumber != null && teacher.whatsappNumber!.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              textDirection: TextDirection.ltr,
              children: [
                const Icon(Icons.phone, size: 16, color: AppColors.success),
                const SizedBox(width: 8),
                Text(
                  teacher.whatsappNumber!,
                  style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, letterSpacing: 1),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isStartingChat ? null : () => _startChat(teacher),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A884),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isStartingChat
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.chat_rounded, size: 20),
              label: Text(_isStartingChat ? 'جاري الفتح...' : 'بدء محادثة', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentGroupCard(Map<String, dynamic> group) {
    final studentName = group['student_name'];
    final phone = group['phone'];
    final classes = group['classes'] as List;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          title: Text(
            studentName,
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16),
          ),
          subtitle: phone != null 
              ? Text(phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))
              : null,
          childrenPadding: const EdgeInsets.only(bottom: 8, left: 12, right: 12),
          children: [
            Container(color: AppColors.darkCardElevated, height: 1, margin: const EdgeInsets.only(bottom: 8)),
            ...classes.map((cls) => _buildClassItem(cls)),
          ],
        ),
      ),
    );
  }

  Widget _buildClassItem(dynamic cls) {
    final title = cls['title'] ?? 'حصة بدون عنوان';
    final rawDate = cls['session_date'] ?? '';
    final startTime = cls['start_time'] ?? '';
    final endTime = cls['end_time'];
    final status = cls['status'] ?? 'scheduled';
    
    // Format Date
    String dateStr = rawDate;
    try {
      if (rawDate.isNotEmpty) {
        final d = DateTime.parse(rawDate);
        dateStr = DateFormat('dd MMM', 'ar').format(d);
      }
    } catch (_) {}
    
    // Status formatting
    Color statusColor;
    String statusTitle;
    
    switch (status) {
      case 'completed':
        statusColor = AppColors.success;
        statusTitle = 'مكتملة';
        break;
      case 'cancelled':
        statusColor = AppColors.coral;
        statusTitle = 'ملغاة';
        break;
      case 'scheduled':
        statusColor = AppColors.primaryLight;
        statusTitle = 'مجدولة';
        break;
      default:
        statusColor = AppColors.amber;
        statusTitle = 'محجوزة';
    }

    final bool isActive = status != 'cancelled';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? statusColor.withValues(alpha: 0.08)
            : AppColors.darkCardElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border(
            left: BorderSide(color: isActive ? statusColor : AppColors.textSecondary, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isActive
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, size: 11, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                        const SizedBox(width: 3),
                        Text(dateStr, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 11, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                        const SizedBox(width: 3),
                        Text(
                          endTime != null ? '$startTime - $endTime' : '$startTime',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('ملغاة',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            )
          else 
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                statusTitle,
                style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
