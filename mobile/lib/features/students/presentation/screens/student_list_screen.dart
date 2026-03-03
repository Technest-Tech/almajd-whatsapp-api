import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/student_model.dart';
import '../bloc/student_list_bloc.dart';

class StudentListScreen extends StatelessWidget {
  const StudentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<StudentListBloc>()..add(const StudentListFetchRequested()),
      child: const _StudentListView(),
    );
  }
}

class _StudentListView extends StatefulWidget {
  const _StudentListView();

  @override
  State<_StudentListView> createState() => _StudentListViewState();
}

class _StudentListViewState extends State<_StudentListView> {
  final _searchController = TextEditingController();

  static const _filters = [
    {'key': 'all', 'label': 'الكل'},
    {'key': 'active', 'label': 'نشط'},
    {'key': 'inactive', 'label': 'غير نشط'},
    {'key': 'suspended', 'label': 'موقوف'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StudentListBloc, StudentListState>(
      builder: (context, state) {
        return Column(
          children: [
            // ── Search Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'بحث عن طالب...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            context.read<StudentListBloc>().add(const StudentListSearchChanged(''));
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  context.read<StudentListBloc>().add(StudentListSearchChanged(value));
                  setState(() {}); // Update suffix icon
                },
              ),
            ),

            // ── Filter Chips ──
            Container(
              height: 44,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isActive = state is StudentListLoaded &&
                      state.activeFilter == filter['key'];
                  return ChoiceChip(
                    label: Text(filter['label']!),
                    selected: isActive,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isActive ? Colors.white : AppColors.textSecondary,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                    ),
                    onSelected: (_) {
                      context.read<StudentListBloc>().add(
                        StudentListFilterChanged(filter['key']!),
                      );
                    },
                  );
                },
              ),
            ),

            // ── Content ──
            Expanded(child: _buildContent(context, state)),
          ],
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, StudentListState state) {
    if (state is StudentListLoading) return _buildShimmer();

    if (state is StudentListError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.coral),
            const SizedBox(height: 16),
            Text(state.message, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<StudentListBloc>().add(StudentListRefreshRequested()),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (state is StudentListLoaded) {
      if (state.students.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.school_outlined, size: 80, color: Colors.white.withValues(alpha: 0.2)),
              const SizedBox(height: 16),
              const Text('لا يوجد طلاب', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
              const SizedBox(height: 8),
              const Text('أضف طلاباً جدد للبدء', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        );
      }

      return Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              context.read<StudentListBloc>().add(StudentListRefreshRequested());
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
              itemCount: state.students.length,
              itemBuilder: (context, index) {
                final student = state.students[index];
                return _StudentCard(
                  student: student,
                  onTap: () => context.push('/students/${student.id}'),
                );
              },
            ),
          ),
          // FAB
          Positioned(
            bottom: 16,
            left: 16,
            child: FloatingActionButton.extended(
              heroTag: 'add_student',
              onPressed: () => context.push('/students/new'),
              icon: const Icon(Icons.person_add),
              label: const Text('إضافة طالب'),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.darkCard,
      highlightColor: AppColors.darkCardElevated,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          height: 88,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ── Student Card ──────────────────────────────────────

class _StudentCard extends StatelessWidget {
  final StudentModel student;
  final VoidCallback onTap;

  const _StudentCard({required this.student, required this.onTap});

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'inactive':
        return AppColors.textSecondary;
      case 'suspended':
        return AppColors.coral;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(student.status);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: Text(
                  student.initials,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            student.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            student.statusDisplay,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (student.guardianName != null)
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                          const SizedBox(width: 4),
                          Text(
                            'ولي الأمر: ${student.guardianName}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    if (student.phone != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Text(
                              student.phone!,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 4),
              const Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
