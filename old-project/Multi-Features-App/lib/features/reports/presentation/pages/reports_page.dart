import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'dart:io';
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../students/data/datasources/student_remote_datasource.dart';
import '../../../students/data/repositories/student_repository_impl.dart';
import '../../../students/presentation/bloc/student_bloc.dart';
import '../../../students/presentation/bloc/student_event.dart';
import '../../../students/presentation/bloc/student_state.dart';
import '../../../students/data/models/student_model.dart';
import '../../data/datasources/report_remote_datasource.dart';
import '../../data/repositories/report_repository_impl.dart';
import '../bloc/report_bloc.dart';
import '../bloc/report_event.dart';
import '../bloc/report_state.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  // Section 1: Student Report
  StudentModel? _selectedStudent;
  DateTime? _studentFromDate;
  DateTime? _studentToDate;
  final TextEditingController _studentSearchController = TextEditingController();

  // Section 2: Academy Statistics Report
  DateTime? _academyFromDate;
  DateTime? _academyToDate;

  @override
  void dispose() {
    _studentSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) {
            final apiService = ApiService();
            StorageService.getToken().then((t) {
              if (t != null) {
                apiService.setAuthToken(t);
              }
            });
            final studentDataSource = StudentRemoteDataSourceImpl(apiService);
            final studentRepository = StudentRepositoryImpl(studentDataSource);
            final studentBloc = StudentBloc(studentRepository);
            // Load all students for dropdown (5000 per page to get all)
            studentBloc.add(const LoadStudents(perPage: 5000));
            return studentBloc;
          },
        ),
        BlocProvider(
          create: (context) {
            final apiService = ApiService();
            StorageService.getToken().then((t) {
              if (t != null) {
                apiService.setAuthToken(t);
              }
            });
            final reportDataSource = ReportRemoteDataSourceImpl(apiService);
            final reportRepository = ReportRepositoryImpl(reportDataSource);
            return ReportBloc(reportRepository);
          },
        ),
      ],
      child: BlocListener<ReportBloc, ReportState>(
        listener: (context, state) {
          if (state is ReportSuccess) {
            _showPdfSuccessDialog(context, state.pdfBytes, state.filename);
            // Reset state after handling success
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                context.read<ReportBloc>().add(const ResetReportState());
              }
            });
          } else if (state is ReportError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
            // Reset state after showing error
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                context.read<ReportBloc>().add(const ResetReportState());
              }
            });
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section 1: Student Report
              _buildStudentReportSection(context),
              const SizedBox(height: 24),
              
              // Section 2: Academy Statistics Report
              _buildAcademyStatisticsSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentReportSection(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تقرير طالب واحد',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            BlocBuilder<StudentBloc, StudentState>(
              builder: (context, state) {
                if (state is StudentsLoaded) {
                  return _buildSearchableStudentDropdown(context, state.students);
                }
                return const CircularProgressIndicator();
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    label: 'من تاريخ',
                    date: _studentFromDate,
                    onTap: () => _selectDate(context, true, true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateField(
                    label: 'إلى تاريخ',
                    date: _studentToDate,
                    onTap: () => _selectDate(context, false, true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            BlocBuilder<ReportBloc, ReportState>(
              builder: (context, reportState) {
                final isLoading = reportState is ReportLoading && 
                    reportState.reportType == ReportType.student;
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: !isLoading &&
                            _selectedStudent != null &&
                            _studentFromDate != null &&
                            _studentToDate != null
                        ? () {
                            context.read<ReportBloc>().add(
                                  GenerateStudentReport(
                                    studentId: _selectedStudent!.id,
                                    fromDate: DateFormat('yyyy-MM-dd')
                                        .format(_studentFromDate!),
                                    toDate: DateFormat('yyyy-MM-dd')
                                        .format(_studentToDate!),
                                  ),
                                );
                          }
                        : null,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('إنشاء التقرير'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcademyStatisticsSection(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تقرير إحصائيات الأكاديمية',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    label: 'من تاريخ',
                    date: _academyFromDate,
                    onTap: () => _selectDate(context, true, null),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateField(
                    label: 'إلى تاريخ',
                    date: _academyToDate,
                    onTap: () => _selectDate(context, false, null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            BlocBuilder<ReportBloc, ReportState>(
              builder: (context, reportState) {
                final isLoading = reportState is ReportLoading && 
                    reportState.reportType == ReportType.academyStatistics;
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: !isLoading &&
                            _academyFromDate != null &&
                            _academyToDate != null
                        ? () {
                            context.read<ReportBloc>().add(
                                  GenerateAcademyStatisticsReport(
                                    fromDate: DateFormat('yyyy-MM-dd')
                                        .format(_academyFromDate!),
                                    toDate: DateFormat('yyyy-MM-dd')
                                        .format(_academyToDate!),
                                  ),
                                );
                          }
                        : null,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('إنشاء التقرير'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchableStudentDropdown(
    BuildContext context,
    List<StudentModel> students,
  ) {
    return InkWell(
      onTap: () {
        _showStudentSearchDialog(context, students);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'اختر الطالب',
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          _selectedStudent?.name ?? '',
          style: TextStyle(
            fontSize: 14,
            color: _selectedStudent == null
                ? Colors.grey[600]
                : Theme.of(context).textTheme.bodyLarge?.color,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }

  void _showStudentSearchDialog(
    BuildContext context,
    List<StudentModel> students,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _StudentSearchDialog(
          students: students,
          initialSelectedStudent: _selectedStudent,
          onConfirm: (student) {
            setState(() {
              _selectedStudent = student;
            });
            Navigator.of(dialogContext).pop();
          },
          onCancel: () {
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          date != null ? DateFormat('yyyy-MM-dd').format(date) : '',
          style: date != null
              ? null
              : TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }

  Future<void> _selectDate(
    BuildContext context,
    bool isFromDate,
    bool? isStudentSection,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar', 'SA'),
    );

    if (picked != null) {
      setState(() {
        if (isStudentSection == true) {
          if (isFromDate) {
            _studentFromDate = picked;
          } else {
            _studentToDate = picked;
          }
        } else {
          if (isFromDate) {
            _academyFromDate = picked;
          } else {
            _academyToDate = picked;
          }
        }
      });
    }
  }

  Future<void> _showPdfSuccessDialog(
    BuildContext context,
    Uint8List pdfBytes,
    String filename,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PdfSuccessDialog(
        pdfBytes: pdfBytes,
        filename: filename,
      ),
    );
  }
}

class _StudentSearchDialog extends StatefulWidget {
  final List<StudentModel> students;
  final StudentModel? initialSelectedStudent;
  final Function(StudentModel?) onConfirm;
  final VoidCallback onCancel;

  const _StudentSearchDialog({
    required this.students,
    required this.initialSelectedStudent,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_StudentSearchDialog> createState() => _StudentSearchDialogState();
}

class _StudentSearchDialogState extends State<_StudentSearchDialog> {
  late TextEditingController _searchController;
  late StudentModel? _selectedStudent;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedStudent = widget.initialSelectedStudent;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = _searchController.text.isEmpty
        ? widget.students
        : widget.students.where((student) {
            final query = _searchController.text.toLowerCase();
            return student.name.toLowerCase().contains(query) ||
                (student.email?.toLowerCase().contains(query) ?? false);
          }).toList();

    return AlertDialog(
      title: const Text('اختر الطالب'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث عن طالب...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 350,
                  minHeight: 150,
                ),
                child: filteredStudents.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('لا توجد نتائج'),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          final isSelected = _selectedStudent?.id == student.id;
                          return ListTile(
                            title: Text(
                              student.name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            selected: isSelected,
                            selectedTileColor: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withOpacity(0.3),
                            onTap: () {
                              setState(() {
                                _selectedStudent = student;
                              });
                            },
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle,
                                    color: Theme.of(context).colorScheme.primary,
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onConfirm(_selectedStudent);
          },
          child: const Text('تأكيد'),
        ),
      ],
    );
  }
}

class _PdfSuccessDialog extends StatelessWidget {
  final Uint8List pdfBytes;
  final String filename;

  const _PdfSuccessDialog({
    required this.pdfBytes,
    required this.filename,
  });

  Future<void> _savePdf(BuildContext context) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(pdfBytes);
      
      if (file.existsSync()) {
        Navigator.pop(context);
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'تقرير الأكاديمية',
        );
      } else {
        throw Exception('File was not created');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ الملف: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _viewPdf(BuildContext context) async {
    try {
      Navigator.pop(context);
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في عرض الملف: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 50,
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              'تم إنشاء التقرير بنجاح',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            // Filename
            Text(
              filename,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewPdf(context),
                    icon: const Icon(Icons.visibility),
                    label: const Text('عرض'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _savePdf(context),
                    icon: const Icon(Icons.download),
                    label: const Text('تحميل'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
