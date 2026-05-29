import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'official_document_parser.dart';

class OfficialDocumentScanDraft {
  const OfficialDocumentScanDraft({
    required this.id,
    required this.imagePath,
    required this.imageSha256,
    required this.extractedText,
    required this.extraction,
  });

  final String id;
  final String imagePath;
  final String imageSha256;
  final String extractedText;
  final OfficialDocumentExtraction extraction;
}

class OfficialDocumentOcrService {
  OfficialDocumentOcrService({
    ImagePicker? picker,
    TextRecognizer? recognizer,
    this._parser = const OfficialDocumentParser(),
    Future<Directory> Function()? directoryProvider,
  }) : _picker = picker ?? ImagePicker(),
       _recognizer =
           recognizer ?? TextRecognizer(script: TextRecognitionScript.latin),
       _directoryProvider =
           directoryProvider ?? getApplicationDocumentsDirectory;

  final ImagePicker _picker;
  final TextRecognizer _recognizer;
  final OfficialDocumentParser _parser;
  final Future<Directory> Function() _directoryProvider;

  Future<OfficialDocumentScanDraft?> scanFromCamera() async {
    final captured = await _picker.pickImage(source: ImageSource.camera);
    if (captured == null) {
      return null;
    }

    final id = 'oficio_${DateTime.now().microsecondsSinceEpoch}';
    final imageFile = await _copyToPrivateStorage(id, captured);
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final recognizedText = await _recognizer.processImage(inputImage);
    final sha = await _sha256(imageFile);
    final rawText = recognizedText.text.trim();

    return OfficialDocumentScanDraft(
      id: id,
      imagePath: imageFile.path,
      imageSha256: sha,
      extractedText: rawText,
      extraction: _parser.parse(rawText),
    );
  }

  Future<void> deleteImage(String imagePath) async {
    if (imagePath.trim().isEmpty) {
      return;
    }
    final file = File(imagePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }

  Future<File> _copyToPrivateStorage(String id, XFile captured) async {
    final source = File(captured.path);
    final dir = await _documentsImageDirectory();
    final destination = File(
      '${dir.path}${Platform.pathSeparator}$id${_extensionFor(captured.path)}',
    );
    await source.copy(destination.path);
    return destination;
  }

  Future<Directory> _documentsImageDirectory() async {
    final base = await _directoryProvider();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}sicro_campo'
      '${Platform.pathSeparator}oficios',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
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
