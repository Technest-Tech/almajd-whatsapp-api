import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'bottom_action_bar.dart';

/// Scaffold wrapper that includes the bottom action bar
class ScaffoldWithBottomBar extends StatelessWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showAppBar;
  final String? currentRoute;
  final bool showBackButton;
  final VoidCallback? onBack;

  const ScaffoldWithBottomBar({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.showAppBar = true,
    this.currentRoute,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    // Use provided route or fallback to getting it from context
    final route = currentRoute ?? GoRouterState.of(context).uri.path;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: showAppBar
          ? AppBar(
              leading: showBackButton
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: onBack ??
                          () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                    )
                  : null,
              title: title != null && title!.isNotEmpty
                  ? Text(title!)
                  : const Text(''),
              actions: actions,
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: body,
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: BottomActionBar(currentRoute: route),
      extendBody: false,
    );
  }
}
