import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CustomCameraController {
  CameraController? _controller;
  bool _isInitialized = false;
  final Function(String) onImageCaptured;
  final Function() onError;

  CustomCameraController({
    required this.onImageCaptured,
    required this.onError,
  });

  bool get isInitialized => _isInitialized;
  CameraController? get controller => _controller;

  Future<void> initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        onError();
        return;
      }

      _controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      onError();
    }
  }

  Future<void> captureImage() async {
    if (!_isInitialized || _controller == null) {
      onError();
      return;
    }

    try {
      final image = await _controller!.takePicture();
      onImageCaptured(image.path);
    } catch (e) {
      debugPrint('Error capturing image: $e');
      onError();
    }
  }

  Future<void> dispose() async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
      _isInitialized = false;
    }
  }
}
