import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:tripytravy_core/tripytravy_core.dart';

/// Shows the pop-up dialog box to select a travel itinerary .tt file.
/// When the user clicks the designated area, it opens the phone's file manager.
Future<TripPackage?> showImportTtFileDialog({
  required BuildContext context,
  required MobileTripManagerService tripManager,
  Future<List<PlatformFile>> Function()? filePickerOverride,
}) {
  return showDialog<TripPackage?>(
    context: context,
    builder: (dialogCtx) => ImportTtDialog(
      tripManager: tripManager,
      filePickerOverride: filePickerOverride,
    ),
  );
}

class ImportTtDialog extends StatefulWidget {
  final MobileTripManagerService tripManager;
  final Future<List<PlatformFile>> Function()? filePickerOverride;

  const ImportTtDialog({
    super.key,
    required this.tripManager,
    this.filePickerOverride,
  });

  @override
  State<ImportTtDialog> createState() => _ImportTtDialogState();
}

class _ImportTtDialogState extends State<ImportTtDialog> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleAreaClick() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<PlatformFile> files;
      if (widget.filePickerOverride != null) {
        files = await widget.filePickerOverride!();
      } else {
        files = await FilePicker.pickFiles(
          type: FileType.any,
        );
      }

      if (files.isEmpty) {
        // User cancelled file selection
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final file = files.first;
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('Selected file is empty');
      }

      TripPackage trip;

      // Determine if file is binary TTRV container or JSON itinerary
      if (bytes.length >= 4 &&
          bytes[0] == 0x54 &&
          bytes[1] == 0x54 &&
          bytes[2] == 0x52 &&
          bytes[3] == 0x56) {
        // Binary .ttrv container
        trip = await widget.tripManager.importTripFromContainer(bytes);
      } else {
        // Try parsing JSON format
        try {
          final decoded = utf8.decode(bytes);
          final map = jsonDecode(decoded) as Map<String, dynamic>;
          trip = await widget.tripManager.importTripFromJson(map);
        } catch (_) {
          // Fallback to container unpack
          trip = await widget.tripManager.importTripFromContainer(bytes);
        }
      }

      if (mounted) {
        Navigator.of(context).pop(trip);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Import failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with Title and Close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Import Itinerary',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D2356),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFF64748B), size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Clickable area that triggers opening the phone's file manager
            InkWell(
              onTap: _isLoading ? null : _handleAreaClick,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5FB),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF0D2356).withValues(alpha: 0.22),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF0D2356)),
                        ),
                      )
                    else ...[
                      // Folder/Document badge icon
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF0D2356).withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.folder_open_rounded,
                          size: 32,
                          color: Color(0xFF0D2356),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Exact text requested by user
                      const Text(
                        'Select your Travel itinerary .tt file',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D2356),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Supporting guidance text
                      Text(
                        'Tap here to open file manager on your phone',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
