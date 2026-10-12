import 'dart:io';
import 'package:flutter/material.dart';
import '../models.dart';
import '../download_manager.dart';
import '../theme_provider.dart';
import 'shimmer_effect.dart';

class DownloadCard extends StatelessWidget {
  final VideoItem video;
  final DownloadTaskModel? task;
  final int index;
  final VoidCallback onDownload;

  const DownloadCard({
    super.key,
    required this.video,
    required this.task,
    required this.index,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeProvider(),
      builder: (context, _) {
        if (task == null) {
          return _buildCard(context, null);
        }
        return ListenableBuilder(
          listenable: task!,
          builder: (context, _) => _buildCard(context, task),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, DownloadTaskModel? currentTask) {
    final t = ThemeProvider();
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: currentTask != null && currentTask.status == DownloadStatus.downloading ? t.accent.withOpacity(0.02) : t.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: currentTask != null && currentTask.status == DownloadStatus.downloading ? t.accent.withOpacity(0.4) : t.border, width: currentTask != null && currentTask.status == DownloadStatus.downloading ? 1.5 : 1.0),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onDoubleTap: () => _showInFolder(context, currentTask),
          onTap: () {}, // empty tap to enable hover effect
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // LEFT: Thumbnail
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 200,
                    height: 112,
                    child: video.thumbnail != null 
                        ? Image.network(
                            video.thumbnail!, 
                            fit: BoxFit.cover,
                            loadingBuilder: (c, child, progress) => progress == null ? child : const ShimmerBox(),
                            errorBuilder: (c,e,s) => Icon(Icons.video_library, color: t.subtext),
                          )
                        : Icon(Icons.video_library, color: t.subtext),
                  ),
                ),
                if (video.duration != null)
                  Positioned(
                    bottom: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                      child: Text(video.duration!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                Positioned(
                  top: 6, left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                    child: Text('#${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                )
              ]
            ),
            const SizedBox(width: 24),
            // CENTER: Details
            Expanded(
               child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(video.title, style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                     const SizedBox(height: 8),
                     // Metadata row
                     Text('${video.duration ?? 'Unknown'} • ${video.quality.name.toUpperCase()} • MP4', style: TextStyle(color: t.subtext, fontSize: 13)),
                     const SizedBox(height: 12),
                     // Progress Bar inside the center section!
                     if (currentTask != null) ...[
                        _buildProgressBar(context, currentTask, t),
                        const SizedBox(height: 8),
                        _buildDownloadInfo(currentTask, t),
                     ] else ...[
                        const SizedBox(height: 8),
                        Text('Ready to download', style: TextStyle(color: t.subtext, fontSize: 13)),
                     ]
                  ]
               )
            ),
            const SizedBox(width: 24),
            // RIGHT: Actions
            _buildRightActions(context, currentTask, t),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildProgressBar(BuildContext context, DownloadTaskModel task, ThemeProvider t) {
    final bool isError = task.status == DownloadStatus.error;
    final bool isPaused = task.status == DownloadStatus.paused;
    final bool isCompleted = task.status == DownloadStatus.completed;
    
    Color activeColor = t.accent;
    if (isError) activeColor = t.danger;
    if (isCompleted) activeColor = t.success;
    if (isPaused) activeColor = t.subtext;

    return Container(
      height: 8,
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.border.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.hardEdge,
      child: task.status == DownloadStatus.queued || (task.status == DownloadStatus.downloading && task.progress == 0)
        ? _buildIndeterminateBar(activeColor)
        : TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: task.progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                child: Container(
                  decoration: BoxDecoration(
                    color: task.status == DownloadStatus.downloading ? Colors.transparent : activeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: task.status == DownloadStatus.downloading
                    ? ShimmerEffect(
                        baseColor: activeColor,
                        highlightColor: Colors.white.withOpacity(0.5),
                        child: Container(color: Colors.white),
                      )
                    : null,
                ),
              );
            },
          ),
    );
  }

