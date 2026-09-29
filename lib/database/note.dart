import 'package:floor/floor.dart';

@entity
class Note {
  @PrimaryKey(autoGenerate: true)
  final int? id;

  final String title;
  final String content;
  final String? location;

  Note({
    this.id,
    required this.title,
    required this.content,
    this.location,
  });
}