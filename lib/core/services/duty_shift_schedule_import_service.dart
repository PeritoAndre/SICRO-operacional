import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../domain/models/app_settings.dart';
import '../../domain/models/duty_shift.dart';

class DutyShiftScheduleImportResult {
  const DutyShiftScheduleImportResult({
    required this.month,
    required this.year,
    required this.candidates,
    this.warnings = const [],
  });

  final int month;
  final int year;
  final List<DutyShiftImportCandidate> candidates;
  final List<String> warnings;

  bool get hasCandidates => candidates.isNotEmpty;
}

class DutyShiftImportCandidate {
  const DutyShiftImportCandidate({
    required this.day,
    required this.weekday,
    required this.columnCode,
    required this.columnLabel,
    required this.area,
    required this.startsAt,
    required this.endsAt,
    required this.sourceFileName,
    required this.fullDay,
    required this.matchedName,
  });

  final int day;
  final String weekday;
  final String columnCode;
  final String columnLabel;
  final ForensicArea area;
  final DateTime startsAt;
  final DateTime endsAt;
  final String sourceFileName;
  final bool fullDay;
  final String matchedName;

  String get key =>
      '${startsAt.toIso8601String()}_${columnCode}_${_normalize(matchedName)}';

  String get durationLabel => fullDay ? '24h' : '12h';

  DutyShift toDutyShift({required int index}) {
    final now = DateTime.now();
    return DutyShift(
      id: 'plantao_importado_${now.microsecondsSinceEpoch}_$index',
      createdAt: now,
      updatedAt: now,
      title: columnLabel,
      area: area,
      startsAt: startsAt,
      endsAt: endsAt,
      unit: 'Escala de plantao',
      team: matchedName,
      notes:
          'Importado da escala $sourceFileName. Horario inferido pelo SICRO; conferir e ajustar se necessario.',
      remindDayBefore: true,
      remindTwoHoursBefore: true,
    );
  }
}

class DutyShiftScheduleImportService {
  DutyShiftScheduleImportResult parsePdf({
    required Uint8List bytes,
    required String expertName,
    required String sourceFileName,
  }) {
    final normalizedTerms = _nameTerms(expertName);
    if (normalizedTerms.isEmpty) {
      throw const DutyShiftScheduleImportException(
        'Informe o nome que deve ser procurado na escala.',
      );
    }

    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      final fullText = extractor.extractText();
      final tokens = <_ScheduleToken>[];
      for (var page = 0; page < document.pages.count; page++) {
        final lines = extractor.extractTextLines(
          startPageIndex: page,
          endPageIndex: page,
        );
        for (final line in lines) {
          for (final word in line.wordCollection) {
            final text = word.text.trim();
            if (text.isEmpty) {
              continue;
            }
            tokens.add(
              _ScheduleToken(
                page: page,
                text: text,
                x: word.bounds.center.dx,
                y: word.bounds.center.dy,
              ),
            );
          }
        }
      }
      final monthYear = _extractMonthYear(
        '$fullText ${tokens.map((token) => token.text).join(' ')}',
      );
      if (monthYear == null) {
        throw const DutyShiftScheduleImportException(
          'Nao foi possivel identificar o mes/ano da escala.',
        );
      }

      final candidates = <DutyShiftImportCandidate>[];
      final seen = <String>{};
      for (var page = 0; page < document.pages.count; page++) {
        final pageTokens = tokens.where((token) => token.page == page).toList();
        final dayRows = _extractDayRows(pageTokens);
        if (dayRows.isEmpty) {
          continue;
        }
        for (final token in pageTokens) {
          if (!_matchesName(token.text, normalizedTerms)) {
            continue;
          }
          final column = _columnFor(token.x);
          if (column == null) {
            continue;
          }
          final row = _nearestRow(token.y, dayRows);
          if (row == null) {
            continue;
          }
          final rowTokens = pageTokens
              .where((item) => _nearestRow(item.y, dayRows) == row)
              .toList();
          final weekday = _weekdayFor(rowTokens);
          final fullDay = _isFullDayShift(weekday, rowTokens);
          final date = DateTime(monthYear.year, monthYear.month, row.day);
          final startsAt = fullDay
              ? DateTime(date.year, date.month, date.day, 7, 30)
              : DateTime(date.year, date.month, date.day, 19, 30);
          final endsAt = fullDay
              ? startsAt.add(const Duration(hours: 24))
              : DateTime(
                  date.year,
                  date.month,
                  date.day,
                  7,
                  30,
                ).add(const Duration(days: 1));
          final candidate = DutyShiftImportCandidate(
            day: row.day,
            weekday: weekday,
            columnCode: column.code,
            columnLabel: column.label,
            area: column.area,
            startsAt: startsAt,
            endsAt: endsAt,
            sourceFileName: sourceFileName,
            fullDay: fullDay,
            matchedName: token.text,
          );
          if (seen.add(candidate.key)) {
            candidates.add(candidate);
          }
        }
      }

      candidates.sort((a, b) {
        final dateCompare = a.startsAt.compareTo(b.startsAt);
        if (dateCompare != 0) {
          return dateCompare;
        }
        return a.columnLabel.compareTo(b.columnLabel);
      });

      return DutyShiftScheduleImportResult(
        month: monthYear.month,
        year: monthYear.year,
        candidates: candidates,
        warnings: [
          if (candidates.isEmpty)
            'Nenhum plantao foi encontrado para "$expertName". Confira se o nome esta igual ao da escala.',
          'Plantões de fim de semana/feriado foram inferidos como 24h; os demais como 12h noturnas.',
        ],
      );
    } finally {
      document.dispose();
    }
  }
}

