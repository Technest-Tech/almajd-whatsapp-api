import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../l10n/app_localizations.dart';

/// WebView page for timetable and calendar interface
class TimetableWebViewPage extends StatefulWidget {
  const TimetableWebViewPage({super.key});

  @override
  State<TimetableWebViewPage> createState() => _TimetableWebViewPageState();
}

class _TimetableWebViewPageState extends State<TimetableWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;
  bool _canGoBack = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    final url = AppConfig.timetableUrl;
    developer.log('Loading timetable URL: $url', name: 'TimetableWebView');
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            developer.log('Page started loading: $url', name: 'TimetableWebView');
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (String url) {
            developer.log('Page finished loading: $url', name: 'TimetableWebView');
            setState(() {
              _isLoading = false;
              // Clear ORB errors when page finishes loading successfully
              if (_errorMessage != null && 
                  (_errorMessage!.contains('ERR_BLOCKED_BY_ORB') ||
                   _errorMessage!.contains('ORB') ||
                   _errorMessage!.contains('Cross-Origin Request Blocked'))) {
                _errorMessage = null;
              }
            });
            _checkCanGoBack();
          },
          onWebResourceError: (WebResourceError error) {
            developer.log(
              'WebView Error: ${error.errorCode} - ${error.description}',
              name: 'TimetableWebView',
              error: error,
            );
            
            // Don't show error if page finished loading successfully
            // ORB errors for external CDN resources are non-critical
            if (error.errorCode == -1 && 
                (error.description.contains('ERR_BLOCKED_BY_ORB') ||
                 error.description.contains('ORB') ||
                 error.description.contains('opaque'))) {
              // Log but don't show error - these are usually just warnings for external resources
              developer.log(
                'ORB warning (non-critical): ${error.description}',
                name: 'TimetableWebView',
              );
              return; // Don't set error message for ORB warnings
            }
            
            // Only show errors if page hasn't finished loading or it's a critical error
            if (!_isLoading) {
              // Page already loaded, this is likely a non-critical resource error
              return;
            }
            
            setState(() {
              _isLoading = false;
              String errorMsg = error.description.isNotEmpty
                  ? error.description
                  : 'Failed to load timetable page.';
              
              // Check for cleartext error specifically
              if (error.errorCode == -2 || 
                  error.description.contains('CLEARTEXT') ||
                  error.description.contains('cleartext') ||
                  error.description.contains('ERR_CLEARTEXT')) {
                errorMsg = 'Network Security Error: HTTP connections are blocked.\n\n'
                    'Error Code: ${error.errorCode}\n'
                    'Please ensure the Laravel backend is running and accessible.\n\n'
                    'URL: $url';
              } else {
                errorMsg = 'Error Code: ${error.errorCode}\n$errorMsg\n\nURL: $url';
              }
              
              _errorMessage = errorMsg;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            developer.log('Navigation request: ${request.url}', name: 'TimetableWebView');
            // Allow all navigation
            return NavigationDecision.navigate;
          },
        ),
      )
      ..setBackgroundColor(Colors.white);
    
    try {
      _controller.loadRequest(Uri.parse(url));
    } catch (e) {
      developer.log('Error loading URL: $e', name: 'TimetableWebView', error: e);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load URL: $url\nError: $e';
      });
    }
  }

  Future<void> _checkCanGoBack() async {
    final canGoBack = await _controller.canGoBack();
    if (mounted) {
      setState(() {
        _canGoBack = canGoBack;
      });
    }
  }

  Future<bool> _handleBackButton() async {
    if (_canGoBack) {
      await _controller.goBack();
      await _checkCanGoBack();
      return false; // Don't pop the page
    }
    return true; // Pop the page
  }

  void _reload() {
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    return WillPopScope(
      onWillPop: _handleBackButton,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                localizations?.calendar ?? 'Timetable Calendar',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF667eea),
                  Color(0xFF764ba2),
                ],
              ),
            ),
          ),
          elevation: 2,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _reload,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Stack(
          children: [
            // WebView
            WebViewWidget(controller: _controller),
            
            // Loading indicator
            if (_isLoading)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSizes.spaceMd),
                      Text(
                        'جاري تحميل التقويم والجداول...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Error message
            if (_errorMessage != null && !_isLoading)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(AppSizes.spaceLg),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: AppSizes.spaceMd),
                      Text(
                        'خطأ في تحميل الصفحة',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSizes.spaceSm),
                      Text(
                        _errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSizes.spaceXl),
                      ElevatedButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.spaceXl,
                            vertical: AppSizes.spaceMd,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

