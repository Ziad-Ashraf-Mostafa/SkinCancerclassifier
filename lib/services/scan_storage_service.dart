import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'skin_cancer_classifier.dart';
import 'package:gal/gal.dart';

class ScanRecord {
  final String id;
  final String imagePath;
  final String label;
  final double confidence;
  final bool isCancerous;
  final String description;
  final DateTime dateTime;

  ScanRecord({
    required this.id,
    required this.imagePath,
    required this.label,
    required this.confidence,
    required this.isCancerous,
    required this.description,
    required this.dateTime,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'imagePath': imagePath,
    'label': label,
    'confidence': confidence,
    'isCancerous': isCancerous,
    'description': description,
    'dateTime': dateTime.toIso8601String(),
  };

  factory ScanRecord.fromJson(Map<String, dynamic> json) => ScanRecord(
    id: json['id'],
    imagePath: json['imagePath'],
    label: json['label'],
    confidence: json['confidence'],
    isCancerous: json['isCancerous'],
    description: json['description'],
    dateTime: DateTime.parse(json['dateTime']),
  );

  String get shortResult => isCancerous ? 'Potentially Concerning' : 'Benign';

  String get formattedDate => DateFormat('MMM dd, yyyy').format(dateTime);

  String get formattedTime => DateFormat('hh:mm a').format(dateTime);

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';
}

class ScanStorageService {
  static const String _folderName = 'SkinScannerData';
  static const String _historyFileName = 'scan_history.json';

  static ScanStorageService? _instance;
  static ScanStorageService get instance {
    _instance ??= ScanStorageService._();
    return _instance!;
  }

  ScanStorageService._();

  Directory? _appDirectory;
  List<ScanRecord> _scanHistory = [];

  List<ScanRecord> get scanHistory => List.unmodifiable(_scanHistory);

  Future<void> initialize() async {
    try {
      // Use internal app documents directory (secure, no permissions needed)
      final appDocDir = await getApplicationDocumentsDirectory();
      _appDirectory = Directory('${appDocDir.path}/$_folderName');

      // Create directory if it doesn't exist
      if (!await _appDirectory!.exists()) {
        await _appDirectory!.create(recursive: true);
      }

      // Create images subdirectory
      final imagesDir = Directory('${_appDirectory!.path}/images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Load existing history
      await _loadHistory();

      debugPrint('ScanStorageService initialized at: ${_appDirectory!.path}');
    } catch (e) {
      debugPrint('Error initializing ScanStorageService: $e');
    }
  }

  Future<void> _loadHistory() async {
    try {
      final historyFile = File('${_appDirectory!.path}/$_historyFileName');
      if (await historyFile.exists()) {
        final content = await historyFile.readAsString();
        final List<dynamic> jsonList = json.decode(content);
        _scanHistory = jsonList.map((e) => ScanRecord.fromJson(e)).toList()
          ..sort(
            (a, b) => b.dateTime.compareTo(a.dateTime),
          ); // Sort newest first
      }
    } catch (e) {
      debugPrint('Error loading scan history: $e');
      _scanHistory = [];
    }
  }

  Future<void> _saveHistory() async {
    try {
      final historyFile = File('${_appDirectory!.path}/$_historyFileName');
      final jsonList = _scanHistory.map((e) => e.toJson()).toList();
      await historyFile.writeAsString(json.encode(jsonList));
    } catch (e) {
      debugPrint('Error saving scan history: $e');
    }
  }

  Future<ScanRecord?> saveScan({
    required File imageFile,
    required ClassificationResult result,
  }) async {
    if (_appDirectory == null) {
      debugPrint('Storage not initialized');
      return null;
    }

    try {
      final uuid = const Uuid();
      final id = uuid.v4();
      final timestamp = DateTime.now();
      final fileName =
          'scan_${DateFormat('yyyyMMdd_HHmmss').format(timestamp)}_$id.jpg';

      // Copy image to our directory
      final imagesDir = '${_appDirectory!.path}/images';
      final newImagePath = '$imagesDir/$fileName';
      await imageFile.copy(newImagePath);

      // Create scan record
      final scanRecord = ScanRecord(
        id: id,
        imagePath: newImagePath,
        label: result.label,
        confidence: result.confidence,
        isCancerous: result.isCancerous,
        description: result.description,
        dateTime: timestamp,
      );

      // Add to history
      _scanHistory.insert(0, scanRecord);

      // Save to file
      await _saveHistory();

      debugPrint('Scan saved successfully: $id');
      return scanRecord;
    } catch (e) {
      debugPrint('Error saving scan: $e');
      return null;
    }
  }

  Future<bool> deleteScan(String id) async {
    try {
      final index = _scanHistory.indexWhere((e) => e.id == id);
      if (index == -1) return false;

      final record = _scanHistory[index];

      // Delete image file
      final imageFile = File(record.imagePath);
      if (await imageFile.exists()) {
        await imageFile.delete();
      }

      // Remove from history
      _scanHistory.removeAt(index);

      // Save updated history
      await _saveHistory();

      return true;
    } catch (e) {
      debugPrint('Error deleting scan: $e');
      return false;
    }
  }

  Future<void> clearAllHistory() async {
    try {
      // Delete all images
      for (final record in _scanHistory) {
        final imageFile = File(record.imagePath);
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      }

      // Clear history
      _scanHistory.clear();

      // Save empty history
      await _saveHistory();
    } catch (e) {
      debugPrint('Error clearing history: $e');
    }
  }

  /// Share a scan image with other apps
  Future<bool> shareScan(ScanRecord record) async {
    try {
      final imageFile = File(record.imagePath);
      if (!await imageFile.exists()) {
        debugPrint('Image file not found for sharing');
        return false;
      }

      final result = await Share.shareXFiles(
        [XFile(record.imagePath)],
        text: 'Skin Scanner Result\n'
            '${record.formattedDate} at ${record.formattedTime}\n'
            'Result: ${record.shortResult}\n'
            'Confidence: ${record.confidencePercent}\n\n'
            '⚠️ This is for educational purposes only. '
            'Please consult a dermatologist for professional diagnosis.',
        subject: 'Skin Scanner - ${record.label}',
      );

      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (e) {
      debugPrint('Error sharing scan: $e');
      return false;
    }
  }

 /// Export scan image to device gallery using GAL package
  Future<String?> exportToGallery(ScanRecord record) async {
    try {
      // 1. Check Permissions
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }

      // 2. Save to Gallery directly
      // This works on Android & iOS automatically
      await Gal.putImage(record.imagePath, album: 'SkinScanner');

      debugPrint('Saved to gallery successfully');
      
      // بنرجع أي كلمة عشان الـ HistoryScreen تفهم إن العملية نجحت
      return "Saved to SkinScanner Album"; 
    } catch (e) {
      debugPrint('Error saving to gallery: $e');
      return null; // لو رجع null الشاشة هتفهم إنه فشل
    }
  }
}