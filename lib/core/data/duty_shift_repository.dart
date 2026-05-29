import 'package:flutter/foundation.dart';

import '../../domain/models/duty_shift.dart';
import 'duty_shift_storage.dart';

class DutyShiftRepository extends ChangeNotifier {
  DutyShiftRepository({DutyShiftStorage? storage})
    : _storage = storage ?? MemoryDutyShiftStorage();

  final DutyShiftStorage _storage;
  final List<DutyShift> _shifts = [];
  bool _loaded = false;
  String? _lastError;

  bool get loaded => _loaded;

  String? get lastError => _lastError;

  List<DutyShift> get shifts {
    final copy = [..._shifts];
    copy.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return copy;
  }

  DutyShift? findById(String id) {
    for (final shift in _shifts) {
      if (shift.id == id) {
        return shift;
      }
    }
    return null;
  }

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    try {
      final loadedShifts = await _storage.loadShifts();
      _shifts
        ..clear()
        ..addAll(loadedShifts);
      _lastError = null;
    } catch (error) {
      _lastError = error.toString();
      _shifts.clear();
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> saveShift(DutyShift shift) async {
    final now = DateTime.now();
    final updated = shift.copyWith(updatedAt: now);
    final index = _shifts.indexWhere((item) => item.id == shift.id);
    if (index == -1) {
      _shifts.add(updated);
    } else {
      _shifts[index] = updated;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> restoreShifts(List<DutyShift> shifts) async {
    _shifts
      ..clear()
      ..addAll(shifts);
    notifyListeners();
    await _persist();
  }

  Future<DutyShift?> deleteShift(String id) async {
    final index = _shifts.indexWhere((shift) => shift.id == id);
    if (index == -1) {
      return null;
    }
    final removed = _shifts.removeAt(index);
    notifyListeners();
    try {
      await _persist();
      _lastError = null;
      return removed;
    } catch (error) {
      _shifts.insert(index, removed);
      _lastError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  DutyShift createDraft({DateTime? startsAt, DateTime? endsAt}) {
    final now = DateTime.now();
    final start = startsAt ?? _defaultNextShiftStart(now);
    return DutyShift(
      id: _newId('plantao'),
      createdAt: now,
      updatedAt: now,
      startsAt: start,
      endsAt: endsAt ?? start.add(const Duration(hours: 12)),
    );
  }

  Future<void> _persist() async {
    try {
      await _storage.saveShifts(_shifts);
      _lastError = null;
    } catch (error) {
      _lastError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  String _newId(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
  }
}

DateTime _defaultNextShiftStart(DateTime now) {
  final todayStart = DateTime(now.year, now.month, now.day, 7, 30);
  if (now.isBefore(todayStart)) {
    return todayStart;
  }
  return todayStart.add(const Duration(days: 1));
}
