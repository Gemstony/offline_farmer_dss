// lib/services/pest_detection_service.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_plus/tflite_plus.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';

class PestDetectionService {
  static final PestDetectionService _instance =
      PestDetectionService._internal();
  factory PestDetectionService() => _instance;
  PestDetectionService._internal();

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;
  int _outputSize = 12;
  Map<String, dynamic>? _recommendations;

  // Hardcoded fallback (used only if JSON file cannot be loaded)
  static final Map<String, dynamic> _fallbackRecommendations = {
    "maize_ET": {
      "symptoms":
          "Madoa makubwa ya kijivu-kahawia kwenye majani, yenye umbo la spindle.",
      "action":
          "Ondoa majani yaliyoathirika, pulizia Propiconazole au Mancozeb.",
      "prevention": "Panda mbegu sugu (ET resistant), fanya mzunguko wa mazao.",
    },
    "maize_MLN": {
      "symptoms":
          "Majani ya juu yana mistari ya njano na kijani, mmea hudumaa na kuufa.",
      "action":
          "Ng'oa na teketeza mimea iliyoathirika, pulizia dawa ya wadudu (Imidacloprid) kudhibiti wadudu wanaoeneza virusi.",
      "prevention":
          "Panda aina zinazostahimili MLN, panda kwa wakati mmoja na majirani.",
    },
    "maize_MSV": {
      "symptoms": "Mistari ya njayo-nyeupe kwenye majani, mmea hudumaa.",
      "action": "Ng'oa mimea iliyoathirika, pulizia dawa dhidi ya leafhoppers.",
      "prevention":
          "Panda mbegu sugu (MSV tolerant), tibu mbegu kwa dawa ya wadudu.",
    },
    "maize_healthy": {
      "symptoms": "Mmea una afya nzuri, majani ya kijani kibichi bila madoa.",
      "action": "Endelea na ulinzi mzuri, palilia na umwagilie vizuri.",
      "prevention": "Endelea na mzunguko wa mazao na matumizi ya mbegu bora.",
    },
    "rice": {
      "symptoms":
          "Madoa ya kahawia kwenye majani yenye katikati nyeupe (Brown Spot).",
      "action":
          "Pulizia Mancozeb au Propiconazole, ongeza mbolea ya potassium.",
      "prevention":
          "Loweka mbegu katika maji ya chumvi kabla ya kupanda, tumia mbolea kamili.",
    },
    "rice_blast": {
      "symptoms":
          "Madoa yenye umbo la jicho la samaki kwenye majani, shingo ya mawimbi inaoza.",
      "action":
          "Pulizia Tricyclazole au Isoprothiolane mara moja, punguza mbolea ya nitrogen.",
      "prevention":
          "Panda aina zinazostahimili blast (SARO 5, IR64), tibu mbegu.",
    },
    "rice_healthy": {
      "symptoms": "Mpunga una afya nzuri, majani ya kijani, mawimbi makubwa.",
      "action": "Endelea kumwagilia vizuri, angalia wadudu mara kwa mara.",
      "prevention":
          "Fuatilia shamba, tumia mbegu za mseto, fanya mzunguko wa mazao.",
    },
    "rice_insect": {
      "symptoms":
          "Majani yamekunjwa, mawimbi meupe, au wadudu wadogo kahawia chini ya mmea.",
      "action":
          "Tambua aina ya wadudu, pulizia Chlorpyrifos, Cartap, au Imidacloprid kwa usahihi.",
      "prevention":
          "Panda kwa wakati mmoja, tibu mbegu, dumisha wadudu wa asili.",
    },
    "rice_leaf_scald": {
      "symptoms":
          "Ncha na kingo za majani zinaonekana kama zimeungua, mipaka ya wavy.",
      "action":
          "Pulizia Propiconazole au Azoxystrobin, punguza unyevu shambani.",
      "prevention": "Panda kwa nafasi sahihi, epuka mbolea nyingi ya nitrogen.",
    },
    "rice_leaffolder": {
      "symptoms":
          "Majani yamekunjwa kwa urefu kama mrija, kiwavi wa kijani ndani.",
      "action":
          "Pulizia Cartap hydrochloride au Chlorpyrifos, ondoa majani yaliyokunjwa kwa mkono.",
      "prevention": "Weka mitego ya mwanga, panda aina zenye majani magumu.",
    },
    "rice_stripes": {
      "symptoms": "Mistari ya njano isiyo wazi kwenye majani, mmea hudumaa.",
      "action":
          "Udhibiti wadudu Small Brown Planthopper (Imidacloprid), ng'oa mimea iliyoathirika.",
      "prevention":
          "Panda aina zinazostahimili RSV, tibu mbegu, palilia magugu.",
    },
    "rice_tungro": {
      "symptoms": "Mmea unageuka njano-machungwa, hudumaa, matawi mengi.",
      "action":
          "Pulizia Imidacloprid au Thiamethoxam kuua Green Leafhoppers, ng'oa mimea iliyoathirika.",
      "prevention":
          "Panda aina zinazostahimili Tungro (IR36, IR64), panda kwa wakati mmoja.",
    },
  };

