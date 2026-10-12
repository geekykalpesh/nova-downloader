import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../download_manager.dart'; 
import '../../data/datasources/local_database_service.dart';
import '../../domain/repositories/download_repository.dart';
import '../../data/repositories/download_repository_impl.dart';

// --- Clean Architecture Providers ---

final localDatabaseProvider = Provider<LocalDatabaseService>((ref) {
  return LocalDatabaseService();
});

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  final dbService = ref.watch(localDatabaseProvider);
  return DownloadRepositoryImpl(dbService);
});

// --- Legacy Bridge Providers ---
// A temporary bridge provider to expose the DownloadManager to the Riverpod ecosystem.
final downloadManagerProvider = Provider<DownloadManager>((ref) {
  return DownloadManager();
});

final downloadTasksProvider = ChangeNotifierProvider<DownloadManager>((ref) {
  return DownloadManager();
});