class DutyShiftScheduleImportException implements Exception {
  const DutyShiftScheduleImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _MonthYear {
  const _MonthYear(this.month, this.year);

  final int month;
  final int year;
}

class _ScheduleToken {
  const _ScheduleToken({
    required this.page,
    required this.text,
    required this.x,
    required this.y,
  });

  final int page;
  final String text;
  final double x;
  final double y;
}

class _DayRow {
  const _DayRow({required this.day, required this.y});

  final int day;
  final double y;
}

class _ScheduleColumn {
  const _ScheduleColumn({
    required this.code,
    required this.label,
    required this.area,
    required this.centerX,
  });

  final String code;
  final String label;
  final ForensicArea area;
  final double centerX;
}

const _columns = [
  _ScheduleColumn(
    code: 'trafego_i',
    label: 'Trafego I',
    area: ForensicArea.traffic,
    centerX: 124.5,
  ),
  _ScheduleColumn(
    code: 'trafego_ii',
    label: 'Trafego II',
    area: ForensicArea.traffic,
    centerX: 183,
  ),
  _ScheduleColumn(
    code: 'pessoa',
    label: 'Pessoa',
    area: ForensicArea.violentDeath,
    centerX: 242.5,
  ),
  _ScheduleColumn(
    code: 'patrimonio',
    label: 'Patrimonio',
    area: ForensicArea.property,
    centerX: 301,
  ),
  _ScheduleColumn(
    code: 'criminalistica',
    label: 'Criminalistica',
    area: ForensicArea.violentDeath,
    centerX: 359,
  ),
  _ScheduleColumn(
    code: 'ambiental',
    label: 'Ambiental',
    area: ForensicArea.environmental,
    centerX: 419,
  ),
  _ScheduleColumn(
    code: 'chassi',
    label: 'Chassi',
    area: ForensicArea.traffic,
    centerX: 480,
  ),
  _ScheduleColumn(
    code: 'informatica',
    label: 'Informatica',
    area: ForensicArea.audioImage,
    centerX: 542,
  ),
  _ScheduleColumn(
    code: 'micro',
    label: 'Micro',
    area: ForensicArea.audioImage,
    centerX: 603,
  ),
  _ScheduleColumn(
    code: 'eficiencia',
    label: 'Eficiencia',
    area: ForensicArea.property,
    centerX: 666,
  ),
  _ScheduleColumn(
    code: 'sinab',
    label: 'Sinab',
    area: ForensicArea.papiloscopy,
    centerX: 729,
  ),
  _ScheduleColumn(
    code: 'avaliacoes_constatacoes_furto',
    label: 'Avaliacoes, constatacoes e furto',
    area: ForensicArea.property,
    centerX: 794,
  ),
];

_MonthYear? _extractMonthYear(String text) {
  final normalized = _normalize(text).toUpperCase();
  final match = RegExp(
    r'REFERENTE\s+AO\s+MES\s+DE\s+([A-Z]+)\s+(\d{4})',
  ).firstMatch(normalized);
  if (match == null) {
    return null;
  }
  final month = _monthNumber(match.group(1)!);
  final year = int.tryParse(match.group(2)!);
  if (month == null || year == null) {
    return null;
  }
  return _MonthYear(month, year);
}

List<_DayRow> _extractDayRows(List<_ScheduleToken> tokens) {
  final rows = <_DayRow>[];
  for (final token in tokens) {
    final day = int.tryParse(token.text);
    if (day == null || day < 1 || day > 31 || token.x > 80) {
      continue;
    }
    rows.add(_DayRow(day: day, y: token.y));
  }
  rows.sort((a, b) => a.y.compareTo(b.y));
  final unique = <_DayRow>[];
  for (final row in rows) {
    final exists = unique.any(
      (item) => item.day == row.day && (item.y - row.y).abs() < 4,
    );
    if (!exists) {
      unique.add(row);
    }
  }
  return unique;
}

_DayRow? _nearestRow(double y, List<_DayRow> rows) {
  if (rows.isEmpty) {
    return null;
  }
  _DayRow? nearest;
  var distance = double.infinity;
  for (final row in rows) {
    final current = (row.y - y).abs();
    if (current < distance) {
      nearest = row;
      distance = current;
    }
  }
  return distance <= 30 ? nearest : null;
}

_ScheduleColumn? _columnFor(double x) {
  _ScheduleColumn? nearest;
  var distance = double.infinity;
  for (final column in _columns) {
    final current = (column.centerX - x).abs();
    if (current < distance) {
      nearest = column;
      distance = current;
    }
  }
  return distance <= 35 ? nearest : null;
}

String _weekdayFor(List<_ScheduleToken> rowTokens) {
  final possible = rowTokens
      .where((token) => token.x >= 45 && token.x <= 100)
      .map((token) => token.text)
      .join(' ')
      .trim();
  return possible.isEmpty ? 'Dia' : possible;
}

bool _isFullDayShift(String weekday, List<_ScheduleToken> rowTokens) {
  final normalizedWeekday = _normalize(weekday);
  final rowText = _normalize(rowTokens.map((token) => token.text).join(' '));
  return normalizedWeekday.contains('sabado') ||
      normalizedWeekday.contains('domingo') ||
      rowText.contains('feriado');
}

bool _matchesName(String value, List<String> normalizedTerms) {
  final normalizedValue = _normalize(value);
  if (normalizedValue.length < 3) {
    return false;
  }
  return normalizedTerms.contains(normalizedValue);
}

List<String> _nameTerms(String name) {
  return _normalize(
    name,
  ).split(RegExp(r'\s+')).where((term) => term.length >= 3).toSet().toList();
}

String _normalize(String value) {
  var text = value.trim().toLowerCase();
  const replacements = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'ê': 'e',
    'è': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ò': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
  };
  for (final entry in replacements.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  return text
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}

int? _monthNumber(String value) {
  const months = {
    'JANEIRO': 1,
    'FEVEREIRO': 2,
    'MARCO': 3,
    'ABRIL': 4,
    'MAIO': 5,
    'JUNHO': 6,
    'JULHO': 7,
    'AGOSTO': 8,
    'SETEMBRO': 9,
    'OUTUBRO': 10,
    'NOVEMBRO': 11,
    'DEZEMBRO': 12,
  };
  return months[value];
}
