import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../common_widgets/custom_text_field.dart';
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/datasources/student_remote_datasource.dart';
import '../../data/models/student_model.dart';
import '../../data/repositories/student_repository_impl.dart';
import '../bloc/student_bloc.dart';
import '../bloc/student_event.dart';
import '../bloc/student_state.dart';
import '../../../../features/teachers/presentation/widgets/currency_hour_price_field.dart';

class StudentFormPage extends StatefulWidget {
  final StudentModel? student;
  final int? studentId;

  const StudentFormPage({super.key, this.student, this.studentId});

  @override
  State<StudentFormPage> createState() => _StudentFormPageState();
}

class _StudentFormPageState extends State<StudentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _whatsappController = TextEditingController();
  
  String? _selectedCurrency;
  String? _hourPrice;

  StudentModel? _loadedStudent;
  bool _isLoadingStudent = false;
  bool _hasLoadedStudent = false;

  @override
  void initState() {
    super.initState();
    if (widget.student != null) {
      _loadedStudent = widget.student;
      _populateForm(widget.student!);
    } else if (widget.studentId != null) {
      _isLoadingStudent = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Don't load here - will be triggered from BlocListener
  }

  void _populateForm(StudentModel student) {
    setState(() {
      _nameController.text = student.name;
      _selectedCurrency = student.currency ?? 'EGP';
      _hourPrice = student.hourPrice?.toString() ?? '';
      _whatsappController.text = student.whatsappNumber ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
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
        final dataSource = StudentRemoteDataSourceImpl(apiService);
        final repository = StudentRepositoryImpl(dataSource);
        return StudentBloc(repository);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text((widget.student == null && widget.studentId == null)
              ? AppLocalizations.of(context)!.addStudent 
              : AppLocalizations.of(context)!.editStudent),
        ),
        body: BlocListener<StudentBloc, StudentState>(
          listener: (context, state) {
            if (state is StudentLoaded && _isLoadingStudent) {
              setState(() {
                _loadedStudent = state.student;
                _isLoadingStudent = false;
                _populateForm(state.student);
              });
            }
            if (state is StudentOperationSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
              context.pop();
            }
            if (state is StudentError) {
              setState(() {
                _isLoadingStudent = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: Builder(
            builder: (builderContext) {
              return BlocBuilder<StudentBloc, StudentState>(
                builder: (context, state) {
                  // Trigger load when bloc becomes available (on initial state)
                  if (widget.studentId != null && !_hasLoadedStudent && state is StudentInitial) {
                    _hasLoadedStudent = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        // Use builderContext which has access to BlocProvider
                        builderContext.read<StudentBloc>().add(LoadStudent(widget.studentId!));
                      }
                    });
                  }
                  
                  if (_isLoadingStudent) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  return SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.disabled,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Personal Information Section
                          _buildSectionHeader(context, 'المعلومات الشخصية'),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _nameController,
                            label: AppLocalizations.of(context)!.name,
                            hint: 'أدخل اسم الطالب',
                            prefixIcon: const Icon(Icons.person),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppLocalizations.of(context)!.nameIsRequired;
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
                            currencies: {
                              'USD': 'USD - US Dollar',
                              'GBP': 'GBP - British Pound',
                              'EUR': 'EUR - Euro',
                              'EGP': 'EGP - جنيه مصري',
                              'SAR': 'SAR - ريال سعودي',
                              'AED': 'AED - درهم إماراتي',
                              'CAD': 'CAD - Canadian Dollar',
                            },
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final price = double.tryParse(value);
                                if (price == null || price < 0) {
                                  return AppLocalizations.of(context)!.invalidPrice;
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
                          const SizedBox(height: 32),
                          BlocBuilder<StudentBloc, StudentState>(
                            builder: (context, state) {
                              final isLoading = state is StudentLoading;
                              return ElevatedButton(
                                onPressed: isLoading ? null : () => _submitForm(context),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text((widget.student == null && widget.studentId == null)
                                        ? AppLocalizations.of(context)!.createStudent 
                                        : AppLocalizations.of(context)!.updateStudent),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _submitForm(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      final currentStudent = _loadedStudent ?? widget.student;
      final student = StudentModel(
        id: currentStudent?.id ?? 0,
        name: _nameController.text,
        email: currentStudent?.email ?? '', // Email will be generated on backend for new students
        whatsappNumber: _whatsappController.text.trim().isNotEmpty ? _whatsappController.text.trim() : null,
        country: null, // No longer needed
        currency: _selectedCurrency,
        hourPrice: _hourPrice != null && _hourPrice!.isNotEmpty
            ? double.tryParse(_hourPrice!)
            : null,
        createdAt: currentStudent?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (currentStudent == null) {
        context.read<StudentBloc>().add(CreateStudent(student));
      } else {
        context.read<StudentBloc>().add(UpdateStudent(currentStudent.id, student));
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

