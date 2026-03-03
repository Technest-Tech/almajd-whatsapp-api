import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/schedule_model.dart';
import '../bloc/schedule_list_bloc.dart';

class ScheduleListScreen extends StatelessWidget {
  const ScheduleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ScheduleListBloc>()..add(const ScheduleListFetchRequested()),
      child: const _ScheduleListView(),
    );
  }
}

class _ScheduleListView extends StatefulWidget {
  const _ScheduleListView();

  @override
  State<_ScheduleListView> createState() => _ScheduleListViewState();
}

class _ScheduleListViewState extends State<_ScheduleListView> {
  final _searchController = TextEditingController();

  static const _filters = [
    {'key': 'all', 'label': 'الكل'},
    {'key': 'active', 'label': 'نشط'},
    {'key': 'inactive', 'label': 'متوقف'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScheduleListBloc, ScheduleListState>(
      builder: (context, state) {
        return Column(
          children: [
            // ── Search Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'بحث عن جدول...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            context.read<ScheduleListBloc>().add(const ScheduleListSearchChanged(''));
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  context.read<ScheduleListBloc>().add(ScheduleListSearchChanged(value));
                  setState(() {});
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
                  final isActive = state is ScheduleListLoaded &&
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
                      context.read<ScheduleListBloc>().add(ScheduleListFilterChanged(filter['key']!));
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

  Widget _buildContent(BuildContext context, ScheduleListState state) {
    if (state is ScheduleListLoading) return _buildShimmer();

    if (state is ScheduleListError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.coral),
            const SizedBox(height: 16),
            Text(state.message, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<ScheduleListBloc>().add(ScheduleListRefreshRequested()),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (state is ScheduleListLoaded) {
      if (state.schedules.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month_outlined, size: 80, color: Colors.white.withValues(alpha: 0.2)),
              const SizedBox(height: 16),
              const Text('لا توجد جداول', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
              const SizedBox(height: 8),
              const Text('أنشئ جداول دراسية جديدة', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        );
      }

      return Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              context.read<ScheduleListBloc>().add(ScheduleListRefreshRequested());
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
              itemCount: state.schedules.length,
              itemBuilder: (context, index) {
                return _ScheduleCard(
                  schedule: state.schedules[index],
                  onTap: () => context.push('/schedules/${state.schedules[index].id}'),
                );
              },
            ),
          ),
          // FAB
          Positioned(
            bottom: 16,
            left: 16,
            child: FloatingActionButton.extended(
              heroTag: 'add_schedule',
              onPressed: () => context.push('/schedules/new'),
              icon: const Icon(Icons.add),
              label: const Text('إضافة جدول'),
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
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          height: 130,
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

// ── Schedule Card ─────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final ScheduleModel schedule;
  final VoidCallback onTap;

  const _ScheduleCard({required this.schedule, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = schedule.isActive ? AppColors.success : AppColors.textSecondary;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_today, size: 22, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schedule.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (schedule.description != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              schedule.description!,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      schedule.statusDisplay,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Container(height: 1, color: AppColors.darkCardElevated),
              const SizedBox(height: 10),

              // Footer info
              Row(
                children: [
                  // Date range
                  Icon(Icons.date_range_outlined, size: 14, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      schedule.dateRangeDisplay,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                  // Entry count
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.list_alt, size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${schedule.entryCount} حصة',
                          style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
