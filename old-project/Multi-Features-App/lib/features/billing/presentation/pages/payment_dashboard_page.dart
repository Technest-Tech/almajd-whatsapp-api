import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui' as ui;
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/datasources/billing_remote_datasource.dart';
import '../bloc/payment_dashboard_bloc.dart';
import '../bloc/payment_dashboard_event.dart';
import '../bloc/payment_dashboard_state.dart';

class PaymentDashboardPage extends StatefulWidget {
  const PaymentDashboardPage({super.key});

  @override
  State<PaymentDashboardPage> createState() => _PaymentDashboardPageState();
}

class _PaymentDashboardPageState extends State<PaymentDashboardPage> {
  late DateTime _selectedDate;
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }


  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: BlocProvider(
        create: (context) {
          final apiService = ApiService();
          final token = StorageService.getToken();
          token.then((t) {
            if (t != null) {
              apiService.setAuthToken(t);
            }
          });
          final dataSource = BillingRemoteDataSourceImpl(apiService);
          final bloc = PaymentDashboardBloc(dataSource);
          bloc.add(
            LoadPaymentDashboardStatistics(
              year: _selectedYear,
              month: _selectedMonth,
            ),
          );
          return bloc;
        },
        child: BlocListener<PaymentDashboardBloc, PaymentDashboardState>(
          listener: (context, state) {
            if (state is PaymentDashboardError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: Builder(
            builder: (blocContext) {
              return Scaffold(
                body: RefreshIndicator(
                  onRefresh: () async {
                    blocContext.read<PaymentDashboardBloc>().add(
                          LoadPaymentDashboardStatistics(
                            year: _selectedYear,
                            month: _selectedMonth,
                          ),
                        );
                    // Wait for the state to update
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _buildDateSelector(blocContext),
                        BlocBuilder<PaymentDashboardBloc, PaymentDashboardState>(
                          builder: (context, state) {
                            if (state is PaymentDashboardLoading) {
                              return const Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            if (state is PaymentDashboardError) {
                              return Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Center(
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
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: () {
                                          context.read<PaymentDashboardBloc>().add(
                                                LoadPaymentDashboardStatistics(
                                                  year: _selectedYear,
                                                  month: _selectedMonth,
                                                ),
                                              );
                                        },
                                        child: const Text('إعادة المحاولة'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            if (state is PaymentDashboardLoaded) {
                              final stats = state.statistics;
                              final gateways = stats['gateways'] as Map<String, dynamic>? ?? {};
                              final currencies = stats['currencies'] as Map<String, dynamic>? ?? {};
                              final overall = stats['overall'] as Map<String, dynamic>? ?? {};
                              
                              return Column(
                                children: [
                                  _buildGatewayCards(context, gateways),
                                  const SizedBox(height: 16),
                                  _buildCurrencyCards(context, currencies),
                                  const SizedBox(height: 16),
                                  _buildOverallStatsCards(
                                    context,
                                    overall,
                                    currencies,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              );
                            }

                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context) {
    final arabicMonths = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavigationButton(
            context,
            icon: Icons.arrow_forward_ios,
            onPressed: () {
              setState(() {
                if (_selectedMonth == 12) {
                  _selectedMonth = 1;
                  _selectedYear++;
                } else {
                  _selectedMonth++;
                }
                _selectedDate = DateTime(_selectedYear, _selectedMonth);
              });
              context.read<PaymentDashboardBloc>().add(
                    LoadPaymentDashboardStatistics(
                      year: _selectedYear,
                      month: _selectedMonth,
                    ),
                  );
            },
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: InkWell(
                    onTap: () => _showMonthPicker(context, arabicMonths),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              arabicMonths[_selectedMonth - 1],
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: InkWell(
                    onTap: () => _showYearPicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_selectedYear',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 18,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildNavigationButton(
            context,
            icon: Icons.arrow_back_ios,
            onPressed: () {
              setState(() {
                if (_selectedMonth == 1) {
                  _selectedMonth = 12;
                  _selectedYear--;
                } else {
                  _selectedMonth--;
                }
                _selectedDate = DateTime(_selectedYear, _selectedMonth);
              });
              context.read<PaymentDashboardBloc>().add(
                    LoadPaymentDashboardStatistics(
                      year: _selectedYear,
                      month: _selectedMonth,
                    ),
                  );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  void _showMonthPicker(BuildContext context, List<String> arabicMonths) {
    final blocContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اختر الشهر'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: arabicMonths.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(arabicMonths[index]),
                  selected: _selectedMonth == index + 1,
                  onTap: () {
                    setState(() {
                      _selectedMonth = index + 1;
                      _selectedDate = DateTime(_selectedYear, _selectedMonth);
                    });
                    Navigator.pop(dialogContext);
                    blocContext.read<PaymentDashboardBloc>().add(
                          LoadPaymentDashboardStatistics(
                            year: _selectedYear,
                            month: _selectedMonth,
                          ),
                        );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showYearPicker(BuildContext context) {
    final blocContext = context;
    final currentYear = DateTime.now().year;
    final years = List.generate(10, (index) => currentYear - 5 + index);

    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اختر السنة'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: years.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text('${years[index]}'),
                  selected: _selectedYear == years[index],
                  onTap: () {
                    setState(() {
                      _selectedYear = years[index];
                      _selectedDate = DateTime(_selectedYear, _selectedMonth);
                    });
                    Navigator.pop(dialogContext);
                    blocContext.read<PaymentDashboardBloc>().add(
                          LoadPaymentDashboardStatistics(
                            year: _selectedYear,
                            month: _selectedMonth,
                          ),
                        );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGatewayCards(BuildContext context, Map<String, dynamic> gateways) {
    final gatewayData = {
      'paypal': {
        'name': 'PayPal',
        'icon': Icons.payment,
        'color': const Color(0xFF0070BA),
      },
      'xpay': {
        'name': 'XPay',
        'icon': Icons.credit_card,
        'color': const Color(0xFF00A859),
      },
      'anubpay': {
        'name': 'AnubPay',
        'icon': Icons.account_balance_wallet,
        'color': const Color(0xFFFF6B35),
      },
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'بوابات الدفع',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildGatewayCard(
                  context,
                  'paypal',
                  gateways['paypal'] ?? {},
                  gatewayData['paypal']!,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGatewayCard(
                  context,
                  'xpay',
                  gateways['xpay'] ?? {},
                  gatewayData['xpay']!,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGatewayCard(
                  context,
                  'anubpay',
                  gateways['anubpay'] ?? {},
                  gatewayData['anubpay']!,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGatewayCard(
    BuildContext context,
    String gatewayKey,
    Map<String, dynamic> data,
    Map<String, dynamic> gatewayInfo,
  ) {
    final totalAmount = (data['total_amount'] as num?)?.toDouble() ?? 0.0;
    final studentsCount = (data['students_count'] as int?) ?? 0;
    final transactionsCount = (data['transactions_count'] as int?) ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gatewayInfo['color'] as Color,
            (gatewayInfo['color'] as Color).withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (gatewayInfo['color'] as Color).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                gatewayInfo['icon'] as IconData,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  gatewayInfo['name'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Flexible(
            child: Text(
              _formatCurrency(totalAmount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: _buildStatItem(
                  context,
                  Icons.people,
                  '$studentsCount',
                  'طلاب',
                  Colors.white70,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: _buildStatItem(
                  context,
                  Icons.receipt,
                  '$transactionsCount',
                  'معاملة',
                  Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.8),
            fontSize: 10,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildCurrencyCards(BuildContext context, Map<String, dynamic> currencies) {
    final currencySymbols = {
      'USD': '\$',
      'GBP': '£',
      'EUR': '€',
      'EGP': 'E£',
      'SAR': '﷼',
      'AED': 'د.إ',
      'CAD': 'C\$',
    };

    final currencyNames = {
      'USD': 'دولار أمريكي',
      'GBP': 'جنيه إسترليني',
      'EUR': 'يورو',
      'EGP': 'جنيه مصري',
      'SAR': 'ريال سعودي',
      'AED': 'درهم إماراتي',
      'CAD': 'دولار كندي',
    };

    // Show all currencies from the response (backend returns all currencies even if zero)
    // If backend doesn't return a currency, create a zero entry for it
    final allCurrencies = ['USD', 'GBP', 'EUR', 'EGP', 'SAR', 'AED', 'CAD'];
    final currenciesToShow = allCurrencies.map((currency) {
      if (currencies.containsKey(currency)) {
        return MapEntry(currency, currencies[currency] as Map<String, dynamic>);
      } else {
        // Create zero entry if currency not in response
        return MapEntry(currency, {
          'collected': 0.0,
          'remaining': 0.0,
          'paid_students': 0,
          'unpaid_students': 0,
        });
      }
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ملخص العملات',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemCount: currenciesToShow.length,
            itemBuilder: (context, index) {
              final entry = currenciesToShow[index];
              final currency = entry.key;
              final data = entry.value as Map<String, dynamic>;
              return _buildCurrencyCard(
                context,
                currency,
                currencySymbols[currency] ?? currency,
                currencyNames[currency] ?? currency,
                data,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyCard(
    BuildContext context,
    String currency,
    String symbol,
    String name,
    Map<String, dynamic> data,
  ) {
    final collected = (data['collected'] as num?)?.toDouble() ?? 0.0;
    final remaining = (data['remaining'] as num?)?.toDouble() ?? 0.0;
    final paidStudents = (data['paid_students'] as int?) ?? 0;
    final unpaidStudents = (data['unpaid_students'] as int?) ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  symbol,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: _buildCurrencyStatRow(
              context,
              'المحصل',
              '$symbol${collected.toStringAsFixed(2)}',
              Colors.green,
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: _buildCurrencyStatRow(
              context,
              'المتبقي',
              '$symbol${remaining.toStringAsFixed(2)}',
              Colors.orange,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: _buildSmallStat(Icons.check_circle, '$paidStudents', Colors.green),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: _buildSmallStat(Icons.pending, '$unpaidStudents', Colors.orange),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyStatRow(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                  fontSize: 11,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildSmallStat(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildOverallStatsCards(
    BuildContext context,
    Map<String, dynamic> overall,
    Map<String, dynamic> currencies,
  ) {
    final totalCollected = (overall['total_collected'] as num?)?.toDouble() ?? 0.0;
    final totalRemaining = (overall['total_remaining'] as num?)?.toDouble() ?? 0.0;
    final successRate = (overall['payment_success_rate'] as num?)?.toDouble() ?? 0.0;
    final avgTransaction = (overall['average_transaction'] as num?)?.toDouble() ?? 0.0;

    // Get active currencies (currencies with data)
    final activeCurrencies = currencies.entries
        .where((entry) {
          final data = entry.value as Map<String, dynamic>;
          final collected = (data['collected'] as num?)?.toDouble() ?? 0.0;
          final remaining = (data['remaining'] as num?)?.toDouble() ?? 0.0;
          return collected > 0 || remaining > 0;
        })
        .map((entry) => entry.key)
        .toList();

    final currencySymbols = {
      'USD': '\$',
      'GBP': '£',
      'EUR': '€',
      'EGP': 'E£',
      'SAR': '﷼',
      'AED': 'د.إ',
      'CAD': 'C\$',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الإحصائيات العامة',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              switch (index) {
                case 0:
                  return _buildOverallStatCard(
                    context,
                    'إجمالي المحصل',
                    _formatCurrency(totalCollected),
                    Icons.account_balance_wallet,
                    Colors.green,
                    activeCurrencies,
                    currencySymbols,
                    currencies,
                    'collected',
                  );
                case 1:
                  return _buildOverallStatCard(
                    context,
                    'إجمالي المتبقي',
                    _formatCurrency(totalRemaining),
                    Icons.pending_actions,
                    Colors.orange,
                    activeCurrencies,
                    currencySymbols,
                    currencies,
                    'remaining',
                  );
                case 2:
                  return _buildOverallStatCard(
                    context,
                    'معدل النجاح',
                    '${successRate.toStringAsFixed(1)}%',
                    Icons.trending_up,
                    Colors.blue,
                    null,
                    null,
                    null,
                    null,
                  );
                case 3:
                  return _buildOverallStatCard(
                    context,
                    'متوسط المعاملة',
                    _formatCurrency(avgTransaction),
                    Icons.analytics,
                    Colors.purple,
                    null,
                    null,
                    null,
                    null,
                  );
                default:
                  return const SizedBox.shrink();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverallStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color, [
    List<String>? activeCurrencies,
    Map<String, String>? currencySymbols,
    Map<String, dynamic>? currencies,
    String? currencyType,
  ]) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 22),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                      fontSize: 12,
                    ),
              ),
              if (activeCurrencies != null &&
                  activeCurrencies.isNotEmpty &&
                  currencySymbols != null &&
                  currencies != null &&
                  currencyType != null) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: activeCurrencies.take(3).map((currency) {
                    final data = currencies[currency] as Map<String, dynamic>?;
                    final amount = (data?[currencyType] as num?)?.toDouble() ?? 0.0;
                    final symbol = currencySymbols[currency] ?? currency;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: color.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '$symbol${amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (activeCurrencies.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '+${activeCurrencies.length - 3} عملات أخرى',
                      style: TextStyle(
                        fontSize: 9,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(2)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(2)}K';
    }
    return amount.toStringAsFixed(2);
  }
}
