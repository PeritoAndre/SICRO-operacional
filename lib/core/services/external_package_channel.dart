import 'package:flutter/services.dart';

class ExternalPackageFile {
  const ExternalPackageFile({
    required this.ok,
    required this.filePath,
    required this.fileName,
    required this.originalName,
    required this.sourceUri,
    required this.mimeType,
    required this.sizeBytes,
    required this.receivedAt,
    this.nativeError,
  });

  final bool ok;
  final String filePath;
  final String fileName;
  final String originalName;
  final String sourceUri;
  final String mimeType;
  final int sizeBytes;
  final DateTime receivedAt;
  final String? nativeError;

  factory ExternalPackageFile.fromMap(Map<Object?, Object?> map) {
    final receivedAtMillis = _int(map['receivedAtMillis']);
    return ExternalPackageFile(
      ok: map['ok'] == true,
      filePath: _string(map['filePath']),
      fileName: _string(map['fileName']),
      originalName: _string(map['originalName']),
      sourceUri: _string(map['sourceUri']),
      mimeType: _string(map['mimeType']),
      sizeBytes: _int(map['sizeBytes']),
      receivedAt: receivedAtMillis > 0
          ? DateTime.fromMillisecondsSinceEpoch(receivedAtMillis)
          : DateTime.now(),
      nativeError: _nullableString(map['error']),
    );
  }
}

class ExternalPackageChannel {
  ExternalPackageChannel({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel(
            'br.gov.ap.policiacientifica.sicro_operacional/package_import',
          );

  final MethodChannel _channel;

  void listen({
    required Future<void> Function(ExternalPackageFile package) onPackage,
  }) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'packageReceived') {
        return null;
      }
      final package = _packageFrom(call.arguments);
      if (package != null) {
        await onPackage(package);
      }
      return null;
    });
  }

  Future<ExternalPackageFile?> getInitialPackage() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('getInitialPackage');
      return _packageFrom(raw);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  ExternalPackageFile? _packageFrom(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    return ExternalPackageFile.fromMap(Map<Object?, Object?>.from(raw));
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
