import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../calendar/presentation/widgets/modern_sidebar.dart';
import '../../data/datasources/student_countries_remote_datasource.dart';
import '../bloc/student_countries_bloc.dart';
import '../bloc/student_countries_event.dart';
import '../bloc/student_countries_state.dart';

class StudentCountriesPage extends StatefulWidget {
  const StudentCountriesPage({super.key});

  @override
  State<StudentCountriesPage> createState() => _StudentCountriesPageState();
}

class _StudentCountriesPageState extends State<StudentCountriesPage>
    with SingleTickerProviderStateMixin {
  bool _isSidebarOpen = false;
  late AnimationController _animationController;
  late Animation<double> _sidebarAnimation;
  late Animation<double> _blurAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _sidebarAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _blurAnimation = _sidebarAnimation;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
      if (_isSidebarOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.path;
    
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: BlocProvider(
        create: (context) {
          final apiService = ApiService();
          final token = StorageService.getToken();
          token.then((t) {
            if (t != null) {
              apiService.setAuthToken(t);
            }
          });
          final dataSource =
              StudentCountriesRemoteDataSourceImpl(apiService);
          return StudentCountriesBloc(dataSource);
        },
        child: BlocListener<StudentCountriesBloc, StudentCountriesState>(
          listener: (context, state) {
            if (state is StudentCountriesSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
            } else if (state is StudentCountriesError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
          child: Scaffold(
            body: SafeArea(
              child: Stack(
                children: [
                  // Main Content
                  Column(
                    children: [
                      // Header with sidebar icon
                      Container(
                        padding: const EdgeInsets.all(AppSizes.spaceMd),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.textTertiary.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.menu_rounded),
                              onPressed: _toggleSidebar,
                              color: AppColors.primary,
                            ),
                            const Expanded(
                              child: Text(
                                'دول الطلاب',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            // Empty space to balance the menu icon
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),
                      // Content
                      const Expanded(
                        child: _StudentCountriesContent(),
                      ),
                    ],
                  ),

                  // Simplified overlay
                  AnimatedBuilder(
                    animation: _sidebarAnimation,
                    builder: (context, child) {
                      return Visibility(
                        visible: _isSidebarOpen,
                        child: GestureDetector(
                          onTap: _toggleSidebar,
                          child: Container(
                            color: Colors.black.withOpacity(0.3 * _sidebarAnimation.value),
                          ),
                        ),
                      );
                    },
                  ),

                  // Sidebar overlay
                  AnimatedBuilder(
                    animation: _sidebarAnimation,
                    builder: (context, child) {
                      return Positioned(
                        right: -280 * (1 - _sidebarAnimation.value),
                        top: 0,
                        bottom: 0,
                        width: 280,
                        child: child ?? const SizedBox.shrink(),
                      );
                    },
                    child: RepaintBoundary(
                      child: ModernSidebar(
                        currentRoute: currentRoute,
                        onClose: _toggleSidebar,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentCountriesContent extends StatelessWidget {
  const _StudentCountriesContent();

  final List<Map<String, String>> _countries = const [
    {'code': 'canada', 'name': 'كندا', 'label': 'Canada'},
    {'code': 'uk', 'name': 'المملكة المتحدة', 'label': 'UK'},
    {'code': 'eg', 'name': 'مصر', 'label': 'EG'},
  ];

  void _showConfirmationDialog(
    BuildContext context,
    String action,
    String countryCode,
    String countryName,
  ) {
    final isPlus = action == 'plus';
    final actionText = isPlus ? 'إضافة' : 'طرح';
    final actionDescription = isPlus
        ? 'سيتم إضافة ساعة واحدة لجميع الدروس في $countryName'
        : 'سيتم طرح ساعة واحدة من جميع الدروس في $countryName';

    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(
                isPlus ? Icons.add_circle_outline : Icons.remove_circle_outline,
                color: isPlus ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text('تأكيد $actionText الساعة'),
            ],
          ),
          content: Text(actionDescription),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<StudentCountriesBloc>().add(
                      UpdateCountryTime(
                        action: action,
                        country: countryCode,
                      ),
                    );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isPlus ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('تأكيد $actionText'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StudentCountriesBloc, StudentCountriesState>(
      builder: (context, state) {
        final isLoading = state is StudentCountriesLoading;
        final loadingCountry = state is StudentCountriesLoading
            ? state.country
            : null;
        final loadingAction = state is StudentCountriesLoading
            ? state.action
            : null;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView.builder(
            itemCount: _countries.length,
            itemBuilder: (context, index) {
              final country = _countries[index];
              final countryCode = country['code']!;
              final countryName = country['name']!;
              final countryLabel = country['label']!;

              final isCountryLoading = isLoading &&
                  loadingCountry == countryCode;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Country Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              countryLabel,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              countryName,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Action Buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Plus Button
                          ElevatedButton(
                            onPressed: isCountryLoading &&
                                    loadingAction == 'plus'
                                ? null
                                : () => _showConfirmationDialog(
                                      context,
                                      'plus',
                                      countryCode,
                                      countryName,
                                    ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: isCountryLoading && loadingAction == 'plus'
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.add),
                          ),
                          const SizedBox(width: 12),
                          // Minus Button
                          ElevatedButton(
                            onPressed: isCountryLoading &&
                                    loadingAction == 'minus'
                                ? null
                                : () => _showConfirmationDialog(
                                      context,
                                      'minus',
                                      countryCode,
                                      countryName,
                                    ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: isCountryLoading && loadingAction == 'minus'
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.remove),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

