import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../common_widgets/custom_text_field.dart';
import '../../../../common_widgets/error_dialog.dart';
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../features/students/data/datasources/student_remote_datasource.dart';
import '../../../../features/students/data/models/student_model.dart';
import '../../../../features/students/data/repositories/student_repository_impl.dart';
import '../../../../features/students/presentation/bloc/student_bloc.dart';
import '../../../../features/students/presentation/bloc/student_event.dart';
import '../../../../features/students/presentation/bloc/student_state.dart';
import '../../data/datasources/teacher_remote_datasource.dart';
import '../../data/models/teacher_model.dart';
import '../../data/repositories/teacher_repository_impl.dart';
import '../bloc/teacher_bloc.dart';
import '../bloc/teacher_event.dart';
import '../bloc/teacher_state.dart';
import '../widgets/student_multi_select.dart';
import '../widgets/currency_hour_price_field.dart';

class TeacherFormPage extends StatefulWidget {
  final TeacherModel? teacher;
  final int? teacherId;

  const TeacherFormPage({super.key, this.teacher, this.teacherId});

  @override
  State<TeacherFormPage> createState() => _TeacherFormPageState();
}

class _TeacherFormPageState extends State<TeacherFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _whatsappController = TextEditingController();

  String? _selectedCurrency;
  String? _hourPrice;
  List<StudentModel> _selectedStudents = [];

  TeacherModel? _loadedTeacher;
  bool _isLoadingTeacher = false;
  bool _hasLoadedTeacher = false;
  bool _shouldFetchTeacher = false;
  String? _lastShownError;
  bool _isLoadingAllStudents = false;

  @override
  void initState() {
    super.initState();
    if (widget.teacher != null) {
      _loadedTeacher = widget.teacher;
      _populateForm(widget.teacher!);
      if ((widget.teacher!.assignedStudents).isEmpty &&
          widget.teacherId != null) {
        _shouldFetchTeacher = true;
      }
    } else if (widget.teacherId != null) {
      _shouldFetchTeacher = true;
    }
    if (_shouldFetchTeacher) {
      _isLoadingTeacher = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Don't load here - will be triggered from BlocListener
  }

  void _populateForm(TeacherModel teacher) {
    setState(() {
      _nameController.text = teacher.name;
      _emailController.text = teacher.email;
      _selectedCurrency = teacher.currency ?? 'EGP';
      _hourPrice = teacher.hourPrice?.toString() ?? '';
      _bankNameController.text = teacher.bankName ?? '';
      _accountNumberController.text = teacher.accountNumber ?? '';
      _whatsappController.text = teacher.whatsappNumber ?? '';
      _selectedStudents = List.from(teacher.assignedStudents);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
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
            return TeacherBloc(repository);
          },
        ),
        BlocProvider(
          create: (context) {
            final apiService = ApiService();
            final token = StorageService.getToken();
            token.then((t) {
              if (t != null) {
                apiService.setAuthToken(t);
              }
            });
            final studentDataSource = StudentRemoteDataSourceImpl(apiService);
            final studentRepository = StudentRepositoryImpl(studentDataSource);
            final bloc = StudentBloc(studentRepository);
            bloc.add(const LoadStudents(page: 1));
            return bloc;
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text((widget.teacher == null && widget.teacherId == null)
              ? AppLocalizations.of(context)!.addTeacher
              : AppLocalizations.of(context)!.editTeacher),
        ),
        body: BlocListener<TeacherBloc, TeacherState>(
          listener: (context, state) {
            if (state is TeacherLoaded && _isLoadingTeacher) {
              setState(() {
                _loadedTeacher = state.teacher;
                _isLoadingTeacher = false;
                _populateForm(state.teacher);
              });
            }
            if (state is TeacherOperationSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
              context.pop();
            }
            if (state is TeacherError) {
              setState(() {
                _isLoadingTeacher = false;
              });
              // Show error dialog that can be dismissed (only if not already shown for this error)
              if (_lastShownError != state.message) {
                _lastShownError = state.message;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    ErrorDialog.show(
                      context,
                      title: 'Error',
                      message: state.message,
                    ).then((_) {
                      // Reset error tracking when dialog is dismissed
                      if (mounted) {
                        _lastShownError = null;
                      }
                    });
                  }
                });
              }
            }
          },
          child: Builder(
            builder: (builderContext) {
              return BlocListener<StudentBloc, dynamic>(
                listener: (context, state) {
                  // Automatically load all students pages
                  if (state is StudentsLoaded && _isLoadingAllStudents) {
                    if (state.hasMore && !state.isLoadingMore) {
                      // Load next page automatically
                      Future.delayed(const Duration(milliseconds: 50), () {
                        if (mounted && _isLoadingAllStudents) {
                          context.read<StudentBloc>().add(
                            LoadMoreStudents(
                              search: null,
                              country: null,
                              currency: null,
                              page: state.currentPage + 1,
                            ),
                          );
                        }
                      });
                    } else if (!state.hasMore) {
                      // All students loaded
                      setState(() {
                        _isLoadingAllStudents = false;
                      });
                    }
                  }
                },
                child: BlocBuilder<TeacherBloc, TeacherState>(
                  builder: (context, state) {
                    // Trigger load when bloc becomes available (on initial state)
                    if (_shouldFetchTeacher &&
                        widget.teacherId != null &&
                        !_hasLoadedTeacher &&
                        state is TeacherInitial) {
                      _hasLoadedTeacher = true;
                      _isLoadingAllStudents = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          // Use builderContext which has access to BlocProvider
                          builderContext
                              .read<TeacherBloc>()
                              .add(LoadTeacher(widget.teacherId!));
                        }
                      });
                    }
                    
                    // Start loading all students for new teacher form
                    if (widget.teacher == null && 
                        widget.teacherId == null && 
                        !_isLoadingAllStudents &&
                        state is TeacherInitial) {
                      _isLoadingAllStudents = true;
                    }

                    if (_isLoadingTeacher) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Personal Information Section
                            _buildSectionHeader(context, 'المعلومات الشخصية'),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _nameController,
                              label: AppLocalizations.of(context)!.name,
                              hint: 'أدخل اسم المعلم',
                              prefixIcon: const Icon(Icons.person),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return AppLocalizations.of(context)!
                                      .nameIsRequired;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _emailController,
                              label: AppLocalizations.of(context)!.email,
                              hint: 'أدخل البريد الإلكتروني',
                              prefixIcon: const Icon(Icons.email),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return AppLocalizations.of(context)!
                                      .emailIsRequired;
                                }
                                if (!value.contains('@')) {
                                  return AppLocalizations.of(context)!
                                      .invalidEmailFormat;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _passwordController,
                              label: (widget.teacher == null &&
                                      widget.teacherId == null)
                                  ? AppLocalizations.of(context)!
                                      .passwordRequired
                                  : AppLocalizations.of(context)!
                                      .passwordLeaveEmpty,
                              hint: (widget.teacher == null &&
                                      widget.teacherId == null)
                                  ? 'أدخل كلمة المرور (8 أحرف على الأقل)'
                                  : 'اتركه فارغاً للاحتفاظ بكلمة المرور الحالية',
                              prefixIcon: const Icon(Icons.lock),
                              obscureText: true,
                              validator: (value) {
                                // Only require password when creating new teacher
                                if (widget.teacher == null &&
                                    widget.teacherId == null) {
                                  if (value == null || value.isEmpty) {
                                    return AppLocalizations.of(context)!
                                        .passwordIsRequired;
                                  }
                                  if (value.length < 8) {
                                    return AppLocalizations.of(context)!
                                        .passwordMinLength;
                                  }
                                }
                                // If updating and password is provided, validate length
                                if (value != null &&
                                    value.isNotEmpty &&
                                    value.length < 8) {
                                  return AppLocalizations.of(context)!
                                      .passwordMinLength;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _whatsappController,
                              label: AppLocalizations.of(context)!.whatsappNumber,
                              hint: 'أدخل رقم الواتساب مع رمز الدولة (مثال: +201234567890)',
                              prefixIcon: const Icon(Icons.phone),
                              keyboardType: TextInputType.phone,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.left,
                            ),
                            const SizedBox(height: 32),
                            // Financial Information Section
                            _buildSectionHeader(context, 'المعلومات المالية'),
                            const SizedBox(height: 16),
                            CurrencyHourPriceField(
                              initialCurrency: _selectedCurrency,
                              initialHourPrice: _hourPrice,
                              label: AppLocalizations.of(context)!.hourPrice,
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final price = double.tryParse(value);
                                  if (price == null || price < 0) {
                                    return AppLocalizations.of(context)!
                                        .invalidPrice;
                                  }
                                }
                                return null;
                              },
                              onChanged: (currency, price) {
                                setState(() {
                                  _selectedCurrency = currency;
                                  _hourPrice = price;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _bankNameController,
                              label: AppLocalizations.of(context)!.bankName,
                              hint: 'أدخل اسم البنك',
                              prefixIcon: const Icon(Icons.account_balance),
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _accountNumberController,
                              label:
                                  AppLocalizations.of(context)!.accountNumber,
                              hint: 'أدخل رقم الحساب',
                              prefixIcon:
                                  const Icon(Icons.account_balance_wallet),
                            ),
                            const SizedBox(height: 32),
                            // Students Assignment Section
                            _buildSectionHeader(context, 'تعيين الطلاب'),
                            const SizedBox(height: 16),
                            BlocBuilder<StudentBloc, dynamic>(
                              builder: (context, state) {
                                if (state is StudentLoading && (state is! StudentsLoaded)) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                if (state is StudentsLoaded) {
                                  return Column(
                                    children: [
                                      StudentMultiSelect(
                                        allStudents: state.students,
                                        selectedStudents: _selectedStudents,
                                        onSelectionChanged: (students) {
                                          setState(() {
                                            _selectedStudents = students;
                                          });
                                        },
                                      ),
                                      if (_isLoadingAllStudents || state.isLoadingMore)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'جاري تحميل الطلاب... (${state.students.length})',
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                            const SizedBox(height: 32),
                            BlocBuilder<TeacherBloc, TeacherState>(
                              builder: (context, state) {
                                final isLoading = state is TeacherLoading;
                                return ElevatedButton(
                                  onPressed: isLoading
                                      ? null
                                      : () => _submitForm(context),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : Text((widget.teacher == null &&
                                              widget.teacherId == null)
                                          ? AppLocalizations.of(context)!
                                              .createTeacher
                                          : AppLocalizations.of(context)!
                                              .updateTeacher),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _submitForm(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      final currentTeacher = _loadedTeacher ?? widget.teacher;

      final teacher = TeacherModel(
        id: currentTeacher?.id ?? 0,
        name: _nameController.text,
        email: _emailController.text,
        whatsappNumber: _whatsappController.text.trim().isNotEmpty 
            ? _whatsappController.text.trim() 
            : null,
        hourPrice: _hourPrice != null && _hourPrice!.isNotEmpty
            ? double.tryParse(_hourPrice!)
            : null,
        currency: _selectedCurrency,
        bankName:
            _bankNameController.text.isEmpty ? null : _bankNameController.text,
        accountNumber: _accountNumberController.text.isEmpty
            ? null
            : _accountNumberController.text,
        assignedStudents: _selectedStudents,
        createdAt: currentTeacher?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final password = _passwordController.text.isEmpty
          ? (currentTeacher != null ? null : 'password')
          : _passwordController.text;

      if (currentTeacher == null) {
        context
            .read<TeacherBloc>()
            .add(CreateTeacher(teacher, password ?? 'password'));
      } else {
        context
            .read<TeacherBloc>()
            .add(UpdateTeacher(currentTeacher.id, teacher, password));
      }
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
