import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract interface class HandPhotoStorage {
  Future<String> persist({
    required String sourcePath,
    required String photoId,
  });

  Future<bool> exists(String path);

  Future<void> delete(String path);
}

class LocalHandPhotoStorage implements HandPhotoStorage {
  LocalHandPhotoStorage({
    Future<Directory> Function()? documentsDirectory,
  }) : _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;

  Future<Directory> _photoDirectory() async {
    final documents = await _documentsDirectory();
    final directory = Directory(p.join(documents.path, 'hand_photos'));
    await directory.create(recursive: true);
    return directory;
  }

  Future<String> _validatedPath(String path) async {
    final directory = await _photoDirectory();
    final root = p.canonicalize(directory.path);
    final candidate = p.canonicalize(path);
    if (!p.isWithin(root, candidate)) {
      throw StateError(
        'Refusing to access a file outside hand photo storage.',
      );
    }
    return candidate;
  }

  @override
  Future<String> persist({
    required String sourcePath,
    required String photoId,
  }) async {
    final directory = await _photoDirectory();
    final target = await _validatedPath(
      p.join(directory.path, '$photoId.jpg'),
    );
    await File(sourcePath).copy(target);
    return target;
  }

  @override
  Future<bool> exists(String path) async {
    return File(await _validatedPath(path)).exists();
  }

  @override
  Future<void> delete(String path) async {
    final file = File(await _validatedPath(path));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
