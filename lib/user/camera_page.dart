import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'detection_carousel_screen.dart';

class CameraPage extends StatefulWidget {
  final String? initialPhoto;
  const CameraPage({Key? key, this.initialPhoto}) : super(key: key);

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final ImagePicker _picker = ImagePicker();
  late List<String> _capturedImages;
  bool _isProcessing = false;
  int _processedImages = 0;

  @override
  void initState() {
    super.initState();
    _capturedImages = widget.initialPhoto != null ? [widget.initialPhoto!] : [];
  }

  Future<void> _takePicture() async {
    if (_capturedImages.length >= 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Maximum 5 photos allowed')));
      return;
    }

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null) {
        setState(() {
          _capturedImages.add(photo.path);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Photo ${_capturedImages.length}/5 saved - ${_capturedImages.length < 5 ? "Take ${5 - _capturedImages.length} more or " : ""}press Process',
            ),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: 80, left: 16, right: 16),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  Future<void> _processPhotos() async {
    if (_capturedImages.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _processedImages = 0;
    });

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => DetectionCarouselScreen(
              imagePaths: _capturedImages,
              onProgressUpdate: (progress) {
                setState(() {
                  _processedImages = progress;
                });
              },
            ),
      ),
    );

    setState(() {
      _capturedImages.clear();
      _isProcessing = false;
    });
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _capturedImages.length,
      itemBuilder: (context, index) {
        // Photo preview
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_capturedImages[index]),
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _capturedImages.removeAt(index);
                    });
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Photos'),
        backgroundColor: Colors.green,
        actions: [
          if (_capturedImages.length < 5)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextButton.icon(
                onPressed: _takePicture,
                icon: const Icon(Icons.add_a_photo, color: Colors.green),
                label: Text(
                  'Add Photo (${_capturedImages.length}/5)',
                  style: const TextStyle(color: Colors.green),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _capturedImages.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 64,
                            color: Colors.green[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No photos taken yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    )
                    : _buildPhotoGrid(),
          ),
          if (_capturedImages.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _processPhotos,
                icon: const Icon(Icons.analytics),
                label: Text(
                  'Analyze ${_capturedImages.length} Photo${_capturedImages.length > 1 ? 's' : ''}',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
