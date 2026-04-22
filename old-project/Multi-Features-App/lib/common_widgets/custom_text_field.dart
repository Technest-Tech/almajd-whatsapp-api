import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';

/// Custom text field with modern design
class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int maxLines;
  final TextDirection? textDirection;
  final TextAlign? textAlign;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.textDirection,
    this.textAlign,
  });

  TextDirection _getTextDirection(BuildContext context) {
    final locale = Localizations.localeOf(context);
    // Arabic and Hebrew are RTL languages
    if (locale.languageCode == 'ar' || locale.languageCode == 'he') {
      return TextDirection.rtl;
    }
    return TextDirection.ltr;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: AppSizes.spaceSm),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
          validator: validator,
          onChanged: onChanged,
          maxLines: maxLines,
          enabled: true,
          readOnly: false,
          enableInteractiveSelection: true,
          autofocus: false,
          textDirection: textDirection ?? _getTextDirection(context), // Support RTL for Arabic
          textAlign: textAlign ?? TextAlign.start,
          textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.done,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 16,
            ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: BorderSide(
                color: AppColors.textTertiary.withOpacity(0.3),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: BorderSide(
                color: AppColors.textTertiary.withOpacity(0.3),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: const BorderSide(
                color: AppColors.primaryBlue,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spaceMd,
              vertical: AppSizes.spaceMd,
            ),
          ),
        ),
      ],
    );
  }
}


