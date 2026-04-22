import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import 'client_sidebar.dart';
import '../../data/services/client_auth_service.dart';

class ClientPanelLayout extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final String currentRoute;
  final String userEmail;
  final List<Widget>? actions;

  const ClientPanelLayout({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    required this.currentRoute,
    required this.userEmail,
    this.actions,
  });

  @override
  State<ClientPanelLayout> createState() => _ClientPanelLayoutState();
}

class _ClientPanelLayoutState extends State<ClientPanelLayout>
    with SingleTickerProviderStateMixin {
  bool _isSidebarOpen = false;
  late AnimationController _animationController;
  late Animation<double> _sidebarAnimation;
  late Animation<double> _blurAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sidebarAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _blurAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
      if (_isSidebarOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: SafeArea(
          child: Stack(
            children: [
              // Main Content (always visible)
              Column(
                children: [
                  // Header
                  _buildHeader(context),
                  
                  // Content
                  Expanded(
                    child: widget.child,
                  ),
                ],
              ),

            // Blur overlay when sidebar is open
            AnimatedBuilder(
              animation: _blurAnimation,
              builder: (context, child) {
                return Visibility(
                  visible: _isSidebarOpen,
                  child: GestureDetector(
                    onTap: _toggleSidebar,
                    child: Container(
                      color: Colors.black.withOpacity(0.3 * _blurAnimation.value),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 5.0 * _blurAnimation.value,
                          sigmaY: 5.0 * _blurAnimation.value,
                        ),
                        child: Container(
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Sidebar overlay
            AnimatedBuilder(
              animation: _sidebarAnimation,
              builder: (context, child) {
                return Positioned(
                  right: -280 * (1 - _sidebarAnimation.value),
                  top: 0,
                  bottom: 0,
                  width: 280,
                  child: ClientSidebar(
                    userEmail: widget.userEmail,
                    currentRoute: widget.currentRoute,
                    onLogout: () async {
                      await ClientAuthService.logout();
                      if (context.mounted) {
                        context.go('/dashboard');
                      }
                    },
                    onClose: _toggleSidebar,
                  ),
                );
              },
            ),

            // Floating toggle button
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                onPressed: _toggleSidebar,
                backgroundColor: AppColors.primary,
                child: Icon(
                  _isSidebarOpen ? Icons.close_rounded : Icons.menu_rounded,
                  color: Colors.white,
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
          if (widget.actions != null) ...[
            const SizedBox(width: 16),
            Flexible(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: widget.actions!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
