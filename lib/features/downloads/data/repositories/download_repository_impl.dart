import 'package:isar/isar.dart';
import '../../domain/repositories/download_repository.dart';
import '../../data/datasources/local_database_service.dart';
import '../../data/models/isar_models.dart';
import '../../../../models.dart';

class DownloadRepositoryImpl implements DownloadRepository {
  final LocalDatabaseService _dbService;

  DownloadRepositoryImpl(this._dbService);

  @override
  Future<void> init() async {
    await _dbService.db;
  }

  @override
  Future<List<DownloadTaskModel>> getAllTasks() async {
    final isarTasks = await _dbService.getAllTasks();
    return isarTasks.map((isarTask) => _fromIsar(isarTask)).toList();
  }

  @override
  Future<void> saveTask(DownloadTaskModel task) async {
    final isarTask = _toIsar(task);
    await _dbService.saveTask(isarTask);
  }

  @override
  Future<void> deleteTask(String id) async {
    final isar = await _dbService.db;
    final task = await isar.downloadTaskIsars.filter().taskIdEqualTo(id).findFirst();
    if (task != null) {
      await _dbService.deleteTasks([task.id]);
    }
  }

  @override
  Future<void> clearAll() async {
    final isar = await _dbService.db;
    await isar.writeTxn(() async {
      await isar.downloadTaskIsars.clear();
    });
  }

  // --- Mappers ---
  DownloadTaskIsar _toIsar(DownloadTaskModel model) {
    return DownloadTaskIsar()
      ..taskId = model.id
      ..outputDirectory = model.outputDirectory
      ..playlistIndex = model.playlistIndex
      ..statusIndex = model.status.index
      ..progress = model.progress
      ..speed = model.speed
      ..eta = model.eta
      ..totalSize = model.totalSize
      ..errorMessage = model.errorMessage
      ..destinationPath = model.destinationPath
      ..createdAt = DateTime.now() // Ideally preserved
      ..updatedAt = DateTime.now()
      ..video = (VideoItemIsar()
        ..videoId = model.video.id
        ..title = model.video.title
        ..url = model.video.url
        ..thumbnail = model.video.thumbnail
        ..duration = model.video.duration
        ..uploader = model.video.uploader
        ..qualityIndex = model.video.quality.index);
  }

  DownloadTaskModel _fromIsar(DownloadTaskIsar isarModel) {
    return DownloadTaskModel(
      id: isarModel.taskId,
      outputDirectory: isarModel.outputDirectory,
      playlistIndex: isarModel.playlistIndex,
      status: DownloadStatus.values[isarModel.statusIndex],
      progress: isarModel.progress,
      destinationPath: isarModel.destinationPath,
      video: VideoItem(
        id: isarModel.video.videoId,
        title: isarModel.video.title,
        url: isarModel.video.url,
        thumbnail: isarModel.video.thumbnail,
        duration: isarModel.video.duration,
        uploader: isarModel.video.uploader,
        quality: VideoQuality.values[isarModel.video.qualityIndex],
      ),
    )..updateProgress(
        isarModel.progress,
        isarModel.speed,
        isarModel.eta,
        isarModel.totalSize,
        destinationPath: isarModel.destinationPath,
      );
  }
}
