import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'dart:ui' as ui;
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/datasources/salary_remote_datasource.dart';
import '../../data/models/salary_model.dart';
import '../../data/repositories/salary_repository_impl.dart';
import '../bloc/salary_bloc.dart';
import '../bloc/salary_event.dart';
import '../bloc/salary_state.dart';
import '../widgets/salary_card.dart';

class SalariesPage extends StatefulWidget {
  const SalariesPage({super.key});

  @override
  State<SalariesPage> createState() => _SalariesPageState();
}

class _SalariesPageState extends State<SalariesPage> {
  late DateTime _selectedDate;
  late int _selectedYear;
  late int _selectedMonth;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _unifiedHourPriceController = TextEditingController();
  String _searchQuery = '';
  bool _showTotals = false;
  double? _unifiedHourPrice;

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
    _unifiedHourPriceController.dispose();
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
          final dataSource = SalaryRemoteDataSourceImpl(apiService);
          final repository = SalaryRepositoryImpl(dataSource);
          final bloc = SalaryBloc(repository, apiService);
          bloc.add(LoadSalaries(
            year: _selectedYear, 
            month: _selectedMonth,
            unifiedHourPrice: _unifiedHourPrice,
          ));
          return bloc;
        },
        child: Scaffold(
          body: BlocListener<SalaryBloc, SalaryState>(
            listener: (context, state) {
              if (state is SalaryExportSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم تصدير الملف بنجاح'),
                    backgroundColor: Colors.green,
                  ),
                );
                // Share the file
                Share.shareXFiles([XFile(state.filePath)]);
              }
              if (state is SalaryExportError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('خطأ في التصدير: ${state.message}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Column(
              children: [
                _buildDateSelector(context),
                _buildUnifiedHourPriceSection(context),
                _buildSearchBar(context),
                Expanded(
                  child: BlocBuilder<SalaryBloc, SalaryState>(
                    key: ValueKey('salaries_${_selectedYear}_${_selectedMonth}_${_unifiedHourPrice ?? 'null'}'),
                    builder: (context, state) {
                      // Show loading only for initial load, not during export
                      if (state is SalaryLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      // During export, show the last loaded data if available
                      SalariesResponseModel? displayResponse;
                      if (state is SalariesLoaded) {
                        displayResponse = state.response;
                      } else if (state is SalaryExporting && state.lastLoadedResponse != null) {
                        displayResponse = state.lastLoadedResponse;
                      } else if (state is SalaryExportSuccess && state.lastLoadedResponse != null) {
                        displayResponse = state.lastLoadedResponse;
                      } else if (state is SalaryExportError && state.lastLoadedResponse != null) {
                        displayResponse = state.lastLoadedResponse;
                      }
                      
                      if (state is SalaryError) {
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
                                  context.read<SalaryBloc>().add(
                                        LoadSalaries(
                                          year: _selectedYear,
                                          month: _selectedMonth,
                                          unifiedHourPrice: _unifiedHourPrice,
                                        ),
                                      );
                                },
                                child: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        );
                      }
                      // Show loaded data or data preserved during export
                      if (displayResponse != null) {
                        final response = displayResponse; // Non-nullable local variable
                        if (response.salaries.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 64,
                                  color: Theme.of(context).hintColor,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'لا توجد رواتب لهذا الشهر',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                          );
                        }

                        // Filter salaries by search query
                        final filteredSalaries = _searchQuery.isEmpty
                            ? response.salaries
                            : response.salaries.where((salary) {
                                return salary.teacherName
                                    .toLowerCase()
                                    .contains(_searchQuery.toLowerCase());
                              }).toList();

                        // Group salaries by currency for totals display (only for filtered salaries)
                        final filteredTotalsByCurrency = <String, double>{};
                        for (final salary in filteredSalaries) {
                          final currency = salary.currency;
                          if (!filteredTotalsByCurrency.containsKey(currency)) {
                            filteredTotalsByCurrency[currency] = 0.0;
                          }
                          filteredTotalsByCurrency[currency] =
                              (filteredTotalsByCurrency[currency] ?? 0.0) + salary.salary;
                        }
                        // Round totals to 2 decimal places
                        for (final key in filteredTotalsByCurrency.keys) {
                          filteredTotalsByCurrency[key] =
                              double.parse(filteredTotalsByCurrency[key]!.toStringAsFixed(2));
                        }
                        
                        // Show export loading overlay if exporting
                        final isExporting = state is SalaryExporting;

                        return Stack(
                          children: [
                            Column(
                              children: [
                                Expanded(
                                  child: RefreshIndicator(
                                    onRefresh: () async {
                                      context.read<SalaryBloc>().add(
                                            LoadSalaries(
                                              year: _selectedYear,
                                              month: _selectedMonth,
                                              unifiedHourPrice: _unifiedHourPrice,
                                            ),
                                          );
                                    },
                                    child: filteredSalaries.isEmpty
                                        ? Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.search_off,
                                                  size: 64,
                                                  color: Theme.of(context).hintColor,
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  'لا توجد نتائج للبحث',
                                                  style: Theme.of(context).textTheme.titleLarge,
                                                ),
                                              ],
                                            ),
                                          )
                                        : ListView.builder(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            itemCount: filteredSalaries.length,
                                            itemBuilder: (context, index) {
                                              final salary = filteredSalaries[index];
                                              return SalaryCard(salary: salary);
                                            },
                                          ),
                                  ),
                                ),
                                // Totals section
                                if (filteredTotalsByCurrency.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surface,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, -2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: Icon(
                                                    _showTotals
                                                        ? Icons.expand_less
                                                        : Icons.expand_more,
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _showTotals = !_showTotals;
                                                    });
                                                  },
                                                  tooltip: _showTotals ? 'إخفاء الإجمالي' : 'عرض الإجمالي',
                                                ),
                                                Text(
                                                  'الإجمالي',
                                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                ),
                                              ],
                                            ),
                                            // Download button
                                            BlocBuilder<SalaryBloc, SalaryState>(
                                              builder: (context, state) {
                                                if (state is SalariesLoaded ||
                                                    (state is SalaryExporting &&
                                                        state.lastLoadedResponse != null) ||
                                                    (state is SalaryExportSuccess &&
                                                        state.lastLoadedResponse != null)) {
                                                  return IconButton(
                                                    icon: const Icon(Icons.download),
                                                    tooltip: 'تصدير Excel',
                                                    onPressed: () {
                                                      context.read<SalaryBloc>().add(
                                                            ExportSalaries(
                                                              year: _selectedYear,
                                                              month: _selectedMonth,
                                                              unifiedHourPrice: _unifiedHourPrice,
                                                            ),
                                                          );
                                                    },
                                                  );
                                                }
                                                return const SizedBox.shrink();
                                              },
                                            ),
                                          ],
                                        ),
                                        if (_showTotals) ...[
                                          const SizedBox(height: 12),
                                          ...filteredTotalsByCurrency.entries.map((entry) {
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'إجمالي ${entry.key}',
                                                    style: Theme.of(context).textTheme.titleMedium,
                                                  ),
                                                  Text(
                                                    '${entry.key} ${entry.value.toStringAsFixed(2)}',
                                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                          fontWeight: FontWeight.bold,
                                                          color: Theme.of(context).colorScheme.primary,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            // Show loading overlay during export
                            if (isExporting)
                              Container(
                                color: Colors.black.withOpacity(0.3),
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
          ),
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
          hintText: 'ابحث عن معلم...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
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
        },
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context) {
    // Arabic month names
    final arabicMonths = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          // Previous month button
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
              _loadSalaries(context);
            },
          ),

          // Date display section
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Clickable month
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
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Clickable year
                InkWell(
                  onTap: () => _showYearPicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                          size: 16,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Next month button
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
              _loadSalaries(context);
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
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
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
                      _loadSalaries(context);
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
                    _loadSalaries(context);
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

  void _loadSalaries(BuildContext context) {
    context.read<SalaryBloc>().add(
          LoadSalaries(
            year: _selectedYear,
            month: _selectedMonth,
            unifiedHourPrice: _unifiedHourPrice,
          ),
        );
  }

  Widget _buildUnifiedHourPriceSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _unifiedHourPriceController,
              decoration: InputDecoration(
                labelText: 'سعر الساعة الموحد',
                labelStyle: Theme.of(context).textTheme.bodySmall,
                hintText: 'أدخل سعر الساعة الموحد',
                hintStyle: Theme.of(context).textTheme.bodySmall,
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 12),
          Builder(
            builder: (builderContext) {
              return ElevatedButton.icon(
                onPressed: () {
                  final priceText = _unifiedHourPriceController.text.trim();
                  if (priceText.isNotEmpty) {
                    final price = double.tryParse(priceText);
                    if (price != null && price > 0) {
                      setState(() {
                        _unifiedHourPrice = price;
                      });
                      // Force reload by dispatching the event directly
                      builderContext.read<SalaryBloc>().add(
                        LoadSalaries(
                          year: _selectedYear,
                          month: _selectedMonth,
                          unifiedHourPrice: price,
                        ),
                      );
                      ScaffoldMessenger.of(builderContext).showSnackBar(
                        SnackBar(
                          content: Text('تم تطبيق سعر الساعة الموحد: $price'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(builderContext).showSnackBar(
                        const SnackBar(
                          content: Text('يرجى إدخال سعر صحيح'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } else {
                    setState(() {
                      _unifiedHourPrice = null;
                    });
                    // Force reload by dispatching the event directly
                    builderContext.read<SalaryBloc>().add(
                      LoadSalaries(
                        year: _selectedYear,
                        month: _selectedMonth,
                        unifiedHourPrice: null,
                      ),
                    );
                    ScaffoldMessenger.of(builderContext).showSnackBar(
                      const SnackBar(
                        content: Text('تم إلغاء سعر الساعة الموحد'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('تطبيق'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              );
            },
          ),
          if (_unifiedHourPrice != null) ...[
            const SizedBox(width: 8),
            Builder(
              builder: (builderContext) {
                return IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _unifiedHourPrice = null;
                      _unifiedHourPriceController.clear();
                    });
                    builderContext.read<SalaryBloc>().add(
                      LoadSalaries(
                        year: _selectedYear,
                        month: _selectedMonth,
                        unifiedHourPrice: null,
                      ),
                    );
                  },
                  tooltip: 'إلغاء',
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
