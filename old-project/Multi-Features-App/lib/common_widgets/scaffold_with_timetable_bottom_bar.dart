import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'timetable_bottom_bar.dart';

/// Scaffold wrapper that includes the timetable bottom action bar
class ScaffoldWithTimetableBottomBar extends StatelessWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showAppBar;
  final String? currentRoute;

  const ScaffoldWithTimetableBottomBar({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.showAppBar = true,
    this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    // Use provided route or fallback to getting it from context
    final route = currentRoute ?? GoRouterState.of(context).uri.path;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: showAppBar
          ? AppBar(
              title: title != null ? Text(title!) : null,
              actions: actions,
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: body,
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: TimetableBottomBar(currentRoute: route),
      extendBody: false,
    );
  }
}

