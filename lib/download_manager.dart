import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'yt_dlp_service.dart';
import 'features/downloads/data/datasources/local_database_service.dart';
import 'features/downloads/data/repositories/download_repository_impl.dart';
import 'features/downloads/domain/repositories/download_repository.dart';

class DownloadManager extends ChangeNotifier {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  late final DownloadRepository _repository;
  bool _isInit = false;

  final List<DownloadTaskModel> _tasks = [];
  final Map<String, DownloadTaskContext> _activeContexts = {};
  final Map<String, StreamSubscription> _activeSubscriptions = {};
  
  final int _maxConcurrentTasks = 1;

  List<DownloadTaskModel> get tasks => List.unmodifiable(_tasks);

  Future<void> init() async {
    if (_isInit) return;
    _repository = DownloadRepositoryImpl(LocalDatabaseService());
    await _repository.init();
    await _loadTasks();
    _isInit = true;
    // Restart tasks that were downloading when app closed, set them to queued
    for (final task in _tasks) {
      if (task.status == DownloadStatus.downloading) {
        task.updateStatus(DownloadStatus.queued);
      }
    }
    _processQueue();
  }

  void addTask(VideoItem video, String outputDirectory, {int? playlistIndex}) {
    final existingMatches = _tasks.where((t) => t.video.id == video.id);
    final existingTask = existingMatches.isEmpty ? null : existingMatches.first;
    
    if (existingTask != null) {
      if (existingTask.status != DownloadStatus.completed && existingTask.status != DownloadStatus.downloading && existingTask.status != DownloadStatus.queued) {
        // Resume task if it's paused or in error state
        existingTask.updateStatus(DownloadStatus.queued);
        existingTask.updateProgress(0, '', '', '', destinationPath: null);
        _saveTasks();
        notifyListeners();
        _processQueue();
      }
      return;
    }

    final task = DownloadTaskModel(
      id: DateTime.now().millisecondsSinceEpoch.toString() + video.id,
      video: video,
      outputDirectory: outputDirectory,
      playlistIndex: playlistIndex,
    );
    
    _tasks.add(task); // Add to bottom of queue
    _saveTasks();
    notifyListeners();
    
    _processQueue();
  }

