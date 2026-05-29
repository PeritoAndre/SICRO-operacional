import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/duty_shift.dart';

abstract class DutyShiftStorage {
  Future<List<DutyShift>> loadShifts();

  Future<void> saveShifts(List<DutyShift> shifts);
}

class MemoryDutyShiftStorage implements DutyShiftStorage {
  MemoryDutyShiftStorage([List<DutyShift>? initial]) : _shifts = initial ?? [];

  List<DutyShift> _shifts;

  @override
  Future<List<DutyShift>> loadShifts() async {
    return [..._shifts];
  }

  @override
  Future<void> saveShifts(List<DutyShift> shifts) async {
    _shifts = [...shifts];
  }
}

class FileDutyShiftStorage implements DutyShiftStorage {
  FileDutyShiftStorage({Future<Directory> Function()? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directoryProvider;

  @override
  Future<List<DutyShift>> loadShifts() async {
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
    final items = root['plantoes'];
    if (items is! List) {
      return [];
    }
    return items
        .map((item) => DutyShift.fromJson(_map(item)))
        .where((shift) => shift.id.isNotEmpty)
        .toList();
  }

  @override
  Future<void> saveShifts(List<DutyShift> shifts) async {
    final file = await _storageFile();
    final payload = {
      'formato': 'sicro_operacional_plantoes_local_store',
      'versao': '0.1',
      'salvo_em': DateTime.now().toIso8601String(),
      'plantoes': shifts.map((shift) => shift.toJson()).toList(),
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
    return File('${dir.path}${Platform.pathSeparator}duty_shifts.json');
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
