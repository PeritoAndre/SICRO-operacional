import 'package:flutter_test/flutter_test.dart';
import 'package:sicro_campo/core/data/duty_shift_repository.dart';
import 'package:sicro_campo/core/data/duty_shift_storage.dart';
import 'package:sicro_campo/domain/models/app_settings.dart';
import 'package:sicro_campo/domain/models/duty_shift.dart';

void main() {
  test('persists duty shifts in local storage', () async {
    final storage = MemoryDutyShiftStorage();
    final repository = DutyShiftRepository(storage: storage);
    await repository.load();

    final start = DateTime(2026, 5, 27, 7, 30);
    await repository.saveShift(
      DutyShift(
        id: 'plantao_1',
        createdAt: start,
        updatedAt: start,
        title: 'Transito I',
        area: ForensicArea.traffic,
        startsAt: start,
        endsAt: start.add(const Duration(hours: 12)),
        unit: 'Departamento de Criminalistica',
        team: 'Equipe Alfa',
        notes: 'Sobreaviso operacional.',
      ),
    );

    final reloaded = DutyShiftRepository(storage: storage);
    await reloaded.load();

    expect(reloaded.shifts, hasLength(1));
    expect(reloaded.shifts.first.displayTitle, 'Transito I');
    expect(reloaded.shifts.first.unit, 'Departamento de Criminalistica');
    expect(reloaded.shifts.first.remindDayBefore, isTrue);
    expect(reloaded.shifts.first.remindTwoHoursBefore, isTrue);
  });

  test('deletes duty shift from local storage', () async {
    final start = DateTime(2026, 5, 27, 7, 30);
    final storage = MemoryDutyShiftStorage([
      DutyShift(
        id: 'plantao_1',
        createdAt: start,
        updatedAt: start,
        startsAt: start,
        endsAt: start.add(const Duration(hours: 12)),
      ),
    ]);
    final repository = DutyShiftRepository(storage: storage);
    await repository.load();

    await repository.deleteShift('plantao_1');

    final reloaded = DutyShiftRepository(storage: storage);
    await reloaded.load();
    expect(reloaded.shifts, isEmpty);
  });
}
