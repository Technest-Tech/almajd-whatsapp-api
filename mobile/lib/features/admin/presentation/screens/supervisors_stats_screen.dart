import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/admin_repository.dart';

class SupervisorsStatsScreen extends StatefulWidget {
  const SupervisorsStatsScreen({super.key});

  @override
  State<SupervisorsStatsScreen> createState() => _SupervisorsStatsScreenState();
}

class _SupervisorsStatsScreenState extends State<SupervisorsStatsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _statsList = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = getIt<AdminRepository>();
      final data = await repo.getAggregatedSupervisorsPerformance();
      if (mounted) {
        setState(() {
          _statsList = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل في جلب إحصائيات المشرفين')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: const Text('أداء المشرفين المميز', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _loading 
          ? _buildShimmer() 
          : _statsList.isEmpty 
              ? const Center(child: Text('لا توجد بيانات', style: TextStyle(color: AppColors.textSecondary)))
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _statsList.length,
                    itemBuilder: (context, index) {
                      final item = _statsList[index];
                      return _buildPremiumCard(item);
                    },
                  ),
                ),
    );
  }

  Widget _buildPremiumCard(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? 'المشرف';
    final metrics = item['metrics'] as Map<String, dynamic>? ?? {};
    
    final overallScore = (metrics['overall_score'] as num?)?.toInt() ?? 0;
    final frt = metrics['avg_first_response_minutes']?.toString() ?? '-';
    final resolution = metrics['avg_resolution_minutes']?.toString() ?? '-';
    
    final classesHandled = metrics['classes_handled'] ?? 0;
    final classesAssigned = metrics['classes_assigned'] ?? 0;
    final classesCompletion = (metrics['class_completion_rate'] as num?)?.toInt() ?? 0;
    
    // Determine gradient color based on score
    List<Color> gradientColors;
    if (overallScore >= 90) {
      gradientColors = [const Color(0xFF00B4DB), const Color(0xFF0083B0)]; // Premium Blue
    } else if (overallScore >= 70) {
      gradientColors = [const Color(0xFF11998e), const Color(0xFF38ef7d)]; // Premium Green
    } else if (overallScore >= 50) {
      gradientColors = [const Color(0xFFF2994A), const Color(0xFFF2C94C)]; // Premium Orange
    } else {
      gradientColors = [const Color(0xFFED213A), const Color(0xFF93291E)]; // Premium Red
    }

    return GestureDetector(
      onTap: () => context.push('/supervisors/${item['supervisor_id']}/performance'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              AppColors.darkCardElevated,
              AppColors.darkCard,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: gradientColors[0].withOpacity(0.3), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Header section with score gradient
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors.map((c) => c.withOpacity(0.15)).toList(),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: gradientColors[0].withOpacity(0.2),
                      radius: 22,
                      child: Text(
                        name.isNotEmpty ? name.characters.first : 'م',
                        style: TextStyle(color: gradientColors[0], fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradientColors),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: gradientColors[0].withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2))
                        ]
                      ),
                      child: Text(
                        '$overallScore%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    )
                  ],
                ),
              ),
              
              // Details section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMiniMetric(Icons.timer, 'الرد الأول', '$frt د'),
                    _buildVerticalDivider(),
                    _buildMiniMetric(Icons.check_circle, 'حل التذاكر', '$resolution د'),
                    _buildVerticalDivider(),
                    _buildMiniMetric(Icons.class_, 'إكمال الحصص', '$classesCompletion%'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMetric(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withOpacity(0.1),
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
          height: 140,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }
}
