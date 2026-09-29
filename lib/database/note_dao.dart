import 'package:floor/floor.dart';
import 'note.dart';

@dao
abstract class NoteDao {

  @Query('SELECT * FROM Note')
  Stream<List<Note>> findAllNotesAsStream();

  @insert
  Future<int> insertNote(Note note);

  @update
  Future<int> updateNote(Note note);

  @delete
  Future<int> deleteNote(Note note);

  @Query('DELETE FROM Note')
  Future<void> deleteAllNotes();
}