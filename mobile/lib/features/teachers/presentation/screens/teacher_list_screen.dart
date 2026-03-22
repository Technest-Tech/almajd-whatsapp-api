import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/teacher_model.dart';
import '../bloc/teacher_list_bloc.dart';

class TeacherListScreen extends StatelessWidget {
  const TeacherListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TeacherListBloc>()..add(const TeacherListFetchRequested()),
      child: const _TeacherListView(),
    );
  }
}

class _TeacherListView extends StatefulWidget {
  const _TeacherListView();

  @override
  State<_TeacherListView> createState() => _TeacherListViewState();
}

class _TeacherListViewState extends State<_TeacherListView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeacherListBloc, TeacherListState>(
      builder: (context, state) {
        return Stack(
          children: [
            Column(
              children: [
                // ── Search Bar ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'بحث عن معلم...',
                      hintStyle: const TextStyle(color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, color: AppColors.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                context.read<TeacherListBloc>().add(const TeacherListSearchChanged(''));
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      context.read<TeacherListBloc>().add(TeacherListSearchChanged(value));
                      setState(() {});
                    },
                  ),
                ),

                // ── Content ──
                Expanded(child: _buildContent(context, state)),
              ],
            ),
            // FAB
            Positioned(
              bottom: 16,
              left: 16,
              child: FloatingActionButton.extended(
                heroTag: 'add_teacher',
                onPressed: () => context.push('/teachers/new'),
                icon: const Icon(Icons.person_add),
                label: const Text('إضافة معلم'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, TeacherListState state) {
    if (state is TeacherListLoading) return _buildShimmer();

    if (state is TeacherListError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.coral),
            const SizedBox(height: 16),
            Text(state.message, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<TeacherListBloc>().add(TeacherListRefreshRequested()),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (state is TeacherListLoaded) {
      if (state.teachers.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_search_outlined, size: 80, color: Colors.white.withValues(alpha: 0.2)),
              const SizedBox(height: 16),
              const Text('لا يوجد معلمون', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
              const SizedBox(height: 8),
              const Text('أضف معلمين جدد للبدء', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        );
      }

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          context.read<TeacherListBloc>().add(TeacherListRefreshRequested());
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
          itemCount: state.teachers.length,
          itemBuilder: (context, index) {
            final teacher = state.teachers[index];
            return _TeacherCard(
              teacher: teacher,
              onTap: () => context.push('/teachers/${teacher.id}'),
            );
          },
        ),
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
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          height: 100,
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

// ── Teacher Card ──────────────────────────────────────

class _TeacherCard extends StatelessWidget {
  final TeacherModel teacher;
  final VoidCallback onTap;

  const _TeacherCard({required this.teacher, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
                radius: 26,
                backgroundColor: AppColors.primaryDark.withValues(alpha: 0.3),
                child: Text(
                  teacher.name.isNotEmpty ? teacher.name[0] : '?',
                  style: const TextStyle(
                    color: AppColors.primaryLight,
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
                    Text(
                      teacher.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    if (teacher.whatsappNumber != null && teacher.whatsappNumber!.isNotEmpty)
                      Row(
                        textDirection: TextDirection.ltr,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                          const SizedBox(width: 4),
                          Text(
                            teacher.whatsappNumber!, 
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
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
