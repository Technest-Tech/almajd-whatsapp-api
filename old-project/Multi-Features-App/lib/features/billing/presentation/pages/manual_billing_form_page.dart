import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../common_widgets/custom_text_field.dart';
import '../../../students/data/datasources/student_remote_datasource.dart';
import '../../../students/data/models/student_model.dart';
import '../../../students/data/repositories/student_repository_impl.dart';
import '../../../students/presentation/bloc/student_bloc.dart';
import '../../../students/presentation/bloc/student_event.dart';
import '../../../students/presentation/bloc/student_state.dart';
import '../../../teachers/presentation/widgets/student_multi_select.dart';
import '../../data/datasources/billing_remote_datasource.dart';
import '../../data/models/manual_billing_model.dart';
import '../bloc/manual_billing_bloc.dart';
import '../bloc/manual_billing_event.dart';
import '../bloc/manual_billing_state.dart';

class ManualBillingFormPage extends StatefulWidget {
  final ManualBillingModel? billing;
  final int? billingId;

  const ManualBillingFormPage({
    super.key,
    this.billing,
    this.billingId,
  });

  @override
  State<ManualBillingFormPage> createState() => _ManualBillingFormPageState();
}

class _ManualBillingFormPageState extends State<ManualBillingFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();

  List<StudentModel> _selectedStudents = [];
  List<StudentModel> _allStudents = [];
  String? _selectedCurrency = 'EGP';
  bool _isLoadingStudents = true;

  final Map<String, String> _currencies = {
    'USD': 'USD - US Dollar',
    'GBP': 'GBP - British Pound',
    'EUR': 'EUR - Euro',
    'EGP': 'EGP - جنيه مصري',
    'SAR': 'SAR - ريال سعودي',
    'AED': 'AED - درهم إماراتي',
    'CAD': 'CAD - Canadian Dollar',
  };

  @override
  void initState() {
    super.initState();
    if (widget.billing != null) {
      _populateForm(widget.billing!);
    }
  }

  void _populateForm(ManualBillingModel billing) {
    setState(() {
      _amountController.text = billing.amount.toString();
      _messageController.text = billing.message ?? '';
      _selectedCurrency = billing.currency;
      _selectedStudents = billing.students?.toList() ?? [];
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: MultiBlocProvider(
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
              final dataSource = StudentRemoteDataSourceImpl(apiService);
              final repository = StudentRepositoryImpl(dataSource);
              final bloc = StudentBloc(repository);
              // Load all students for dropdown (5000 per page to get all)
              bloc.add(const LoadStudents(perPage: 5000));
              return bloc;
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
              final dataSource = BillingRemoteDataSourceImpl(apiService);
              return ManualBillingBloc(dataSource);
            },
          ),
        ],
        child: BlocListener<StudentBloc, StudentState>(
          listener: (context, state) {
            if (state is StudentsLoaded) {
              setState(() {
                _allStudents = state.students;
                _isLoadingStudents = false;
              });
              // If editing, restore selected students
              if (widget.billing != null && _selectedStudents.isEmpty) {
                final billingStudentIds = widget.billing!.studentIds;
                _selectedStudents = _allStudents
                    .where((s) => billingStudentIds.contains(s.id))
                    .toList();
              }
            }
          },
          child: BlocListener<ManualBillingBloc, ManualBillingState>(
            listener: (context, state) {
              if (state is ManualBillingOperationSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: Colors.green,
                  ),
                );
                context.pop(true); // Return true to indicate success
              }
              if (state is ManualBillingError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Scaffold(
              appBar: AppBar(
                title: Text(widget.billing == null ? 'إضافة فاتورة يدوية' : 'تعديل فاتورة يدوية'),
              ),
              body: _isLoadingStudents
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Student Selection
                            StudentMultiSelect(
                              allStudents: _allStudents,
                              selectedStudents: _selectedStudents,
                              onSelectionChanged: (students) {
                                setState(() {
                                  _selectedStudents = students;
                                });
                              },
                            ),
                            const SizedBox(height: 24),

                            // Currency Selector
                            Text(
                              'العملة',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _showCurrencyPicker(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(context).dividerColor,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Theme.of(context).colorScheme.surface,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _currencies[_selectedCurrency] ?? 'EGP',
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    ),
                                    const Icon(Icons.arrow_drop_down),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Amount Input
                            CustomTextField(
                              controller: _amountController,
                              label: 'المبلغ',
                              hint: 'أدخل المبلغ',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'الرجاء إدخال المبلغ';
                                }
                                final amount = double.tryParse(value);
                                if (amount == null || amount <= 0) {
                                  return 'الرجاء إدخال مبلغ صحيح';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Message Input
                            Text(
                              'الرسالة (اختياري)',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _messageController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: 'أدخل رسالة للفاتورة...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Submit Button
                            BlocBuilder<ManualBillingBloc, ManualBillingState>(
                              builder: (blocContext, state) {
                                final isLoading = state is ManualBillingLoading;
                                return ElevatedButton(
                                  onPressed: isLoading ? null : () => _handleSubmit(blocContext),
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
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          widget.billing == null ? 'إنشاء فاتورة' : 'تحديث فاتورة',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اختر العملة'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _currencies.length,
              itemBuilder: (context, index) {
                final currency = _currencies.keys.elementAt(index);
                final label = _currencies[currency]!;
                final isSelected = _selectedCurrency == currency;
                return ListTile(
                  title: Text(label),
                  leading: Radio<String>(
                    value: currency,
                    groupValue: _selectedCurrency,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCurrency = value;
                        });
                        Navigator.pop(dialogContext);
                      }
                    },
                  ),
                  selected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedCurrency = currency;
                    });
                    Navigator.pop(dialogContext);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _handleSubmit(BuildContext context) {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار طالب واحد على الأقل'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final billing = ManualBillingModel(
      id: widget.billing?.id ?? 0,
      studentIds: _selectedStudents.map((s) => s.id).toList(),
      students: _selectedStudents,
      amount: double.parse(_amountController.text),
      currency: _selectedCurrency!,
      message: _messageController.text.isEmpty ? null : _messageController.text,
      paymentToken: widget.billing?.paymentToken,
      isPaid: widget.billing?.isPaid ?? false,
      paidAt: widget.billing?.paidAt,
      paymentMethod: widget.billing?.paymentMethod,
      createdBy: widget.billing?.createdBy ?? 0,
      createdAt: widget.billing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (widget.billing == null) {
      context.read<ManualBillingBloc>().add(CreateManualBilling(billing));
    } else {
      context.read<ManualBillingBloc>().add(UpdateManualBilling(widget.billing!.id, billing));
    }
  }
}
