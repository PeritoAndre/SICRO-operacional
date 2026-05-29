import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../domain/models/official_document.dart';
import 'official_document_storage.dart';

class OfficialDocumentRepository extends ChangeNotifier {
  OfficialDocumentRepository({OfficialDocumentStorage? storage})
    : _storage = storage ?? MemoryOfficialDocumentStorage();

  final OfficialDocumentStorage _storage;
  final List<OfficialDocument> _documents = [];
  bool _loaded = false;
  String? _lastError;

  bool get loaded => _loaded;

  String? get lastError => _lastError;

  List<OfficialDocument> get documents {
    final copy = [..._documents];
    copy.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return copy;
  }

  OfficialDocument? findById(String id) {
    for (final document in _documents) {
      if (document.id == id) {
        return document;
      }
    }
    return null;
  }

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    try {
      final loadedDocuments = await _storage.loadDocuments();
      _documents
        ..clear()
        ..addAll(loadedDocuments);
      _lastError = null;
    } catch (error) {
      _lastError = error.toString();
      _documents.clear();
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> saveDocument(OfficialDocument document) async {
    final now = DateTime.now();
    final index = _documents.indexWhere((item) => item.id == document.id);
    final updated = document.copyWith(updatedAt: now);
    if (index == -1) {
      _documents.add(updated);
    } else {
      _documents[index] = updated;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> restoreDocuments(List<OfficialDocument> documents) async {
    _documents
      ..clear()
      ..addAll(documents);
    notifyListeners();
    await _persist();
  }

  Future<OfficialDocument?> deleteDocument(String id) async {
    final index = _documents.indexWhere((document) => document.id == id);
    if (index == -1) {
      return null;
    }
    final removed = _documents.removeAt(index);
    notifyListeners();
    try {
      await _deleteImage(removed.imagePath);
      await _persist();
      _lastError = null;
      return removed;
    } catch (error) {
      _documents.insert(index, removed);
      _lastError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _persist() async {
    try {
      await _storage.saveDocuments(_documents);
      _lastError = null;
    } catch (error) {
      _lastError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _deleteImage(String imagePath) async {
    if (imagePath.trim().isEmpty) {
      return;
    }
    final file = File(imagePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
