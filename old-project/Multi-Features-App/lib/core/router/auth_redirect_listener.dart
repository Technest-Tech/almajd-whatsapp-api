import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../core/models/user_role.dart';
import 'app_router.dart';

/// Widget that listens to auth state changes and redirects accordingly
class AuthRedirectListener extends StatelessWidget {
  final Widget child;
  final GoRouter router;

  const AuthRedirectListener({
    super.key,
    required this.child,
    required this.router,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) {
        // Listen to all state changes, including from AuthInitial
        return previous != current;
      },
      listener: (context, state) {
        // Use a post-frame callback to ensure router is available
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            // Safely get current location
            String currentLocation = '';
            try {
              final uri = router.routerDelegate.currentConfiguration.uri;
              currentLocation = uri.path;
            } catch (e) {
              // Router might not be fully initialized, use empty string
              currentLocation = '';
            }
            
            if (state is Authenticated) {
              // User is authenticated, redirect based on role
              final targetRoute = state.user.role == UserRole.teacher 
                  ? AppRouter.teacherPanel 
                  : AppRouter.dashboard;
              
              // Only redirect if we're on login page or empty path
              // Don't redirect if already navigating (let LoginPage handle it)
              if ((currentLocation == AppRouter.login || currentLocation.isEmpty) && 
                  currentLocation != targetRoute) {
                // Small delay to let LoginPage navigation complete first
                Future.delayed(const Duration(milliseconds: 300), () {
                  try {
                    router.go(targetRoute);
                  } catch (e) {
                    debugPrint('AuthRedirectListener: Failed to navigate to $targetRoute: $e');
                  }
                });
              }
            } else if (state is Unauthenticated) {
              // User is not authenticated, redirect to login
              // Only redirect if we're not already on login
              if (currentLocation != AppRouter.login && currentLocation.isNotEmpty) {
                // Trigger router refresh to run redirect callback
                router.refresh();
                // Also try direct navigation as fallback
                try {
                  router.go(AppRouter.login);
                } catch (e) {
                  // If immediate redirect fails, try with a small delay
                  Future.delayed(const Duration(milliseconds: 200), () {
                    try {
                      router.go(AppRouter.login);
                    } catch (e2) {
                      debugPrint('AuthRedirectListener: Failed to navigate to login: $e2');
                    }
                  });
                }
              }
            }
            // Don't redirect on AuthLoading or AuthInitial - wait for result
          } catch (e) {
            // Silently handle errors - router might not be ready yet
            debugPrint('AuthRedirectListener error: $e');
          }
        });
      },
      child: child,
    );
  }
}

