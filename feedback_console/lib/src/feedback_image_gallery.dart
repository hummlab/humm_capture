import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'external_url_opener.dart';
import 'feedback_report.dart';
import 'feedback_repository.dart';

void openFeedbackGallery(
  BuildContext context, {
  required FeedbackReport report,
  required FeedbackRepository repository,
  String? attachmentPath,
}) {
  final images = <FeedbackGalleryImage>[
    if (report.screenshotPath?.isNotEmpty == true)
      FeedbackGalleryImage(label: 'Screenshot', loadUrl: () => repository.screenshotUrlFor(report)),
    for (final attachment in report.attachments.where((item) => !item.isVideo))
      FeedbackGalleryImage(
        label: attachment.fileName,
        loadUrl: () => repository.attachmentUrlFor(attachment, refresh: true),
      ),
  ];
  if (images.isEmpty) return;
  final attachments = report.attachments.where((item) => !item.isVideo).toList();
  final index = attachmentPath == null ? 0 : attachments.indexWhere((item) => item.path == attachmentPath);
  showDialog<void>(
    context: context,
    builder: (_) => FeedbackImageGallery(
      images: images,
      initialIndex: attachmentPath == null || index < 0
          ? 0
          : index + (report.screenshotPath?.isNotEmpty == true ? 1 : 0),
    ),
  );
}

class FeedbackGalleryImage {
  const FeedbackGalleryImage({required this.label, required this.loadUrl});
  final String label;
  final Future<String?> Function() loadUrl;
}

class FeedbackImageGallery extends StatefulWidget {
  const FeedbackImageGallery({required this.images, this.initialIndex = 0, super.key}) : assert(images.length > 0);
  final List<FeedbackGalleryImage> images;
  final int initialIndex;
  @override
  State<FeedbackImageGallery> createState() => _FeedbackImageGalleryState();
}

class _FeedbackImageGalleryState extends State<FeedbackImageGallery> {
  late int _index = widget.initialIndex.clamp(0, widget.images.length - 1);
  late Future<String?> _url = widget.images[_index].loadUrl();
  final _transform = TransformationController();
  final _keyboardFocus = FocusNode(debugLabel: 'Feedback gallery');
  double _scale = 1;

  @override
  void dispose() {
    _keyboardFocus.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index < 0 || index >= widget.images.length || index == _index) return;
    setState(() {
      _index = index;
      _url = widget.images[index].loadUrl();
      _transform.value = Matrix4.identity();
      _scale = 1;
    });
    // Next/previous can become disabled at the boundary; retain shortcuts.
    _keyboardFocus.requestFocus();
  }

  void _zoom(double scale) => setState(() {
    _scale = scale.clamp(1, 4);
    _transform.value = Matrix4.diagonal3Values(_scale, _scale, 1);
  });

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _select(_index - 1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _select(_index + 1),
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(),
      },
      child: Focus(
        focusNode: _keyboardFocus,
        autofocus: true,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.photo_library_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.images[_index].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text('${_index + 1} / ${widget.images.length}'),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Close gallery',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<String?>(
                  future: _url,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final url = snapshot.data;
                    if (snapshot.hasError || url == null) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.broken_image_outlined, size: 40),
                            const SizedBox(height: 12),
                            const Text('Could not load image.'),
                            TextButton(
                              onPressed: () {
                                final url = widget.images[_index].loadUrl();
                                setState(() {
                                  _url = url;
                                });
                              },
                              child: const Text('Retry image'),
                            ),
                          ],
                        ),
                      );
                    }
                    return ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          InteractiveViewer(
                            transformationController: _transform,
                            minScale: 1,
                            maxScale: 4,
                            onInteractionEnd: (_) => setState(() => _scale = _transform.value.getMaxScaleOnAxis()),
                            child: Center(
                              child: Image.network(
                                url,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Center(child: Text('Could not load image.')),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Material(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                elevation: 2,
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    IconButton(
                                      tooltip: 'Zoom out',
                                      onPressed: _scale <= 1 ? null : () => _zoom(_scale - 0.5),
                                      icon: const Icon(Icons.remove),
                                    ),
                                    TextButton(onPressed: () => _zoom(1), child: Text('${(_scale * 100).round()}%')),
                                    IconButton(
                                      tooltip: 'Zoom in',
                                      onPressed: _scale >= 4 ? null : () => _zoom(_scale + 0.5),
                                      icon: const Icon(Icons.add),
                                    ),
                                    TextButton(onPressed: () => _zoom(1), child: const Text('Fit')),
                                    IconButton(
                                      tooltip: 'Open original',
                                      onPressed: () => openExternalUrl(Uri.parse(url)),
                                      icon: const Icon(Icons.open_in_new),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous image',
                    onPressed: _index == 0 ? null : () => _select(_index - 1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: widget.images.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => ChoiceChip(
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(widget.images[index].label, overflow: TextOverflow.ellipsis),
                          ),
                          selected: index == _index,
                          onSelected: (_) => _select(index),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next image',
                    onPressed: _index == widget.images.length - 1 ? null : () => _select(_index + 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
