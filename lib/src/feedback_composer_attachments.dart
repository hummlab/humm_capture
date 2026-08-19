import 'package:flutter/material.dart';

import 'feedback_models.dart';

/// Overlay menu for adding or managing feedback media.
class FeedbackAttachmentActionMenu extends StatelessWidget {
  /// Creates an attachment action menu.
  const FeedbackAttachmentActionMenu({
    required this.attachmentCount,
    required this.onChoosePhotos,
    required this.onChooseVideo,
    required this.onManage,
    super.key,
  });

  /// Number of currently selected attachments.
  final int attachmentCount;

  /// Opens the host's photo picker.
  final VoidCallback onChoosePhotos;

  /// Opens the host's video picker.
  final VoidCallback onChooseVideo;

  /// Opens the selected-media manager.
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: colorScheme.surfaceContainerHigh,
      child: ConstrainedBox(
        constraints: const BoxConstraints.tightFor(width: 228),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose photos'),
              onTap: onChoosePhotos,
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('Choose video'),
              onTap: onChooseVideo,
            ),
            if (attachmentCount > 0) ...<Widget>[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: Text('Manage media ($attachmentCount)'),
                onTap: onManage,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Modal manager for selected feedback images and videos.
class FeedbackAttachmentManager extends StatelessWidget {
  /// Creates an attachment manager.
  const FeedbackAttachmentManager({
    required this.attachments,
    required this.onClose,
    required this.onRemove,
    super.key,
  });

  /// Attachments selected for the current report.
  final List<FeedbackAttachment> attachments;

  /// Closes the manager.
  final VoidCallback onClose;

  /// Removes one selected attachment.
  final ValueChanged<FeedbackAttachment> onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: Colors.black54,
      child: SafeArea(
        minimum: const EdgeInsets.all(20),
        child: Center(
          child: Material(
            color: colorScheme.surface,
            elevation: 16,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Attached media', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Review the selected files before sending feedback.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: attachments.length,
                        separatorBuilder: (_, _) => const Divider(height: 16),
                        itemBuilder: (context, index) {
                          final attachment = attachments[index];
                          final isVideo = attachment.mimeType.startsWith('video/');
                          return Row(
                            children: <Widget>[
                              FeedbackAttachmentThumbnail(attachment: attachment, isVideo: isVideo),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  isVideo ? 'Video ${index + 1}' : 'Photo ${index + 1}',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove',
                                onPressed: () => onRemove(attachment),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(onPressed: onClose, child: const Text('Done')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thumbnail for one selected feedback attachment.
class FeedbackAttachmentThumbnail extends StatelessWidget {
  /// Creates an attachment thumbnail.
  const FeedbackAttachmentThumbnail({required this.attachment, required this.isVideo, super.key});

  /// Attachment represented by the thumbnail.
  final FeedbackAttachment attachment;

  /// Whether the attachment is a video.
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        height: 72,
        child: isVideo
            ? ColoredBox(
                color: colorScheme.surfaceContainerHighest,
                child: Icon(Icons.play_circle_outline_rounded, color: colorScheme.onSurfaceVariant, size: 30),
              )
            : Image.memory(
                attachment.bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.broken_image_outlined, color: colorScheme.onSurfaceVariant),
                ),
              ),
      ),
    );
  }
}
