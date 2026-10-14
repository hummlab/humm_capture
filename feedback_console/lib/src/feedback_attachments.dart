import 'package:flutter/material.dart';

import 'external_url_opener.dart';
import 'feedback_report.dart';
import 'feedback_repository.dart';
import 'feedback_shimmer.dart';
import 'feedback_image_gallery.dart';

class FeedbackAttachments extends StatelessWidget {
  const FeedbackAttachments({required this.report, required this.repository, super.key});

  final FeedbackReport report;
  final FeedbackRepository repository;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text('Attachments · ${report.attachments.length}', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 10),
      ...report.attachments.map(
        (attachment) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _FeedbackAttachmentTile(attachment: attachment, report: report, repository: repository),
        ),
      ),
    ],
  );
}

class _FeedbackAttachmentTile extends StatefulWidget {
  const _FeedbackAttachmentTile({required this.attachment, required this.report, required this.repository});

  final FeedbackReportAttachment attachment;
  final FeedbackReport report;
  final FeedbackRepository repository;

  @override
  State<_FeedbackAttachmentTile> createState() => _FeedbackAttachmentTileState();
}

class _FeedbackAttachmentTileState extends State<_FeedbackAttachmentTile> {
  late Future<String?> _url;

  @override
  void initState() {
    super.initState();
    _url = widget.repository.attachmentUrlFor(widget.attachment);
  }

  @override
  void didUpdateWidget(covariant _FeedbackAttachmentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.path != widget.attachment.path) {
      _url = widget.repository.attachmentUrlFor(widget.attachment);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _url,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ListTile(
          leading: const Icon(Icons.broken_image_outlined),
          title: Text(widget.attachment.fileName),
          subtitle: const Text('Could not load attachment. Check Storage permissions and its saved path.'),
          trailing: IconButton(
            tooltip: 'Retry',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _url = widget.repository.attachmentUrlFor(widget.attachment, refresh: true));
            },
          ),
        );
      }
      final url = snapshot.data;
      final uri = url == null ? null : Uri.tryParse(url);
      Widget buildTile(VoidCallback? onOpen) => Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide.none),
        child: InkWell(
          onTap: uri == null ? null : onOpen,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 42,
                  height: 42,
                  child: widget.attachment.isVideo
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.all(Radius.circular(7)),
                          ),
                          child: Icon(Icons.videocam_outlined, color: Theme.of(context).colorScheme.primary),
                        )
                      : url == null
                      ? const FeedbackThumbnailShimmer(width: 42, height: 42)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(widget.attachment.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.attachment.isVideo ? 'Video · opens in player' : 'Image'} · ${_fileSizeLabel(widget.attachment.sizeBytes)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new_rounded, color: Theme.of(context).colorScheme.primary, size: 17),
              ],
            ),
          ),
        ),
      );
      if (uri == null || !uri.hasScheme) return buildTile(null);
      if (widget.attachment.isVideo) return buildTile(() => openExternalUrl(uri));
      return buildTile(
        () => openFeedbackGallery(
          context,
          report: widget.report,
          repository: widget.repository,
          attachmentPath: widget.attachment.path,
        ),
      );
    },
  );
}

String _fileSizeLabel(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
