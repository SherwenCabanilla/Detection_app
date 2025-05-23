import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

/// Saves the picked image to the app's documents directory and returns the new file path.
Future<String> saveImagePermanently(XFile image) async {
  final directory = await getApplicationDocumentsDirectory();
  final name = image.name;
  final newImage = await File(image.path).copy('${directory.path}/$name');
  return newImage.path;
}
