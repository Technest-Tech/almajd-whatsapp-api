import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_config.dart';
import '../../data/models/auto_billing_model.dart';

class AutoBillingCard extends StatelessWidget {
  final AutoBillingModel billing;
  final VoidCallback? onTap;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onSendWhatsApp;

  const AutoBillingCard({
    super.key,
    required this.billing,
    this.onTap,
    this.onMarkPaid,
    this.onSendWhatsApp,
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

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _formatPhoneNumber(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) return '';
    // Remove all non-digit characters except +
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    // Remove + if present (we'll add it back if needed)
    bool hasPlus = cleaned.startsWith('+');
    if (hasPlus) {
      cleaned = cleaned.substring(1);
    }
    // Remove leading zeros if present (for local numbers)
    if (cleaned.startsWith('0') && !hasPlus) {
      cleaned = cleaned.substring(1);
    }
    return cleaned;
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final student = billing.student;
    if (student?.whatsappNumber == null || student!.whatsappNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد رقم واتساب للطالب'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final phoneNumber = _formatPhoneNumber(student.whatsappNumber);
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رقم واتساب غير صحيح'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final currencySymbol = _getCurrencySymbol(billing.currency);
    final monthName = _getMonthName(billing.month);
    
    // Build payment link if token exists
    String paymentLinkText = '';
    if (billing.paymentToken != null && billing.paymentToken!.isNotEmpty) {
      final paymentUrl = '${AppConfig.backendBaseUrl}/pay/${billing.paymentToken}';
      paymentLinkText = '\n\n💳 *Pay Securely:*\n$paymentUrl';
    }

    // Build modern English message with Almajd Academy branding
    final message = '🎓 *Almajd Academy*\n'
        '━━━━━━━━━━━━━━━━━━\n\n'
        '📋 *Invoice Details*\n'
        'Period: ${monthName} ${billing.year}\n'
        'Hours: ${billing.totalHours.toStringAsFixed(2)} hours\n\n'
        '💰 *Total Amount*\n'
        '*$currencySymbol${billing.totalAmount.toStringAsFixed(2)}*\n'
        '$paymentLinkText\n\n'
        'Thank you for choosing Almajd Academy! 🌟';

    // Encode the message for URL
    final encodedMessage = Uri.encodeComponent(message);
    
    // Build WhatsApp URL
    final whatsappUrl = Uri.parse('https://wa.me/$phoneNumber?text=$encodedMessage');
    
    // Try to launch WhatsApp
    try {
      // Try different launch modes for better compatibility
      bool launched = false;
      
      // First try: external non-browser application (preferred for Android)
      try {
        launched = await launchUrl(
          whatsappUrl,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } catch (e) {
        // If that fails, try external application
        try {
          launched = await launchUrl(
            whatsappUrl,
            mode: LaunchMode.externalApplication,
          );
        } catch (e2) {
          // Last resort: platform default
          launched = await launchUrl(
            whatsappUrl,
            mode: LaunchMode.platformDefault,
          );
        }
      }
      
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح واتساب. تأكد من تثبيت التطبيق'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // If all launch attempts fail, show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تعذر فتح واتساب. تأكد من تثبيت التطبيق'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'إعادة المحاولة',
              onPressed: () => _openWhatsApp(context),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = _getCurrencySymbol(billing.currency);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Student avatar/icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: billing.isPaid
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  billing.isPaid ? Icons.check_circle : Icons.pending,
                  color: billing.isPaid ? Colors.green : Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Student name and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      billing.student?.name ?? 'Unknown',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Theme.of(context).hintColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${billing.totalHours.toStringAsFixed(2)} ساعة',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).hintColor,
                              ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$currencySymbol ${billing.totalAmount.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons
              if (!billing.isPaid) ...[
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366), // WhatsApp green
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.message,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  onPressed: () => _openWhatsApp(context),
                  tooltip: 'فتح واتساب',
                ),
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  color: Colors.blue,
                  onPressed: onMarkPaid,
                  tooltip: 'تحديد كمدفوع',
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'مدفوع',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (billing.paidAt != null)
                        Text(
                          '${billing.paidAt!.day}/${billing.paidAt!.month}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).hintColor,
                                fontSize: 10,
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
