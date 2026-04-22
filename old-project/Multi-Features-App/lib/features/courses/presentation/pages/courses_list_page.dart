import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:multi_features_app/l10n/app_localizations.dart';
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/datasources/course_remote_datasource.dart';
import '../../data/repositories/course_repository_impl.dart';
import '../bloc/course_bloc.dart';
import '../bloc/course_event.dart';
import '../bloc/course_state.dart';
import '../widgets/course_card.dart';

class CoursesListPage extends StatefulWidget {
  const CoursesListPage({super.key});

  @override
  State<CoursesListPage> createState() => _CoursesListPageState();
}

class _CoursesListPageState extends State<CoursesListPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
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
        final dataSource = CourseRemoteDataSourceImpl(apiService);
        final repository = CourseRepositoryImpl(dataSource);
        final bloc = CourseBloc(repository);
        bloc.add(const LoadCourses());
        return bloc;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الدورات'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: AppLocalizations.of(context)!.addCourse,
              onPressed: () {
                context.push('/courses/create');
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Search bar
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.searchCourses,
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (_searchController.text == value) {
                            _loadCourses();
                          }
                        });
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isSearching ? Icons.close : Icons.search),
                    onPressed: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchController.clear();
                          _loadCourses();
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            // Total courses section
            BlocBuilder<CourseBloc, CourseState>(
              builder: (context, state) {
                if (state is CoursesLoaded) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.book,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'إجمالي الدورات:',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${state.courses.length}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 16,
                              ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Expanded(
              child: BlocBuilder<CourseBloc, CourseState>(
                builder: (context, state) {
                  if (state is CourseLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is CourseError) {
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
                          ElevatedButton(
                            onPressed: () => _loadCourses(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (state is CoursesLoaded) {
                    if (state.courses.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.book_outlined,
                              size: 64,
                              color: Theme.of(context).hintColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No courses found',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the + button to add a course',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).hintColor,
                                  ),
                            ),
                          ],
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async => _loadCourses(),
                      child: ListView.builder(
                        itemCount: state.courses.length,
                        itemBuilder: (context, index) {
                          final course = state.courses[index];
                          return CourseCard(
                            course: course,
                            onTap: () {
                              context.push('/courses/${course.id}/lessons');
                            },
                            onEdit: () {
                              context.push('/courses/${course.id}/edit');
                            },
                            onDelete: () {
                              _showDeleteDialog(context, course.id);
                            },
                          );
                        },
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.searchCourses,
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (value) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_searchController.text == value) {
              _loadCourses();
            }
          });
        },
      ),
    );
  }

  void _loadCourses() {
    context.read<CourseBloc>().add(
          LoadCourses(
            search: _searchController.text.isEmpty ? null : _searchController.text,
          ),
        );
  }

  void _showDeleteDialog(BuildContext context, int courseId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Course'),
        content: const Text('Are you sure you want to delete this course? All lessons will also be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<CourseBloc>().add(DeleteCourse(courseId));
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

