import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/datasources/billing_remote_datasource.dart';
import '../bloc/auto_billing_bloc.dart';
import '../bloc/auto_billing_event.dart';
import '../bloc/auto_billing_state.dart';

class BillingSendLogsPage extends StatefulWidget {
  final int year;
  final int month;

  const BillingSendLogsPage({
    super.key,
    required this.year,
    required this.month,
  });

  @override
  State<BillingSendLogsPage> createState() => _BillingSendLogsPageState();
}

class _BillingSendLogsPageState extends State<BillingSendLogsPage> {
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
          // Load logs when bloc is created
          bloc.add(
            LoadAutoBillingsSendLogs(
              year: widget.year,
              month: widget.month,
            ),
          );
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
              // Reload logs after sending
              context.read<AutoBillingBloc>().add(
                    LoadAutoBillingsSendLogs(
                      year: widget.year,
                      month: widget.month,
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
          child: Scaffold(
            appBar: AppBar(
              title: const Text('سجل إرسال الفواتير'),
            ),
            body: BlocBuilder<AutoBillingBloc, AutoBillingState>(
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
                                  LoadAutoBillingsSendLogs(
                                    year: widget.year,
                                    month: widget.month,
                                  ),
                                );
                          },
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  );
                }

                if (state is AutoBillingsSendLogsLoaded) {
                  final logsData = state.logsData;
                  final batches = logsData['batches'] as List<dynamic>;
                  final summary = logsData['summary'] as Map<String, dynamic>;

                  if (batches.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color: Theme.of(context).hintColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد سجلات إرسال',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Summary Card
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ملخص الإرسال',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryItem(
                                    context,
                                    'إجمالي الطلاب',
                                    '${summary['total_students']}',
                                    Colors.blue,
                                  ),
                                ),
                                Expanded(
                                  child: _buildSummaryItem(
                                    context,
                                    'تم الإرسال',
                                    '${summary['total_sent']}',
                                    Colors.green,
                                  ),
                                ),
                                Expanded(
                                  child: _buildSummaryItem(
                                    context,
                                    'فشل',
                                    '${summary['total_failed']}',
                                    Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            if (summary['total_failed'] as int > 0) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showResumeDialog(context),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('إعادة إرسال للفاشلين'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Batches List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: batches.length,
                          itemBuilder: (context, index) {
                            final batch = batches[index] as Map<String, dynamic>;
                            return _buildBatchCard(context, batch);
                          },
                        ),
                      ),
                    ],
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).hintColor,
              ),
        ),
      ],
    );
  }

  Widget _buildBatchCard(BuildContext context, Map<String, dynamic> batch) {
    final sent = batch['sent'] as int;
    final failed = batch['failed'] as int;
    final total = batch['total'] as int;
    final pending = batch['pending'] as int;
    final createdAt = DateTime.parse(batch['created_at'] as String);
    final logs = batch['logs'] as List<dynamic>;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(
          failed > 0
              ? Icons.error_outline
              : (pending > 0 ? Icons.pending : Icons.check_circle),
          color: failed > 0
              ? Colors.red
              : (pending > 0 ? Colors.orange : Colors.green),
        ),
        title: Text(
          'دفعة ${DateFormat('yyyy-MM-dd HH:mm').format(createdAt)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        subtitle: Text(
          'الإجمالي: $total | تم: $sent | فشل: $failed | قيد الانتظار: $pending',
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تفاصيل الإرسال',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                ...logs.map((log) {
                  final status = log['status'] as String;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: status == 'success'
                          ? Colors.green.withOpacity(0.1)
                          : status == 'failed'
                              ? Colors.red.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: status == 'success'
                            ? Colors.green
                            : status == 'failed'
                                ? Colors.red
                                : Colors.orange,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          status == 'success'
                              ? Icons.check_circle
                              : status == 'failed'
                                  ? Icons.error
                                  : Icons.pending,
                          color: status == 'success'
                              ? Colors.green
                              : status == 'failed'
                                  ? Colors.red
                                  : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log['student_name'] as String,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              if (log['error_message'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  log['error_message'] as String,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.red,
                                      ),
                                ),
                              ],
                              if (log['sent_at'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'تم الإرسال: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(log['sent_at'] as String))}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).hintColor,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showResumeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إعادة إرسال للفاشلين'),
          content: const Text(
            'سيتم إعادة إرسال رسائل واتساب للطلاب الذين فشل إرسال رسائلهم فقط. هل تريد المتابعة؟',
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
                      ResumeSendAutoBillingsWhatsApp(
                        year: widget.year,
                        month: widget.month,
                      ),
                    );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('إعادة الإرسال'),
            ),
          ],
        ),
      ),
    );
  }
}
