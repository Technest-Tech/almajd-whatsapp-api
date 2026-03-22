import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/api/api_client.dart';
import '../../data/admin_repository.dart';

class SupervisorPerformanceScreen extends StatefulWidget {
  final int supervisorId;

  const SupervisorPerformanceScreen({super.key, required this.supervisorId});

  @override
  State<SupervisorPerformanceScreen> createState() => _SupervisorPerformanceScreenState();
}

class _SupervisorPerformanceScreenState extends State<SupervisorPerformanceScreen> {
  bool _loading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = getIt<AdminRepository>();
      final data = await repo.getSupervisorPerformance(widget.supervisorId);
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل في جلب أداء المشرف')),
        );
      }
    }
  }

  Future<void> _exportExcel() async {
    try {
      final apiClient = getIt<ApiClient>();
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      final urlStr = '${apiClient.dio.options.baseUrl}/admin/supervisors/${widget.supervisorId}/performance/export?token=$token';
      final uri = Uri.parse(urlStr);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $uri');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تصدير الملف')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: const Text('أداء المشرف', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!_loading && _data != null)
            IconButton(
              icon: const Icon(Icons.file_download, color: AppColors.primary),
              tooltip: 'تصدير Excel',
              onPressed: _exportExcel,
            ),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.primary)) : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_data == null) {
      return const Center(child: Text('لا توجد بيانات متاحة', style: TextStyle(color: AppColors.textSecondary)));
    }

    final m = _data!['metrics']['metrics'] as Map<String, dynamic>;
    final name = _data!['name'] as String? ?? 'المشرف';

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
             child: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 24),
          _buildStatCard('تقييم الأداء العام', '${m['overall_score'] ?? 0}%', Icons.star, AppColors.amber),
          const SizedBox(height: 16),
          const Text('استجابة التذاكر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildStatCard('متوسط الرد الأول', '${m['avg_first_response_minutes'] ?? '-'} د', Icons.timer, AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('متوسط الحل', '${m['avg_resolution_minutes'] ?? '-'} د', Icons.check_circle_outline, AppColors.success)),
            ],
          ),
          const SizedBox(height: 8),
          _buildStatCard('تذاكر متأخرة', '${m['sla_breach_rate'] ?? 0}%', Icons.warning_amber, AppColors.coral),
          const SizedBox(height: 16),
          const Text('إدارة الحصص', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildStatCard('تمت المشاركة', '${m['classes_handled'] ?? 0} / ${m['classes_assigned'] ?? 0}', Icons.class_outlined, AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('معدل الإكمال', '${m['class_completion_rate'] ?? 0}%', Icons.pie_chart, AppColors.success)),
            ],
          ),
          const SizedBox(height: 8),
          _buildStatCard('متوسط تأخير تحديث الحصة', '${m['avg_class_action_delay_minutes'] ?? '-'} د', Icons.hourglass_bottom, AppColors.amber),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.file_download),
              label: const Text('تحميل سجل الأداء (Excel)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _exportExcel,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
