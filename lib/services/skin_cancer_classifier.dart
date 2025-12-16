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
  static const String _modelAssetBackup =
      'lib/ai/skin_cancer_model_ready.tflite';
  static const String _labelsAsset = 'lib/ai/labels_cancer.txt';

  // Fixed model input size: 299x299x3
  static const int _inputSize = 299;

  // Configurable threshold for binary classification
  // Values below threshold = Benign, above = Malignant
  static const double _malignantThreshold = 0.3;

  Interpreter? _interpreter;
  List<String> _labels = [];

  // Descriptions for binary classification
  static const Map<String, String> _labelDescriptions = {
    'Benign':
        'The lesion appears to be benign (non-cancerous). However, continue to monitor for any changes in size, shape, or color.',
    'Malignant':
        'The lesion shows characteristics that may indicate malignancy. Please consult a dermatologist for professional evaluation as soon as possible.',
  };

  bool get isReady => _interpreter != null && _labels.isNotEmpty;

  Future<bool> initialize() async {
    try {
      // Load labels
      final labelsData = await rootBundle.loadString(_labelsAsset);
      _labels = labelsData
          .split('\n')
          .map((e) => e.trim().replaceAll('\r', ''))
          .where((e) => e.isNotEmpty)
          .toList();

      // Load model from assets to temp file
      final modelFile = await _loadModelFile();

      // Create interpreter with multi-threading
      final options = InterpreterOptions()..threads = 4;

      try {
        _interpreter = Interpreter.fromFile(modelFile, options: options);
      } catch (e) {
        // Fallback: try without options
        try {
          _interpreter = Interpreter.fromFile(modelFile);
        } catch (e2) {
          // Last resort: load from buffer
          final modelBytes = await modelFile.readAsBytes();
          _interpreter = Interpreter.fromBuffer(modelBytes);
        }
      }

      _interpreter!.allocateTensors();
      debugPrint('SkinCancerClassifier initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Error initializing classifier: $e');
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
      // Read and decode image
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        debugPrint('Failed to decode image');
        return null;
      }

      // Preprocess image: resize to 299x299
      final resizedImage = img.copyResize(
        image,
        width: _inputSize,
        height: _inputSize,
        interpolation: img.Interpolation.linear,
      );

      // Create input as 4D List matching [1, 299, 299, 3]
      var input = List.generate(
        1,
        (b) => List.generate(
          _inputSize,
          (y) => List.generate(_inputSize, (x) {
            final pixel = resizedImage.getPixel(x, y);
            return <double>[
              pixel.r.toDouble() / 255.0,
              pixel.g.toDouble() / 255.0,
              pixel.b.toDouble() / 255.0,
            ];
          }),
        ),
      );

      // Create output buffer matching [1, 1]
      var output = List.generate(1, (_) => List.filled(1, 0.0));

      // Run inference
      _interpreter!.run(input, output);

      // Get the sigmoid probability from output
      final double probability = output[0][0];

      // Apply threshold for binary classification
      final bool isMalignant = probability >= _malignantThreshold;
      final String label = isMalignant ? 'Malignant' : 'Benign';

      // Confidence is the probability for the predicted class
      final double confidence = isMalignant ? probability : (1.0 - probability);

      final description =
          _labelDescriptions[label] ?? 'No description available.';

      return ClassificationResult(
        label: label,
        confidence: confidence,
        isCancerous: isMalignant,
        description: description,
      );
    } catch (e) {
      debugPrint('Error during classification: $e');
      return null;
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
