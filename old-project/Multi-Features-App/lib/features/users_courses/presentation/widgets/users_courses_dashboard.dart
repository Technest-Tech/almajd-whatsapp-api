import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../dashboard/data/datasources/dashboard_remote_datasource.dart';
import '../../../dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../../dashboard/presentation/bloc/dashboard_event.dart';
import '../../../dashboard/presentation/bloc/dashboard_state.dart';
import '../../../dashboard/presentation/widgets/stat_card.dart';
import '../../../dashboard/presentation/widgets/profit_chart.dart';

/// Arabic month names (1-based index)
const _arabicMonths = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

String? _periodLabel(dynamic month, dynamic year) {
  final m = month is int ? month : (month != null ? int.tryParse(month.toString()) : null);
  final y = year is int ? year : (year != null ? int.tryParse(year.toString()) : null);
  if (m == null || y == null || m < 1 || m > 12) return null;
  final monthName = _arabicMonths[m - 1];
  return 'بيانات شهر $monthName $y';
}

/// Dashboard view for Users & Courses section
class UsersCoursesDashboard extends StatefulWidget {
  const UsersCoursesDashboard({super.key});

  @override
  State<UsersCoursesDashboard> createState() => _UsersCoursesDashboardState();
}

class _UsersCoursesDashboardState extends State<UsersCoursesDashboard> {
  DashboardBloc? _bloc;
  String? _errorMessage;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeBloc();
  }

  Future<void> _initializeBloc() async {
    try {
      final apiService = ApiService();
      // Set token before creating bloc
      final token = await StorageService.getToken();
      if (token != null) {
        apiService.setAuthToken(token);
      }
      final dataSource = DashboardRemoteDataSourceImpl(apiService);
      final bloc = DashboardBloc(dataSource);
      // Load stats after ensuring token is set
      bloc.add(LoadAdminStats());
      
      if (mounted) {
        setState(() {
          _bloc = bloc;
          _isInitializing = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Failed to initialize dashboard: ${e.toString()}';
        });
      }
    }
  }

  @override
  void dispose() {
    _bloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while initializing
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Show error if initialization failed
    if (_errorMessage != null || _bloc == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                'خطأ في تحميل لوحة التحكم',
                style: Theme.of(context).textTheme.titleMedium,
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'فشل في تهيئة لوحة التحكم',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isInitializing = true;
                    _errorMessage = null;
                    _bloc = null;
                  });
                  _initializeBloc();
                },
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return BlocProvider.value(
      value: _bloc!,
      child: const _DashboardContent(),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Stats section
            BlocBuilder<DashboardBloc, DashboardState>(
              builder: (context, state) {
                if (state is AdminStatsLoaded) {
                  // Handle profit_by_currency - it might be a List or Map
                  Map<String, dynamic> profitByCurrency = {};
                  final profitData = state.stats['profit_by_currency'];
                  if (profitData != null) {
                    if (profitData is Map) {
                      profitByCurrency = Map<String, dynamic>.from(profitData);
                    } else if (profitData is List) {
                      // Convert list of objects to map
                      for (var item in profitData) {
                        if (item is Map) {
                          final currency = item['currency']?.toString() ?? item['key']?.toString();
                          final value = item['total_profit'] ?? item['value'] ?? 0;
                          if (currency != null) {
                            profitByCurrency[currency] = value;
                          }
                        }
                      }
                    }
                  }

                  final year = state.stats['year'];
                  final month = state.stats['month'];
                  final periodLabel = _periodLabel(month, year);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (periodLabel != null) ...[
                        Text(
                          periodLabel,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _StatsGrid(stats: state.stats),
                      const SizedBox(height: 24),
                      ProfitChart(
                        profitByCurrency: profitByCurrency,
                      ),
                    ],
                  );
                }
                if (state is DashboardLoading) {
                  return Container(
                    height: 400,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(),
                  );
                }
                if (state is DashboardError) {
                  return Container(
                    height: 400,
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'خطأ في تحميل الإحصائيات',
                            style: Theme.of(context).textTheme.titleMedium,
                            textDirection: TextDirection.rtl,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.message,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              context.read<DashboardBloc>().add(LoadAdminStats());
                            },
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                // Show loading for initial state
                if (state is DashboardInitial) {
                  return Container(
                    height: 400,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(),
                  );
                }
                // Fallback to prevent black screen
                return Container(
                  height: 400,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                );
              },
            ),
          ],
        ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _StatsGrid({required this.stats});

  // Helper method to safely convert to double
  double _toDouble(dynamic value) {
    if (value is double) {
      return value;
    } else if (value is int) {
      return value.toDouble();
    } else if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return _buildStatsGrid(context, stats);
  }

  Widget _buildStatsGrid(BuildContext context, Map<String, dynamic> stats) {
    // Extract profit by currency
    Map<String, dynamic> profitByCurrency = {};
    final profitData = stats['profit_by_currency'];
    if (profitData != null) {
      if (profitData is Map) {
        profitByCurrency = Map<String, dynamic>.from(profitData);
      }
    }

    // Get currency values (default to 0 if not present)
    // Safely convert to double (handles both int and double from JSON)
    final gbpProfit = _toDouble(profitByCurrency['GBP'] ?? 0.0);
    final eurProfit = _toDouble(profitByCurrency['EUR'] ?? 0.0);
    final usdProfit = _toDouble(profitByCurrency['USD'] ?? 0.0);
    final cadProfit = _toDouble(profitByCurrency['CAD'] ?? 0.0);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        StatCard(
          title: 'إجمالي الطلاب',
          value: (stats['total_students'] ?? 0).toString(),
          icon: Icons.school,
          color: Colors.blue,
        ),
        StatCard(
          title: 'إجمالي المعلمين',
          value: (stats['total_teachers'] ?? 0).toString(),
          icon: Icons.person,
          color: Colors.green,
        ),
        StatCard(
          title: 'إجمالي الساعات',
          value: (stats['total_hours'] ?? 0.0).toStringAsFixed(1),
          icon: Icons.access_time,
          color: Colors.orange,
        ),
        StatCard(
          title: 'ربح GBP',
          value: '£${gbpProfit.toStringAsFixed(2)}',
          icon: Icons.currency_pound,
          color: Colors.indigo,
        ),
        StatCard(
          title: 'ربح EUR',
          value: '€${eurProfit.toStringAsFixed(2)}',
          icon: Icons.euro,
          color: Colors.teal,
        ),
        StatCard(
          title: 'ربح USD',
          value: '\$${usdProfit.toStringAsFixed(2)}',
          icon: Icons.attach_money,
          color: Colors.green.shade700,
        ),
        StatCard(
          title: 'ربح CAD',
          value: 'C\$${cadProfit.toStringAsFixed(2)}',
          icon: Icons.currency_exchange,
          color: Colors.red.shade700,
        ),
      ],
    );
  }
}

