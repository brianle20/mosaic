import 'package:image_picker/image_picker.dart';
import 'package:meta/meta.dart';
import 'package:mosaic/services/media/hand_photo_storage.dart';
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
    HandPhotoStorage? storage,
    String Function()? newPhotoId,
    DateTime Function()? now,
  })  : _picker = picker ?? ImagePicker(),
        _storage = storage ?? LocalHandPhotoStorage(),
        _newPhotoId = newPhotoId ?? const Uuid().v4,
        _now = now ?? DateTime.now;

  final ImagePicker _picker;
  final HandPhotoStorage _storage;
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
    final targetPath = await _storage.persist(
      sourcePath: picked.path,
      photoId: clientPhotoId,
    );

    return CapturedHandPhoto(
      clientPhotoId: clientPhotoId,
      localPath: targetPath,
      capturedAt: capturedAt,
    );
  }
}
