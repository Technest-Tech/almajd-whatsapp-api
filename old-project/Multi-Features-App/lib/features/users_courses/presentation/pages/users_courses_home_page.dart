import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:multi_features_app/l10n/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../common_widgets/scaffold_with_bottom_bar.dart';
import '../../../students/presentation/pages/students_list_page.dart';
import '../../../teachers/presentation/pages/teachers_list_page.dart';
import '../../../salaries/presentation/pages/salaries_page.dart';
import '../widgets/users_courses_dashboard.dart';

/// Users & Courses Home Page - Main entry point for Users & Courses module
/// This page shows the Students list by default and includes the bottom action bar
class UsersCoursesHomePage extends StatelessWidget {
  const UsersCoursesHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the current route to determine which page to show
    final currentLocation = GoRouterState.of(context).uri.path;

    Widget currentPage;
    String? pageTitle;

    // Check if we're in the users-courses section
    if (currentLocation == AppRouter.usersAndCourses ||
        (currentLocation.startsWith(AppRouter.usersAndCourses) &&
            !currentLocation.contains('/students') &&
            !currentLocation.contains('/teachers') &&
            !currentLocation.contains('/salaries'))) {
      // Show dashboard when on the main users-courses route
      currentPage = const UsersCoursesDashboard();
      pageTitle = AppLocalizations.of(context)!.usersAndCourses;
    } else if (currentLocation.contains('/students')) {
      // Use a key based on route to force rebuild when route changes
      currentPage = StudentsListPage(key: ValueKey(currentLocation));
      pageTitle = 'الطلاب'; // Students in Arabic
    } else if (currentLocation.contains('/teachers')) {
      currentPage = const TeachersListPage();
      pageTitle = 'المعلمون'; // Teachers in Arabic
    } else if (currentLocation.contains('/salaries')) {
      currentPage = const SalariesPage();
      pageTitle = 'الرواتب'; // Salaries in Arabic
    } else {
      // Default to Dashboard when first entering users-courses
      currentPage = const UsersCoursesDashboard();
      pageTitle = AppLocalizations.of(context)!.usersAndCourses;
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ScaffoldWithBottomBar(
        title: pageTitle,
        body: currentPage,
        showBackButton: true,
        onBack: () => context.go(AppRouter.dashboard),
      ),
    );
  }
}
