import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../common_widgets/billing_bottom_bar.dart';
import 'payment_dashboard_page.dart';
import 'auto_billings_page.dart';
import 'manual_billings_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';

/// Billing and Reports Home Page - Main entry point for Billing and Reports module
/// This page shows Payment Dashboard by default and includes the bottom bar with 4 buttons
class BillingAndReportsHomePage extends StatelessWidget {
  const BillingAndReportsHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the current route to determine which page to show
    final currentLocation = GoRouterState.of(context).uri.path;

    Widget currentPage;
    String pageTitle;

    // Check which section we're in
    if (currentLocation == AppRouter.billings ||
        currentLocation.contains('/dashboard')) {
      // Show Payment Dashboard by default
      currentPage = const PaymentDashboardPage();
      pageTitle = 'لوحة المدفوعات';
    } else if (currentLocation.contains('/auto')) {
      currentPage = const AutoBillingsPage();
      pageTitle = 'الفواتير التلقائية';
    } else if (currentLocation.contains('/manual')) {
      currentPage = const ManualBillingsPage();
      pageTitle = 'الفواتير اليدوية';
    } else if (currentLocation.contains('/reports')) {
      currentPage = const ReportsPage();
      pageTitle = 'التقارير';
    } else {
      // Default to Payment Dashboard
      currentPage = const PaymentDashboardPage();
      pageTitle = 'لوحة المدفوعات';
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(pageTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(AppRouter.dashboard),
          ),
        ),
        body: currentPage,
        bottomNavigationBar: BillingBottomBar(
          currentRoute: currentLocation,
        ),
      ),
    );
  }
}
