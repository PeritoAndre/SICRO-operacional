import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/occurrence.dart';

abstract class OccurrenceStorage {
  Future<List<FieldOccurrence>> loadOccurrences();

  Future<void> saveOccurrences(List<FieldOccurrence> occurrences);
}

class MemoryOccurrenceStorage implements OccurrenceStorage {
  List<FieldOccurrence> _occurrences;

  MemoryOccurrenceStorage([List<FieldOccurrence>? initial])
    : _occurrences = initial ?? [];

  @override
  Future<List<FieldOccurrence>> loadOccurrences() async {
    return [..._occurrences];
  }

  @override
  Future<void> saveOccurrences(List<FieldOccurrence> occurrences) async {
    _occurrences = [...occurrences];
  }
}

class FileOccurrenceStorage implements OccurrenceStorage {
  FileOccurrenceStorage({Future<Directory> Function()? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directoryProvider;

  @override
  Future<List<FieldOccurrence>> loadOccurrences() async {
    final file = await _storageFile();
    if (!await file.exists()) {
      return [];
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw);
    final root = _map(decoded);
    final items = root['ocorrencias'];
    if (items is! List) {
      return [];
    }

    return items
        .map((item) => FieldOccurrence.fromJson(_map(item)))
        .where((occurrence) => occurrence.id.isNotEmpty)
        .toList();
  }

  @override
  Future<void> saveOccurrences(List<FieldOccurrence> occurrences) async {
    final file = await _storageFile();
    final payload = {
      'formato': 'sicrocampo_local_store',
      'versao': '0.1',
      'salvo_em': DateTime.now().toIso8601String(),
      'ocorrencias': occurrences
          .map((occurrence) => occurrence.toJson())
          .toList(),
    };
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(payload), flush: true);
  }

  Future<File> _storageFile() async {
    final base = await _directoryProvider();
    final dir = Directory('${base.path}${Platform.pathSeparator}sicro_campo');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}occurrences.json');
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}
