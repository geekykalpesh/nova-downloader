import 'package:isar/isar.dart';

part 'isar_models.g.dart';

@collection
class DownloadTaskIsar {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String taskId; // String ID to match existing logic

  late VideoItemIsar video;
  
  late String outputDirectory;
  int? playlistIndex;
  
  // Enums stored as indices
  late byte statusIndex;
  
  late double progress;
  late String speed;
  late String eta;
  late String totalSize;
  late String errorMessage;
  String? destinationPath;
  
  late DateTime createdAt;
  late DateTime updatedAt;
}

@embedded
class VideoItemIsar {
  late String videoId;
  late String title;
  late String url;
  String? thumbnail;
  String? duration;
  late String uploader;
  late byte qualityIndex;
}
