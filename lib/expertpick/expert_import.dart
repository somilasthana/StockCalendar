import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('stockcalendar/export');

/// Asks for a file that lives in Google Drive, then drops it.
///
/// Nothing is stored. A later phase will read the file.
Future<void> importExpertDriveFile(BuildContext context) async {
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
  if (proceed != true || !context.mounted) return;
  if (Theme.of(context).platform != TargetPlatform.android) {
    await _notice(context, 'Google Drive could not be opened.');
    return;
  }

  try {
    final selected = await _channel.invokeMethod<String>('openDrive');
    if (!context.mounted || selected == null || selected.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('File selected.')));
  } on PlatformException catch (error) {
    if (!context.mounted) return;
    await _notice(
      context,
      error.code == 'not_drive'
          ? 'Choose a file in Google Drive.'
          : 'Google Drive could not be opened.',
    );
  } on MissingPluginException {
    if (!context.mounted) return;
    await _notice(context, 'Google Drive could not be opened.');
  }
}

Future<void> _notice(BuildContext context, String message) {
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
