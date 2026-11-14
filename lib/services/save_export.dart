import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _exportChannel = MethodChannel('stockcalendar/export');

/// Opens a place to store [bytes].
///
/// Android's save screen starts in Downloads. On that platform this asks the
/// screen to open in Google Drive instead. Other platforms use the system
/// save dialog, which lists Drive when the Drive app is installed.
Future<Uri?> saveExportFile({
  required String fileName,
  required Uint8List bytes,
}) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    final saved = await _exportChannel.invokeMethod<String>('saveJson', {
      'fileName': fileName,
      'bytes': bytes,
    });
    if (saved == null || saved.isEmpty) return null;
    return Uri.tryParse(saved);
  }
  return FilePicker.saveFile(
    dialogTitle: 'Export buys',
    fileName: fileName,
    mimeType: 'application/json',
    bytes: bytes,
  );
}