  void removeTask(String id, {bool deleteFile = false}) {
    final matches = _tasks.where((t) => t.id == id);
    final task = matches.isEmpty ? null : matches.first;
    if (task == null) return;
    
    pauseTask(id);
    if (deleteFile && task.destinationPath != null) {
      try {
        final file = File(task.destinationPath!);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (e) {
        debugPrint('Failed to delete file: $e');
      }
    }
    
    _tasks.removeWhere((t) => t.id == id);
    _saveTasks();
    notifyListeners();
  }

  void resumeTask(String id) {
    _resumeTaskInternal(id);
    _processQueue();
  }
  
  void resumeTasks(List<String> ids) {
    for (final id in ids) {
      _resumeTaskInternal(id);
    }
    _processQueue();
  }

  void _resumeTaskInternal(String id) {
    final matches = _tasks.where((t) => t.id == id);
    if (matches.isEmpty) return;
    final task = matches.first;
    
    if (task.status == DownloadStatus.paused || task.status == DownloadStatus.error) {
      task.updateStatus(DownloadStatus.queued);
      _saveTasks();
    }
  }

  void pauseTask(String id) {
    _pauseTaskInternal(id);
    _processQueue(); // start next task if available
  }
  
  void pauseTasks(List<String> ids) {
    for (final id in ids) {
      _pauseTaskInternal(id);
    }
    _processQueue();
  }

  void _pauseTaskInternal(String id) {
    final matches = _tasks.where((t) => t.id == id);
    if (matches.isEmpty) return;
    final task = matches.first;
    
    if (task.status == DownloadStatus.downloading) {
      _activeContexts[id]?.cancel();
      _activeSubscriptions[id]?.cancel();
      _activeContexts.remove(id);
      _activeSubscriptions.remove(id);
      
      task.updateStatus(DownloadStatus.paused);
      task.updateProgress(0, '', '', '', destinationPath: null);
      _saveTasks();
      notifyListeners();
    } else if (task.status == DownloadStatus.queued) {
      task.updateStatus(DownloadStatus.paused);
      _saveTasks();
      notifyListeners();
    }
  }

  void pauseAll() {
    pauseTasks(_tasks.map((t) => t.id).toList());
  }

  void resumeAll() {
    for (final task in _tasks) {
      resumeTask(task.id);
    }
  }
  
  void reorderTasks(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _tasks.removeAt(oldIndex);
    _tasks.insert(newIndex, item);
    _saveTasks();
    notifyListeners();
  }

  void _processQueue() {
    final activeCount = _tasks.where((t) => t.status == DownloadStatus.downloading).length;
    if (activeCount >= _maxConcurrentTasks) return;
    
    var availableSlots = _maxConcurrentTasks - activeCount;

    for (final task in _tasks) {
      if (task.status == DownloadStatus.queued) {
        if (availableSlots <= 0) break;
        
        // Synchronously mark as downloading to prevent race conditions!
        task.updateStatus(DownloadStatus.downloading);
        notifyListeners();
        
        _startTask(task);
        availableSlots--;
      }
    }
  }

  Future<void> _startTask(DownloadTaskModel task) async {
    // Status is already set to downloading by _processQueue
    
    try {
      final context = await YtDlpService().download(task);
      
      // RACECONDITION FIX: If task was removed or paused while awaiting Process.start
      final stillExists = _tasks.where((t) => t.id == task.id).isNotEmpty;
      if (!stillExists || task.status == DownloadStatus.paused) {
        context.cancel();
        return;
      }
      
      _activeContexts[task.id] = context;
      
      final sub = context.progressStream.listen(
        (progress) {
          task.updateProgress(progress.percentage, progress.speed, progress.eta, progress.totalSize, destinationPath: progress.destinationPath);
        },
        onError: (e) {
          task.updateStatus(DownloadStatus.error, errorMessage: e.toString());
          // Log error for debugging
          debugPrint('Download error: ${e.toString()}');
          _cleanupTaskResources(task.id);
        },
        // Ensure final UI update if process finishes without emitting 100% progress
        onDone: () {
          if (task.status == DownloadStatus.downloading) {
            task.updateProgress(1.0, '', '', '', destinationPath: task.destinationPath);
            task.updateStatus(DownloadStatus.completed);
          }
        },
      );
      
      _activeSubscriptions[task.id] = sub;
      
      try {
        final exitCode = await context.exitCode;
        if (exitCode == 0) {
          task.updateProgress(1.0, '', '', '', destinationPath: task.destinationPath);
          task.updateStatus(DownloadStatus.completed);
        } else {
          if (task.status != DownloadStatus.paused) {
            task.updateStatus(DownloadStatus.error, errorMessage: 'Process exited with code $exitCode');
          }
        }
      } catch (e) {
        if (task.status != DownloadStatus.paused) {
          task.updateStatus(DownloadStatus.error, errorMessage: e.toString());
        }
      } finally {
        _cleanupTaskResources(task.id);
      }
      
    } catch (e) {
      task.updateStatus(DownloadStatus.error, errorMessage: e.toString());
    }
  }
  
  void _cleanupTaskResources(String id) {
    _activeSubscriptions.remove(id)?.cancel();
    _activeContexts.remove(id);
    _saveTasks();
    _processQueue();
  }

  Future<void> _saveTasks() async {
    // For this bridge implementation, we sync the in-memory list to Isar.
    // In the future pure-Riverpod Notifier, we will update individual tasks reactively.
    if (!_isInit) return;
    await _repository.clearAll();
    for (final task in _tasks) {
      await _repository.saveTask(task);
    }
  }

  Future<void> _loadTasks() async {
    try {
      final savedTasks = await _repository.getAllTasks();
      _tasks.clear();
      _tasks.addAll(savedTasks);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading tasks from Isar: $e');
    }
  }
}
