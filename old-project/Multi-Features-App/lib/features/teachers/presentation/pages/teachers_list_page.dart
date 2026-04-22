import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:multi_features_app/l10n/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/datasources/teacher_remote_datasource.dart';
import '../../data/repositories/teacher_repository_impl.dart';
import '../bloc/teacher_bloc.dart';
import '../bloc/teacher_event.dart';
import '../bloc/teacher_state.dart';
import '../widgets/teacher_card.dart';

class TeachersListPage extends StatefulWidget {
  const TeachersListPage({super.key});

  @override
  State<TeachersListPage> createState() => _TeachersListPageState();
}

class _TeachersListPageState extends State<TeachersListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
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
        final dataSource = TeacherRemoteDataSourceImpl(apiService);
        final repository = TeacherRepositoryImpl(dataSource);
        final bloc = TeacherBloc(repository);
        bloc.add(const LoadTeachers(page: 1));
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
                              hintText:
                                  AppLocalizations.of(context)!.searchTeachers,
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: (value) {
                              Future.delayed(const Duration(milliseconds: 500),
                                  () {
                                if (_searchController.text == value) {
                                  builderContext.read<TeacherBloc>().add(
                                        LoadTeachers(
                                          search: value.isEmpty ? null : value,
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
                          icon: Icon(
                              _isSearching ? Icons.close : Icons.filter_list),
                          onPressed: () {
                            if (_isSearching) {
                              // Close filters and reset all filter values
                              setState(() {
                                _isSearching = false;
                                _searchController.clear();
                              });
                              // Call load with the builder context
                              builderContext.read<TeacherBloc>().add(
                                    const LoadTeachers(page: 1),
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
              Expanded(
                child: BlocListener<TeacherBloc, TeacherState>(
                  listener: (context, state) {
                    // Reload teachers after successful operations (like delete)
                    if (state is TeacherOperationSuccess) {
                      // Small delay to ensure state is updated
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (mounted) {
                          _loadTeachers(context);
                        }
                      });
                    }
                  },
                  child: BlocBuilder<TeacherBloc, TeacherState>(
                    builder: (context, state) {
                      if (state is TeacherLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is TeacherError) {
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
                                  onPressed: () =>
                                      _loadTeachers(builderContext),
                                  child: Text(
                                      AppLocalizations.of(context)!.tryAgain),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }
                    if (state is TeachersLoaded) {
                      if (state.teachers.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 64,
                                color: Theme.of(context).hintColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا يوجد معلمون',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'اضغط على زر + لإضافة معلم',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context).hintColor,
                                    ),
                              ),
                            ],
                          ),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () async {
                          final bloc = context.read<TeacherBloc>();
                          bloc.add(
                            LoadTeachers(
                              search: _searchController.text.isEmpty
                                  ? null
                                  : _searchController.text,
                              page: 1,
                            ),
                          );
                          await Future.delayed(
                              const Duration(milliseconds: 500));
                        },
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (ScrollNotification scrollInfo) {
                            if (scrollInfo is ScrollUpdateNotification) {
                              final maxScroll = scrollInfo.metrics.maxScrollExtent;
                              final currentScroll = scrollInfo.metrics.pixels;
                              final delta = 200.0;

                              if (currentScroll >= (maxScroll - delta)) {
                                final currentState = context.read<TeacherBloc>().state;
                                if (currentState is TeachersLoaded) {
                                  if (currentState.hasMore && 
                                      !currentState.isLoadingMore && 
                                      currentState.teachers.length < currentState.maxTotalItems) {
                                    context.read<TeacherBloc>().add(
                                      LoadMoreTeachers(
                                        search: _searchController.text.isEmpty ? null : _searchController.text,
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
                            itemCount: state.teachers.length + (state.isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              // Show loading indicator at the bottom when loading more
                              if (index == state.teachers.length && state.isLoadingMore) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                            final teacher = state.teachers[index];
                            return TeacherCard(
                              teacher: teacher,
                              onTap: () {
                                context.push(
                                    '${AppRouter.usersAndCourses}/teachers/${teacher.id}/courses');
                              },
                              onEdit: () async {
                                await context.push(
                                  '${AppRouter.usersAndCourses}/teachers/${teacher.id}/edit',
                                  extra: teacher,
                                );
                                // Refresh the list when returning from edit page
                                Future.delayed(const Duration(milliseconds: 300), () {
                                  if (mounted) {
                                    _loadTeachers(context);
                                  }
                                });
                              },
                              onDelete: () {
                                _showDeleteDialog(context, teacher.id);
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
                await context.push('${AppRouter.usersAndCourses}/teachers/create');
                // Refresh the list when returning from create/edit page
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    _loadTeachers(context);
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

  void _loadTeachers([BuildContext? ctx]) {
    // Use provided context or widget's context
    final contextToUse = ctx ?? context;
    final bloc = contextToUse.read<TeacherBloc>();
    bloc.add(
      LoadTeachers(
        search: _searchController.text.isEmpty ? null : _searchController.text,
        page: 1,
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, int teacherId) {
    // Get the bloc from the context that has access to it
    final bloc = context.read<TeacherBloc>();
    final localizations = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${localizations.delete} ${localizations.teacher}'),
        content: Text(
            'هل أنت متأكد من حذف ${localizations.teacher}؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () {
              bloc.add(DeleteTeacher(teacherId));
              Navigator.pop(dialogContext);
            },
            child: Text(localizations.delete,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
