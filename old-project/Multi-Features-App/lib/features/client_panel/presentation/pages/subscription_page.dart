import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../data/models/subscription_model.dart';
import '../../data/models/client_limits_model.dart';
import '../../data/services/client_api_service.dart';
import '../../data/services/client_auth_service.dart';
import '../widgets/client_panel_layout.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  Subscription? _subscription;
  ClientLimits? _limits;
  bool _isLoading = true;
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = ClientAuthService.currentUser;
      if (user != null) {
        _userEmail = user['email'] as String? ?? '';
      }

      final results = await Future.wait([
        ClientApiService.getSubscription(),
        ClientApiService.getLimits(),
      ]);

      setState(() {
        _subscription = results[0] as Subscription;
        _limits = results[1] as ClientLimits;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل البيانات: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return ClientPanelLayout(
      title: 'معلومات الاشتراك',
      subtitle: 'عرض تفاصيل اشتراكك وخطتك',
      currentRoute: currentRoute,
      userEmail: _userEmail,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_subscription != null) _buildSubscriptionCard(),
                  const SizedBox(height: AppSizes.spaceLg),
                  if (_subscription?.plan != null) _buildPlanFeatures(),
                  const SizedBox(height: AppSizes.spaceLg),
                  if (_limits != null) _buildUsageQuotas(),
                ],
              ),
            ),
    );
  }

  Widget _buildSubscriptionCard() {
    final status = _subscription!.status;
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'حالة الاشتراك',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.spaceMd,
                    vertical: AppSizes.spaceSm,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (_subscription!.plan != null) ...[
              const SizedBox(height: AppSizes.spaceMd),
              Text(
                _subscription!.plan!.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_subscription!.plan!.description != null) ...[
                const SizedBox(height: AppSizes.spaceXs),
                Text(
                  _subscription!.plan!.description!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlanFeatures() {
    final features = _subscription!.plan!.features;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الميزات المتاحة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceMd),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: AppSizes.spaceMd,
                mainAxisSpacing: AppSizes.spaceMd,
                childAspectRatio: 2.5,
              ),
              itemCount: features.length,
              itemBuilder: (context, index) {
                final feature = features[index];
                return Container(
                  padding: const EdgeInsets.all(AppSizes.spaceSm),
                  decoration: BoxDecoration(
                    color: feature.enabled
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    border: Border.all(
                      color: feature.enabled
                          ? AppColors.success.withOpacity(0.3)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        feature.enabled
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: feature.enabled
                            ? AppColors.success
                            : AppColors.textSecondary,
                        size: AppSizes.iconSm,
                      ),
                      const SizedBox(width: AppSizes.spaceSm),
                      Expanded(
                        child: Text(
                          _getFeatureLabel(feature.feature),
                          style: TextStyle(
                            fontSize: 12,
                            color: feature.enabled
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageQuotas() {
    final limits = _limits!;
    final percentage = limits.maxRooms > 0
        ? (limits.currentRooms / limits.maxRooms)
        : 0.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الحصص والاستخدام',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceLg),
            // Rooms Quota
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'الغرف',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${limits.currentRooms} / ${limits.maxRooms}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spaceSm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      percentage >= 0.9
                          ? AppColors.error
                          : percentage >= 0.7
                              ? AppColors.warning
                              : AppColors.success,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: AppSizes.spaceXs),
                Text(
                  '${(percentage * 100).toStringAsFixed(1)}% مستخدم',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spaceLg),
            // Max Participants
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'الحد الأقصى للمشاركين',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${limits.maxParticipants} مشارك',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return AppColors.success;
      case 'TRIAL':
        return AppColors.info;
      case 'EXPIRED':
      case 'TRIAL_EXPIRED':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'ACTIVE':
        return 'نشط';
      case 'TRIAL':
        return 'تجريبي';
      case 'EXPIRED':
        return 'منتهي';
      case 'TRIAL_EXPIRED':
        return 'انتهت الفترة التجريبية';
      default:
        return 'غير نشط';
    }
  }

  String _getFeatureLabel(String feature) {
    const labels = {
      'RECORDING': 'التسجيل',
      'WAITING_ROOM': 'غرفة الانتظار',
      'PRIVATE_CHAT': 'الدردشة الخاصة',
      'GUEST_UNMUTE': 'إلغاء كتم الضيوف',
      'HOST_APPROVAL': 'موافقة المضيف',
      'SCREEN_ANNOTATION': 'تعليقات الشاشة',
      'FILE_SHARING': 'مشاركة الملفات',
      'PDF_VIEWER': 'عارض PDF',
      'REACTIONS': 'التفاعلات',
      'RAISE_HAND': 'رفع اليد',
      'E2EE': 'التشفير من طرف لطرف',
      'CUSTOM_BRANDING': 'العلامة التجارية المخصصة',
      'PICTURE_IN_PICTURE': 'صورة داخل صورة',
      'STUDENT_MONITOR_PIP': 'مراقبة الطلاب',
      'COLLABORATIVE_WHITEBOARD': 'السبورة التعاونية',
      'NORMAL_WHITEBOARD': 'السبورة العادية',
      'MANAGE_PARTICIPANTS': 'إدارة المشاركين',
      'VIRTUAL_BACKGROUND': 'الخلفية الافتراضية',
    };
    return labels[feature] ?? feature;
  }
}
