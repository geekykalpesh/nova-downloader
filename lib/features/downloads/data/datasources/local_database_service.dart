import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/isar_models.dart';

class LocalDatabaseService {
  late Future<Isar> db;

  LocalDatabaseService() {
    db = _initDb();
  }

  Future<Isar> _initDb() async {
    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationSupportDirectory();
      return await Isar.open(
        [DownloadTaskIsarSchema],
        directory: dir.path,
        inspector: true,
      );
    }
    return Future.value(Isar.getInstance());
  }

  Future<List<DownloadTaskIsar>> getAllTasks() async {
    final isar = await db;
    return await isar.downloadTaskIsars.where().findAll();
  }

  Future<void> saveTask(DownloadTaskIsar task) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.downloadTaskIsars.put(task);
    });
  }

  Future<void> deleteTasks(List<int> ids) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.downloadTaskIsars.deleteAll(ids);
    });
  }
}