  Future<void> loadModel() async {
    if (_isInitialized) return;
    _interpreter = await Interpreter.fromAsset(
      'assets/models/crop_disease_model.tflite',
    );
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    _outputSize = outputShape.last;
    await _loadLabels();
    await _loadRecommendations();
    _isInitialized = true;
    print('✅ Model loaded. Output size: $_outputSize');
  }

  Future<void> _loadLabels() async {
    try {
      final String labelsContent = await rootBundle.loadString(
        'assets/labels/labels.txt',
      );
      _labels = labelsContent.trim().split('\n');
      if (_labels.length != _outputSize) {
        _labels = List.generate(_outputSize, (i) => 'Class ${i + 1}');
      }
      print('✅ Loaded ${_labels.length} labels');
    } catch (e) {
      print('⚠️ No labels.txt found. Using generic labels.');
      _labels = List.generate(_outputSize, (i) => 'Class ${i + 1}');
    }
  }

  Future<void> _loadRecommendations() async {
    bool loadedFromFile = false;
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/recommendations.json',
      );
      final rawMap = json.decode(jsonString) as Map<String, dynamic>;

      // Normalize keys: trim whitespace and convert to lowercase
      _recommendations = {};
      rawMap.forEach((key, value) {
        final normalizedKey = key.trim().toLowerCase();
        _recommendations![normalizedKey] = value;
      });

