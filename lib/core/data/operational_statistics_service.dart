import '../../domain/models/forensic_case_metadata.dart';
import '../../domain/models/occurrence.dart';

enum StatisticsPeriodPreset {
  today('hoje', 'Hoje'),
  last7Days('ultimos_7_dias', 'Ultimos 7 dias'),
  currentMonth('mes_atual', 'Mes atual'),
  currentYear('ano_atual', 'Ano atual'),
  custom('personalizado', 'Personalizado');

  const StatisticsPeriodPreset(this.code, this.label);

  final String code;
  final String label;
}

class StatisticsFilter {
  const StatisticsFilter({
    this.period = StatisticsPeriodPreset.currentMonth,
    this.customStart,
    this.customEnd,
    this.type,
    this.status,
  });

  final StatisticsPeriodPreset period;
  final DateTime? customStart;
  final DateTime? customEnd;
  final ForensicCaseType? type;
  final OccurrenceStatus? status;

  StatisticsFilter copyWith({
    StatisticsPeriodPreset? period,
    DateTime? customStart,
    DateTime? customEnd,
    ForensicCaseType? type,
    OccurrenceStatus? status,
    bool clearCustomStart = false,
    bool clearCustomEnd = false,
    bool clearType = false,
    bool clearStatus = false,
  }) {
    return StatisticsFilter(
      period: period ?? this.period,
      customStart: clearCustomStart ? null : customStart ?? this.customStart,
      customEnd: clearCustomEnd ? null : customEnd ?? this.customEnd,
      type: clearType ? null : type ?? this.type,
      status: clearStatus ? null : status ?? this.status,
    );
  }

  StatisticsDateRange dateRange(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (period) {
      StatisticsPeriodPreset.today => StatisticsDateRange(
        start: today,
        endExclusive: today.add(const Duration(days: 1)),
      ),
      StatisticsPeriodPreset.last7Days => StatisticsDateRange(
        start: today.subtract(const Duration(days: 6)),
        endExclusive: today.add(const Duration(days: 1)),
      ),
      StatisticsPeriodPreset.currentMonth => StatisticsDateRange(
        start: DateTime(now.year, now.month),
        endExclusive: DateTime(now.year, now.month + 1),
      ),
      StatisticsPeriodPreset.currentYear => StatisticsDateRange(
        start: DateTime(now.year),
        endExclusive: DateTime(now.year + 1),
      ),
      StatisticsPeriodPreset.custom => StatisticsDateRange(
        start: customStart == null ? null : _startOfDay(customStart!),
        endExclusive: customEnd == null
            ? null
            : _startOfDay(customEnd!).add(const Duration(days: 1)),
      ),
    };
  }
}

class StatisticsDateRange {
  const StatisticsDateRange({this.start, this.endExclusive});

  final DateTime? start;
  final DateTime? endExclusive;

  bool contains(DateTime value) {
    final start = this.start;
    if (start != null && value.isBefore(start)) {
      return false;
    }
    final endExclusive = this.endExclusive;
    if (endExclusive != null && !value.isBefore(endExclusive)) {
      return false;
    }
    return true;
  }
}

class DistributionEntry {
  const DistributionEntry({required this.label, required this.count});

  final String label;
  final int count;
}

class OperationalStatisticsSnapshot {
  const OperationalStatisticsSnapshot({
    required this.filter,
    required this.generatedAt,
    required this.occurrences,
    required this.stats,
    required this.totalOccurrences,
    required this.completedOccurrences,
    required this.exportedOccurrences,
    required this.totalDurationSeconds,
    required this.averageDurationSeconds,
    required this.totalPhotos,
    required this.totalTraces,
    required this.totalMeasurements,
    required this.totalVictims,
    required this.totalVehicles,
    required this.totalNotes,
    required this.firstOccurrenceAt,
    required this.lastOccurrenceAt,
    required this.averagePhotosPerOccurrence,
    required this.byType,
    required this.byNature,
    required this.byMonth,
    required this.byMunicipality,
    required this.byDistrict,
  });

  final StatisticsFilter filter;
  final DateTime generatedAt;
  final List<FieldOccurrence> occurrences;
  final List<OccurrenceStats> stats;
  final int totalOccurrences;
  final int completedOccurrences;
  final int exportedOccurrences;
  final int totalDurationSeconds;
  final int averageDurationSeconds;
  final int totalPhotos;
  final int totalTraces;
  final int totalMeasurements;
  final int totalVictims;
  final int totalVehicles;
  final int totalNotes;
  final DateTime? firstOccurrenceAt;
  final DateTime? lastOccurrenceAt;
  final double averagePhotosPerOccurrence;
  final List<DistributionEntry> byType;
  final List<DistributionEntry> byNature;
  final List<DistributionEntry> byMonth;
  final List<DistributionEntry> byMunicipality;
  final List<DistributionEntry> byDistrict;

