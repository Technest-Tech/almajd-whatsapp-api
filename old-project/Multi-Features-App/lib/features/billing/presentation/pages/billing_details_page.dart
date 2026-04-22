import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;
import '../../../../core/router/app_router.dart';
import '../../../../core/constants/app_config.dart';
import '../../data/models/auto_billing_model.dart';
import '../../data/models/manual_billing_model.dart';
import 'package:url_launcher/url_launcher.dart';

class BillingDetailsPage extends StatelessWidget {
  final AutoBillingModel? autoBilling;
  final ManualBillingModel? manualBilling;

  const BillingDetailsPage({
    super.key,
    this.autoBilling,
    this.manualBilling,
  });

  String _getCurrencySymbol(String currency) {
    const symbols = {
      'USD': '\$',
      'GBP': '£',
      'EUR': '€',
      'EGP': 'E£',
      'SAR': '﷼',
      'AED': 'د.إ',
      'CAD': 'C\$',
    };
    return symbols[currency] ?? currency;
  }

  Future<void> _openPaymentLink(String? token) async {
    if (token == null) return;
    
    final url = Uri.parse('${AppConfig.backendBaseUrl}/payment/$token');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyPaymentLink(BuildContext context, String? token) async {
    if (token == null) return;
    
    final paymentUrl = '${AppConfig.backendBaseUrl}/payment/$token';
    await Clipboard.setData(ClipboardData(text: paymentUrl));
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نسخ رابط الدفع'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuto = autoBilling != null;
    final autoBillingModel = autoBilling;
    final manualBillingModel = manualBilling;
    
    // Get currency from the appropriate model
    final currency = isAuto 
        ? (autoBillingModel?.currency ?? 'USD')
        : (manualBillingModel?.currency ?? 'USD');
    final currencySymbol = _getCurrencySymbol(currency);
    
    // Get common properties
    final isPaid = isAuto 
        ? (autoBillingModel?.isPaid ?? false)
        : (manualBillingModel?.isPaid ?? false);
    final paidAt = isAuto 
        ? autoBillingModel?.paidAt
        : manualBillingModel?.paidAt;
    final paymentMethod = isAuto 
        ? autoBillingModel?.paymentMethod
        : manualBillingModel?.paymentMethod;
    final paymentToken = isAuto 
        ? autoBillingModel?.paymentToken
        : manualBillingModel?.paymentToken;
    final amount = isAuto 
        ? (autoBillingModel?.totalAmount ?? 0.0)
        : (manualBillingModel?.amount ?? 0.0);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isAuto ? 'تفاصيل الفاتورة التلقائية' : 'تفاصيل الفاتورة اليدوية'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        isPaid ? Icons.check_circle : Icons.pending,
                        color: isPaid ? Colors.green : Colors.orange,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPaid ? 'مدفوع' : 'غير مدفوع',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isPaid ? Colors.green : Colors.orange,
                                  ),
                            ),
                            if (paidAt != null)
                              Text(
                                'تاريخ الدفع: ${paidAt.day}/${paidAt.month}/${paidAt.year}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Billing Details
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تفاصيل الفاتورة',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      if (isAuto && autoBillingModel != null) ...[
                        _buildDetailRow(
                          context,
                          label: 'الطالب',
                          value: autoBillingModel.student?.name ?? 'Unknown',
                        ),
                        _buildDetailRow(
                          context,
                          label: 'الشهر',
                          value: '${autoBillingModel.monthName} ${autoBillingModel.year}',
                        ),
                        _buildDetailRow(
                          context,
                          label: 'إجمالي الساعات',
                          value: '${autoBillingModel.totalHours.toStringAsFixed(2)} ساعة',
                        ),
                      ] else if (!isAuto && manualBillingModel != null) ...[
                        _buildDetailRow(
                          context,
                          label: 'الطلاب',
                          value: manualBillingModel.studentNames,
                        ),
                        if (manualBillingModel.message != null && manualBillingModel.message!.isNotEmpty)
                          _buildDetailRow(
                            context,
                            label: 'الرسالة',
                            value: manualBillingModel.message!,
                          ),
                      ],
                      const Divider(),
                      _buildDetailRow(
                        context,
                        label: 'المبلغ',
                        value: '$currencySymbol ${amount.toStringAsFixed(2)}',
                        isHighlighted: true,
                      ),
                      if (paymentMethod != null)
                        _buildDetailRow(
                          context,
                          label: 'طريقة الدفع',
                          value: paymentMethod!,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Payment Link Section
              if (!isPaid && paymentToken != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'رابط الدفع',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _openPaymentLink(paymentToken),
                                icon: const Icon(Icons.payment),
                                label: const Text('فتح رابط الدفع'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _copyPaymentLink(context, paymentToken),
                              icon: const Icon(Icons.copy),
                              label: const Text('نسخ'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required String label,
    required String value,
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                  color: isHighlighted
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}
