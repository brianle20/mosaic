import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/features/scoring/widgets/hand_photo_preview.dart';

void main() {
  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets('pinch zoom changes transform and re-center restores identity',
      (tester) async {
    final provider = await _readyProvider(tester, 'pinch-photo');
    await tester.pumpWidget(
      _previewHarness(photoId: 'photo_01', photoImage: provider),
    );
    await tester.pumpAndSettle();

    final viewerFinder = find.byKey(HandPhotoPreview.interactiveViewerKey);
    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    final controller = viewer.transformationController!;
    expect(
      controller.value.storage,
      orderedEquals(Matrix4.identity().storage),
    );

    final center = tester.getCenter(viewerFinder);
    final first = await tester.startGesture(
      center - const Offset(20, 0),
      pointer: 1,
    );
    final second = await tester.startGesture(
      center + const Offset(20, 0),
      pointer: 2,
    );
    await tester.pump();
    await first.moveTo(center - const Offset(55, 0));
    await second.moveTo(center + const Offset(55, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    expect(
      controller.value.storage,
      isNot(orderedEquals(Matrix4.identity().storage)),
    );

    await tester.tap(find.byKey(HandPhotoPreview.recenterKey));
    await tester.pump();

    expect(
      controller.value.storage,
      orderedEquals(Matrix4.identity().storage),
    );
  });

  testWidgets('one-finger pan changes transform while photo is zoomed',
      (tester) async {
    final provider = await _readyProvider(tester, 'pan-photo');
    await tester.pumpWidget(
      _previewHarness(photoId: 'photo_01', photoImage: provider),
    );
    await tester.pumpAndSettle();

    final viewerFinder = find.byKey(HandPhotoPreview.interactiveViewerKey);
    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    final controller = viewer.transformationController!;
    controller.value = Matrix4.identity()..scaleByDouble(2.0, 2.0, 2.0, 1.0);
    final zoomedTransform = List<double>.of(controller.value.storage);
    await tester.pump();

    await tester.drag(viewerFinder, const Offset(-40, -20));
    await tester.pump();

    expect(controller.value.storage, isNot(orderedEquals(zoomedTransform)));
  });

  testWidgets('changing photo resets preview transform', (tester) async {
    final provider = await _readyProvider(tester, 'changing-photo');
    await tester.pumpWidget(
      _previewHarness(photoId: 'photo_01', photoImage: provider),
    );
    await tester.pumpAndSettle();

    final viewerFinder = find.byKey(HandPhotoPreview.interactiveViewerKey);
    final initialViewer = tester.widget<InteractiveViewer>(viewerFinder);
    initialViewer.transformationController!.value = Matrix4.identity()
      ..scaleByDouble(2.0, 2.0, 2.0, 1.0);
    await tester.pump();

    await tester.pumpWidget(
      _previewHarness(photoId: 'photo_02', photoImage: provider),
    );
    await tester.pump();

    final updatedViewer = tester.widget<InteractiveViewer>(viewerFinder);
    expect(
      updatedViewer.transformationController!.value.storage,
      orderedEquals(Matrix4.identity().storage),
    );
  });

  testWidgets('changing only the provider resets preview transform',
      (tester) async {
    final firstProvider = await _readyProvider(tester, 'first-provider');
    final replacementProvider = await _readyProvider(
      tester,
      'replacement-provider-reset',
    );
    await tester.pumpWidget(
      _previewHarness(photoId: 'photo_01', photoImage: firstProvider),
    );
    await tester.pumpAndSettle();

    final viewerFinder = find.byKey(HandPhotoPreview.interactiveViewerKey);
    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    final controller = viewer.transformationController!;
    controller.value = Matrix4.identity()..scaleByDouble(2.0, 2.0, 2.0, 1.0);
    await tester.pump();

    await tester.pumpWidget(
      _previewHarness(photoId: 'photo_01', photoImage: replacementProvider),
    );
    await tester.pumpAndSettle();

    expect(
      controller.value.storage,
      orderedEquals(Matrix4.identity().storage),
    );
  });

  testWidgets('equal provider rebuild preserves preview transform',
      (tester) async {
    final firstProvider = await _readyProvider(tester, 'equal-provider');
    final equalProvider = _ControlledImageProvider('equal-provider');
    expect(equalProvider, firstProvider);
    await tester.pumpWidget(
      _previewHarness(photoId: 'photo_01', photoImage: firstProvider),
    );
    await tester.pumpAndSettle();

    final viewerFinder = find.byKey(HandPhotoPreview.interactiveViewerKey);
    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    final controller = viewer.transformationController!;
    controller.value = Matrix4.identity()..scaleByDouble(2.0, 2.0, 2.0, 1.0);
    final zoomedTransform = List<double>.of(controller.value.storage);
    await tester.pump();

    await tester.pumpWidget(
      _previewHarness(photoId: 'photo_01', photoImage: equalProvider),
    );
    await tester.pumpAndSettle();

    expect(controller.value.storage, orderedEquals(zoomedTransform));
  });

  testWidgets('hides controls until the provider emits a decoded frame',
      (tester) async {
    final provider = _ControlledImageProvider('delayed-ready');
    await tester.pumpWidget(
      _previewHarness(photoId: 'photo_01', photoImage: provider),
    );
    await tester.pump();

    expect(find.text('Loading photo'), findsOneWidget);
    expect(find.byKey(HandPhotoPreview.interactiveViewerKey), findsNothing);
    expect(find.byKey(HandPhotoPreview.recenterKey), findsNothing);
    expect(find.byKey(HandPhotoPreview.expandKey), findsNothing);

    final image = await tester.runAsync(createTestImage);
    provider.complete(ImageInfo(image: image!));
    await tester.pumpAndSettle();

    expect(find.text('Loading photo'), findsNothing);
    expect(find.byKey(HandPhotoPreview.interactiveViewerKey), findsOneWidget);
    expect(find.byKey(HandPhotoPreview.recenterKey), findsOneWidget);
    expect(find.byKey(HandPhotoPreview.expandKey), findsOneWidget);
  });

  testWidgets('shows the active provider decode error and hides controls',
      (tester) async {
    final provider = _ControlledImageProvider('decode-error');
    await tester.pumpWidget(
      _previewHarness(photoId: 'photo_01', photoImage: provider),
    );
    await tester.pump();

    provider.fail(StateError('decode failed for photo_01'));
    await tester.pumpAndSettle();

    expect(find.text('Photo could not be loaded'), findsOneWidget);
    expect(find.textContaining('decode failed for photo_01'), findsOneWidget);
    expect(find.byKey(HandPhotoPreview.recenterKey), findsNothing);
    expect(find.byKey(HandPhotoPreview.expandKey), findsNothing);
  });

  testWidgets('ignores a stale provider failure after photo replacement',
      (tester) async {
    final previousFlutterErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('stale decode failure')) {
        return;
      }
      previousFlutterErrorHandler?.call(details);
    };
    addTearDown(() {
      FlutterError.onError = previousFlutterErrorHandler;
    });
    final staleProvider = _ControlledImageProvider('stale-provider');
    final replacementProvider = _ControlledImageProvider(
      'replacement-provider',
    );
    await tester.pumpWidget(
      _previewHarness(photoId: 'photo_01', photoImage: staleProvider),
    );
    await tester.pump();

    await tester.pumpWidget(
      _previewHarness(
        photoId: 'photo_02',
        photoImage: replacementProvider,
      ),
    );
    staleProvider.fail(StateError('stale decode failure'));
    await tester.pump();

    expect(find.text('Loading photo'), findsOneWidget);
    expect(find.text('Photo could not be loaded'), findsNothing);
    expect(find.byKey(HandPhotoPreview.recenterKey), findsNothing);
    expect(find.byKey(HandPhotoPreview.expandKey), findsNothing);

    final image = await tester.runAsync(createTestImage);
    replacementProvider.complete(ImageInfo(image: image!));
    await tester.pumpAndSettle();

    expect(find.text('Photo could not be loaded'), findsNothing);
    expect(find.byKey(HandPhotoPreview.recenterKey), findsOneWidget);
    expect(find.byKey(HandPhotoPreview.expandKey), findsOneWidget);
  });

  testWidgets(
      'disposes readiness image clones for active duplicate stale and unmounted callbacks',
      (tester) async {
    final sourceImage = await tester.runAsync(createTestImage);
    final sourceInfo = ImageInfo(image: sourceImage!);
    final deliveredInfos = <ImageInfo>[];
    addTearDown(() {
      for (final imageInfo in deliveredInfos) {
        if (!imageInfo.image.debugDisposed) {
          imageInfo.dispose();
        }
      }
      if (!sourceInfo.image.debugDisposed) {
        sourceInfo.dispose();
      }
    });

    final provider = _TrackingImageProvider('disposal-active');
    await tester.pumpWidget(
      _previewHarness(photoId: 'photo_01', photoImage: provider),
    );
    await tester.pump();
    final readinessListener = provider.completer.addedListeners.single;

    deliveredInfos.add(
      provider.completer.deliver(readinessListener, sourceInfo),
    );
    await tester.pump();
    deliveredInfos.add(
      provider.completer.deliver(readinessListener, sourceInfo),
    );

    final replacementProvider = _TrackingImageProvider('disposal-stale');
    await tester.pumpWidget(
      _previewHarness(
        photoId: 'photo_02',
        photoImage: replacementProvider,
      ),
    );
    await tester.pump();
    deliveredInfos.add(
      provider.completer.deliver(readinessListener, sourceInfo),
    );

    final replacementListener =
        replacementProvider.completer.addedListeners.single;
    await tester.pumpWidget(const SizedBox.shrink());
    deliveredInfos.add(
      replacementProvider.completer.deliver(
        replacementListener,
        sourceInfo,
      ),
    );

    for (final imageInfo in deliveredInfos) {
      expect(imageInfo.image.debugDisposed, isTrue);
    }
  });

  testWidgets('disposes a synchronously delivered readiness image clone',
      (tester) async {
    final sourceImage = await tester.runAsync(createTestImage);
    final sourceInfo = ImageInfo(image: sourceImage!);
    final provider = _TrackingImageProvider(
      'disposal-synchronous',
      synchronousImage: sourceInfo,
    );
    addTearDown(() {
      for (final imageInfo in provider.completer.deliveredImages) {
        if (!imageInfo.image.debugDisposed) {
          imageInfo.dispose();
        }
      }
      if (!sourceInfo.image.debugDisposed) {
        sourceInfo.dispose();
      }
    });

    await tester.pumpWidget(
      _previewHarness(photoId: 'photo_01', photoImage: provider),
    );
    await tester.pump();
    final readinessImageInfo = provider.completer.deliveredImages.first;
    await tester.pumpWidget(const SizedBox.shrink());

    expect(readinessImageInfo.image.debugDisposed, isTrue);
  });

  testWidgets('removes readiness listener on replacement and unmount',
      (tester) async {
    final firstProvider = _TrackingImageProvider('listener-first');
    final replacementProvider = _TrackingImageProvider('listener-replacement');

    await tester.pumpWidget(
      _previewHarness(photoId: 'photo_01', photoImage: firstProvider),
    );
    await tester.pump();
    expect(firstProvider.completer.addCount, 1);
    expect(firstProvider.completer.activeListeners, hasLength(1));

    await tester.pumpWidget(
      _previewHarness(
        photoId: 'photo_02',
        photoImage: replacementProvider,
      ),
    );
    await tester.pump();
    expect(firstProvider.completer.removeCount, 1);
    expect(firstProvider.completer.activeListeners, isEmpty);
    expect(replacementProvider.completer.addCount, 1);
    expect(replacementProvider.completer.activeListeners, hasLength(1));

    await tester.pumpWidget(const SizedBox.shrink());
    expect(replacementProvider.completer.removeCount, 1);
    expect(replacementProvider.completer.activeListeners, isEmpty);
  });

  testWidgets('tapping photo opens full-screen viewer', (tester) async {
    var openCount = 0;
    final provider = await _readyProvider(tester, 'tap-photo');
    await tester.pumpWidget(
      _previewHarness(
        photoId: 'photo_01',
        photoImage: provider,
        onOpenPhoto: () {
          openCount += 1;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(HandPhotoPreview.previewKey));
    await tester.pump();

    expect(openCount, 1);
  });

  testWidgets('loading and error states hide photo controls', (tester) async {
    await tester.pumpWidget(
      _previewHarness(photoId: 'photo_01', isLoading: true),
    );
    await tester.pump();

    expect(find.text('Loading photo'), findsOneWidget);
    expect(find.byKey(HandPhotoPreview.recenterKey), findsNothing);
    expect(find.byKey(HandPhotoPreview.expandKey), findsNothing);

    await tester.pumpWidget(
      _previewHarness(
        photoId: 'photo_01',
        error: StateError('photo failed'),
      ),
    );
    await tester.pump();

    expect(find.text('Photo could not be loaded'), findsOneWidget);
    expect(find.byKey(HandPhotoPreview.recenterKey), findsNothing);
    expect(find.byKey(HandPhotoPreview.expandKey), findsNothing);
  });
}

Widget _previewHarness({
  required String photoId,
  ImageProvider? photoImage,
  bool isLoading = false,
  Object? error,
  VoidCallback? onOpenPhoto,
}) {
  return MaterialApp(
    home: Center(
      child: SizedBox(
        width: 390,
        child: HandPhotoPreview(
          photoId: photoId,
          photoImage: isLoading || error != null ? null : photoImage,
          isLoading: isLoading,
          error: error,
          height: 128,
          rotationQuarterTurns: 0,
          onOpenPhoto: onOpenPhoto ?? () {},
        ),
      ),
    ),
  );
}

Future<_ControlledImageProvider> _readyProvider(
  WidgetTester tester,
  String cacheKey,
) async {
  final provider = _ControlledImageProvider(cacheKey);
  final image = await tester.runAsync(createTestImage);
  provider.complete(ImageInfo(image: image!));
  return provider;
}

class _ControlledImageProvider extends ImageProvider<String> {
  _ControlledImageProvider(this.cacheKey);

  final String cacheKey;
  final _imageCompleter = Completer<ImageInfo>();

  void complete(ImageInfo imageInfo) {
    _imageCompleter.complete(imageInfo);
  }

  void fail(Object error) {
    _imageCompleter.completeError(error, StackTrace.current);
  }

  @override
  Future<String> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(cacheKey);
  }

  @override
  ImageStreamCompleter loadImage(String key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(_imageCompleter.future);
  }

  @override
  bool operator ==(Object other) {
    return other is _ControlledImageProvider && other.cacheKey == cacheKey;
  }

  @override
  int get hashCode => cacheKey.hashCode;
}

class _TrackingImageProvider extends ImageProvider<String> {
  _TrackingImageProvider(
    this.cacheKey, {
    ImageInfo? synchronousImage,
  }) : completer = _TrackingImageStreamCompleter(
          synchronousImage: synchronousImage,
        );

  final String cacheKey;
  final _TrackingImageStreamCompleter completer;

  @override
  Future<String> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(cacheKey);
  }

  @override
  void resolveStreamForKey(
    ImageConfiguration configuration,
    ImageStream stream,
    String key,
    ImageErrorListener handleError,
  ) {
    if (stream.completer == null) {
      stream.setCompleter(completer);
    }
  }

  @override
  ImageStreamCompleter loadImage(String key, ImageDecoderCallback decode) {
    return completer;
  }
}

class _TrackingImageStreamCompleter extends ImageStreamCompleter {
  _TrackingImageStreamCompleter({this.synchronousImage});

  final ImageInfo? synchronousImage;
  final addedListeners = <ImageStreamListener>[];
  final activeListeners = <ImageStreamListener>{};
  final deliveredImages = <ImageInfo>[];
  var addCount = 0;
  var removeCount = 0;

  @override
  void addListener(ImageStreamListener listener) {
    addCount += 1;
    addedListeners.add(listener);
    activeListeners.add(listener);
    super.addListener(listener);
    final imageInfo = synchronousImage;
    if (imageInfo != null) {
      deliver(listener, imageInfo, synchronousCall: true);
    }
  }

  @override
  void removeListener(ImageStreamListener listener) {
    removeCount += 1;
    activeListeners.remove(listener);
    super.removeListener(listener);
  }

  ImageInfo deliver(
    ImageStreamListener listener,
    ImageInfo source, {
    bool synchronousCall = false,
  }) {
    final delivered = source.clone();
    deliveredImages.add(delivered);
    listener.onImage(delivered, synchronousCall);
    return delivered;
  }
}
