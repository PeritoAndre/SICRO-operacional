import 'package:flutter/services.dart';

class PickedDocumentFile {
  const PickedDocumentFile({
    required this.ok,
    required this.filePath,
    required this.fileName,
    required this.originalName,
    required this.mimeType,
    required this.sizeBytes,
    this.nativeError,
  });

  final bool ok;
  final String filePath;
  final String fileName;
  final String originalName;
  final String mimeType;
  final int sizeBytes;
  final String? nativeError;

  factory PickedDocumentFile.fromMap(Map<Object?, Object?> map) {
    return PickedDocumentFile(
      ok: map['ok'] == true,
      filePath: _string(map['filePath']),
      fileName: _string(map['fileName']),
      originalName: _string(map['originalName']),
      mimeType: _string(map['mimeType']),
      sizeBytes: _int(map['sizeBytes']),
      nativeError: _nullableString(map['error']),
    );
  }
}

class DocumentPickerChannel {
  DocumentPickerChannel({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel(
            'br.gov.ap.policiacientifica.sicro_operacional/document_picker',
          );

  final MethodChannel _channel;

  Future<PickedDocumentFile?> pickPdf() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('pickPdf');
      if (raw is! Map) {
        return null;
      }
      return PickedDocumentFile.fromMap(Map<Object?, Object?>.from(raw));
    } on MissingPluginException {
      return null;
    }
  }

  Future<PickedDocumentFile?> pickBackup() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('pickBackup');
      if (raw is! Map) {
        return null;
      }
      return PickedDocumentFile.fromMap(Map<Object?, Object?>.from(raw));
    } on MissingPluginException {
      return null;
    }
  }
}

String _string(Object? value) => value is String ? value : '';

String? _nullableString(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return value;
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  return 0;
}
