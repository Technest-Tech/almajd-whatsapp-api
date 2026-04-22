import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:multi_features_app/l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/back_button_handler.dart';
import '../../../../common_widgets/dashboard_card.dart';
import '../../../../core/models/user_role.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../client_panel/data/services/client_auth_service.dart';

/// Main dashboard page with module selection cards
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BackButtonHandler(
      child: Builder(
        builder: (context) => Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              leadingWidth: 170,
              titleSpacing: 0,
              leading: Padding(
                padding: const EdgeInsets.only(left: AppSizes.spaceMd),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildLogoutButton(context),
                ),
              ),
              title: Text(AppLocalizations.of(context)!.dashboard),
            ),
            body: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.backgroundLight,
                      AppColors.backgroundLight.withOpacity(0.95),
                    ],
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        final userRole = state is Authenticated ? state.user.role : null;
                        final isViewerAccount = userRole == UserRole.calendarViewer || 
                                               userRole == UserRole.certificateViewer;
                        
                        if (isViewerAccount) {
                          // For viewer accounts, use a centered layout that fills the screen
                          return SingleChildScrollView(
                            padding: EdgeInsets.symmetric(
                              horizontal: MediaQuery.of(context).size.width > 600 
                                  ? AppSizes.spaceXl 
                                  : AppSizes.spaceMd,
                              vertical: AppSizes.spaceLg,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Welcome header
                                  _buildWelcomeHeader(context)
                                      .animate()
                                      .fadeIn(duration: 400.ms)
                                      .slideX(
                                        begin: -0.2,
                                        end: 0,
                                        duration: 400.ms,
                                        curve: Curves.easeOutCubic,
                                      ),

                                  SizedBox(
                                    height: MediaQuery.of(context).size.width > 600 
                                        ? AppSizes.spaceXxl 
                                        : AppSizes.spaceXl,
                                  ),

                                  // Module cards (single card for viewer)
                                  _buildModuleCards(context),
                                ],
                              ),
                            ),
                          );
                        }
                        
                        // For regular accounts, use the original layout
                        return SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width > 600 
                                ? AppSizes.spaceXl 
                                : AppSizes.spaceMd,
                            vertical: AppSizes.spaceLg,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Welcome header with improved design
                              _buildWelcomeHeader(context)
                                  .animate()
                                  .fadeIn(duration: 400.ms)
                                  .slideX(
                                    begin: -0.2,
                                    end: 0,
                                    duration: 400.ms,
                                    curve: Curves.easeOutCubic,
                                  ),

                              SizedBox(
                                height: MediaQuery.of(context).size.width > 600 
                                    ? AppSizes.spaceXxl 
                                    : AppSizes.spaceXl,
                              ),

                              // Module cards grid
                              _buildModuleCards(context),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
  }


  Widget _buildLogoutButton(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final bool canShowButton = state is Authenticated || state is AuthLoading;
        final bool isLoading = state is AuthLoading;

        if (!canShowButton) {
          return const SizedBox.shrink();
        }

        return Opacity(
          opacity: isLoading ? 0.8 : 1,
          child: GestureDetector(
            onTap: isLoading
                ? null
                : () => context.read<AuthBloc>().add(const LogoutEvent()),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spaceMd,
                vertical: AppSizes.spaceSm,
              ),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    const SizedBox(
                      height: AppSizes.iconSm,
                      width: AppSizes.iconSm,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    const Icon(
                      Icons.logout_rounded,
                      color: Colors.white,
                      size: AppSizes.iconSm,
                    ),
                  const SizedBox(width: AppSizes.spaceSm),
                  Text(
                    AppLocalizations.of(context)!.logout,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeHeader(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          // userName available if needed
        }

        return Container(
          padding: const EdgeInsets.all(AppSizes.spaceLg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowLight,
                blurRadius: 20,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              // Welcome icon
              Container(
                padding: const EdgeInsets.all(AppSizes.spaceMd),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: const Icon(
                  Icons.waving_hand_rounded,
                  color: Colors.white,
                  size: AppSizes.iconLg,
                ),
              ),
              const SizedBox(width: AppSizes.spaceLg),
              // Welcome text
              Expanded(
                child: Text(
                  'أهلا بعودتك د/ابراهيم',
                  style: GoogleFonts.almarai(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModuleCards(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final userRole = state is Authenticated ? state.user.role : null;
        
        // Get cards based on user role
        final cards = _getCardsForRole(context, userRole);
        
        if (cards.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.spaceXl),
              child: Text(
                'لا توجد أقسام متاحة لحسابك',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        }
        
        // If only one card, center it instead of using GridView
        if (cards.length == 1) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width > 600 
                    ? AppSizes.spaceXl * 2
                    : AppSizes.spaceLg,
                vertical: AppSizes.spaceLg,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: 300,
                ),
                child: cards.first,
              ),
            ),
          );
        }
        
        final screenWidth = MediaQuery.of(context).size.width;
        final isTablet = screenWidth > 600;
        final crossAxisCount = _getCrossAxisCount(context);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cards grid
            GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: isTablet ? AppSizes.spaceLg : AppSizes.spaceMd,
              mainAxisSpacing: isTablet ? AppSizes.spaceLg : AppSizes.spaceMd,
              childAspectRatio: isTablet ? 1.1 : 1.0,
              children: cards,
            ),
          ],
        );
      },
    );
  }

  List<Widget> _getCardsForRole(BuildContext context, UserRole? role) {
    final cards = <Widget>[];
    int delay = 100;

    // Calendar Viewer - Only Calendar
    if (role == UserRole.calendarViewer) {
      cards.add(
        DashboardCard(
          title: AppLocalizations.of(context)!.calendar,
          icon: Icons.calendar_today_rounded,
          gradient: AppColors.purpleGradient,
          onTap: () => context.push(AppRouter.calendar),
        ).animate(delay: delay.ms),
      );
      return cards;
    }

    // Certificate Viewer - Only Certificates
    if (role == UserRole.certificateViewer) {
      cards.add(
        DashboardCard(
          title: AppLocalizations.of(context)!.certificates,
          icon: Icons.workspace_premium_rounded,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
          ),
          onTap: () => context.push(AppRouter.certificates),
        ).animate(delay: delay.ms),
      );
      return cards;
    }

    // Admin sees all cards
    if (role == UserRole.admin) {
      cards.addAll([
        // Rooms Card
        DashboardCard(
          title: AppLocalizations.of(context)!.rooms,
          icon: Icons.meeting_room_rounded,
          gradient: AppColors.primaryGradient,
          onTap: () => _handleRoomsClick(context),
        ).animate(delay: (delay += 50).ms),

        // Users & Courses Card
        DashboardCard(
          title: AppLocalizations.of(context)!.usersAndCourses,
          icon: Icons.school_rounded,
          gradient: AppColors.successGradient,
          onTap: () => context.push(AppRouter.usersAndCourses),
        ).animate(delay: (delay += 50).ms),

        // Billings Card
        DashboardCard(
          title: AppLocalizations.of(context)!.billings,
          icon: Icons.account_balance_wallet_rounded,
          gradient: AppColors.accentGradient,
          onTap: () => context.push(AppRouter.billings),
        ).animate(delay: (delay += 50).ms),

        // Calendar Card
        DashboardCard(
          title: AppLocalizations.of(context)!.calendar,
          icon: Icons.calendar_today_rounded,
          gradient: AppColors.purpleGradient,
          onTap: () => context.push(AppRouter.calendar),
        ).animate(delay: (delay += 50).ms),

        // Certificates Card
        DashboardCard(
          title: AppLocalizations.of(context)!.certificates,
          icon: Icons.workspace_premium_rounded,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
          ),
          onTap: () => context.push(AppRouter.certificates),
        ).animate(delay: (delay += 50).ms),

        // Settings & Reports Card
        DashboardCard(
          title: AppLocalizations.of(context)!.settingsReports,
          icon: Icons.settings_rounded,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF64748B), Color(0xFF94A3B8)],
          ),
          onTap: () => context.push(AppRouter.settings),
        ).animate(delay: (delay += 50).ms),
      ]);
      return cards;
    }

    // Default cards for teacher and student (existing behavior)
    cards.addAll([
      // Rooms Card
      DashboardCard(
        title: AppLocalizations.of(context)!.rooms,
        icon: Icons.meeting_room_rounded,
        gradient: AppColors.primaryGradient,
        onTap: () => _handleRoomsClick(context),
      ).animate(delay: (delay += 50).ms),

      // Users & Courses Card
      DashboardCard(
        title: AppLocalizations.of(context)!.usersAndCourses,
        icon: Icons.school_rounded,
        gradient: AppColors.successGradient,
        onTap: () => context.push(AppRouter.usersAndCourses),
      ).animate(delay: (delay += 50).ms),

      // Billings Card
      DashboardCard(
        title: AppLocalizations.of(context)!.billings,
        icon: Icons.account_balance_wallet_rounded,
        gradient: AppColors.accentGradient,
        onTap: () => context.push(AppRouter.billings),
      ).animate(delay: (delay += 50).ms),

      // Calendar Card
      DashboardCard(
        title: AppLocalizations.of(context)!.calendar,
        icon: Icons.calendar_today_rounded,
        gradient: AppColors.purpleGradient,
        onTap: () => context.push(AppRouter.calendar),
      ).animate(delay: (delay += 50).ms),

      // Certificates Card
      DashboardCard(
        title: AppLocalizations.of(context)!.certificates,
        icon: Icons.workspace_premium_rounded,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
        ),
        onTap: () => context.push(AppRouter.certificates),
      ).animate(delay: (delay += 50).ms),

      // Settings & Reports Card
      DashboardCard(
        title: AppLocalizations.of(context)!.settingsReports,
        icon: Icons.settings_rounded,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF64748B), Color(0xFF94A3B8)],
        ),
        onTap: () => context.push(AppRouter.settings),
      ).animate(delay: (delay += 50).ms),
    ]);

    return cards;
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 3;
    if (width > 800) return 3;
    if (width > 600) return 2;
    return 2;
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'teacher':
        return Icons.school_rounded;
      case 'student':
        return Icons.person_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  Future<void> _handleRoomsClick(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Auto-login to client panel
      await ClientAuthService.autoLogin();

      if (context.mounted) {
        // Close loading dialog
        Navigator.of(context).pop();
        
        // Navigate to client dashboard
        context.push('/client/dashboard');
      }
    } catch (e) {
      if (context.mounted) {
        // Close loading dialog
        Navigator.of(context).pop();
        
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تسجيل الدخول: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

