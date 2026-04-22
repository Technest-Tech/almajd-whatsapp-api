import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../data/services/client_auth_service.dart';
import '../widgets/client_panel_layout.dart';

class ClientSettingsPage extends StatelessWidget {
  const ClientSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final user = ClientAuthService.currentUser;
    final userEmail = user?['email'] as String? ?? '';

    return ClientPanelLayout(
      title: 'الإعدادات',
      subtitle: 'إعدادات حسابك',
      currentRoute: currentRoute,
      userEmail: userEmail,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        child: Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: userEmail,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    border: OutlineInputBorder(),
                    enabled: false,
                  ),
                ),
                const SizedBox(height: AppSizes.spaceMd),
                const Text(
                  'لا يمكن تغيير البريد الإلكتروني. يرجى التواصل مع المسؤول',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.spaceXl),
                const Divider(),
                const SizedBox(height: AppSizes.spaceLg),
                const Text(
                  'تغيير كلمة المرور',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.spaceMd),
                const Text(
                  'لطلب تغيير كلمة المرور، يرجى التواصل مع المسؤول',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
