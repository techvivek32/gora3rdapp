import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Ask whether to use the CAMERA or the GALLERY, then pick that image.
///
/// Every document upload in the app used to call `pickImage(source: gallery)`
/// directly, so a user photographing their Aadhaar or licence had to leave the
/// app, open the camera, take the shot and come back — the camera was simply
/// never offered. Driver KYC, account registration and the garage forms all go
/// through here now, so the choice looks the same everywhere.
///
/// Returns the picked file, or null when the sheet is dismissed or the pick is
/// cancelled. Permission failures are reported here rather than at each call
/// site, because the handling would be identical in all of them.
Future<XFile?> pickImageFromCameraOrGallery(
  BuildContext context, {
  double? maxWidth,
  int imageQuality = 80,
  String title = 'Add photo',
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Camera first: for a document the user is holding, it is the one they
          // want, and the gallery was the only option for far too long.
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined, color: Color(0xFFF97316)),
            title: const Text('Take Photo'),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: Color(0xFFF97316)),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (source == null) return null;

  try {
    return await ImagePicker().pickImage(
      source: source,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
    );
  } catch (_) {
    // Thrown when the camera permission is denied for good, or the device has
    // no camera at all. Say so instead of looking like the tap did nothing.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'Camera is not available. Allow camera access in Settings, or choose from the gallery.'
                : 'Could not open the gallery. Allow photo access in Settings.',
          ),
        ),
      );
    }
    return null;
  }
}
