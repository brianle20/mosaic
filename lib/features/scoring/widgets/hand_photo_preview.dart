import 'package:flutter/material.dart';

class HandPhotoPreview extends StatefulWidget {
  const HandPhotoPreview({
    super.key,
    required this.photoId,
    required this.photoImage,
    required this.isLoading,
    required this.error,
    required this.height,
    required this.rotationQuarterTurns,
    required this.onOpenPhoto,
  });

  static const previewKey = Key('hand-photo-preview');
  static const interactiveViewerKey = Key('hand-photo-interactive-viewer');
  static const recenterKey = Key('hand-photo-recenter');
  static const expandKey = Key('hand-photo-expand');

  final String photoId;
  final ImageProvider? photoImage;
  final bool isLoading;
  final Object? error;
  final double height;
  final int rotationQuarterTurns;
  final VoidCallback onOpenPhoto;

  @override
  State<HandPhotoPreview> createState() => _HandPhotoPreviewState();
}

class _HandPhotoPreviewState extends State<HandPhotoPreview> {
  final _transformationController = TransformationController();
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  var _imageGeneration = 0;
  var _hasDecodedFrame = false;
  var _isAttachingImageStreamListener = false;
  Object? _imageLoadError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final imageStream = _resolveCurrentImageStream();
    if (!_isCurrentImageStream(imageStream)) {
      _replaceImageStream(imageStream);
    }
  }

  @override
  void didUpdateWidget(covariant HandPhotoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoId != widget.photoId ||
        oldWidget.photoImage != widget.photoImage) {
      _resetView();
      _replaceImageStream(_resolveCurrentImageStream());
    }
  }

  @override
  void dispose() {
    _imageGeneration += 1;
    _detachImageStreamListener();
    _transformationController.dispose();
    super.dispose();
  }

  void _resetView() {
    _transformationController.value = Matrix4.identity();
  }

  ImageStream? _resolveCurrentImageStream() {
    return widget.photoImage?.resolve(createLocalImageConfiguration(context));
  }

  bool _isCurrentImageStream(ImageStream? imageStream) {
    final currentStream = _imageStream;
    if (identical(currentStream, imageStream)) {
      return true;
    }
    if (currentStream == null || imageStream == null) {
      return false;
    }
    return currentStream.key == imageStream.key;
  }

  void _replaceImageStream(ImageStream? imageStream) {
    _imageGeneration += 1;
    _detachImageStreamListener();
    _hasDecodedFrame = false;
    _imageLoadError = null;
    if (imageStream == null) {
      return;
    }

    final generation = _imageGeneration;
    final listener = ImageStreamListener(
      (imageInfo, synchronousCall) {
        _handleImageFrame(generation, imageInfo, synchronousCall);
      },
      onError: (error, stackTrace) {
        _handleImageError(generation, error);
      },
    );
    _imageStream = imageStream;
    _imageStreamListener = listener;
    _isAttachingImageStreamListener = true;
    try {
      imageStream.addListener(listener);
    } finally {
      _isAttachingImageStreamListener = false;
    }
  }

  void _detachImageStreamListener() {
    final imageStream = _imageStream;
    final listener = _imageStreamListener;
    if (imageStream != null && listener != null) {
      imageStream.removeListener(listener);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  void _handleImageFrame(
    int generation,
    ImageInfo imageInfo,
    bool synchronousCall,
  ) {
    try {
      if (!mounted || generation != _imageGeneration) {
        return;
      }
      if (_hasDecodedFrame && _imageLoadError == null) {
        return;
      }
      if (synchronousCall || _isAttachingImageStreamListener) {
        _hasDecodedFrame = true;
        _imageLoadError = null;
        return;
      }
      setState(() {
        _hasDecodedFrame = true;
        _imageLoadError = null;
      });
    } finally {
      imageInfo.dispose();
    }
  }

  void _handleImageError(int generation, Object error) {
    if (!mounted || generation != _imageGeneration) {
      return;
    }
    if (_isAttachingImageStreamListener) {
      _hasDecodedFrame = false;
      _imageLoadError = error;
      return;
    }
    setState(() {
      _hasDecodedFrame = false;
      _imageLoadError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      key: HandPhotoPreview.previewKey,
      height: widget.height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: ColoredBox(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
              child: _buildContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (widget.isLoading) {
      return const Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text('Loading photo'),
            ],
          ),
        ),
      );
    }
    final imageLoadError = widget.error ?? _imageLoadError;
    if (imageLoadError != null) {
      return _PhotoStatusPanel(
        icon: Icons.broken_image_outlined,
        iconColor: colors.error,
        title: 'Photo could not be loaded',
        titleColor: colors.error,
        detail: imageLoadError.toString(),
      );
    }
    final photoImage = widget.photoImage;
    if (photoImage == null) {
      return _PhotoStatusPanel(
        icon: Icons.image_not_supported_outlined,
        iconColor: colors.onSurfaceVariant,
        title: 'Photo unavailable',
        detail: 'The captured photo could not be opened.',
      );
    }
    if (!_hasDecodedFrame) {
      return const Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text('Loading photo'),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onOpenPhoto,
          child: InteractiveViewer(
            key: HandPhotoPreview.interactiveViewerKey,
            transformationController: _transformationController,
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: RotatedBox(
                quarterTurns: widget.rotationQuarterTurns,
                child: Image(
                  image: photoImage,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 6,
          bottom: 6,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                key: HandPhotoPreview.recenterKey,
                tooltip: 'Re-center photo',
                onPressed: _resetView,
                icon: const Icon(Icons.center_focus_strong),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                key: HandPhotoPreview.expandKey,
                tooltip: 'Open full-screen photo',
                onPressed: widget.onOpenPhoto,
                icon: const Icon(Icons.open_in_full),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoStatusPanel extends StatelessWidget {
  const _PhotoStatusPanel({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.titleColor,
    this.detail,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      (constraints.maxWidth - 12).clamp(0, 480).toDouble(),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: iconColor),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: titleColor),
                    ),
                    if (detail != null)
                      Text(
                        detail!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
