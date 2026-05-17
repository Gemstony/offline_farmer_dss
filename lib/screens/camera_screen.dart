import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  File? _capturedImage;
  bool _isProcessing = false;
  String _resultMessage = '';
  final ImagePicker _picker = ImagePicker();

  Future<void> _takePicture() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (photo != null) {
        // Save to a permanent local file to avoid temp deletion
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'pest_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = path.join(appDir.path, fileName);
        final savedFile = await File(photo.path).copy(savedPath);
        setState(() {
          _capturedImage = savedFile;
          _resultMessage = '';
        });
        // Simulate AI processing (placeholder for future model)
        _simulatePestDetection();
      }
    } catch (e) {
      _showError('Failed to take picture: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'pest_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = path.join(appDir.path, fileName);
        final savedFile = await File(image.path).copy(savedPath);
        setState(() {
          _capturedImage = savedFile;
          _resultMessage = '';
        });
        _simulatePestDetection();
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  void _simulatePestDetection() {
    setState(() {
      _isProcessing = true;
      _resultMessage = '';
    });
    // Simulate AI processing delay
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        _isProcessing = false;
        // Placeholder message until AI model is integrated
        _resultMessage = '🔍 AI model not yet integrated.\n\nThis feature will identify pests and diseases from the image once the TensorFlow Lite model is added.';
      });
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _clearImage() {
    setState(() {
      _capturedImage = null;
      _resultMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tambua Wadudu / Magonjwa'),
        backgroundColor: Colors.green,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade50, Colors.green.shade100],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: _capturedImage == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 80, color: Colors.green.shade700),
                          SizedBox(height: 16),
                          Text(
                            'Picha itaonekana hapa',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Chukua picha au chagua kutoka kwenye nyaraka',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: Image.file(
                            _capturedImage!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, size: 64, color: Colors.red),
                                    Text('Image could not be loaded'),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        if (_isProcessing)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                CircularProgressIndicator(color: Colors.green),
                                SizedBox(height: 8),
                                Text('Inachanganua picha...'),
                              ],
                            ),
                          ),
                        if (_resultMessage.isNotEmpty && !_isProcessing)
                          Container(
                            margin: EdgeInsets.all(16),
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: Colors.grey.shade300, blurRadius: 4)
                              ],
                            ),
                            child: Text(
                              _resultMessage,
                              style: TextStyle(fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
            ),
            Container(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _capturedImage != null ? _clearImage : null,
                    icon: Icon(Icons.delete),
                    label: Text('Futa'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _takePicture,
                    icon: Icon(Icons.camera),
                    label: Text('Chukua Picha'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: Icon(Icons.photo_library),
                    label: Text('Kutoka Nyaraka'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
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
}