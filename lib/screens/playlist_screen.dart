import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import '../models.dart';
import '../download_manager.dart';
import '../theme_provider.dart';
import '../widgets/download_card.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final MediaGroup group;
  const PlaylistDetailScreen({super.key, required this.group});

  Future<void> _downloadAll(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final defaultDir = prefs.getString('default_dir');
    if (defaultDir == null) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please set a default directory in Settings')));
      return;
    }
    final outputDir = p.join(defaultDir, _sanitize(group.uploader), _sanitize(group.title));
    try { Directory(outputDir).createSync(recursive: true); } catch (_) {}
    for (int i = 0; i < group.items.length; i++) {
      DownloadManager().addTask(group.items[i], outputDir, playlistIndex: i);
    }
  }

  void _downloadSingle(BuildContext context, VideoItem video, int index) async {
    final prefs = await SharedPreferences.getInstance();
    final defaultDir = prefs.getString('default_dir');
    if (defaultDir == null) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please set a default directory in Settings')));
      return;
    }
    final outputDir = p.join(defaultDir, _sanitize(group.uploader), _sanitize(group.title));
    try { Directory(outputDir).createSync(recursive: true); } catch (_) {}
    DownloadManager().addTask(video, outputDir, playlistIndex: index);
  }

  String _sanitize(String name) => name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeProvider(),
      builder: (context, _) {
        final t = ThemeProvider();
        return Scaffold(
          backgroundColor: t.bg,
          appBar: AppBar(
            backgroundColor: t.panel,
        elevation: 0,
        iconTheme: IconThemeData(color: t.text),
        title: Text(group.title, style: TextStyle(color: t.text, fontWeight: FontWeight.bold)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: t.border, height: 1)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Center(
              child: ListenableBuilder(
                listenable: DownloadManager(),
                builder: (context, _) {
                  final videoIds = group.items.map((v) => v.id).toSet();
                  final groupTasks = DownloadManager().tasks.where((t) => videoIds.contains(t.video.id));
                  
                  final hasActive = groupTasks.any((t) => t.status == DownloadStatus.downloading || t.status == DownloadStatus.queued);
                  final hasPaused = groupTasks.any((t) => t.status == DownloadStatus.paused);
                  
                  if (hasActive) {
                    return ElevatedButton.icon(
                      onPressed: () {
                        final ids = groupTasks
                            .where((t) => t.status == DownloadStatus.downloading || t.status == DownloadStatus.queued)
                            .map((t) => t.id)
                            .toList();
                        DownloadManager().pauseTasks(ids);
                      },
                      icon: const Icon(Icons.pause, size: 16),
                      label: const Text('Pause All'),
                      style: ElevatedButton.styleFrom(backgroundColor: t.panel, foregroundColor: t.text, elevation: 0, side: BorderSide(color: t.border)),
                    );
                  } else if (hasPaused) {
                    return ElevatedButton.icon(
                      onPressed: () {
                        for (final id in groupTasks.where((t) => t.status == DownloadStatus.paused || t.status == DownloadStatus.error).map((t) => t.id)) {
                          DownloadManager().resumeTask(id);
                        }
                      },
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Resume All'),
                      style: ElevatedButton.styleFrom(backgroundColor: t.panel, foregroundColor: t.text, elevation: 0, side: BorderSide(color: t.border)),
                    );
                  }
                  
                  final hasUncompleted = group.items.any((video) {
                    final task = DownloadManager().tasks.where((t) => t.video.id == video.id).firstOrNull;
                    return task == null || (task.status != DownloadStatus.completed && task.status != DownloadStatus.downloading && task.status != DownloadStatus.queued);
                  });
                  
                  if (!hasUncompleted) {
                     return const SizedBox.shrink(); // All downloaded!
                  }
                  
                  return ElevatedButton.icon(
                    onPressed: () => _downloadAll(context),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download All'),
                    style: ElevatedButton.styleFrom(backgroundColor: t.accent, foregroundColor: t.bg, elevation: 0),
                  );
                },
              ),
            ),
          )
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: group.items.length,
        separatorBuilder: (c, i) => Divider(height: 24, color: t.border),
        itemBuilder: (context, index) {
          final video = group.items[index];
          return ListenableBuilder(
            listenable: DownloadManager(),
            builder: (context, child) {
              final tasks = DownloadManager().tasks;
              final taskIndex = tasks.indexWhere((t) => t.video.id == video.id);
              final task = taskIndex != -1 ? tasks[taskIndex] : null;

              return DownloadCard(
                video: video,
                task: task,
                index: index,
                onDownload: () => _downloadSingle(context, video, index),
              );
            },
          );
        },
      ),
        );
      },
    );
  }
}
