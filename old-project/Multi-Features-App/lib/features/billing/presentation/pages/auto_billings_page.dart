import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/router/app_router.dart';
import '../../data/datasources/billing_remote_datasource.dart';
import '../bloc/auto_billing_bloc.dart';
import '../bloc/auto_billing_event.dart';
import '../bloc/auto_billing_state.dart';
import '../widgets/auto_billing_card.dart';
import 'billing_send_logs_page.dart';
import '../../data/models/auto_billing_model.dart';

class AutoBillingsPage extends StatefulWidget {
  const AutoBillingsPage({super.key});

  @override
  State<AutoBillingsPage> createState() => _AutoBillingsPageState();
}

class _AutoBillingsPageState extends State<AutoBillingsPage> {
  late DateTime _selectedDate;
  late int _selectedYear;
  late int _selectedMonth;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showUnpaid = true; // Default to unpaid

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          final bloc = AutoBillingBloc(dataSource);
          bloc.add(LoadAutoBillings(
            year: _selectedYear,
            month: _selectedMonth,
            isPaid: !_showUnpaid,
          ));
          return bloc;
        },
        child: BlocListener<AutoBillingBloc, AutoBillingState>(
          listener: (context, state) {
            if (state is AutoBillingsSendComplete) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم إرسال ${state.sent} من ${state.total} فاتورة بنجاح. فشل: ${state.failed}',
                  ),
                  backgroundColor: state.failed > 0 ? Colors.orange : Colors.green,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
            if (state is AutoBillingError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: Builder(
            builder: (scaffoldContext) => Scaffold(
              body: Column(
                children: [
                  _buildDateSelector(scaffoldContext),
                  _buildActionButtons(scaffoldContext),
                  _buildSummaryCards(scaffoldContext),
                  _buildSearchBar(scaffoldContext),
                  Expanded(
                child: BlocBuilder<AutoBillingBloc, AutoBillingState>(
                  builder: (context, state) {
                    if (state is AutoBillingLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state is AutoBillingError) {
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
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                context.read<AutoBillingBloc>().add(
                                      LoadAutoBillings(
                                        year: _selectedYear,
                                        month: _selectedMonth,
                                        isPaid: !_showUnpaid,
                                      ),
                                    );
                              },
                              child: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      );
                    }

                    if (state is AutoBillingsLoaded) {
                      final billings = state.billings;
                      
                      // Filter by search query
                      final filteredBillings = _searchQuery.isEmpty
                          ? billings
                          : billings.where((billing) {
                              return billing.student?.name
                                      .toLowerCase()
                                      .contains(_searchQuery.toLowerCase()) ??
                                  false;
                            }).toList();

                      if (filteredBillings.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: Theme.of(context).hintColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'لا توجد فواتير لهذا الشهر'
                                    : 'لا توجد نتائج للبحث',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          context.read<AutoBillingBloc>().add(
                                LoadAutoBillings(
                                  year: _selectedYear,
                                  month: _selectedMonth,
                                  isPaid: !_showUnpaid,
                                  search: _searchQuery.isEmpty ? null : _searchQuery,
                                ),
                              );
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          itemCount: filteredBillings.length,
                          itemBuilder: (context, index) {
                            final billing = filteredBillings[index];
                            return AutoBillingCard(
                              billing: billing,
                              onTap: () {
                                // Navigate to details page
                                // TODO: Implement billing details page
                              },
                              onMarkPaid: () {
                                _showMarkPaidConfirmationDialog(context, billing);
                              },
                              onSendWhatsApp: () {
                                // WhatsApp opening is now handled in the card widget
                              },
                            );
                          },
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                  ),
                ),
              ],
            ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  scaffoldContext.read<AutoBillingBloc>().add(
                        GenerateAutoBillings(
                          year: _selectedYear,
                          month: _selectedMonth,
                        ),
                      );
                },
                child: const Icon(Icons.refresh),
                tooltip: 'توليد الفواتير',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return BlocBuilder<AutoBillingBloc, AutoBillingState>(
      builder: (blocContext, state) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showSendAllDialog(blocContext),
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text(
                    'إرسال جميع الفواتير',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    blocContext.push(
                      '${AppRouter.billings}/auto/send-logs',
                      extra: {
                        'year': _selectedYear,
                        'month': _selectedMonth,
                      },
                    );
                  },
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('سجل الإرسال'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMarkPaidConfirmationDialog(BuildContext context, AutoBillingModel billing) {
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('تأكيد الدفع'),
            ],
          ),
          content: Text(
            'هل أنت متأكد من أنك تريد تحديد فاتورة ${billing.student?.name ?? "الطالب"} كمدفوعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<AutoBillingBloc>().add(
                      MarkAutoBillingAsPaid(billing.id),
                    );
                // Reload after marking as paid
                Future.delayed(const Duration(seconds: 1), () {
                  context.read<AutoBillingBloc>().add(
                        LoadAutoBillings(
                          year: _selectedYear,
                          month: _selectedMonth,
                          isPaid: !_showUnpaid,
                        ),
                      );
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSendAllDialog(BuildContext context) {
    // Capture the bloc from the context that has access to it
    final bloc = context.read<AutoBillingBloc>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // Auto-focus the dialog
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(dialogContext).requestFocus(FocusNode());
        });
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: BlocProvider.value(
            value: bloc,
            child: BlocListener<AutoBillingBloc, AutoBillingState>(
              listener: (blocContext, state) {
                if (state is AutoBillingsSendComplete) {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  });
                }
              },
              child: BlocBuilder<AutoBillingBloc, AutoBillingState>(
                builder: (blocContext, state) {
                  if (state is AutoBillingsSendComplete) {
                    return AlertDialog(
                      title: Row(
                        children: [
                          Icon(
                            state.failed > 0 ? Icons.warning : Icons.check_circle,
                            color: state.failed > 0 ? Colors.orange : Colors.green,
                          ),
                          const SizedBox(width: 16),
                          const Text('اكتمل الإرسال'),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الإجمالي: ${state.total}'),
                          Text(
                            'تم الإرسال: ${state.sent}',
                            style: const TextStyle(color: Colors.green),
                          ),
                          Text(
                            'فشل: ${state.failed}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('إغلاق'),
                        ),
                      ],
                    );
                  }
                  if (state is AutoBillingLoading || state is AutoBillingsSending) {
                    return AlertDialog(
                      title: const Row(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Text('جاري الإرسال...'),
                        ],
                      ),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('يرجى الانتظار...'),
                          SizedBox(height: 16),
                          Text(
                            'يمكنك إغلاق هذه النافذة. سيستمر الإرسال في الخلفية.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('إغلاق'),
                        ),
                      ],
                    );
                  }
                  return AlertDialog(
                    title: const Text('إرسال جميع الفواتير'),
                    content: const Text(
                      'سيتم إرسال رسائل واتساب لجميع الطلاب الذين لم يدفعوا فواتيرهم لهذا الشهر. هل تريد المتابعة؟',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('إلغاء'),
                      ),
                      ElevatedButton(
                        autofocus: true,
                        onPressed: () {
                          blocContext.read<AutoBillingBloc>().add(
                                SendAllAutoBillingsWhatsApp(
                                  year: _selectedYear,
                                  month: _selectedMonth,
                                ),
                              );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('إرسال'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    return BlocBuilder<AutoBillingBloc, AutoBillingState>(
      builder: (context, state) {
        Map<String, dynamic>? totals;
        if (state is AutoBillingsLoaded && state.totals != null) {
          totals = state.totals;
        }

        // Handle both array and map formats from backend
        final unpaidData = totals?['unpaid'];
        final paidData = totals?['paid'];
        
        final unpaidTotals = (unpaidData is Map)
            ? Map<String, dynamic>.from(unpaidData)
            : (unpaidData is List && unpaidData.isEmpty)
                ? <String, dynamic>{}
                : <String, dynamic>{};
        
        final paidTotals = (paidData is Map)
            ? Map<String, dynamic>.from(paidData)
            : (paidData is List && paidData.isEmpty)
                ? <String, dynamic>{}
                : <String, dynamic>{};

        // Get billing counts
        final unpaidCount = totals?['unpaid_count'] ?? 0;
        final paidCount = totals?['paid_count'] ?? 0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  context,
                  title: 'إجمالي غير المدفوع',
                  totals: unpaidTotals,
                  count: unpaidCount is int ? unpaidCount : (unpaidCount is num ? unpaidCount.toInt() : 0),
                  color: Colors.red,
                  isSelected: _showUnpaid,
                  onTap: () {
                    setState(() {
                      _showUnpaid = true;
                    });
                    context.read<AutoBillingBloc>().add(
                          LoadAutoBillings(
                            year: _selectedYear,
                            month: _selectedMonth,
                            isPaid: false,
                          ),
                        );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  context,
                  title: 'إجمالي المدفوع',
                  totals: paidTotals,
                  count: paidCount is int ? paidCount : (paidCount is num ? paidCount.toInt() : 0),
                  color: Colors.green,
                  isSelected: !_showUnpaid,
                  onTap: () {
                    setState(() {
                      _showUnpaid = false;
                    });
                    context.read<AutoBillingBloc>().add(
                          LoadAutoBillings(
                            year: _selectedYear,
                            month: _selectedMonth,
                            isPaid: true,
                          ),
                        );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required Map<String, dynamic> totals,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: isSelected ? color : Colors.grey,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: color,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (totals.isEmpty)
              Text(
                '0.00',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: color,
                    ),
              )
            else
              ...totals.entries.map((entry) {
                final value = entry.value;
                final amount = value is num 
                    ? value.toDouble() 
                    : (value is String 
                        ? double.tryParse(value) ?? 0.0 
                        : 0.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${entry.key} ${amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: color,
                        ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'ابحث عن طالب...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                    context.read<AutoBillingBloc>().add(
                          LoadAutoBillings(
                            year: _selectedYear,
                            month: _selectedMonth,
                            isPaid: !_showUnpaid,
                          ),
                        );
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
          context.read<AutoBillingBloc>().add(
                LoadAutoBillings(
                  year: _selectedYear,
                  month: _selectedMonth,
                  isPaid: !_showUnpaid,
                  search: value.isEmpty ? null : value,
                ),
              );
        },
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
              _loadBillings(context);
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
              _loadBillings(context);
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              width: 1,
            ),
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
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اختر الشهر'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(12, (index) {
                  final monthNumber = index + 1;
                  final isSelected = monthNumber == _selectedMonth;
                  return ListTile(
                    title: Text(
                      arabicMonths[index],
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedMonth = monthNumber;
                        _selectedDate = DateTime(_selectedYear, _selectedMonth);
                      });
                      Navigator.pop(dialogContext);
                      _loadBillings(context);
                    },
                  );
                }),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      ),
    );
  }

  void _showYearPicker(BuildContext context) {
    final currentYear = DateTime.now().year;
    final startYear = currentYear - 10;
    final endYear = currentYear + 10;

    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اختر السنة'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: endYear - startYear + 1,
              itemBuilder: (context, index) {
                final year = startYear + index;
                final isSelected = year == _selectedYear;
                return ListTile(
                  title: Text(
                    '$year',
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedYear = year;
                      _selectedDate = DateTime(_selectedYear, _selectedMonth);
                    });
                    Navigator.pop(dialogContext);
                    _loadBillings(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      ),
    );
  }

  void _loadBillings(BuildContext context) {
    context.read<AutoBillingBloc>().add(
          LoadAutoBillings(
            year: _selectedYear,
            month: _selectedMonth,
            isPaid: !_showUnpaid,
            search: _searchQuery.isEmpty ? null : _searchQuery,
          ),
        );
    // Also load totals
    context.read<AutoBillingBloc>().add(
          LoadAutoBillingsTotals(
            year: _selectedYear,
            month: _selectedMonth,
          ),
        );
  }
}
