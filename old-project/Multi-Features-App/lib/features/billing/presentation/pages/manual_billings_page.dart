import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/datasources/billing_remote_datasource.dart';
import '../bloc/manual_billing_bloc.dart';
import '../bloc/manual_billing_event.dart';
import '../bloc/manual_billing_state.dart';
import '../widgets/manual_billing_card.dart';
import 'manual_billing_form_page.dart';

class ManualBillingsPage extends StatefulWidget {
  const ManualBillingsPage({super.key});

  @override
  State<ManualBillingsPage> createState() => _ManualBillingsPageState();
}

class _ManualBillingsPageState extends State<ManualBillingsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshBillings(BuildContext context) {
    if (mounted) {
      // Use post-frame callback to ensure the route is fully back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ManualBillingBloc>().add(
                LoadManualBillings(
                  search: _searchQuery.isEmpty ? null : _searchQuery,
                ),
              );
        }
      });
    }
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
          final bloc = ManualBillingBloc(dataSource);
          bloc.add(const LoadManualBillings());
          return bloc;
        },
        child: BlocListener<ManualBillingBloc, ManualBillingState>(
          listener: (context, state) {
            if (state is ManualBillingOperationSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
            }
            if (state is ManualBillingError) {
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
                  _buildSearchBar(scaffoldContext),
                  Expanded(
                    child: BlocBuilder<ManualBillingBloc, ManualBillingState>(
                    builder: (context, state) {
                      if (state is ManualBillingLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (state is ManualBillingError) {
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
                                  scaffoldContext.read<ManualBillingBloc>().add(
                                        const LoadManualBillings(),
                                      );
                                },
                                child: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        );
                      }

                      if (state is ManualBillingsLoaded) {
                        final billings = state.billings;

                        // Filter by search query
                        final filteredBillings = _searchQuery.isEmpty
                            ? billings
                            : billings.where((billing) {
                                return billing.studentNames
                                    .toLowerCase()
                                    .contains(_searchQuery.toLowerCase());
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
                                      ? 'لا توجد فواتير يدوية'
                                      : 'لا توجد نتائج للبحث',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () async {
                            scaffoldContext.read<ManualBillingBloc>().add(
                                  LoadManualBillings(
                                    search: _searchQuery.isEmpty ? null : _searchQuery,
                                  ),
                                );
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            itemCount: filteredBillings.length,
                            itemBuilder: (context, index) {
                              final billing = filteredBillings[index];
                              return ManualBillingCard(
                                billing: billing,
                                onTap: () async {
                                  // Navigate to details/edit
                                  await scaffoldContext.push(
                                    '${AppRouter.billings}/manual/${billing.id}/edit',
                                    extra: billing,
                                  );
                                  // Always refresh when coming back from edit page
                                  _refreshBillings(scaffoldContext);
                                },
                                onMarkPaid: () {
                                  scaffoldContext.read<ManualBillingBloc>().add(
                                        MarkManualBillingAsPaid(billing.id),
                                      );
                                },
                                onSendWhatsApp: () {
                                  // WhatsApp opening is now handled in the card widget
                                },
                                onDelete: () {
                                  _showDeleteDialog(scaffoldContext, billing.id);
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
                onPressed: () async {
                  await scaffoldContext.push('${AppRouter.billings}/manual/create');
                  // Always refresh when coming back from create page
                  _refreshBillings(scaffoldContext);
                },
                child: const Icon(Icons.add),
                tooltip: 'إضافة فاتورة يدوية',
              ),
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
                    context.read<ManualBillingBloc>().add(
                          const LoadManualBillings(),
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
          context.read<ManualBillingBloc>().add(
                LoadManualBillings(search: value.isEmpty ? null : value),
              );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: const Text('هل أنت متأكد من حذف هذه الفاتورة؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<ManualBillingBloc>().add(
                      DeleteManualBilling(id),
                    );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }
}
