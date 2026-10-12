import 'dart:io';
import 'package:flutter/foundation.dart';

enum DownloadStatus { queued, downloading, paused, completed, error }
enum VideoQuality { best, p1080, p720, p480, audio }

class MediaGroup {
  final String id;
  final String title;
  final String uploader;
  final List<VideoItem> items;

  MediaGroup({
    required this.id,
    required this.title,
    required this.uploader,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'uploader': uploader,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }

  factory MediaGroup.fromJson(Map<String, dynamic> json) {
    return MediaGroup(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown',
      uploader: json['uploader'] ?? 'Unknown Channel',
      items: (json['items'] as List<dynamic>?)?.map((e) => VideoItem.fromJson(e)).toList() ?? [],
    );
  }
}

class VideoItem {
  final String id;
  final String title;
  final String url;
  final String? thumbnail;
  final String? duration;
  final String uploader;
  VideoQuality quality;

  VideoItem({
    required this.id,
    required this.title,
    required this.url,
    this.thumbnail,
    this.duration,
    required this.uploader,
    this.quality = VideoQuality.best,
  });

  factory VideoItem.fromJson(Map<String, dynamic> json, {VideoQuality quality = VideoQuality.best}) {
    String? parsedThumbnail = json['thumbnail'];
    if (parsedThumbnail == null && json['thumbnails'] != null && json['thumbnails'].isNotEmpty) {
      parsedThumbnail = json['thumbnails'].last['url'];
    }

    return VideoItem(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown Title',
      url: json['webpage_url'] ?? json['url'] ?? '',
      thumbnail: parsedThumbnail,
      duration: json['duration_string'] ?? (json['duration'] != null ? _formatDuration(json['duration']) : null),
      uploader: json['channel'] ?? json['uploader'] ?? 'Unknown Channel',
      quality: json['quality'] != null ? VideoQuality.values[json['quality']] : quality,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'thumbnail': thumbnail,
      'duration_string': duration,
      'uploader': uploader,
      'quality': quality.index,
    };
  }

  static String _formatDuration(dynamic duration) {
    if (duration == null) return '';
    final seconds = duration is int ? duration : double.tryParse(duration.toString())?.toInt() ?? 0;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m >= 60) {
      final h = m ~/ 60;
      final hm = m % 60;
      return '$h:${hm.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class DownloadTaskModel extends ChangeNotifier {
  final String id;
  final VideoItem video;
  final String outputDirectory;
  final int? playlistIndex;

  DownloadStatus _status = DownloadStatus.queued;
  double _progress = 0.0;
  String _speed = '';
  String _eta = '';
  String _totalSize = '';
  String _errorMessage = '';
  String? _destinationPath;

  DownloadTaskModel({
    required this.id,
    required this.video,
    required this.outputDirectory,
    this.playlistIndex,
    DownloadStatus status = DownloadStatus.queued,
    double progress = 0.0,
    String? destinationPath,
  }) {
    _status = status;
    _progress = progress;
    _destinationPath = destinationPath;
  }

  DownloadStatus get status => _status;
  double get progress => _progress;
  String get speed => _speed;
  String get eta => _eta;
  String get totalSize => _totalSize;
  String get errorMessage => _errorMessage;
  String? get destinationPath => _destinationPath;

  void updateProgress(double progress, String speed, String eta, String totalSize, {String? destinationPath}) {
    _progress = progress;
    _speed = speed;
    _eta = eta;
    if (totalSize.isNotEmpty) {
      _totalSize = totalSize;
    }
    if (destinationPath != null) {
      _destinationPath = destinationPath;
    }
    notifyListeners();
  }

  void updateStatus(DownloadStatus status, {String? errorMessage}) {
    _status = status;
    if (errorMessage != null) {
      _errorMessage = errorMessage;
    }
    notifyListeners();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'video': video.toJson(),
      'outputDirectory': outputDirectory,
      'playlistIndex': playlistIndex,
      'status': _status.index,
      'progress': _progress,
      'destinationPath': _destinationPath,
    };
  }

  factory DownloadTaskModel.fromJson(Map<String, dynamic> json) {
    return DownloadTaskModel(
      id: json['id'],
      video: VideoItem.fromJson(json['video']),
      outputDirectory: json['outputDirectory'],
      playlistIndex: json['playlistIndex'],
      status: DownloadStatus.values[json['status'] ?? 0],
      progress: json['progress'] ?? 0.0,
      destinationPath: json['destinationPath'],
    );
  }
}

void openFileCrossPlatform(String path) {
  if (Platform.isWindows) {
    Process.run('explorer.exe', [path]);
  } else if (Platform.isMacOS) {
    Process.run('open', [path]);
  } else if (Platform.isLinux) {
    Process.run('xdg-open', [path]);
  }
}

void showInFolderCrossPlatform(String path) {
  if (Platform.isWindows) {
    Process.run('explorer.exe', ['/select,', path]);
  } else if (Platform.isMacOS) {
    Process.run('open', ['-R', path]);
  } else if (Platform.isLinux) {
    try {
      final parent = File(path).parent.path;
      Process.run('xdg-open', [parent]);
    } catch (_) {
      Process.run('xdg-open', [path]);
    }
  }
}

