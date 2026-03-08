import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  late final AnimationController _animController;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/inbox');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message, textAlign: TextAlign.center),
              backgroundColor: AppColors.coral,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SlideTransition(
                position: _slideUp,
                child: FadeTransition(
                  opacity: _animController,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Logo ──
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.school_rounded, size: 48, color: Colors.white),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'أكاديمية المجد',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'تسجيل الدخول',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white54,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // ── Email ──
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(
                            hintText: 'البريد الإلكتروني',
                            prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'مطلوب';
                            if (!v.contains('@')) return 'بريد إلكتروني غير صالح';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // ── Password ──
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            hintText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'مطلوب';
                            if (v.length < 6) return 'كلمة المرور قصيرة جداً';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // ── Remember Me ──
                        Row(
                          children: [
                            Text(
                              'تذكرني',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                            const Spacer(),
                            Switch.adaptive(
                              value: _rememberMe,
                              activeTrackColor: AppColors.primary,
                              onChanged: (v) => setState(() => _rememberMe = v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── Login Button ──
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) {
                            final isLoading = state is AuthLoading;
                            return ElevatedButton(
                              onPressed: isLoading ? null : _onLogin,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('تسجيل الدخول'),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // ── Biometric ──
                        IconButton(
                          icon: Icon(
                            Icons.fingerprint_rounded,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          onPressed: () {
                            // TODO: Biometric auth
                          },
                        ),

                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(AuthLoginRequested(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ));
    }
  }
}
