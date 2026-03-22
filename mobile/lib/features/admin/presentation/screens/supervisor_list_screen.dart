import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/admin_repository.dart';

class SupervisorListScreen extends StatefulWidget {
  const SupervisorListScreen({super.key});

  @override
  State<SupervisorListScreen> createState() => _SupervisorListScreenState();
}

class _SupervisorListScreenState extends State<SupervisorListScreen> {
  bool _loading = true;
  final List<Map<String, dynamic>> _supervisors = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = getIt<AdminRepository>();
      final data = await repo.getSupervisors(perPage: 100);
      if (mounted) {
        setState(() {
          _supervisors.clear();
          _supervisors.addAll(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل في جلب المشرفين')),
      );
    }
  }

  Future<void> _deleteSupervisor(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        title: const Text('حذف المشرف', style: TextStyle(color: Colors.white)),
        content: const Text('هل أنت متأكد من حذف هذا المشرف؟ لا يمكن التراجع عن هذا الإجراء.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await getIt<AdminRepository>().deleteSupervisor(id);
      setState(() {
        _supervisors.removeWhere((s) => s['id'] == id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحذف بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء الحذف')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredSupervisors {
    var result = _supervisors;
    if (_searchController.text.isNotEmpty) {
      final q = _searchController.text.toLowerCase();
      result = result.where((u) =>
          ((u['name'] as String?) ?? '').toLowerCase().contains(q) ||
          ((u['email'] as String?) ?? '').toLowerCase().contains(q)).toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'إدارة المشرفين',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              FilledButton.icon(
                onPressed: () async {
                  await context.push('/supervisors/new');
                  _load();
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة مشرف'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'بحث عن مشرف بالاسم أو الإيميل...',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.darkCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () { _searchController.clear(); setState(() {}); },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),

        // Content
        Expanded(child: _loading ? _buildShimmer() : _buildList()),
      ],
    );
  }

  Widget _buildList() {
    final supervisors = _filteredSupervisors;
    if (supervisors.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined, size: 80, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            const Text('لا يوجد مشرفون', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        setState(() => _loading = true);
        await _load();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: supervisors.length,
        itemBuilder: (context, index) {
          final supervisor = supervisors[index];
          final name = supervisor['name'] as String? ?? 'Unknown';
          final email = supervisor['email'] as String? ?? '';
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            color: AppColors.darkCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.1)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      name.isNotEmpty ? name.characters.first : '؟',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.analytics_outlined, color: AppColors.success, size: 22),
                    onPressed: () async {
                      await context.push('/supervisors/${supervisor['id']}/performance');
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 22),
                    onPressed: () async {
                      await context.push('/supervisors/${supervisor['id']}/edit');
                      _load();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.coral, size: 22),
                    onPressed: () => _deleteSupervisor(supervisor['id']),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.darkCard,
      highlightColor: AppColors.darkCardElevated,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          height: 80,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
