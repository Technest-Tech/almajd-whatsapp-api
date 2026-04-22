import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:multi_features_app/l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/back_button_handler.dart';

/// Billing Management placeholder page
class BillingPage extends StatelessWidget {
  const BillingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BackButtonHandler(
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.billings),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.spaceLg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon with gradient background
                Container(
                  padding: const EdgeInsets.all(AppSizes.spaceXl),
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowMedium,
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 80,
                    color: Colors.white,
                  ),
                )
                    .animate()
                    .scale(duration: 600.ms, curve: Curves.easeOutBack)
                    .then()
                    .shimmer(duration: 1000.ms),

                const SizedBox(height: AppSizes.spaceXl),

                // Coming soon text
                Text(
                  AppLocalizations.of(context)!.comingSoon,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                  textAlign: TextAlign.center,
                ).animate(delay: 200.ms).fadeIn(duration: 600.ms).slideY(
                      begin: 0.3,
                      end: 0,
                      duration: 600.ms,
                      curve: Curves.easeOutCubic,
                    ),

                const SizedBox(height: AppSizes.spaceMd),

                // Module name
                Text(
                  AppLocalizations.of(context)!.billings,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.accentOrange,
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ).animate(delay: 300.ms).fadeIn(duration: 600.ms),

                const SizedBox(height: AppSizes.spaceMd),

                // Description
                Text(
                  AppLocalizations.of(context)!.featureInDevelopment,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ).animate(delay: 400.ms).fadeIn(duration: 600.ms),

                const SizedBox(height: AppSizes.spaceXl),

                // Feature list
                _buildFeatureList(context)
                    .animate(delay: 500.ms)
                    .fadeIn(duration: 600.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureList(BuildContext context) {
    final features = [
      'Invoice generation and management',
      'Payment tracking',
      'Fee collection',
      'Payment history',
      'Financial reports',
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upcoming Features:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: AppSizes.spaceMd),
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.spaceSm),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.success,
                      size: AppSizes.iconSm,
                    ),
                    const SizedBox(width: AppSizes.spaceSm),
                    Expanded(
                      child: Text(
                        feature,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

