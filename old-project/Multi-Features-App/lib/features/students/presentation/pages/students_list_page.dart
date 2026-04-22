import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:multi_features_app/l10n/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/datasources/student_remote_datasource.dart';
import '../../data/repositories/student_repository_impl.dart';
import '../bloc/student_bloc.dart';
import '../bloc/student_event.dart';
import '../bloc/student_state.dart';
import '../widgets/student_card.dart';

class StudentsListPage extends StatefulWidget {
  const StudentsListPage({super.key});

  @override
  State<StudentsListPage> createState() => _StudentsListPageState();
}

class _StudentsListPageState extends State<StudentsListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _selectedCountry;
  String? _selectedCurrency;
  bool _isSearching = false;
  String? _lastRoute;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if we're returning from a different route
    final currentRoute = GoRouterState.of(context).uri.path;
    if (_lastRoute != null && _lastRoute != currentRoute && currentRoute.contains('/students') && !currentRoute.contains('/create') && !currentRoute.contains('/edit')) {
      // We've returned to the students list page, reload data
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadStudents(context);
        }
      });
    }
    _lastRoute = currentRoute;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final apiService = ApiService();
        final token = StorageService.getToken();
        token.then((t) {
          if (t != null) {
            apiService.setAuthToken(t);
          }
        });
        final dataSource = StudentRemoteDataSourceImpl(apiService);
        final repository = StudentRepositoryImpl(dataSource);
        final bloc = StudentBloc(repository);
        bloc.add(const LoadStudents(page: 1));
        return bloc;
      },
      child: Stack(
        children: [
          Column(
            children: [
              // Search bar
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (builderContext) {
                          return TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context)!.searchStudents,
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: (value) {
                              Future.delayed(const Duration(milliseconds: 500), () {
                                if (_searchController.text == value) {
                                  builderContext.read<StudentBloc>().add(
                                    LoadStudents(
                                      search: value.isEmpty ? null : value,
                                      country: _selectedCountry,
                                      currency: _selectedCurrency,
                                      page: 1,
                                    ),
                                  );
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Builder(
                      builder: (builderContext) {
                        return IconButton(
                          icon: Icon(_isSearching ? Icons.close : Icons.filter_list),
                          onPressed: () {
                            if (_isSearching) {
                              // Close filters and reset all filter values
                              setState(() {
                                _isSearching = false;
                                _searchController.clear();
                                _selectedCountry = null;
                                _selectedCurrency = null;
                              });
                              // Call _loadStudents with the builder context
                              builderContext.read<StudentBloc>().add(
                                LoadStudents(
                                  search: null,
                                  country: null,
                                  currency: null,
                                  page: 1,
                                ),
                              );
                            } else {
                              // Open filters
                              setState(() {
                                _isSearching = true;
                              });
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (_isSearching) _buildFilters(),
              Expanded(
                child: BlocListener<StudentBloc, StudentState>(
                  listener: (context, state) {
                    // Reload students after successful operations (like delete)
                    if (state is StudentOperationSuccess) {
                      // Small delay to ensure state is updated
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (mounted) {
                          _loadStudents(context);
                        }
                      });
                    }
                  },
                  child: BlocBuilder<StudentBloc, StudentState>(
                    builder: (context, state) {
                      if (state is StudentLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is StudentError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                state.message,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Builder(
                                builder: (builderContext) {
                                  return ElevatedButton(
                                    onPressed: () => _loadStudents(builderContext),
                                    child: const Text('Retry'),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      }
                      if (state is StudentsLoaded) {
                        if (state.students.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.school_outlined,
                                  size: 64,
                                  color: Theme.of(context).hintColor,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No students found',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap the + button to add a student',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).hintColor,
                                      ),
                                ),
                              ],
                            ),
                          );
                        }
                        return RefreshIndicator(
                          onRefresh: () async {
                            // Force reload by dispatching LoadStudents event
                            final bloc = context.read<StudentBloc>();
                            bloc.add(
                              LoadStudents(
                                search: _searchController.text.isEmpty ? null : _searchController.text,
                                country: _selectedCountry,
                                currency: _selectedCurrency,
                                page: 1,
                              ),
                            );
                            // Wait for the state to update
                            await Future.delayed(const Duration(milliseconds: 500));
                          },
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (ScrollNotification scrollInfo) {
                              if (scrollInfo is ScrollUpdateNotification) {
                                final maxScroll = scrollInfo.metrics.maxScrollExtent;
                                final currentScroll = scrollInfo.metrics.pixels;
                                final delta = 200.0;

                                if (currentScroll >= (maxScroll - delta)) {
                                  final currentState = context.read<StudentBloc>().state;
                                  if (currentState is StudentsLoaded) {
                                    if (currentState.hasMore && 
                                        !currentState.isLoadingMore && 
                                        currentState.students.length < currentState.maxTotalItems) {
                                      context.read<StudentBloc>().add(
                                        LoadMoreStudents(
                                          search: _searchController.text.isEmpty ? null : _searchController.text,
                                          country: _selectedCountry,
                                          currency: _selectedCurrency,
                                          page: currentState.currentPage + 1,
                                        ),
                                      );
                                    }
                                  }
                                }
                              }
                              return false;
                            },
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: state.students.length + (state.isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                              // Show loading indicator at the bottom when loading more
                              if (index == state.students.length && state.isLoadingMore) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              
                              final student = state.students[index];
                              return StudentCard(
                                student: student,
                                onTap: () async {
                                  await context.push('${AppRouter.usersAndCourses}/students/${student.id}/edit');
                                  // Refresh the list when returning from edit page
                                  Future.delayed(const Duration(milliseconds: 300), () {
                                    if (mounted) {
                                      _loadStudents(context);
                                    }
                                  });
                                },
                                onEdit: () async {
                                  await context.push('${AppRouter.usersAndCourses}/students/${student.id}/edit');
                                  // Refresh the list when returning from edit page
                                  Future.delayed(const Duration(milliseconds: 300), () {
                                    if (mounted) {
                                      _loadStudents(context);
                                    }
                                  });
                                },
                                onDelete: () {
                                  _showDeleteDialog(context, student.id);
                                },
                              );
                            },
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            ],
          ),
        // Floating action button
        Positioned(
          bottom: 80, // Above bottom bar
          right: 16,
          child: FloatingActionButton(
            onPressed: () async {
              await context.push('${AppRouter.usersAndCourses}/students/create');
              // Refresh the list when returning from create page
              // Use a delay to ensure the page is fully visible and backend has processed
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) {
                  _loadStudents(context);
                }
              });
            },
            child: const Icon(Icons.add),
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.searchStudents,
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (value) {
          // Debounce search
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_searchController.text == value) {
              _loadStudents();
            }
          });
        },
      ),
    );
  }

  Widget _buildFilters() {
    return Builder(
      builder: (builderContext) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCountry,
                  decoration: InputDecoration(
                    labelText: 'Country',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text(AppLocalizations.of(context)!.allCountries)),
                    const DropdownMenuItem(value: 'EG', child: Text('مصر')),
                    const DropdownMenuItem(value: 'SA', child: Text('السعودية')),
                    const DropdownMenuItem(value: 'AE', child: Text('الإمارات')),
                    const DropdownMenuItem(value: 'US', child: Text('الولايات المتحدة')),
                    const DropdownMenuItem(value: 'GB', child: Text('المملكة المتحدة')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCountry = value;
                    });
                    builderContext.read<StudentBloc>().add(
                      LoadStudents(
                        search: _searchController.text.isEmpty ? null : _searchController.text,
                        country: value,
                        currency: _selectedCurrency,
                        page: 1,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCurrency,
                  decoration: InputDecoration(
                    labelText: 'Currency',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text(AppLocalizations.of(context)!.allCurrencies)),
                    const DropdownMenuItem(value: 'USD', child: Text('USD')),
                    const DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                    const DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                    const DropdownMenuItem(value: 'EGP', child: Text('EGP')),
                    const DropdownMenuItem(value: 'SAR', child: Text('SAR')),
                    const DropdownMenuItem(value: 'AED', child: Text('AED')),
                    const DropdownMenuItem(value: 'CAD', child: Text('CAD')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCurrency = value;
                    });
                    builderContext.read<StudentBloc>().add(
                      LoadStudents(
                        search: _searchController.text.isEmpty ? null : _searchController.text,
                        country: _selectedCountry,
                        currency: value,
                        page: 1,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _loadStudents([BuildContext? ctx]) {
    // Use provided context or widget's context
    final contextToUse = ctx ?? context;
    final bloc = contextToUse.read<StudentBloc>();
    bloc.add(
      LoadStudents(
        search: _searchController.text.isEmpty ? null : _searchController.text,
        country: _selectedCountry,
        currency: _selectedCurrency,
        page: 1,
      ),
    );
  }


  void _showDeleteDialog(BuildContext context, int studentId) {
    // Get the bloc from the context that has access to it
    final bloc = context.read<StudentBloc>();
    final localizations = AppLocalizations.of(context)!;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${localizations.delete} ${localizations.student}'),
        content: Text('هل أنت متأكد من حذف ${localizations.student}؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () {
              bloc.add(DeleteStudent(studentId));
              Navigator.pop(dialogContext);
            },
            child: Text(localizations.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
