import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../database/note.dart';

class EditNoteScreen extends StatefulWidget {
  final AppDatabase database;
  final Note note;
  const EditNoteScreen({super.key, required this.database, required this.note});

  @override
  State<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _updateNote() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isBusy = true);

    final updatedNote = Note(
      id: widget.note.id,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      location: widget.note.location,
    );
    await widget.database.noteDao.updateNote(updatedNote);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteNote() async {
    setState(() => _isBusy = true);

    final db = widget.database;
    final note = widget.note;
    final messenger = ScaffoldMessenger.of(context);

    await db.noteDao.deleteNote(note);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Note deleted'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await db.noteDao.insertNote(note);
          },
        ),
      ),
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit note'),
        actions: [
          if (_isBusy)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else
            IconButton(
              tooltip: 'Save changes',
              icon: const Icon(Icons.check),
              color: scheme.primary,
              onPressed: _updateNote,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              TextFormField(
                controller: _titleController,
                enabled: !_isBusy,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Add a title' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _contentController,
                enabled: !_isBusy,
                minLines: 6,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Write something in your note'
                    : null,
              ),
              if (widget.note.location != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.note.location!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _deleteNote,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete note'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
