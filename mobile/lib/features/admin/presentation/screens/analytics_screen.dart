import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/admin_repository.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _adminRepo = getIt<AdminRepository>();
  
  bool _loading = true;
  Map<String, dynamic> _data = {};
  String _selectedFilter = 'الكل'; // 'اليوم', 'هذا الأسبوع', 'هذا الشهر', 'الكل'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    
    try {
      String? fromDate;
      String? toDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      final now = DateTime.now();
      if (_selectedFilter == 'اليوم') {
        fromDate = DateFormat('yyyy-MM-dd').format(now);
      } else if (_selectedFilter == 'هذا الأسبوع') {
        fromDate = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 7)));
      } else if (_selectedFilter == 'هذا الشهر') {
        fromDate = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
      } else {
        fromDate = null; // fetch all time based on backend default (usually 30 days or all)
        toDate = null;
      }

      final response = await _adminRepo.getAnalytics(from: fromDate, to: toDate);
      
      if (mounted) {
        setState(() {
          _data = response;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تحميل التقارير')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/management'),
        ),
        title: const Text('تقارير الأكاديمية', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterRow(),
          Expanded(
            child: _loading 
                ? _buildShimmer() 
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: [
                        _buildSectionHeader('نظرة عامة على الأكاديمية'),
                        const SizedBox(height: 12),
                        _buildOverviewCards(),
                        
                        const SizedBox(height: 24),
                        _buildSectionHeader('إحصائيات الحصص'),
                        const SizedBox(height: 12),
                        _buildSessionsCards(),
                        
                        const SizedBox(height: 24),
                        _buildSectionHeader('الدعم الفني (التذاكر)'),
                        const SizedBox(height: 12),
                        _buildSupportCards(),
                        
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    const filters = ['الكل', 'هذا الشهر', 'هذا الأسبوع', 'اليوم'];
    
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = filter == _selectedFilter;
          return GestureDetector(
            onTap: () {
              if (!isSelected) {
                setState(() => _selectedFilter = filter);
                _load();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.darkCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary.withOpacity(0.3),
                ),
                boxShadow: isSelected ? [
                  BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))
                ] : null,
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildOverviewCards() {
    final overview = _data['overview'] ?? {};
    final students = overview['total_students'] ?? 0;
    final activeStudents = overview['active_students'] ?? 0;
    final teachers = overview['total_teachers'] ?? 0;
    final schedules = overview['total_schedules'] ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _PremiumStatCard(
                title: 'الطلاب',
                value: '$students',
                subtitle: '$activeStudents نشط',
                icon: Icons.school_rounded,
                colors: const [Color(0xFF00B4DB), Color(0xFF0083B0)],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PremiumStatCard(
                title: 'المعلمون',
                value: '$teachers',
                subtitle: 'إجمالي الكادر',
                icon: Icons.person_pin_rounded,
                colors: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PremiumStatCard(
          title: 'الجداول الدراسية',
          value: '$schedules',
          subtitle: 'جداول مخصصة للطلاب',
          icon: Icons.calendar_month_rounded,
          colors: const [Color(0xFF11998e), Color(0xFF38ef7d)],
          isFullWidth: true,
        ),
      ],
    );
  }

  Widget _buildSessionsCards() {
    final overview = _data['overview'] ?? {};
    final total = overview['total_sessions'] ?? 0;
    final completed = overview['completed_sessions'] ?? 0;
    final cancelled = overview['cancelled_sessions'] ?? 0;
    final rate = total > 0 ? (completed / total * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.darkCardElevated.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('إجمالي الحصص', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              Text('$total', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.darkCardElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              FractionallySizedBox(
                widthFactor: rate / 100,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF11998e), Color(0xFF38ef7d)]),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF38ef7d).withOpacity(0.5), blurRadius: 6)
                    ]
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric(Icons.check_circle_rounded, 'مكتملة', '$completed', AppColors.success),
              _buildMiniMetric(Icons.cancel_rounded, 'ملغاة', '$cancelled', AppColors.coral),
              _buildMiniMetric(Icons.trending_up_rounded, 'نسبة الإنجاز', '${rate.toStringAsFixed(1)}%', const Color(0xFF00B4DB)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCards() {
    final overview = _data['overview'] ?? {};
    final openTickets = overview['open_tickets'] ?? 0;
    final resolvedTickets = overview['resolved_tickets'] ?? 0;
    final avgFrt = overview['avg_first_response_minutes']?.toString() ?? '0';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _PremiumStatCard(
                title: 'تذاكر مفتوحة',
                value: '$openTickets',
                subtitle: 'تحتاج استجابة',
                icon: Icons.mark_email_unread_rounded,
                colors: const [Color(0xFFF2994A), Color(0xFFF2C94C)],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PremiumStatCard(
                title: 'تذاكر محلولة',
                value: '$resolvedTickets',
                subtitle: 'تمت معالجتها',
                icon: Icons.task_alt_rounded,
                colors: const [Color(0xFF7b4397), Color(0xFFdc2430)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.darkCardElevated.withOpacity(0.6), AppColors.darkCard],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.speed_rounded, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('متوسط سرعة الرد', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  Text('$avgFrt دقيقة', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniMetric(IconData icon, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.darkCard,
      highlightColor: AppColors.darkCardElevated,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          height: 120,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }
}

class _PremiumStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final bool isFullWidth;

  const _PremiumStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.colors,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: colors[0].withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors.map((c) => c.withOpacity(0.2)).toList()),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colors[0], size: 24),
              ),
              if (isFullWidth)
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 16),
          if (!isFullWidth)
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}
