import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

@immutable
class CapturedHandPhoto {
  const CapturedHandPhoto({
    required this.clientPhotoId,
    required this.localPath,
    required this.capturedAt,
  });

  final String clientPhotoId;
  final String localPath;
  final DateTime capturedAt;
}

abstract interface class HandPhotoService {
  Future<CapturedHandPhoto?> captureWinningHandPhoto();
}

class ImagePickerHandPhotoService implements HandPhotoService {
  ImagePickerHandPhotoService({
    ImagePicker? picker,
    String Function()? newPhotoId,
    DateTime Function()? now,
  })  : _picker = picker ?? ImagePicker(),
        _newPhotoId = newPhotoId ?? const Uuid().v4,
        _now = now ?? DateTime.now;

  final ImagePicker _picker;
  final String Function() _newPhotoId;
  final DateTime Function() _now;

  @override
  Future<CapturedHandPhoto?> captureWinningHandPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked == null) {
      return null;
    }

    final clientPhotoId = _newPhotoId();
    final capturedAt = _now().toUtc();
    final directory = await getApplicationDocumentsDirectory();
    final photoDirectory = Directory(p.join(directory.path, 'hand_photos'));
    await photoDirectory.create(recursive: true);
    final targetPath = p.join(photoDirectory.path, '$clientPhotoId.jpg');
    await File(picked.path).copy(targetPath);

    return CapturedHandPhoto(
      clientPhotoId: clientPhotoId,
      localPath: targetPath,
      capturedAt: capturedAt,
    );
  }
}
