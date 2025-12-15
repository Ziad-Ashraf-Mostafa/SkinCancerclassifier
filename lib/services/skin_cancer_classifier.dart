import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ClassificationResult {
  final String label;
  final double confidence;
  final bool isCancerous;
  final String description;

  ClassificationResult({
    required this.label,
    required this.confidence,
    required this.isCancerous,
    required this.description,
  });
}

class SkinCancerClassifier {
  static const String _modelAsset = 'lib/ai/skin_cancer_model.tflite';
  static const String _labelsAsset = 'lib/ai/labels_cancer.txt';

  Interpreter? _interpreter;
  List<String> _labels = [];

  // Labels that indicate potentially cancerous conditions
  static const List<String> _cancerousLabels = [
    'Basal cell carcinoma',
    'Actinic keratoses',
  ];

  // Descriptions for each condition
  static const Map<String, String> _labelDescriptions = {
    'Actinic keratoses':
        'Rough, scaly patches caused by sun damage. Should be evaluated by a dermatologist.',
    'Basal cell carcinoma':
        'A type of skin cancer that begins in the basal cells. Requires medical attention.',
    'Benign keratosis-like lesions':
        'Non-cancerous skin growths that are generally harmless.',
    'Dermatofibroma': 'A benign skin growth that is typically harmless.',
    'Melanocytic nevi':
        'Common moles that are usually benign. Monitor for changes.',
    'Vascular lesions':
        'Blood vessel-related skin marks that are typically benign.',
  };

  bool get isReady => _interpreter != null && _labels.isNotEmpty;
  String? lastError;

  Future<bool> initialize() async {
    try {
      debugPrint('Starting classifier initialization...');

      // Load labels first (simpler operation)
      final labelsData = await rootBundle.loadString(_labelsAsset);
      _labels = labelsData
          .split('\n')
          .map((e) => e.trim().replaceAll('\r', ''))
          .where((e) => e.isNotEmpty)
          .toList();

      debugPrint('Labels loaded: $_labels');

      // Copy model from assets to temp directory for TFLite to access
      final modelFile = await _loadModelFile();
      debugPrint('Model file path: ${modelFile.path}');

      // Create interpreter from file
      _interpreter = Interpreter.fromFile(modelFile);

      debugPrint('SkinCancerClassifier initialized successfully');
      debugPrint(
        'Interpreter input shape: ${_interpreter!.getInputTensor(0).shape}',
      );
      debugPrint(
        'Interpreter output shape: ${_interpreter!.getOutputTensor(0).shape}',
      );

      return true;
    } catch (e, stackTrace) {
      lastError = e.toString();
      debugPrint('Error initializing classifier: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<File> _loadModelFile() async {
    // Get the bytes from assets
    final byteData = await rootBundle.load(_modelAsset);

    // Get temp directory
    final tempDir = await getTemporaryDirectory();
    final modelPath = '${tempDir.path}/skin_cancer_model.tflite';

    // Write to file
    final file = File(modelPath);
    await file.writeAsBytes(
      byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
    );

    return file;
  }

  Future<ClassificationResult?> classifyImage(File imageFile) async {
    if (!isReady) {
      debugPrint('Classifier not initialized');
      return null;
    }

    try {
      // Read and preprocess image
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        debugPrint('Failed to decode image');
        return null;
      }

      // Get actual input size from interpreter
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final actualInputSize =
          inputShape[1]; // Assuming [1, height, width, channels]

      debugPrint('Using input size: $actualInputSize');

      // Resize to model input size
      final resizedImage = img.copyResize(
        image,
        width: actualInputSize,
        height: actualInputSize,
      );

      // Convert to input tensor format (normalized float32)
      final input = _imageToInputTensor(resizedImage, actualInputSize);

      // Get output shape
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final numClasses = outputShape[1];

      // Prepare output tensor
      final output = List.filled(numClasses, 0.0).reshape([1, numClasses]);

      // Run inference
      _interpreter!.run(input, output);

      // Find the class with highest confidence
      final results = (output[0] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      int maxIndex = 0;
      double maxConfidence = results[0];

      for (int i = 1; i < results.length; i++) {
        if (results[i] > maxConfidence) {
          maxConfidence = results[i];
          maxIndex = i;
        }
      }

      // Ensure maxIndex is within labels range
      if (maxIndex >= _labels.length) {
        debugPrint(
          'Warning: maxIndex $maxIndex >= labels length ${_labels.length}',
        );
        maxIndex = 0;
      }

      final label = _labels[maxIndex];
      final isCancerous = _cancerousLabels.contains(label);
      final description =
          _labelDescriptions[label] ?? 'No description available.';

      debugPrint(
        'Classification result: $label with confidence $maxConfidence',
      );

      return ClassificationResult(
        label: label,
        confidence: maxConfidence,
        isCancerous: isCancerous,
        description: description,
      );
    } catch (e, stackTrace) {
      debugPrint('Error during classification: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  List<List<List<List<double>>>> _imageToInputTensor(
    img.Image image,
    int size,
  ) {
    final input = List.generate(
      1,
      (_) => List.generate(
        size,
        (y) => List.generate(size, (x) {
          final pixel = image.getPixel(x, y);
          return [
            pixel.r.toDouble() / 255.0,
            pixel.g.toDouble() / 255.0,
            pixel.b.toDouble() / 255.0,
          ];
        }),
      ),
    );
    return input;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
