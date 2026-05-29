import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/official_document.dart';

abstract class OfficialDocumentStorage {
  Future<List<OfficialDocument>> loadDocuments();

  Future<void> saveDocuments(List<OfficialDocument> documents);
}

class MemoryOfficialDocumentStorage implements OfficialDocumentStorage {
  MemoryOfficialDocumentStorage([List<OfficialDocument>? initial])
    : _documents = initial ?? [];

  List<OfficialDocument> _documents;

  @override
  Future<List<OfficialDocument>> loadDocuments() async {
    return [..._documents];
  }

  @override
  Future<void> saveDocuments(List<OfficialDocument> documents) async {
    _documents = [...documents];
  }
}

class FileOfficialDocumentStorage implements OfficialDocumentStorage {
  FileOfficialDocumentStorage({Future<Directory> Function()? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directoryProvider;

  @override
  Future<List<OfficialDocument>> loadDocuments() async {
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
    final items = root['oficios'];
    if (items is! List) {
      return [];
    }
    return items
        .map((item) => OfficialDocument.fromJson(_map(item)))
        .where((document) => document.id.isNotEmpty)
        .toList();
  }

  @override
  Future<void> saveDocuments(List<OfficialDocument> documents) async {
    final file = await _storageFile();
    final payload = {
      'formato': 'sicro_operacional_oficios_local_store',
      'versao': '0.1',
      'salvo_em': DateTime.now().toIso8601String(),
      'oficios': documents.map((document) => document.toJson()).toList(),
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
    return File('${dir.path}${Platform.pathSeparator}official_documents.json');
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
