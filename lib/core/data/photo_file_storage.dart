import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/field_photo.dart';

class PhotoFileStorage {
  PhotoFileStorage({Future<Directory> Function()? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directoryProvider;

  Future<FieldPhoto> saveCapturedPhoto({
    required String occurrenceId,
    required XFile capturedFile,
    required PhotoCategory category,
  }) async {
    final photoId = _newPhotoId();
    final source = File(capturedFile.path);
    final extension = _extensionFor(capturedFile.path);
    final photosDir = await _photosDirectory(occurrenceId);
    final destination = File(
      '${photosDir.path}${Platform.pathSeparator}$photoId$extension',
    );

    await source.copy(destination.path);
    final sha = await _sha256(destination);

    return FieldPhoto(
      id: photoId,
      filePath: destination.path,
      category: category,
      capturedAt: DateTime.now(),
      sha256: sha,
    );
  }

  Future<void> deletePhoto(FieldPhoto photo) async {
    final file = File(photo.filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deleteOccurrencePhotos({
    required String occurrenceId,
    required Iterable<FieldPhoto> photos,
  }) async {
    for (final photo in photos) {
      await deletePhoto(photo);
    }

    final dir = await _photosDirectoryForDelete(occurrenceId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<Directory> _photosDirectory(String occurrenceId) async {
    final dir = await _photosDirectoryForDelete(occurrenceId);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _photosDirectoryForDelete(String occurrenceId) async {
    final base = await _directoryProvider();
    final safeOccurrenceId = occurrenceId.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    return Directory(
      '${base.path}${Platform.pathSeparator}sicro_campo'
      '${Platform.pathSeparator}photos'
      '${Platform.pathSeparator}$safeOccurrenceId',
    );
  }

  String _newPhotoId() {
    return 'foto_${DateTime.now().microsecondsSinceEpoch}';
  }

  String _extensionFor(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) {
      return '.jpg';
    }
    final extension = path.substring(dot).toLowerCase();
    if (extension.length > 6) {
      return '.jpg';
    }
    return extension;
  }

  Future<String> _sha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return base64Url.encode(digest.bytes);
  }
}
