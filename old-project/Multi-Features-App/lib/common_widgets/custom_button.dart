import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';

/// Custom gradient button with modern design
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color? textColor;
  final Widget? icon;
  final double? width;
  final double height;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.gradient,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.width,
    this.height = AppSizes.buttonHeightMd,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasGradient = gradient != null;

    Widget button = Container(
      width: width,
      height: height,
      decoration: hasGradient
          ? BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowMedium,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            )
          : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: hasGradient ? Colors.transparent : backgroundColor,
          foregroundColor: textColor ?? Colors.white,
          shadowColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    textColor ?? Colors.white,
                  ),
                ),
              )
            : Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      icon!,
                      const SizedBox(width: AppSizes.spaceSm),
                    ],
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor ?? Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );

    return button;
  }
}