      print('✅ Loaded ${_recommendations!.length} recommendations from file.');
      print('   Keys in file: ${_recommendations!.keys.toList()}');
      loadedFromFile = true;
    } catch (e) {
      print('❌ Failed to load recommendations.json: $e');
    }

    if (!loadedFromFile) {
      print('⚠️ Using hardcoded fallback recommendations.');
      _recommendations = _fallbackRecommendations;
    }

    // Now check each label and fill missing ones with generic fallback
    for (var label in _labels) {
      // Normalize label as well
      final normalizedLabel = label.trim().toLowerCase();
      if (!_recommendations!.containsKey(normalizedLabel)) {
        print(
          '⚠️ Missing recommendation for $normalizedLabel – using generic fallback.',
        );
        _recommendations![normalizedLabel] = {
          "symptoms": "Hakuna maelezo maalum.",
          "action": "Wasiliana na mtaalam wa kilimo.",
          "prevention": "Fuatilia shamba lako mara kwa mara.",
        };
      }
    }
  }

  Future<List> _processImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) throw Exception('Could not decode image.');
    img.Image resized = img.copyResize(image, width: 224, height: 224);

    List input = List.generate(
      1,
      (_) => List.generate(
        224,
        (_) => List.generate(224, (_) => List.filled(3, 0.0)),
      ),
    );
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resized.getPixel(x, y);
        input[0][y][x][0] = pixel.r / 255.0;
        input[0][y][x][1] = pixel.g / 255.0;
        input[0][y][x][2] = pixel.b / 255.0;
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

      final rawScores = output[0];
      List<double> scores;
      if (rawScores is List<double>) {
        scores = rawScores;
      } else if (rawScores is List<num>) {
        scores = rawScores.map((e) => e.toDouble()).toList();
      } else {
        throw Exception('Unexpected output type: ${rawScores.runtimeType}');
      }

      double maxConfidence = -1.0;
      int maxIndex = -1;
      for (int i = 0; i < scores.length; i++) {
        if (scores[i] > maxConfidence) {
          maxConfidence = scores[i];
          maxIndex = i;
        }
      }
      const double threshold = 0.75;

      if (maxConfidence >= threshold && maxIndex < _labels.length) {
        final advice = _getRecommendation(_labels[maxIndex]);
        return PestDetectionResult(
          isSuccess: true,
          pestName: _labels[maxIndex],
          confidence: maxConfidence,
          message:
              'Ugonjwa: ${_getDisplayName(_labels[maxIndex])} (${(maxConfidence * 100).toStringAsFixed(1)}%)',
          advice: advice,
          alternatives: [],
        );
      } else {
        List<int> indices = List.generate(scores.length, (i) => i);
        indices.sort((a, b) => scores[b].compareTo(scores[a]));
        final alternatives = indices
            .take(3)
            .map(
              (idx) => AlternativeClass(
                name: _labels[idx],
                displayName: _getDisplayName(_labels[idx]),
                confidence: scores[idx],
              ),
            )
            .toList();
        return PestDetectionResult(
          isSuccess: false,
          message: 'Uhakika wa chini. Chagua ugonjwa unaofanana:',
          alternatives: alternatives,
        );
      }
    } catch (e) {
      print('Prediction error: $e');
      return PestDetectionResult(
        isSuccess: false,
        message: 'Tatizo la kiufundi: $e',
        alternatives: [],
      );
    }
  }

  String _getRecommendation(String key) {
    final normalizedKey = key.trim().toLowerCase();
    if (_recommendations == null) return 'Wasiliana na mtaalam wa kilimo.';
    final rec = _recommendations![normalizedKey];
    if (rec == null) return 'Wasiliana na mtaalam wa kilimo.';
    return '📋 Dalili: ${rec['symptoms'] ?? '-'}\n💊 Kitendo: ${rec['action'] ?? '-'}\n🛡️ Kinga: ${rec['prevention'] ?? '-'}';
  }

  /// Public method for manual selection – returns advice for a given class name
  Future<String> getAdviceForClass(String className) async {
    if (!_isInitialized) await loadModel();
    return _getRecommendation(className);
  }

  String _getDisplayName(String generic) {
    final names = {
      'maize_ET': 'Maize Ear Rot',
      'maize_MLN': 'Maize Lethal Necrosis',
      'maize_MSV': 'Maize Streak Virus',
      'maize_healthy': 'Maize (Healthy)',
      'rice': 'Rice Brown Spot',
      'rice_blast': 'Rice Blast',
      'rice_healthy': 'Rice (Healthy)',
      'rice_insect': 'Rice Insect Damage',
      'rice_leaf_scald': 'Rice Leaf Scald',
      'rice_leaffolder': 'Rice Leaffolder',
      'rice_stripes': 'Rice Stripe Virus',
      'rice_tungro': 'Rice Tungro',
    };
    return names[generic] ?? generic;
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}

class AlternativeClass {
  final String name;
  final String displayName;
  final double confidence;
  AlternativeClass({
    required this.name,
    required this.displayName,
    required this.confidence,
  });
}

class PestDetectionResult {
  final bool isSuccess;
  final String? pestName;
  final double? confidence;
  final String message;
  final String? advice;
  final List<AlternativeClass> alternatives;
  PestDetectionResult({
    required this.isSuccess,
    this.pestName,
    this.confidence,
    required this.message,
    this.advice,
    this.alternatives = const [],
  });
}
