import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class DownloadTaskContext {
  final Stream<DownloadProgress> progressStream;
  final Future<void> Function() cancel;
  final Future<int> exitCode;

  DownloadTaskContext({required this.progressStream, required this.cancel, required this.exitCode});
}

class DownloadProgress {
  final double percentage;
  final String speed;
  final String eta;
  final String totalSize;
  final String rawLog;
  final String? destinationPath;

  DownloadProgress(this.percentage, this.speed, this.eta, this.totalSize, this.rawLog, {this.destinationPath});
}

class YtDlpService {
  static final YtDlpService _instance = YtDlpService._internal();
  factory YtDlpService() => _instance;
  YtDlpService._internal();

  String? _executablePath;
  String? _ffmpegPath;
  String? _aria2cPath;
  final Dio _dio = Dio();

  Future<void> init(void Function(double, String) onInitProgress) async {
    final supportDir = await getApplicationSupportDirectory();
    final isWin = Platform.isWindows;
    final isMac = Platform.isMacOS;

    final ytDlpName = isWin ? 'yt-dlp.exe' : 'yt-dlp';
    final ffmpegName = isWin ? 'ffmpeg.exe' : 'ffmpeg';
    final aria2cName = isWin ? 'aria2c.exe' : 'aria2c';

    _executablePath = p.join(supportDir.path, ytDlpName);
    _ffmpegPath = p.join(supportDir.path, ffmpegName);
    _aria2cPath = p.join(supportDir.path, aria2cName);

    final ytDlpFile = File(_executablePath!);
    if (!await ytDlpFile.exists()) {
      onInitProgress(0.0, 'Downloading yt-dlp core...');
      final ytDlpUrl = isWin
          ? 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe'
          : (isMac
              ? 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos'
              : 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp');
      await _downloadFile(
        ytDlpUrl,
        _executablePath!,
        (p) => onInitProgress(p * 0.2, 'Downloading yt-dlp core...'),
      );
      if (!isWin) {
        try {
          await Process.run('chmod', ['+x', _executablePath!]);
        } catch (_) {}
      }
    }

    if (isWin) {
      final ffmpegFile = File(_ffmpegPath!);
      if (!await ffmpegFile.exists()) {
        onInitProgress(0.2, 'Downloading FFmpeg (Required for Audio & Thumbnails)...');
        final zipPath = p.join(supportDir.path, 'ffmpeg.zip');
        
        await _downloadFile(
          'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip',
          zipPath,
          (p) => onInitProgress(0.2 + (p * 0.4), 'Downloading FFmpeg...'),
        );
        onInitProgress(0.6, 'Extracting FFmpeg...');
        await _extractZipFile(zipPath, _ffmpegPath!, 'bin/ffmpeg.exe');
      }

      final aria2cFile = File(_aria2cPath!);
      if (!await aria2cFile.exists()) {
        onInitProgress(0.7, 'Downloading Aria2c (10x Speed Engine)...');
        final zipPath = p.join(supportDir.path, 'aria2c.zip');
        await _downloadFile(
          'https://github.com/aria2/aria2/releases/download/release-1.37.0/aria2-1.37.0-win-64bit-build1.zip',
          zipPath,
          (p) => onInitProgress(0.7 + (p * 0.2), 'Downloading Aria2c...'),
        );
        onInitProgress(0.9, 'Extracting Aria2c...');
        await _extractZipFile(zipPath, _aria2cPath!, 'aria2c.exe');
      }
    }
    
    onInitProgress(1.0, 'Ready');
  }

  Future<void> _extractZipFile(String zipPath, String destPath, String targetFileName) async {
    final bytes = File(zipPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    
    for (final file in archive) {
      if (file.name.endsWith(targetFileName)) {
        final data = file.content as List<int>;
        File(destPath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
        break;
      }
    }
    try { File(zipPath).deleteSync(); } catch (_) {}
  }

  Future<void> _downloadFile(String url, String destPath, void Function(double) onProgress) async {
    await _dio.download(
      url,
      destPath,
      onReceiveProgress: (count, total) {
        if (total != -1) {
          onProgress(count / total);
        }
      },
    );
  }

  Future<MediaGroup> fetchMetadata(String url, {VideoQuality quality = VideoQuality.best}) async {
    if (_executablePath == null) throw Exception('yt-dlp is not initialized');

    final result = await Process.run(_executablePath!, [
      '-J',
      '--flat-playlist',
      url
    ]);

    if (result.exitCode != 0) {
      throw Exception('Failed to fetch metadata: ${result.stderr}');
    }

    final jsonStr = result.stdout as String;
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    final playlistTitle = data['title'] ?? 'Unknown Source';

    if (data.containsKey('entries')) {
      final List<dynamic> entries = data['entries'];
      final playlistUploader = data['channel'] ?? data['uploader'] ?? data['uploader_id'] ?? data['channel_id'] ?? 'Unknown Channel';
      
      final items = entries.map((e) {
        if (e['channel'] == null && e['uploader'] == null) {
          e['uploader'] = playlistUploader;
        }
        return VideoItem.fromJson(e, quality: quality);
      }).toList();
      return MediaGroup(id: url, title: playlistTitle, uploader: playlistUploader, items: items);
    } else {
      final item = VideoItem.fromJson(data, quality: quality);
      return MediaGroup(id: url, title: item.title, uploader: item.uploader, items: [item]);
    }
  }

  Future<DownloadTaskContext> download(DownloadTaskModel taskModel) async {
    if (_executablePath == null) throw Exception('yt-dlp is not initialized');
    
    final prefs = await SharedPreferences.getInstance();
    final browser = prefs.getString('browser') ?? 'None';

    final args = <String>[
      taskModel.video.url,
      '--newline',
      '--no-colors',
      
      if (browser != 'None') ...[
        '--cookies-from-browser', browser,
      ],
      
      // 1. Speed Engine (Native Multi-threading)
      '-N', '16', // 16 concurrent fragments
      
      // 2. Metadata & Cover Art Embedding
      '--embed-metadata',
      '--parse-metadata', 'playlist_index:%(track_number)s',
      
      // 3. Chapters
      '--embed-chapters',
      
      // 4. Basic Anti-Bot (Phase 1)
      '--min-sleep-interval', '1',
      '--max-sleep-interval', '4',
      '--no-warnings',
      
      // Paths
      '--ffmpeg-location', _ffmpegPath!,
      '-o',
      p.join(taskModel.outputDirectory, '${taskModel.playlistIndex != null ? (taskModel.playlistIndex! + 1).toString().padLeft(3, '0') + '_' : ''}%(title)s.%(ext)s'),
      // Print the final file path after all post-processing (merge, embed thumbnail, etc.)
      '--print', 'after_move:filepath',
    ];

    switch (taskModel.video.quality) {
      case VideoQuality.best:
        args.addAll(['-f', 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best']);
        break;
      case VideoQuality.p1080:
        args.addAll(['-f', 'bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[height<=1080]/best']);
        break;
      case VideoQuality.p720:
        args.addAll(['-f', 'best[height<=720]/best']);
        break;
      case VideoQuality.p480:
        args.addAll(['-f', 'best[height<=480]/best']);
        break;
      case VideoQuality.audio:
        args.addAll(['-f', 'bestaudio', '-x', '--audio-format', 'mp3']);
        break;
    }

    final process = await Process.start(
      _executablePath!, 
      args,
      environment: {'PYTHONUNBUFFERED': '1'},
    );
    
    final stderrBuffer = StringBuffer();
    process.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen((data) {
      stderrBuffer.write(data);
    });

    String? currentDestination;

    String buffer = '';
    
    final stream = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .expand((chunk) {
          buffer += chunk;
          final lines = buffer.split(RegExp(r'[\r\n]+'));
          buffer = lines.removeLast();
          return lines;
        })
        .where((line) => line.isNotEmpty)
        .map((line) {
          if (line.contains('ERROR:')) {
            throw Exception(line);
          }
          
          if (line.contains('[download] Destination:')) {
             currentDestination = line.split('[download] Destination:').last.trim().replaceAll('"', '');
          } else if (line.contains('[Merger] Merging formats into')) {
             currentDestination = line.split('[Merger] Merging formats into').last.trim().replaceAll('"', '');
          } else if (!line.startsWith('[') && !line.startsWith('WARNING') && line.isNotEmpty && (line.endsWith('.mp4') || line.endsWith('.mkv') || line.endsWith('.webm') || line.endsWith('.mp3') || line.endsWith('.m4a'))) {
             // --print after_move:filepath output — the exact final file after all processing
             currentDestination = line.trim().replaceAll('"', '');
             return DownloadProgress(1.0, '', '', '', 'Completed', destinationPath: currentDestination);
          }
          
          return _parseProgress(line, currentDestination);
        })
        .where((progress) => progress != null)
        .cast<DownloadProgress>();

    return DownloadTaskContext(
      progressStream: stream,
      exitCode: process.exitCode,
      cancel: () async {
        if (Platform.isWindows) {
          Process.runSync('taskkill', ['/F', '/T', '/PID', process.pid.toString()]);
        } else {
          process.kill();
        }
      },
    );
  }

  DownloadProgress? _parseProgress(String line, String? currentDestination) {
    if (line.startsWith('[download]')) {
      final RegExp progressRegex = RegExp(r'\[download\]\s+([\d\.]+)%\s+of\s+[~]?([\d\.\w]+)(?:\s+at\s+([^\s]+(?:\sB/s)?))?(?:\s+(?:ETA|in)\s+([a-zA-Z0-9:]+))?');
      final match = progressRegex.firstMatch(line);
      
      if (match != null) {
        final percentage = double.tryParse(match.group(1) ?? '0') ?? 0;
        final totalSize = match.group(2) ?? '';
        final speed = match.group(3) ?? '';
        final eta = match.group(4) ?? '';
        return DownloadProgress(percentage / 100, speed, eta, totalSize, line, destinationPath: currentDestination);
      }

      if (line.contains('100%')) {
        final RegExp sizeRegex = RegExp(r'\[download\]\s+100%\s+of\s+[~]?([\d\.\w]+)');
        final sizeMatch = sizeRegex.firstMatch(line);
        final size = sizeMatch != null ? (sizeMatch.group(1) ?? '') : '';
        return DownloadProgress(1, '', '', size, 'Completed', destinationPath: currentDestination);
      }
    }

    if (line.startsWith('[#')) {
      // Aria2c regex, making ETA optional since it doesn't always appear
      final RegExp ariaRegex = RegExp(r'\[#\w+\s+([\d\.\w]+)/([\d\.\w]+)\(([\d\.]+)%\).*?DL:([\d\.\w]+)(?:.*?ETA:([\d\w]+))?.*\]');
      final match = ariaRegex.firstMatch(line);
      if (match != null) {
        final percentage = double.tryParse(match.group(3) ?? '0') ?? 0;
        final speed = match.group(4) ?? '';
        final eta = match.group(5) ?? '';
        final totalSize = match.group(2) ?? '';
        return DownloadProgress(percentage / 100, '$speed/s', eta, totalSize, line, destinationPath: currentDestination);
      }
    }

    return null;
  }
}
