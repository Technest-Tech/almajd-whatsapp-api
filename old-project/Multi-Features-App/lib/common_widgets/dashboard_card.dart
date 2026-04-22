import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/constants/app_sizes.dart';

/// Modern animated dashboard card for module selection
class DashboardCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const DashboardCard({
    super.key,
    required this.title,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<DashboardCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _animationController.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _animationController.reverse();
      },
      child: GestureDetector(
        onTapDown: (_) => _animationController.forward(),
        onTapUp: (_) {
          _animationController.reverse();
          widget.onTap();
        },
        onTapCancel: () => _animationController.reverse(),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  gradient: widget.gradient,
                  borderRadius: BorderRadius.circular(AppSizes.radiusXl),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(_isHovered ? 0.25 : 0.15),
                      blurRadius: _isHovered ? 24 : 16,
                      offset: Offset(0, _isHovered ? 12 : 8),
                      spreadRadius: _isHovered ? 2 : 0,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Decorative background pattern
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -30,
                      left: -30,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                    ),
                    // Main content
                    Padding(
                      padding: const EdgeInsets.all(AppSizes.spaceMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Icon container with modern design
                          Container(
                            padding: const EdgeInsets.all(AppSizes.spaceSm),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              widget.icon,
                              size: AppSizes.iconLg,
                              color: Colors.white,
                            ),
                          ),
                          
                          const Spacer(),
                          
                          // Title with better typography
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppSizes.spaceXs),
                              // Subtle subtitle indicator
                              Container(
                                width: 35,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: AppSizes.spaceXs),
                          
                          // Arrow icon with smooth animation
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              transform: Matrix4.translationValues(
                                _isHovered ? 4 : 0,
                                0,
                                0,
                              ),
                              child: Directionality.of(context) == TextDirection.rtl
                                  ? Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
                                      child: Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        color: Colors.white.withOpacity(0.9),
                                        size: AppSizes.iconXs,
                                      ),
                                    )
                                  : Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: Colors.white.withOpacity(0.9),
                                      size: AppSizes.iconXs,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ).animate().fadeIn(duration: 400.ms).slideY(
              begin: 0.2,
              end: 0,
              duration: 400.ms,
              curve: Curves.easeOutCubic,
            ),
      ),
    );
  }
}

