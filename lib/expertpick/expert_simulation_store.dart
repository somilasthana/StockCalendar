import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../logic/export_buys.dart';
import '../logic/import_buys.dart';
import '../models/buy_series.dart';
import '../models/expert_run.dart';

/// Widget tests have no application folder. Skip the real file there.
bool get expertFilesAvailable {
  final binding = WidgetsBinding.instance.runtimeType.toString();
  return !binding.contains('Test');
}

/// The expert simulation file. A new run replaces the previous file.
class ExpertSimulationStore {
  ExpertSimulationStore({Future<Directory> Function()? directory, this.initial})
    : _directory = directory ?? expertScripDirectory;

  final Future<Directory> Function() _directory;

  /// Buys already stored. When set, [read] returns these and skips the file.
  final List<BuySeries>? initial;

  Future<ExpertRun?> readRun() async {
    if (_skipFiles) return null;
    try {
      final file = await _planFile();
      if (!file.existsSync()) return null;
      return ExpertRun.fromJson(jsonDecode(await file.readAsString()));
    } catch (_) {
      return null;
    }
  }

  Future<List<BuySeries>> read() async {
    final preset = initial;
    if (preset != null) return preset;
    if (_skipFiles) {
      return const [];
    }
    try {
      final file = await _file();
      if (!file.existsSync()) return const [];
      final result = parseImportBuys(
        await file.readAsString(),
        existing: const [],
      );
      if (result.fileError != null) return const [];
      return result.accepted;
    } catch (_) {
      return const [];
    }
  }

  /// Writes [buys], or removes the file when the list is empty.
  ///
  /// [run] is the scrip, strategy, and amount used to build those buys.
  Future<String?> write(List<BuySeries> buys, {ExpertRun? run}) async {
    if (_skipFiles) {
      return null;
    }
    try {
      final file = await _file();
      if (buys.isEmpty) {
        if (file.existsSync()) await file.delete();
        await _removePlan();
        return null;
      }
      final document = exportBuys(buys, includeShares: true);
      if (document == null) return 'Could not save the simulation file.';
      await file.writeAsString(document.json);
      if (run != null) {
        final plan = await _planFile();
        await plan.writeAsString(jsonEncode(run.toJson()));
      }
      return null;
    } catch (_) {
      return 'Could not save the simulation file.';
    }
  }

  Future<String?> delete() async {
    if (_skipFiles) {
      return null;
    }
    try {
      final file = await _file();
      if (file.existsSync()) await file.delete();
      await _removePlan();
      return null;
    } catch (_) {
      return 'The calendar was cleared, but the saved simulation file could not be removed.';
    }
  }

  bool get _skipFiles =>
      identical(_directory, expertScripDirectory) && !expertFilesAvailable;

  Future<void> _removePlan() async {
    final plan = await _planFile();
    if (plan.existsSync()) await plan.delete();
  }

  Future<File> _planFile() async {
    final dir = await _directory();
    await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}plan.json');
  }

  Future<File> _file() async {
    final dir = await _directory();
    await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}simulation.json');
  }
}

Future<Directory> expertScripDirectory() async {
  final root = await getApplicationSupportDirectory();
  return Directory('${root.path}${Platform.pathSeparator}expert_scrip');
}
