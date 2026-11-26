import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'expert_scrip.dart';
import 'expert_simulation_store.dart';

const _channel = MethodChannel('stockcalendar/export');

/// The expert file chosen from Google Drive.
///
/// The phone keeps the file. Expert Opinion reads it instead of the sample.
class ExpertImportStore {
  ExpertImportStore({Future<Directory> Function()? directory})
    : _directory = directory ?? expertScripDirectory;

  final Future<Directory> Function() _directory;
  List<ExpertScrip>? _memory;

  Future<List<ExpertScrip>> read() async {
    final cached = _memory;
    if (cached != null) return cached;
    if (_skipFiles) {
      _memory = const [];
      return _memory!;
    }
    try {
      final file = await _file();
      if (!file.existsSync()) {
        _memory = const [];
        return _memory!;
      }
      final scrips = parseExpertList(await file.readAsString());
      _memory = scrips;
      return scrips;
    } catch (_) {
      return const [];
    }
  }

  /// Keeps [raw] when it is a list of expert scrips.
  ///
  /// Returns a message when the file cannot replace the current list.
  Future<String?> save(String raw) async {
    final List<ExpertScrip> scrips;
    try {
      scrips = parseExpertList(raw);
    } catch (_) {
      return 'The file could not be read.';
    }
    if (!_skipFiles) {
      try {
        final file = await _file();
        await file.writeAsString(raw);
      } catch (_) {
        return 'The file could not be saved.';
      }
    }
    _memory = scrips;
    return null;
  }

  bool get _skipFiles =>
      identical(_directory, expertScripDirectory) && !expertFilesAvailable;

  Future<File> _file() async {
    final dir = await _directory();
    await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}import.json');
  }
}

/// The file chosen from Google Drive, or why it was not kept.
class ExpertDrivePick {
  const ExpertDrivePick._({this.error, required this.cancelled});

  const ExpertDrivePick.cancelled() : this._(cancelled: true);

  const ExpertDrivePick.saved() : this._(cancelled: false);

  const ExpertDrivePick.failed(String message)
    : this._(error: message, cancelled: false);

  final String? error;
  final bool cancelled;
}

/// Opens Google Drive and keeps the chosen expert file.
///
/// A closed picker is [ExpertDrivePick.cancelled]. A file that cannot be read
/// is [ExpertDrivePick.failed].
Future<ExpertDrivePick> pickExpertDriveFile(
  BuildContext context, {
  required ExpertImportStore store,
}) async {
  if (Theme.of(context).platform != TargetPlatform.android) {
    return const ExpertDrivePick.failed('Google Drive could not be opened.');
  }
  try {
    final selected = await _channel.invokeMethod<String>('openDrive');
    if (!context.mounted || selected == null) {
      return const ExpertDrivePick.cancelled();
    }
    final saved = await store.save(selected);
    if (saved != null) return ExpertDrivePick.failed(saved);
    return const ExpertDrivePick.saved();
  } on PlatformException catch (error) {
    return ExpertDrivePick.failed(
      error.code == 'not_drive'
          ? 'Choose a file in Google Drive.'
          : error.code == 'unreadable'
          ? 'The file could not be read.'
          : 'Google Drive could not be opened.',
    );
  } on MissingPluginException {
    return const ExpertDrivePick.failed('Google Drive could not be opened.');
  }
}

/// Asks for a file that lives in Google Drive, then keeps its expert scrips.
///
/// True when a new file replaced the saved list.
Future<bool> importExpertDriveFile(
  BuildContext context, {
  required ExpertImportStore store,
}) async {
  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: const Text(
        'Import the fresh expert pick file from your google drive',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  if (proceed != true || !context.mounted) return false;
  final picked = await pickExpertDriveFile(context, store: store);
  if (!context.mounted || picked.cancelled) return false;
  final error = picked.error;
  if (error != null) {
    await showExpertNotice(context, error);
    return false;
  }
  final count = (await store.read()).length;
  if (!context.mounted) return false;
  await showExpertNotice(context, _importedMessage(count));
  return true;
}

String _importedMessage(int count) {
  if (count == 1) return '1 expert scrip was imported.';
  return '$count expert scrips were imported.';
}

Future<void> showExpertNotice(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Import'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
