import '../../../../models.dart';

abstract class DownloadRepository {
  Future<void> init();
  Future<List<DownloadTaskModel>> getAllTasks();
  Future<void> saveTask(DownloadTaskModel task);
  Future<void> deleteTask(String id);
  Future<void> clearAll();
}