  Widget _buildIndeterminateBar(Color color) {
    // Subtle indeterminate state if queued or initializing
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(
              width: constraints.maxWidth * 0.3,
              decoration: BoxDecoration(
                color: color.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getDownloadedStr(double progress, String total) {
    if (total.isEmpty) return '';
    final match = RegExp(r'([\d\.]+)([a-zA-Z]+)').firstMatch(total.replaceAll(' ', ''));
    if (match != null) {
      final val = double.tryParse(match.group(1) ?? '') ?? 0;
      final unit = match.group(2) ?? '';
      final downloaded = val * progress;
      return '${downloaded.toStringAsFixed(1)} $unit of $total';
    }
    return total;
  }

  Widget _buildDownloadInfo(DownloadTaskModel task, ThemeProvider t) {
    String info = '';
    
    if (task.status == DownloadStatus.queued) {
      info = 'Waiting in queue...';
    } else if (task.status == DownloadStatus.paused) {
      final sizeStr = _getDownloadedStr(task.progress, task.totalSize);
      info = sizeStr.isNotEmpty ? '$sizeStr • Paused' : 'Paused';
    } else if (task.status == DownloadStatus.completed) {
      info = task.totalSize.isNotEmpty ? '${task.totalSize} • Completed' : 'Completed';
    } else if (task.status == DownloadStatus.error) {
      final sizeStr = _getDownloadedStr(task.progress, task.totalSize);
      info = 'Download failed' + (sizeStr.isNotEmpty ? ' • $sizeStr' : '');
    } else {
      // Downloading or initializing
      final parts = <String>[];
      final sizeStr = _getDownloadedStr(task.progress, task.totalSize);
      if (sizeStr.isNotEmpty) parts.add(sizeStr);
      if (task.speed.isNotEmpty) parts.add(task.speed);
      if (task.eta.isNotEmpty) parts.add('${task.eta} left');
      
      final statsStr = parts.isEmpty ? 'Initializing download...' : parts.join(' • ');
      
      return Row(
         children: [
            Icon(Icons.circle, color: t.accent, size: 10),
            const SizedBox(width: 6),
            Text('Downloading', style: TextStyle(color: t.accent, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text(statsStr, style: TextStyle(color: t.subtext, fontSize: 13)),
         ]
      );
    }

    return Text(info, style: TextStyle(color: t.subtext, fontSize: 13));
  }

  Widget _buildRightActions(BuildContext context, DownloadTaskModel? task, ThemeProvider t) {
    if (task == null) {
      return IconButton(
        icon: Icon(Icons.download_rounded, color: t.text),
        onPressed: onDownload,
        tooltip: 'Download',
        style: IconButton.styleFrom(backgroundColor: t.panel, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: t.border))),
      );
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 50,
          child: Text(
            task.status == DownloadStatus.queued || (task.status == DownloadStatus.downloading && task.progress == 0)
              ? '0%'
              : '${(task.progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 16),
        _buildActionButtons(context, task, t),
      ],
    );
  }
  
  Widget _buildActionButtons(BuildContext context, DownloadTaskModel task, ThemeProvider t) {
    final dm = DownloadManager();
    final buttonStyle = IconButton.styleFrom(
      backgroundColor: t.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: t.border)),
    );

    if (task.status == DownloadStatus.completed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: t.success, size: 28),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(Icons.folder_open, color: t.text),
            tooltip: 'Show in folder',
            onPressed: () => _showInFolder(context, task),
            style: buttonStyle,
          ),
        ],
      );
    }

    if (task.status == DownloadStatus.error) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.refresh, color: t.text),
            tooltip: 'Retry download',
            onPressed: () => dm.resumeTask(task.id),
            style: buttonStyle,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.close, color: t.text),
            tooltip: 'Remove download',
            onPressed: () => dm.removeTask(task.id),
            style: buttonStyle,
          ),
        ],
      );
    }

    if (task.status == DownloadStatus.paused) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.play_arrow, color: t.text),
            tooltip: 'Resume download',
            onPressed: () => dm.resumeTask(task.id),
            style: buttonStyle,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.close, color: t.text),
            tooltip: 'Cancel download',
            onPressed: () => dm.removeTask(task.id, deleteFile: true),
            style: buttonStyle,
          ),
        ],
      );
    }

    // Downloading or Queued
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (task.status == DownloadStatus.downloading) ...[
          IconButton(
            icon: Icon(Icons.pause, color: t.text),
            tooltip: 'Pause download',
            onPressed: () => dm.pauseTask(task.id),
            style: buttonStyle,
          ),
          const SizedBox(width: 8),
        ],
        IconButton(
          icon: Icon(Icons.close, color: t.text),
          tooltip: 'Cancel download',
          onPressed: () => dm.removeTask(task.id, deleteFile: true),
          style: buttonStyle,
        ),
      ],
    );
  }

  void _showInFolder(BuildContext context, DownloadTaskModel? task) {
    if (task == null || task.status == DownloadStatus.queued) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download has not started yet.')));
      return;
    }

    // --- Strategy 1: Use the exact file path captured from yt-dlp output ---
    final rawPath = task.destinationPath;
    if (rawPath != null && rawPath.isNotEmpty) {
      final path = rawPath.replaceAll('/', '\\').trim();
      if (File(path).existsSync()) {
        Process.run('explorer.exe', ['/select,$path']);
        return;
      }
    }

    // --- Strategy 2: Fall back to outputDirectory (always known) ---
    final dir = task.outputDirectory.replaceAll('/', '\\').trim();
    if (dir.isNotEmpty && Directory(dir).existsSync()) {
      Process.run('explorer.exe', [dir]);
      return;
    }

    // --- Strategy 3: Nothing available ---
    if (task.status == DownloadStatus.downloading) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download is still in progress.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloaded file could not be found.')));
    }
  }
}
