import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../features/students/data/models/student_model.dart';

class StudentMultiSelect extends StatefulWidget {
  final List<StudentModel> allStudents;
  final List<StudentModel> selectedStudents;
  final Function(List<StudentModel>) onSelectionChanged;

  const StudentMultiSelect({
    super.key,
    required this.allStudents,
    required this.selectedStudents,
    required this.onSelectionChanged,
  });

  @override
  State<StudentMultiSelect> createState() => _StudentMultiSelectState();
}

class _StudentMultiSelectState extends State<StudentMultiSelect> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<StudentModel> get _filteredStudents {
    final selectedIds = widget.selectedStudents.map((s) => s.id).toSet();
    
    List<StudentModel> filtered;
    if (_searchQuery.isEmpty) {
      filtered = widget.allStudents;
    } else {
      final query = _searchQuery.toLowerCase();
      filtered = widget.allStudents.where((student) {
        return student.name.toLowerCase().contains(query) ||
            student.email.toLowerCase().contains(query);
      }).toList();
    }
    
    // Sort to show selected students first
    filtered.sort((a, b) {
      final aSelected = selectedIds.contains(a.id);
      final bSelected = selectedIds.contains(b.id);
      
      if (aSelected && !bSelected) return -1;
      if (!aSelected && bSelected) return 1;
      
      // If both selected or both not selected, sort by name
      return a.name.compareTo(b.name);
    });
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIds = widget.selectedStudents.map((s) => s.id).toSet();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Text(
          '${AppLocalizations.of(context)!.assignedStudents} (${widget.selectedStudents.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: widget.selectedStudents.isEmpty
            ? Text(
                AppLocalizations.of(context)!.noStudentsAssigned,
                style: TextStyle(color: Theme.of(context).hintColor),
              )
            : Text(
                widget.selectedStudents.map((s) => s.name).join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.searchStudents,
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
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            child: _filteredStudents.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'لا يوجد طلاب يطابقون البحث',
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredStudents.length,
                    itemBuilder: (context, index) {
                      final student = _filteredStudents[index];
                      final isSelected = selectedIds.contains(student.id);

                      return CheckboxListTile(
                        title: Text(student.name),
                        value: isSelected,
                        onChanged: (value) {
                          final newSelection = List<StudentModel>.from(widget.selectedStudents);
                          if (value == true) {
                            if (!newSelection.any((s) => s.id == student.id)) {
                              newSelection.add(student);
                            }
                          } else {
                            newSelection.removeWhere((s) => s.id == student.id);
                          }
                          widget.onSelectionChanged(newSelection);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

