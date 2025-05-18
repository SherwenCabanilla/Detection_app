import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'detection_carousel_screen.dart';
import 'camera_page.dart';

class ScanPage extends StatelessWidget {
  const ScanPage({Key? key}) : super(key: key);

  Future<void> _takePicture(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (photo != null) {
      // Navigate to camera page with the first photo
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraPage(initialPhoto: photo.path),
        ),
      );
    }
  }

  Future<void> _selectFromGallery(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? images = await picker.pickMultiImage();
    if (images != null && images.isNotEmpty) {
      if (images.length > 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 5 images can be selected'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => DetectionCarouselScreen(
                imagePaths: images.map((img) => img.path).toList(),
              ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Scan',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Icon(Icons.document_scanner, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _takePicture(context),
              icon: const Icon(Icons.camera_alt, size: 32),
              label: const Text('Take Photo', style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _selectFromGallery(context),
              icon: const Icon(Icons.photo_library, size: 32),
              label: const Text(
                'Select from Gallery',
                style: TextStyle(fontSize: 20),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green,
                side: const BorderSide(color: Colors.green, width: 2),
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
