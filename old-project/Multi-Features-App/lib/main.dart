import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multi_features_app/l10n/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/back_button_handler.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'core/router/auth_redirect_listener.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(
          create: (context) => AuthRepositoryImpl(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) {
              final bloc = AuthBloc(
                authRepository: context.read<AuthRepository>(),
              );
              // Check auth status immediately when bloc is created
              bloc.add(CheckAuthStatusEvent());
              return bloc;
            },
          ),
        ],
        child: Builder(
          builder: (context) {
            return BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                // Show loading screen while checking authentication
                if (state is AuthInitial || state is AuthLoading) {
                  return MaterialApp(
                    title: 'Almajd Academy',
                    theme: AppTheme.lightTheme,
                    darkTheme: AppTheme.darkTheme,
                    themeMode: ThemeMode.system,
                    debugShowCheckedModeBanner: false,
                    home: const Scaffold(
                      body: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                }

                // Once auth state is determined, show the router
                return AuthRedirectListener(
                  router: AppRouter.router,
                  child: BackButtonHandler(
                    child: MaterialApp.router(
                      title: 'Almajd Academy',
                      theme: AppTheme.lightTheme,
                      darkTheme: AppTheme.darkTheme,
                      themeMode: ThemeMode.system,
                      routerConfig: AppRouter.router,
                      debugShowCheckedModeBanner: false,
                      locale: const Locale('ar', 'SA'),
                      supportedLocales: const [
                        Locale('ar', 'SA'),
                        Locale('en', 'US'),
                      ],
                      localizationsDelegates: const [
                        AppLocalizations.delegate,
                        GlobalMaterialLocalizations.delegate,
                        GlobalWidgetsLocalizations.delegate,
                        GlobalCupertinoLocalizations.delegate,
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
