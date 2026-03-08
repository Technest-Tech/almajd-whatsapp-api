import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_theme.dart';


class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  bool _loading = true;
  final List<Map<String, dynamic>> _users = [];
  String _roleFilter = 'all';
  final _searchController = TextEditingController();

  static const _roleFilters = [
    {'key': 'all', 'label': 'الكل'},
    {'key': 'admin', 'label': 'مدير'},
    {'key': 'senior_supervisor', 'label': 'مشرف أول'},
    {'key': 'supervisor', 'label': 'مشرف'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // TODO: fetch users from API
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filteredUsers {
    var result = _users;
    if (_roleFilter != 'all') {
      result = result.where((u) => u['role'] == _roleFilter).toList();
    }
    if (_searchController.text.isNotEmpty) {
      final q = _searchController.text.toLowerCase();
      result = result.where((u) =>
          (u['name'] as String).toLowerCase().contains(q) ||
          (u['email'] as String).toLowerCase().contains(q)).toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'بحث عن مستخدم...',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
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

        // Role filters
        Container(
          height: 44,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _roleFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = _roleFilters[index];
              final isActive = _roleFilter == filter['key'];
              return ChoiceChip(
                label: Text(filter['label']!),
                selected: isActive,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isActive ? Colors.white : AppColors.textSecondary,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                ),
                onSelected: (_) => setState(() { _roleFilter = filter['key']!; }),
              );
            },
          ),
        ),

        // Content
        Expanded(child: _loading ? _buildShimmer() : _buildList()),
      ],
    );
  }

  Widget _buildList() {
    final users = _filteredUsers;
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined, size: 80, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            const Text('لا يوجد مستخدمون', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
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
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        itemCount: users.length,
        itemBuilder: (context, index) => _UserCard(user: users[index]),
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.darkCard,
      highlightColor: AppColors.darkCardElevated,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          height: 72,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

}

// ── User Card ─────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;

  const _UserCard({required this.user});

  String _roleDisplay(String role) {
    switch (role) {
      case 'admin': return 'مدير';
      case 'senior_supervisor': return 'مشرف أول';
      case 'supervisor': return 'مشرف';
      default: return role;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin': return AppColors.coral;
      case 'senior_supervisor': return AppColors.amber;
      case 'supervisor': return AppColors.primary;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = user['role'] as String;
    final color = _roleColor(role);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text(
            (user['name'] as String).characters.first,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          user['name'],
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          user['email'],
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _roleDisplay(role),
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
