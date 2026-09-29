import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../database/app_database.dart';
import '../database/note.dart';

class AddNoteScreen extends StatefulWidget {
  final AppDatabase database;
  const AddNoteScreen({super.key, required this.database});

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _LocationException implements Exception {
  final String message;
  final String? actionLabel;
  final Future<bool> Function()? action;
  _LocationException(this.message, {this.actionLabel, this.action});

  factory _LocationException.serviceOff() => _LocationException(
    'Location is turned off on your device.',
    actionLabel: 'Turn on',
    action: Geolocator.openLocationSettings,
  );
}

class _LocationResult {
  final String text;
  final String? notice;
  const _LocationResult(this.text, {this.notice});
}

class _AddNoteScreenState extends State<AddNoteScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final Geocoding _geocoding = Geocoding();

  bool _useLocation = false;
  bool _isFetchingLocation = false;
  String? _locationStr;
  int _locationRequestId = 0;

  bool _retryOnResume = false;

  bool _isSaving = false;

  bool get _canSave =>
      !_isSaving &&
      !_isFetchingLocation &&
      (!_useLocation || _locationStr != null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _retryOnResume) {
      _retryOnResume = false;
      if (mounted && !_useLocation && !_isFetchingLocation && !_isSaving) {
        _onLocationToggled(true);
      }
    }
  }

  Future<_LocationResult> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw _LocationException.serviceOff();

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw _LocationException('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw _LocationException(
        'Location permission is blocked. Allow it in Settings.',
        actionLabel: 'Settings',
        action: Geolocator.openAppSettings,
      );
    }

    final Position position;
    try {
      position = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 15),
      );
    } on TimeoutException {
      throw _LocationException(
        "Couldn't find your location in time. Try again.",
      );
    } on LocationServiceDisabledException {
      // Turned off while we were waiting.
      throw _LocationException.serviceOff();
    } on PermissionDeniedException {
      throw _LocationException('Location permission was denied.');
    }

    return _addressFromPosition(position);
  }

  Future<_LocationResult> _addressFromPosition(Position position) async {
    final coords = '${position.latitude}, ${position.longitude}';
    try {
      final placemarks = await _geocoding
          .placemarkFromCoordinates(position.latitude, position.longitude)
          .timeout(const Duration(seconds: 10));

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [p.street, p.subLocality, p.locality, p.country]
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();
        if (parts.isNotEmpty) return _LocationResult(parts.join(', '));
      }
      return _LocationResult(
        coords,
        notice: 'No address found for this spot. Using coordinates instead.',
      );
    } catch (_) {
      return _LocationResult(
        coords,
        notice:
            "Couldn't look up the address (check your internet). "
            'Using coordinates instead.',
      );
    }
  }

  Future<void> _onLocationToggled(bool value) async {
    final requestId = ++_locationRequestId;

    if (!value) {
      setState(() {
        _useLocation = false;
        _isFetchingLocation = false;
        _locationStr = null;
      });
      return;
    }

    setState(() {
      _useLocation = true;
      _isFetchingLocation = true;
      _locationStr = null;
    });

    try {
      final result = await _getCurrentLocation();
      if (!mounted || requestId != _locationRequestId) return;
      setState(() {
        _locationStr = result.text;
        _isFetchingLocation = false;
      });
      if (result.notice != null) _showMessage(result.notice!);
    } catch (e) {
      if (!mounted || requestId != _locationRequestId) return;
      setState(() {
        _useLocation = false;
        _isFetchingLocation = false;
      });
      final error = e is _LocationException
          ? e
          : _LocationException("Couldn't get your location. Try again.");
      _showLocationError(error);
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _showLocationError(_LocationException error) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(error.message),
        action: error.action == null
            ? null
            : SnackBarAction(
                label: error.actionLabel ?? 'Open',
                onPressed: () {
                  _retryOnResume = true;
                  error.action!();
                },
              ),
      ),
    );
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isSaving = true);
    try {
      final newNote = Note(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        location: _useLocation ? _locationStr : null,
      );
      await widget.database.noteDao.insertNote(newNote);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final String locationSubtitle = _isFetchingLocation
        ? 'Getting your location…'
        : _locationStr != null
        ? _locationStr!
        : 'Saves your address with this note';

    return Scaffold(
      appBar: AppBar(
        title: const Text('New note'),
        actions: [
          if (_isSaving)
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
              tooltip: 'Save note',
              icon: const Icon(Icons.check),
              color: scheme.primary,
              onPressed: _canSave ? _saveNote : null,
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
                enabled: !_isSaving,
                autofocus: true,
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
                enabled: !_isSaving,
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
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SwitchListTile(
                  value: _useLocation,
                  onChanged: _isSaving ? null : _onLocationToggled,
                  secondary: _isFetchingLocation
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: Padding(
                            padding: EdgeInsets.all(2),
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        )
                      : Icon(
                          _locationStr != null
                              ? Icons.location_on
                              : Icons.location_off_outlined,
                          color: _locationStr != null ? scheme.primary : null,
                        ),
                  title: const Text('Attach current location'),
                  subtitle: Text(locationSubtitle),
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
