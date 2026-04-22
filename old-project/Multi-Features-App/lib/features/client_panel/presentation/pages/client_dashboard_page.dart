import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../data/models/subscription_model.dart';
import '../../data/models/client_limits_model.dart';
import '../../data/services/client_api_service.dart';
import '../../data/services/client_auth_service.dart';
import '../widgets/client_panel_layout.dart';

class ClientDashboardPage extends StatefulWidget {
  const ClientDashboardPage({super.key});

  @override
  State<ClientDashboardPage> createState() => _ClientDashboardPageState();
}

class _ClientDashboardPageState extends State<ClientDashboardPage> {
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
      title: 'لوحة التحكم',
      subtitle: 'نظرة عامة على حسابك واشتراكك',
      currentRoute: currentRoute,
      userEmail: _userEmail,
      actions: [
        ElevatedButton.icon(
          onPressed: () => context.push('/client/rooms'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('إنشاء غرفة جديدة'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spaceMd,
              vertical: AppSizes.spaceSm,
            ),
          ),
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Card
                  _buildWelcomeCard(),

                  const SizedBox(height: AppSizes.spaceLg),

                  // Subscription Status
                  if (_subscription != null) _buildSubscriptionCard(),

                  const SizedBox(height: AppSizes.spaceLg),

                  // Usage Limits
                  if (_limits != null) _buildLimitsCards(),

                  const SizedBox(height: AppSizes.spaceLg),

                  // Quick Actions
                  _buildQuickActions(),
                ],
              ),
            ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spaceLg),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.waving_hand_rounded,
            color: Colors.white,
            size: AppSizes.iconXl,
          ),
          const SizedBox(width: AppSizes.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'مرحباً بك، $_userEmail',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: AppSizes.spaceXs),
                const Text(
                  'إدارة غرفك ومراقبة استخدامك',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    final status = _subscription!.status;
    final isActive = status == 'ACTIVE' || status == 'TRIAL';
    final statusColor = isActive ? AppColors.success : AppColors.error;
    final statusText = _getStatusText(status);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.spaceSm),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Icon(
                    isActive ? Icons.check_circle : Icons.error,
                    color: statusColor,
                    size: AppSizes.iconMd,
                  ),
                ),
                const SizedBox(width: AppSizes.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'حالة الاشتراك',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subscription!.plan?.name ?? 'لا توجد خطة',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.spaceSm),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spaceSm,
                      vertical: AppSizes.spaceXs,
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
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
            if (!isActive) ...[
              const SizedBox(height: AppSizes.spaceMd),
              Container(
                padding: const EdgeInsets.all(AppSizes.spaceMd),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  border: Border.all(
                    color: AppColors.warning.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_rounded,
                      color: AppColors.warning,
                      size: AppSizes.iconSm,
                    ),
                    const SizedBox(width: AppSizes.spaceSm),
                    Expanded(
                      child: Text(
                        'اشتراكك غير نشط. يرجى التواصل مع المسؤول لتفعيل اشتراكك',
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLimitsCards() {
    final limits = _limits!;
    final totalHostsCapacity = limits.maxRooms;
    final perRoomGuestCapacity = (limits.maxParticipants - 1).clamp(0, double.infinity).toInt();
    final totalGuestCapacity = perRoomGuestCapacity * limits.maxRooms;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use responsive layout: wrap on small screens, row on large screens
        final isWide = constraints.maxWidth > 600;
        
        if (isWide) {
          return Row(
            children: [
              Expanded(
                child: _buildLimitCard(
                  icon: Icons.meeting_room_rounded,
                  title: 'الغرف',
                  used: limits.currentRooms,
                  total: limits.maxRooms,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSizes.spaceMd),
              Expanded(
                child: _buildLimitCard(
                  icon: Icons.trending_up_rounded,
                  title: 'السعة القصوى للمضيفين',
                  used: totalHostsCapacity,
                  total: totalHostsCapacity,
                  color: AppColors.success,
                  subtitle: 'مضيف واحد لكل غرفة',
                ),
              ),
              const SizedBox(width: AppSizes.spaceMd),
              Expanded(
                child: _buildLimitCard(
                  icon: Icons.people_rounded,
                  title: 'السعة القصوى للضيوف',
                  used: totalGuestCapacity,
                  total: totalGuestCapacity,
                  color: AppColors.accentPurple,
                  subtitle: 'إجمالي الضيوف المسموح بهم',
                ),
              ),
            ],
          );
        } else {
          // Stack vertically on small screens
          return Column(
            children: [
              _buildLimitCard(
                icon: Icons.meeting_room_rounded,
                title: 'الغرف',
                used: limits.currentRooms,
                total: limits.maxRooms,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppSizes.spaceMd),
              _buildLimitCard(
                icon: Icons.trending_up_rounded,
                title: 'السعة القصوى للمضيفين',
                used: totalHostsCapacity,
                total: totalHostsCapacity,
                color: AppColors.success,
                subtitle: 'مضيف واحد لكل غرفة',
              ),
              const SizedBox(height: AppSizes.spaceMd),
              _buildLimitCard(
                icon: Icons.people_rounded,
                title: 'السعة القصوى للضيوف',
                used: totalGuestCapacity,
                total: totalGuestCapacity,
                color: AppColors.accentPurple,
                subtitle: 'إجمالي الضيوف المسموح بهم',
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildLimitCard({
    required IconData icon,
    required String title,
    required int used,
    required int total,
    required Color color,
    String? subtitle,
  }) {
    final percentage = total > 0 ? (used / total) : 0.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.spaceSm),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Icon(icon, color: color, size: AppSizes.iconMd),
                ),
                const SizedBox(width: AppSizes.spaceSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spaceMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '$used',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '/ $total',
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
                  percentage >= 0.8 ? AppColors.error : color,
                ),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'إجراءات سريعة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceMd),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 400;
                if (isWide) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionCard(
                          icon: Icons.meeting_room_rounded,
                          title: 'إدارة الغرف',
                          color: AppColors.primary,
                          onTap: () => context.push('/client/rooms'),
                        ),
                      ),
                      const SizedBox(width: AppSizes.spaceMd),
                      Expanded(
                        child: _buildQuickActionCard(
                          icon: Icons.credit_card_rounded,
                          title: 'معلومات الاشتراك',
                          color: AppColors.accentPurple,
                          onTap: () => context.push('/client/subscription'),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildQuickActionCard(
                        icon: Icons.meeting_room_rounded,
                        title: 'إدارة الغرف',
                        color: AppColors.primary,
                        onTap: () => context.push('/client/rooms'),
                      ),
                      const SizedBox(height: AppSizes.spaceMd),
                      _buildQuickActionCard(
                        icon: Icons.credit_card_rounded,
                        title: 'معلومات الاشتراك',
                        color: AppColors.accentPurple,
                        onTap: () => context.push('/client/subscription'),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.spaceMd),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.spaceSm),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Icon(icon, color: color, size: AppSizes.iconSm),
              ),
              const SizedBox(width: AppSizes.spaceSm),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: AppSizes.iconXs,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
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
}
