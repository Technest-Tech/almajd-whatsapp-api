import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:printing/printing.dart';
import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';

/// WebView page for certificate generation interface
class CertificateWebViewPage extends StatefulWidget {
  const CertificateWebViewPage({super.key});

  @override
  State<CertificateWebViewPage> createState() => _CertificateWebViewPageState();
}

class _CertificateWebViewPageState extends State<CertificateWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;
  bool _canGoBack = false;
  bool _isDownloading = false;
  String? _downloadMessage;
  String? _downloadedFilePath;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    final url = AppConfig.certificateIndexUrl;
    developer.log('Loading certificate URL: $url', name: 'CertificateWebView');
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            developer.log('Page started loading: $url', name: 'CertificateWebView');
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (String url) {
            developer.log('Page finished loading: $url', name: 'CertificateWebView');
            setState(() {
              _isLoading = false;
            });
            _checkCanGoBack();
          },
          onWebResourceError: (WebResourceError error) {
            developer.log(
              'WebView Error: ${error.errorCode} - ${error.description}',
              name: 'CertificateWebView',
              error: error,
            );
            setState(() {
              _isLoading = false;
              String errorMsg = error.description.isNotEmpty
                  ? error.description
                  : 'Failed to load certificate page.';
              
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
            developer.log('Navigation request: ${request.url}', name: 'CertificateWebView');
            
            // Intercept download URLs
            if (request.url.contains('/download')) {
              _handleDownload(request.url);
              return NavigationDecision.prevent; // Prevent navigation, handle download ourselves
            }
            
            // Allow all other navigation
            return NavigationDecision.navigate;
          },
        ),
      )
      ..setBackgroundColor(Colors.white);
    
    try {
      _controller.loadRequest(Uri.parse(url));
    } catch (e) {
      developer.log('Error loading URL: $e', name: 'CertificateWebView', error: e);
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

  Future<void> _handleDownload(String url) async {
    if (_isDownloading) return; // Prevent multiple simultaneous downloads
    
    // Show download dialog immediately
    setState(() {
      _isDownloading = true;
      _downloadMessage = 'جاري التحميل...';
    });

    try {
      developer.log('Starting download from: $url', name: 'CertificateWebView');
      
      // Get download directory
      // Use application documents directory for better compatibility
      final directory = await getApplicationDocumentsDirectory();
      
      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      final downloadPath = path.join(directory.path, 'certificates');
      final downloadDir = Directory(downloadPath);
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      // Generate filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'certificate_$timestamp.pdf';
      final filePath = path.join(downloadPath, fileName);

      // Download the file
      final dio = Dio();

      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            if (mounted) {
              setState(() {
                _downloadMessage = 'جاري التحميل: $progress%';
              });
            }
          }
        },
      );

      setState(() {
        _isDownloading = false;
        _downloadedFilePath = filePath;
        _downloadMessage = null;
      });

      developer.log('Download completed: $filePath', name: 'CertificateWebView');

      // Show success dialog with options to open or share
      if (mounted) {
        _showDownloadSuccessDialog(filePath, fileName);
      }
    } catch (e) {
      developer.log('Download error: $e', name: 'CertificateWebView', error: e);
      setState(() {
        _isDownloading = false;
        _downloadMessage = 'فشل التحميل: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التحميل: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _showDownloadSuccessDialog(String filePath, String fileName) async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('اكتمل التحميل'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تم تحميل الشهادة بنجاح!',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'الملف: $fileName',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _openPdf(filePath);
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('فتح PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openPdf(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ملف PDF غير موجود'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final bytes = await file.readAsBytes();
      
      if (mounted) {
        await Printing.layoutPdf(
          onLayout: (format) async => bytes,
        );
      }
    } catch (e) {
      developer.log('Error opening PDF: $e', name: 'CertificateWebView', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في فتح PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackButton,
      child: Scaffold(
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
                        'جاري تحميل محرر الشهادات...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Download progress overlay
            if (_isDownloading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(AppSizes.spaceXl),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.spaceXl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: AppSizes.spaceMd),
                          Text(
                            _downloadMessage ?? 'Downloading...',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
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

