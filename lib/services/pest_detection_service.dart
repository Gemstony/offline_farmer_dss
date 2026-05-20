// lib/services/pest_detection_service.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_plus/tflite_plus.dart';
import 'package:image/image.dart' as img;
import 'dart:math' as math;

class PestDetectionService {
  static final PestDetectionService _instance =
      PestDetectionService._internal();
  factory PestDetectionService() => _instance;
  PestDetectionService._internal();

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;
  int _outputSize = 10; // default from our Flask model

  Future<void> loadModel() async {
    if (_isInitialized) return;
    _interpreter = await Interpreter.fromAsset(
      'assets/models/plant_disease_model.tflite',
    );
    // Get output shape from interpreter to know number of classes
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    _outputSize = outputShape.last; // e.g., 10 or 38
    await _loadLabels();
    _isInitialized = true;
    print('✅ Model loaded. Output size: $_outputSize');
  }

  Future<void> _loadLabels() async {
    try {
      final String labelsContent = await rootBundle.loadString(
        'assets/labels/labels.txt',
      );
      _labels = labelsContent.trim().split('\n');
      // If labels count doesn't match model output, pad or truncate
      if (_labels.length != _outputSize) {
        print(
          '⚠️ Labels count (${_labels.length}) != model output ($_outputSize). Using generic labels.',
        );
        _labels = List.generate(_outputSize, (i) => 'Class ${i + 1}');
      }
      print('✅ Loaded ${_labels.length} labels');
    } catch (e) {
      print(
        '⚠️ No labels.txt found. Using generic labels for $_outputSize classes.',
      );
      _labels = List.generate(_outputSize, (i) => 'Class ${i + 1}');
    }
  }

  Future<List> _processImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) throw Exception('Could not decode image.');

    // Resize to model's expected input size (224x224)
    img.Image resized = img.copyResize(image, width: 224, height: 224);

    // Create a 4D list: batch=1, height=224, width=224, channels=3
    // All values are integers (0-255)
    List input = List.generate(
      1,
      (_) => List.generate(
        224,
        (_) => List.generate(224, (_) => List.filled(3, 0)),
      ),
    );

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resized.getPixel(x, y);
        input[0][y][x][0] = pixel.r; // red (0-255)
        input[0][y][x][1] = pixel.g; // green
        input[0][y][x][2] = pixel.b; // blue
      }
    }
    return input;
  }

  Future<PestDetectionResult> predict(File imageFile) async {
    if (!_isInitialized) await loadModel();
    try {
      final input = await _processImage(imageFile);
      final output = List.filled(
        1 * _outputSize,
        0.0,
      ).reshape([1, _outputSize]);
      _interpreter!.run(input, output);
      final result = _processOutput(output);
      return result;
    } catch (e) {
      print('Prediction error: $e');
      return PestDetectionResult(
        isSuccess: false,
        message: 'Tatizo la kiufundi: $e',
      );
    }
  }

  PestDetectionResult _processOutput(List output) {
    final rawScores = output[0];
    List<double> logits;
    if (rawScores is List<double>) {
      logits = rawScores;
    } else if (rawScores is List<num>) {
      logits = rawScores.map((e) => e.toDouble()).toList();
    } else if (rawScores is List<int>) {
      logits = rawScores.map((e) => e.toDouble()).toList();
    } else {
      throw Exception('Unexpected output type: ${rawScores.runtimeType}');
    }

    // Apply softmax to convert logits to probabilities
    final probabilities = _softmax(logits);

    double maxConfidence = -1.0;
    int maxIndex = -1;
    for (int i = 0; i < probabilities.length; i++) {
      if (probabilities[i] > maxConfidence) {
        maxConfidence = probabilities[i];
        maxIndex = i;
      }
    }
    final confidencePercent = (maxConfidence * 100).toStringAsFixed(1);
    if (maxIndex >= 0 && maxIndex < _labels.length && maxConfidence > 0.5) {
      // Map generic label to a user‑friendly name
      final displayName = _getDisplayName(_labels[maxIndex]);
      return PestDetectionResult(
        isSuccess: true,
        pestName: _labels[maxIndex],
        confidence: maxConfidence,
        message: 'Ugonjwa unaowezekana: $displayName ($confidencePercent%)',
      );
    } else {
      return PestDetectionResult(
        isSuccess: false,
        message: 'Hakuna ugonjwa uliotambuliwa kwa uhakika wa kutosha.',
      );
    }
  }

  // Softmax function
List<double> _softmax(List<double> logits) {
  final double maxLogit =
      logits.reduce((a, b) => a > b ? a : b);

  final List<double> expValues = logits
      .map((x) => math.exp(x - maxLogit))
      .toList();

  final double sumExp =
      expValues.reduce((a, b) => a + b);

  return expValues
      .map((x) => x / sumExp)
      .toList();
}
  String _getDisplayName(String genericLabel) {
    final Map<String, String> displayNames = {
      'apple_diseased': 'Apple Scab or Black Rot',
      'apple_healthy': 'Apple (Healthy)',
      'corn_diseased': 'Corn (Common Rust, Blight, etc.)',
      'corn_healthy': 'Corn (Healthy)',
      'grape_diseased': 'Grape (Black Rot, Esca, etc.)',
      'grape_healthy': 'Grape (Healthy)',
      'sugarcane_diseased': 'Sugarcane (Red Rot, Smut)',
      'sugarcane_healthy': 'Sugarcane (Healthy)',
      'wheat_diseased': 'Wheat (Leaf Rust, Stripe Rust)',
      'wheat_healthy': 'Wheat (Healthy)',
    };
    return displayNames[genericLabel] ?? genericLabel;
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}

class PestDetectionResult {
  final bool isSuccess;
  final String? pestName;
  final double? confidence;
  final String message;
  PestDetectionResult({
    required this.isSuccess,
    this.pestName,
    this.confidence,
    required this.message,
  });
}
