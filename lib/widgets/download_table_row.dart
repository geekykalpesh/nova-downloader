import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models.dart';
import '../../download_manager.dart';
import '../../theme_provider.dart';

class DownloadTableRow extends StatefulWidget {
  final DownloadTaskModel task;
  final bool isSelected;
  final ValueChanged<bool?> onSelect;

  const DownloadTableRow({
    super.key,
    required this.task,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  State<DownloadTableRow> createState() => _DownloadTableRowState();
}

class _DownloadTableRowState extends State<DownloadTableRow> {
  bool _isHovering = false;

  void _showContextMenu(BuildContext context, Offset position, ThemeProvider t) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      color: t.surface,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: t.border),
      ),
      items: <PopupMenuEntry<dynamic>>[
        if (widget.task.status == DownloadStatus.completed && widget.task.destinationPath != null) ...[
          PopupMenuItem(
            onTap: () => openFileCrossPlatform(widget.task.destinationPath!),
            child: Row(children: [Icon(Icons.play_circle_outline, color: t.accent, size: 18), const SizedBox(width: 10), Text('Play File', style: TextStyle(color: t.text, fontSize: 13))]),
          ),
          PopupMenuItem(
            onTap: () => showInFolderCrossPlatform(widget.task.destinationPath!),
            child: Row(children: [Icon(Icons.folder_open, color: t.text, size: 18), const SizedBox(width: 10), Text('Show in Folder', style: TextStyle(color: t.text, fontSize: 13))]),
          ),
          const PopupMenuDivider(),
        ],
        if (widget.task.status == DownloadStatus.downloading)
          PopupMenuItem(
            onTap: () => DownloadManager().pauseTask(widget.task.id),
            child: Row(children: [Icon(Icons.pause, color: t.warning, size: 18), const SizedBox(width: 10), Text('Pause Download', style: TextStyle(color: t.text, fontSize: 13))]),
          ),
        if (widget.task.status == DownloadStatus.paused || widget.task.status == DownloadStatus.error)
          PopupMenuItem(
            onTap: () => DownloadManager().resumeTask(widget.task.id),
            child: Row(children: [Icon(Icons.play_arrow, color: t.success, size: 18), const SizedBox(width: 10), Text('Resume Download', style: TextStyle(color: t.text, fontSize: 13))]),
          ),
        PopupMenuItem(
          onTap: () {
            Clipboard.setData(ClipboardData(text: widget.task.video.url));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: const Text('Video URL copied to clipboard'), duration: const Duration(seconds: 2), backgroundColor: t.panel),
            );
          },
          child: Row(children: [Icon(Icons.link, color: t.subtext, size: 18), const SizedBox(width: 10), Text('Copy Link', style: TextStyle(color: t.text, fontSize: 13))]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: () => DownloadManager().removeTask(widget.task.id),
          child: Row(children: [Icon(Icons.delete_outline, color: t.danger, size: 18), const SizedBox(width: 10), Text('Remove from Queue', style: TextStyle(color: t.danger, fontSize: 13))]),
        ),
        if (widget.task.status == DownloadStatus.completed)
          PopupMenuItem(
            onTap: () => DownloadManager().removeTask(widget.task.id, deleteFile: true),
            child: Row(children: [Icon(Icons.delete_forever, color: t.danger, size: 18), const SizedBox(width: 10), Text('Delete Downloaded File', style: TextStyle(color: t.danger, fontSize: 13))]),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeProvider(),
      builder: (context, _) {
        final t = ThemeProvider();
        return ListenableBuilder(
          listenable: widget.task,
          builder: (context, _) {
            final task = widget.task;

            Color statusColor;
            Color statusBg;
            String statusText;
            IconData statusIcon;

            switch (task.status) {
              case DownloadStatus.queued:
                statusColor = t.subtext;
                statusBg = t.subtext.withOpacity(0.12);
                statusText = 'Queued';
                statusIcon = Icons.schedule;
                break;
              case DownloadStatus.downloading:
                statusColor = t.accent;
                statusBg = t.accentLight;
                statusText = task.speed.isNotEmpty ? task.speed : 'Downloading';
                statusIcon = Icons.arrow_downward;
                break;
              case DownloadStatus.paused:
                statusColor = t.warning;
                statusBg = t.warning.withOpacity(0.12);
                statusText = 'Paused';
                statusIcon = Icons.pause;
                break;
              case DownloadStatus.completed:
                statusColor = t.success;
                statusBg = t.success.withOpacity(0.12);
                statusText = 'Completed';
                statusIcon = Icons.check_circle;
                break;
              case DownloadStatus.error:
                statusColor = t.danger;
                statusBg = t.danger.withOpacity(0.12);
                statusText = 'Failed';
                statusIcon = Icons.error_outline;
                break;
            }

            final double progress = task.status == DownloadStatus.completed ? 1.0 : task.progress.clamp(0.0, 1.0);

            return MouseRegion(
              onEnter: (_) => setState(() => _isHovering = true),
              onExit: (_) => setState(() => _isHovering = false),
              child: GestureDetector(
                onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition, t),
                onDoubleTap: () {
                  if (task.status == DownloadStatus.completed && task.destinationPath != null) {
                    openFileCrossPlatform(task.destinationPath!);
                  }
                },
                child: Container(
                  height: 76,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? t.accent.withOpacity(0.12)
                        : _isHovering
                            ? t.surfaceLight
                            : t.panel,
                    border: Border(bottom: BorderSide(color: t.border.withOpacity(0.6))),
                  ),
                  child: Row(
                    children: [
                      // Selection Checkbox
                      SizedBox(
                        width: 24,
                        child: Checkbox(
                          value: widget.isSelected,
                          onChanged: widget.onSelect,
                          activeColor: t.accent,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Video Thumbnail with Duration badge
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 88,
                          height: 52,
                          color: t.bg,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (task.video.thumbnail != null && task.video.thumbnail!.isNotEmpty)
                                Image.network(
                                  task.video.thumbnail!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => _buildFallbackThumbnail(t),
                                )
                              else
                                _buildFallbackThumbnail(t),

                              // Duration pill
                              if (task.video.duration != null && task.video.duration!.isNotEmpty)
                                Positioned(
                                  bottom: 3,
                                  right: 3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      task.video.duration!,
                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Title, Uploader & Progress Bar (Flexible)
                      Expanded(
                        flex: 6,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    task.video.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: t.text,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (task.video.quality == VideoQuality.audio)
                                  _buildQualityBadge('MP3 Audio', t)
                                else if (task.video.quality == VideoQuality.p1080)
                                  _buildQualityBadge('1080p', t)
                                else if (task.video.quality == VideoQuality.p720)
                                  _buildQualityBadge('720p', t)
                                else
                                  _buildQualityBadge('Best HD', t),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Subtitle: channel / details
                            Row(
                              children: [
                                if (task.video.uploader.isNotEmpty && task.video.uploader != 'Unknown Channel') ...[
                                  Text(
                                    task.video.uploader,
                                    style: TextStyle(color: t.subtext, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(' • ', style: TextStyle(color: t.subtext, fontSize: 11)),
                                ],
                                if (task.status == DownloadStatus.downloading && task.totalSize.isNotEmpty) ...[
                                  Text(
                                    '${task.totalSize} • ${task.eta.isNotEmpty ? "ETA: ${task.eta}" : ""}',
                                    style: TextStyle(color: t.accent, fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                ] else if (task.status == DownloadStatus.completed && task.totalSize.isNotEmpty) ...[
                                  Text(
                                    task.totalSize,
                                    style: TextStyle(color: t.subtext, fontSize: 11),
                                  ),
                                ] else if (task.status == DownloadStatus.error && task.errorMessage.isNotEmpty) ...[
                                  Expanded(
                                    child: Text(
                                      task.errorMessage,
                                      style: TextStyle(color: t.danger, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ] else ...[
                                  Text(
                                    'YouTube Video',
                                    style: TextStyle(color: t.subtext, fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Progress Bar
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: t.border.withOpacity(0.5),
                                      color: statusColor,
                                      minHeight: 4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    '${(progress * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(color: t.subtext, fontSize: 11, fontWeight: FontWeight.w600),
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),

                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: statusColor, size: 13),
                            const SizedBox(width: 6),
                            Text(
                              statusText,
                              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Action Buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (task.status == DownloadStatus.downloading)
                            _buildActionButton(
                              icon: Icons.pause_rounded,
                              color: t.warning,
                              tooltip: 'Pause',
                              onPressed: () => DownloadManager().pauseTask(task.id),
                              t: t,
                            )
                          else if (task.status == DownloadStatus.paused || task.status == DownloadStatus.error)
                            _buildActionButton(
                              icon: Icons.play_arrow_rounded,
                              color: t.success,
                              tooltip: 'Resume',
                              onPressed: () => DownloadManager().resumeTask(task.id),
                              t: t,
                            ),

                          if (task.status == DownloadStatus.completed && task.destinationPath != null) ...[
                            _buildActionButton(
                              icon: Icons.folder_open_rounded,
                              color: t.accent,
                              tooltip: 'Show in Folder',
                              onPressed: () => showInFolderCrossPlatform(task.destinationPath!),
                              t: t,
                            ),
                            _buildActionButton(
                              icon: Icons.play_circle_fill_rounded,
                              color: t.success,
                              tooltip: 'Play Video',
                              onPressed: () => openFileCrossPlatform(task.destinationPath!),
                              t: t,
                            ),
                          ],

                          _buildActionButton(
                            icon: Icons.more_horiz_rounded,
                            color: t.subtext,
                            tooltip: 'More Options',
                            onPressed: () {
                              final renderBox = context.findRenderObject() as RenderBox;
                              final offset = renderBox.localToGlobal(Offset.zero);
                              _showContextMenu(context, Offset(offset.dx + renderBox.size.width - 40, offset.dy + 35), t);
                            },
                            t: t,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFallbackThumbnail(ThemeProvider t) {
    return Center(
      child: Icon(Icons.movie_outlined, color: t.subtext.withOpacity(0.4), size: 24),
    );
  }

  Widget _buildQualityBadge(String label, ThemeProvider t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: t.surfaceLight,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: t.border),
      ),
      child: Text(
        label,
        style: TextStyle(color: t.subtext, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
    required ThemeProvider t,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
        tooltip: tooltip,
        splashRadius: 18,
        hoverColor: t.surfaceLight,
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(6),
          minimumSize: const Size(32, 32),
        ),
      ),
    );
  }
}
