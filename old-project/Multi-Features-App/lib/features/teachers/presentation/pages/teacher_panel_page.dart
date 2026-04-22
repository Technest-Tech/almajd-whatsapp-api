import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:multi_features_app/l10n/app_localizations.dart';
import 'dart:ui' as ui;
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../dashboard/data/datasources/dashboard_remote_datasource.dart';
import '../../../dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../../dashboard/presentation/bloc/dashboard_event.dart';
import '../../../dashboard/presentation/bloc/dashboard_state.dart';
import '../../../dashboard/presentation/widgets/stat_card.dart';
import 'teacher_courses_page.dart';

class TeacherPanelPage extends StatelessWidget {
  const TeacherPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('لوحة المعلم'),
            actions: [
              IconButton(
                tooltip: l10n?.logout ?? 'تسجيل الخروج',
                icon: const Icon(Icons.logout),
                onPressed: () {
                  // Use AuthBloc to properly logout (clears storage and navigates)
                  context.read<AuthBloc>().add(const LogoutEvent());
                },
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.dashboard), text: 'لوحة التحكم'),
                Tab(icon: Icon(Icons.book), text: 'الدورات'),
              ],
            ),
          ),
          body: TabBarView(
            physics: const NeverScrollableScrollPhysics(), // Disable swipe navigation
            children: [
              _TeacherDashboardTab(),
              const TeacherCoursesPage(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherDashboardTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final apiService = ApiService();
        final token = StorageService.getToken();
        token.then((t) {
          if (t != null) {
            apiService.setAuthToken(t);
          }
        });
        final dataSource = DashboardRemoteDataSourceImpl(apiService);
        final bloc = DashboardBloc(dataSource);
        bloc.add(LoadTeacherStats());
        return bloc;
      },
      child: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is DashboardError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            );
          }
          if (state is TeacherStatsLoaded) {
            final stats = state.stats;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      StatCard(
                        title: 'الطلاب المعينون',
                        value:
                            (stats['assigned_students_count'] ?? 0).toString(),
                        icon: Icons.school,
                        color: Colors.blue,
                      ),
                      StatCard(
                        title: 'ساعات هذا الشهر',
                        value: (stats['hours_this_month'] ?? 0.0)
                            .toStringAsFixed(1),
                        icon: Icons.access_time,
                        color: Colors.green,
                      ),
                      StatCard(
                        title: 'إجمالي الأرباح',
                        value:
                            '\$${(stats['total_profit'] ?? 0.0).toStringAsFixed(2)}',
                        icon: Icons.account_balance_wallet,
                        color: Colors.purple,
                      ),
                      StatCard(
                        title: 'إجمالي الدورات',
                        value: (stats['courses_count'] ?? 0).toString(),
                        icon: Icons.book,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

