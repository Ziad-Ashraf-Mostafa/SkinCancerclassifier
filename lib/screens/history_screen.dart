import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../theme/theme.dart';
import '../services/scan_storage_service.dart';
import '../services/skin_cancer_classifier.dart';
import 'preprocessing_screen.dart';

class HistoryScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final SkinCancerClassifier classifier;

  const HistoryScreen({
    super.key,
    required this.cameras,
    required this.classifier,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<ScanRecord> _scanHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    await ScanStorageService.instance.initialize();
    setState(() {
      _scanHistory = ScanStorageService.instance.scanHistory;
      _isLoading = false;
    });
  }

  Future<void> _deleteScan(ScanRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Scan',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          'Are you sure you want to delete this scan?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.dangerRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ScanStorageService.instance.deleteScan(record.id);
      if (success) {
        setState(() {
          _scanHistory = ScanStorageService.instance.scanHistory;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Scan deleted'),
              backgroundColor: AppTheme.cardDark,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _shareScan(ScanRecord record) async {
    final success = await ScanStorageService.instance.shareScan(record);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not share scan'),
          backgroundColor: AppTheme.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _exportScan(ScanRecord record) async {
    final exportPath = await ScanStorageService.instance.exportToGallery(record);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            exportPath != null
                ? 'Saved to: Pictures/SkinScanner'
                : 'Could not export scan',
          ),
          backgroundColor: exportPath != null ? AppTheme.safeGreen : AppTheme.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _viewScanDetails(ScanRecord record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ScanDetailsSheet(
        record: record,
        onDelete: () {
          Navigator.pop(context);
          _deleteScan(record);
        },
        onRescan: () {
          Navigator.pop(context);
          // Navigate to preprocessing with the saved image
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  PreprocessingScreen(
                    imagePath: record.imagePath,
                    classifier: widget.classifier,
                    cameras: widget.cameras,
                  ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        },
        onShare: () {
          Navigator.pop(context);
          _shareScan(record);
        },
        onExport: () {
          Navigator.pop(context);
          _exportScan(record);
        },
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: GlassmorphicContainer(
                          opacity: 0.15,
                          borderRadius: 14,
                          padding: const EdgeInsets.all(12),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 20,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Opacity(
                        opacity: _fadeAnimation.value,
                        child: Text(
                          'Scan History',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.accentTeal,
                          ),
                        )
                      : _scanHistory.isEmpty
                      ? Opacity(
                          opacity: _fadeAnimation.value,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 80,
                                  color: Colors.white.withAlpha(50),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'No Scans Yet',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(color: Colors.white54),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Your saved scans will appear here',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.white38),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Opacity(
                          opacity: _fadeAnimation.value,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: _scanHistory.length,
                            itemBuilder: (context, index) {
                              final record = _scanHistory[index];
                              return _ScanHistoryCard(
                                record: record,
                                onTap: () => _viewScanDetails(record),
                                onDelete: () => _deleteScan(record),
                              );
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScanHistoryCard extends StatelessWidget {
  final ScanRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ScanHistoryCard({
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = record.isCancerous
        ? AppTheme.dangerRed
        : AppTheme.safeGreen;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withAlpha(60), width: 1),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 100,
                height: 100,
                child: File(record.imagePath).existsSync()
                    ? Image.file(File(record.imagePath), fit: BoxFit.cover)
                    : Container(
                        color: AppTheme.surfaceDark,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white38,
                        ),
                      ),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date and time
                    Text(
                      '${record.formattedDate} • ${record.formattedTime}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white54),
                    ),
                    const SizedBox(height: 6),

                    // Result
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        record.shortResult,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Confidence
                    Row(
                      children: [
                        Text(
                          'Confidence: ',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white54),
                        ),
                        Text(
                          record.confidencePercent,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.accentTeal,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Delete button
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline_rounded, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanDetailsSheet extends StatelessWidget {
  final ScanRecord record;
  final VoidCallback onDelete;
  final VoidCallback onRescan;
  final VoidCallback onShare;
  final VoidCallback onExport;

  const _ScanDetailsSheet({
    required this.record,
    required this.onDelete,
    required this.onRescan,
    required this.onShare,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = record.isCancerous
        ? AppTheme.dangerRed
        : AppTheme.safeGreen;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: File(record.imagePath).existsSync()
                          ? Image.file(
                              File(record.imagePath),
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: AppTheme.cardDark,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.white38,
                                size: 60,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Date and time
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${record.formattedDate} at ${record.formattedTime}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Result card
                  GlassmorphicContainer(
                    opacity: 0.1,
                    borderRadius: 16,
                    borderColor: statusColor.withAlpha(60),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(40),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                record.isCancerous
                                    ? Icons.warning_rounded
                                    : Icons.check_circle_rounded,
                                color: statusColor,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                record.shortResult,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Label
                        Text(
                          record.label,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),

                        const SizedBox(height: 8),

                        // Confidence
                        Row(
                          children: [
                            Text(
                              'Confidence: ',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white54),
                            ),
                            Text(
                              record.confidencePercent,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.accentTeal,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Description
                        Text(
                          record.description,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white60, height: 1.5),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.dangerRed,
                            side: BorderSide(
                              color: AppTheme.dangerRed.withAlpha(100),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onRescan,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Re-analyze'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentTeal,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Share and Export row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onShare,
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Share'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accentTeal,
                            side: BorderSide(
                              color: AppTheme.accentTeal.withAlpha(100),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onExport,
                          icon: const Icon(Icons.save_alt_rounded),
                          label: const Text('Save to Gallery'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(
                              color: Colors.white24,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