  bool get isEmpty => totalOccurrences == 0;
}

class OperationalStatisticsService {
  const OperationalStatisticsService();

  OperationalStatisticsSnapshot aggregate(
    List<FieldOccurrence> occurrences,
    StatisticsFilter filter, {
    DateTime? now,
  }) {
    final generatedAt = now ?? DateTime.now();
    final range = filter.dateRange(generatedAt);
    final filtered = occurrences.where((occurrence) {
      final stats = occurrence.stats;
      if (!range.contains(stats.startedAt)) {
        return false;
      }
      final type = filter.type;
      if (type != null && stats.forensicType != type.code) {
        return false;
      }
      final status = filter.status;
      if (status != null && stats.occurrenceStatus != status.code) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => a.stats.startedAt.compareTo(b.stats.startedAt));

    final stats = filtered.map((occurrence) => occurrence.stats).toList();
    final totalOccurrences = stats.length;
    final totalDurationSeconds = stats.fold<int>(
      0,
      (sum, item) => sum + item.durationSeconds,
    );
    final totalPhotos = stats.fold<int>(
      0,
      (sum, item) => sum + item.photosCount,
    );

    return OperationalStatisticsSnapshot(
      filter: filter,
      generatedAt: generatedAt,
      occurrences: filtered,
      stats: stats,
      totalOccurrences: totalOccurrences,
      completedOccurrences: stats
          .where(
            (item) => item.occurrenceStatus == OccurrenceStatus.completed.code,
          )
          .length,
      exportedOccurrences: stats.where((item) => item.exported).length,
      totalDurationSeconds: totalDurationSeconds,
      averageDurationSeconds: totalOccurrences == 0
          ? 0
          : (totalDurationSeconds / totalOccurrences).round(),
      totalPhotos: totalPhotos,
      totalTraces: stats.fold<int>(0, (sum, item) => sum + item.tracesCount),
      totalMeasurements: stats.fold<int>(
        0,
        (sum, item) => sum + item.measurementsCount,
      ),
      totalVictims: stats.fold<int>(0, (sum, item) => sum + item.victimsCount),
      totalVehicles: stats.fold<int>(
        0,
        (sum, item) => sum + item.vehiclesCount,
      ),
      totalNotes: stats.fold<int>(0, (sum, item) => sum + item.notesCount),
      firstOccurrenceAt: stats.isEmpty ? null : stats.first.startedAt,
      lastOccurrenceAt: stats.isEmpty ? null : stats.last.startedAt,
      averagePhotosPerOccurrence: totalOccurrences == 0
          ? 0
          : totalPhotos / totalOccurrences,
      byType: _distribution(stats, (item) => item.forensicTypeLabel),
      byNature: _distribution(
        stats,
        (item) => item.natureLabel.trim().isEmpty
            ? 'Natureza nao informada'
            : item.natureLabel,
      ),
      byMonth: _distribution(stats, (item) => _monthLabel(item.startedAt)),
      byMunicipality: _distribution(
        stats,
        (item) => item.municipality.trim().isEmpty
            ? 'Municipio nao informado'
            : item.municipality.trim(),
      ),
      byDistrict: _distribution(
        stats,
        (item) => item.district.trim().isEmpty
            ? 'Bairro nao informado'
            : item.district.trim(),
      ),
    );
  }

  static List<DistributionEntry> _distribution(
    List<OccurrenceStats> stats,
    String Function(OccurrenceStats item) labelOf,
  ) {
    final counts = <String, int>{};
    for (final item in stats) {
      final label = labelOf(item).trim();
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final entries =
        counts.entries
            .map(
              (entry) =>
                  DistributionEntry(label: entry.key, count: entry.value),
            )
            .toList()
          ..sort((a, b) {
            final countCompare = b.count.compareTo(a.count);
            return countCompare == 0
                ? a.label.compareTo(b.label)
                : countCompare;
          });
    return entries;
  }
}

DateTime _startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

String _monthLabel(DateTime date) {
  return '${_two(date.month)}/${date.year}';
}

String _two(int value) => value.toString().padLeft(2, '0');
