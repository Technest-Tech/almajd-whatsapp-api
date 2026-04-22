import 'package:flutter/material.dart';
import 'package:multi_features_app/l10n/app_localizations.dart';
import '../../../../core/widgets/back_button_handler.dart';
import 'admin_dashboard_page.dart';

/// Meeting Rooms Management page with Admin Dashboard
class MeetingsPage extends StatelessWidget {
  const MeetingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BackButtonHandler(
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.rooms),
        ),
        body: const AdminDashboardPage(),
      ),
    );
  }
}