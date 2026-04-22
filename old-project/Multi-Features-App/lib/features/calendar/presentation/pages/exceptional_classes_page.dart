import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../bloc/calendar_bloc.dart';
import '../widgets/modern_sidebar.dart';

class ExceptionalClassesPage extends StatefulWidget {
  const ExceptionalClassesPage({super.key});

  @override
  State<ExceptionalClassesPage> createState() => _ExceptionalClassesPageState();
}

class _ExceptionalClassesPageState extends State<ExceptionalClassesPage>
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
    final currentRoute = '/calendar/exceptional-classes';

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content
            Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(AppSizes.spaceMd),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.textTertiary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu_rounded),
                        onPressed: _toggleSidebar,
                        color: AppColors.primary,
                      ),
                      const Expanded(
                        child: Text(
                          'الحصص الاستثنائية',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48), // Balance the menu button
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: Center(
                    child: Text(
                      'صفحة الحصص الاستثنائية',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
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
                  child: ModernSidebar(
                    currentRoute: currentRoute,
                    onClose: _toggleSidebar,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
