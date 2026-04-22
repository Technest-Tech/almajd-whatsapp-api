import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multi_features_app/l10n/app_localizations.dart';
import '../models/admin_room.dart';

class RoomCard extends StatelessWidget {
  final AdminRoom room;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String baseUrl;

  const RoomCard({
    super.key,
    required this.room,
    required this.onEdit,
    required this.onDelete,
    this.baseUrl = 'https://almajdmeet.org',
  });

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.linkCopiedToClipboard),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: room.isActive ? Colors.green.shade200 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: room.isActive ? Colors.green.shade50 : Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (room.description != null && room.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              room.description!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        color: Colors.blue,
                        onPressed: onEdit,
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        color: Colors.red,
                        onPressed: onDelete,
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Status badges
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatusChip(
                    context,
                    room.isActive 
                        ? AppLocalizations.of(context)!.active 
                        : AppLocalizations.of(context)!.inactive,
                    room.isActive ? Colors.green : Colors.grey,
                  ),
                  _buildStatusChip(
                    context,
                    room.canRecord 
                        ? AppLocalizations.of(context)!.recordingAllowed 
                        : AppLocalizations.of(context)!.noRecording,
                    room.canRecord ? Colors.blue : Colors.grey,
                  ),
                  _buildStatusChip(
                    context,
                    '${room.participants.length} ${AppLocalizations.of(context)!.participants}',
                    Colors.orange,
                  ),
                ],
              ),
            ),

            // Links section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.hostLink,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildLinkRow(
                    context,
                    '$baseUrl/${room.hostLink}/h',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.guestLink,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildLinkRow(
                    context,
                    '$baseUrl/${room.guestLink}/g',
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${AppLocalizations.of(context)!.created}: ${_formatDate(room.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '${AppLocalizations.of(context)!.max}: ${room.maxParticipants}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _getDarkerColor(color),
        ),
      ),
    );
  }

  Widget _buildLinkRow(BuildContext context, String link) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              link,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.copy, size: 18),
          color: Colors.blue,
          onPressed: () => _copyToClipboard(context, link),
          tooltip: AppLocalizations.of(context)!.copyLink,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Color _getDarkerColor(Color color) {
    return Color.fromRGBO(
      (color.red * 0.7).round().clamp(0, 255),
      (color.green * 0.7).round().clamp(0, 255),
      (color.blue * 0.7).round().clamp(0, 255),
      1.0,
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}

