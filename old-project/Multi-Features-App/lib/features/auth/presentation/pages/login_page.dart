import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:multi_features_app/l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../common_widgets/custom_text_field.dart';
import '../../../../common_widgets/custom_button.dart';
import '../../../../common_widgets/loading_overlay.dart';
import '../../../../common_widgets/error_dialog.dart';
import '../../../../core/widgets/back_button_handler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../../core/models/user_role.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    // Ensure loading is false when page initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authState = context.read<AuthBloc>().state;
        if (authState is! AuthLoading) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _getUserFriendlyErrorMessage(String error) {
    // Clean up technical error messages
    if (error.toLowerCase().contains('invalid credentials') ||
        error.toLowerCase().contains('email') ||
        error.toLowerCase().contains('password')) {
      return AppLocalizations.of(context)!.invalidCredentials;
    }
    if (error.toLowerCase().contains('network') ||
        error.toLowerCase().contains('connection')) {
      return AppLocalizations.of(context)!.networkError;
    }
    // Return the error message as is, or a default message
    return error.isNotEmpty ? error : AppLocalizations.of(context)!.invalidCredentials;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseEnterEmailAndPassword),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Set loading state when user clicks login
    setState(() {
      _isLoading = true;
    });
    
    // Dispatch login event to BLoC
    context.read<AuthBloc>().add(LoginEvent(email: email, password: password));
  }

  @override
  Widget build(BuildContext context) {
    return BackButtonHandler(
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            setState(() {
              _isLoading = false;
            });
            // Use post-frame callback to ensure navigation happens after state update
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Navigate based on user role
              final targetRoute = state.user.role == UserRole.teacher 
                  ? '/teacher-panel' 
                  : '/dashboard';
              try {
                context.go(targetRoute);
              } catch (e) {
                debugPrint('Login navigation error: $e');
                // Retry navigation after a short delay
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted) {
                    try {
                      context.go(targetRoute);
                    } catch (e2) {
                      debugPrint('Login navigation retry error: $e2');
                    }
                  }
                });
              }
            });
          } else if (state is AuthError) {
            setState(() {
              _isLoading = false;
            });
            // Show modern error dialog
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ErrorDialog.show(
                  context,
                  title: AppLocalizations.of(context)!.loginFailed,
                  message: _getUserFriendlyErrorMessage(state.message),
                );
              }
            });
          } else if (state is Unauthenticated || state is AuthInitial) {
            // Clear loading when not authenticated (from CheckAuthStatus)
            setState(() {
              _isLoading = false;
            });
          } else if (state is AuthLoading) {
            // Keep loading state when login is in progress
            setState(() {
              _isLoading = true;
            });
          }
        },
        child: Scaffold(
        body: LoadingOverlay(
          isLoading: _isLoading,
          child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryBlue,
                AppColors.accentPurple,
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo and Title
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.school,
                            size: 60,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context)!.appName,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.appTagline,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Login Form
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.welcomeBack,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context)!.loginToContinue,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            
                            // Email Field
                            CustomTextField(
                              controller: _emailController,
                              label: AppLocalizations.of(context)!.email,
                              hint: AppLocalizations.of(context)!.enterYourEmailAddress,
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: const Icon(Icons.email_outlined),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return AppLocalizations.of(context)!.email + ' ' + AppLocalizations.of(context)!.isRequired;
                                }
                                if (!value.contains('@')) {
                                  return AppLocalizations.of(context)!.invalidCredentials;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Password Field
                            CustomTextField(
                              controller: _passwordController,
                              label: AppLocalizations.of(context)!.password,
                              hint: AppLocalizations.of(context)!.enterYourPassword,
                              obscureText: true,
                              prefixIcon: const Icon(Icons.lock_outlined),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return AppLocalizations.of(context)!.password + ' ' + AppLocalizations.of(context)!.isRequired;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            
                            // Login Button
                            CustomButton(
                              text: AppLocalizations.of(context)!.login,
                              onPressed: _handleLogin,
                              isLoading: _isLoading,
                              gradient: AppColors.primaryGradient,
                            ),
                          ],
                        ),
                      ),
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
}
