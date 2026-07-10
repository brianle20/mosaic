import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/services/media/hand_photo_storage.dart';
import 'package:path/path.dart' as p;

void main() {
  test('storage persists, finds, and deletes an app-owned photo', () async {
    final root = await Directory.systemTemp.createTemp('mosaic-photo-test');
    addTearDown(() => root.delete(recursive: true));
    final source = File(p.join(root.path, 'source.png'));
    await source.writeAsBytes([1, 2, 3]);
    final storage = LocalHandPhotoStorage(
      documentsDirectory: () async => root,
    );

    final path = await storage.persist(
      sourcePath: source.path,
      photoId: 'photo_01',
    );

    expect(path, p.join(root.path, 'hand_photos', 'photo_01.jpg'));
    expect(await storage.exists(path), isTrue);
    expect(await File(path).readAsBytes(), [1, 2, 3]);

    await storage.delete(path);

    expect(await storage.exists(path), isFalse);
  });

  test('storage refuses to delete a path outside hand_photos', () async {
    final root = await Directory.systemTemp.createTemp('mosaic-photo-test');
    addTearDown(() => root.delete(recursive: true));
    final storage = LocalHandPhotoStorage(
      documentsDirectory: () async => root,
    );
    final outside = File(p.join(root.parent.path, 'outside.jpg'));
    addTearDown(() async {
      if (await outside.exists()) {
        await outside.delete();
      }
    });
    await outside.writeAsBytes([1]);

    await expectLater(storage.delete(outside.path), throwsA(isA<StateError>()));
    expect(await outside.exists(), isTrue);
  });

  test('storage refuses a photo id that escapes hand_photos', () async {
    final root = await Directory.systemTemp.createTemp('mosaic-photo-test');
    addTearDown(() => root.delete(recursive: true));
    final source = File(p.join(root.path, 'source.jpg'));
    await source.writeAsBytes([1]);
    final storage = LocalHandPhotoStorage(
      documentsDirectory: () async => root,
    );

    await expectLater(
      storage.persist(sourcePath: source.path, photoId: '../outside'),
      throwsA(isA<StateError>()),
    );
    expect(await File(p.join(root.path, 'outside.jpg')).exists(), isFalse);
  });
}
