import 'package:flutter/material.dart';
import 'package:multi_features_app/l10n/app_localizations.dart';
import '../../../../core/widgets/back_button_handler.dart';
import 'certificate_webview_page.dart';

/// Certificates Management page with WebView integration
class CertificatesPage extends StatelessWidget {
  const CertificatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BackButtonHandler(
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.certificates),
        ),
        body: const CertificateWebViewPage(),
      ),
    );
  }
}
