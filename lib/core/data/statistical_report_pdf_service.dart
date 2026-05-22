import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/models/app_settings.dart';
import 'operational_statistics_service.dart';

class StatisticalReportResult {
  const StatisticalReportResult({
    required this.file,
    required this.fileName,
    required this.sizeBytes,
    required this.occurrenceCount,
    required this.generatedAt,
  });

  final File file;
  final String fileName;
  final int sizeBytes;
  final int occurrenceCount;
  final DateTime generatedAt;
}

class StatisticalReportPdfService {
  StatisticalReportPdfService({
    Future<Directory> Function()? outputDirectoryProvider,
    DateTime Function()? clock,
  }) : _outputDirectoryProvider =
           outputDirectoryProvider ?? getApplicationDocumentsDirectory,
       _clock = clock ?? DateTime.now;

  final Future<Directory> Function() _outputDirectoryProvider;
  final DateTime Function() _clock;

  Future<StatisticalReportResult> generate({
    required OperationalStatisticsSnapshot snapshot,
    required ExpertProfile profile,
  }) async {
    final generatedAt = _clock();
    final theme = await _loadReportTheme();
    final document = pw.Document(
      title: 'Relatorio Estatistico Operacional',
      author: 'SICRO Operacional',
      creator: 'SICRO Operacional',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 28),
        build: (context) {
          return [
            _buildHeader(theme),
            pw.SizedBox(height: 14),
            _buildIdentification(theme, snapshot, profile, generatedAt),
            pw.SizedBox(height: 14),
            _buildSummary(theme, snapshot),
            pw.SizedBox(height: 14),
            _buildDistributionTable(
              theme,
              title: 'PERICIAS POR TIPO',
              entries: snapshot.byType,
            ),
            pw.SizedBox(height: 12),
            _buildDistributionTable(
              theme,
              title: 'PERICIAS POR NATUREZA',
              entries: snapshot.byNature,
            ),
            pw.SizedBox(height: 12),
            _buildFooter(theme, generatedAt),
          ];
        },
      ),
    );

    final bytes = await document.save();
    final directory = await _reportsDirectory();
    final fileName = _fileName(generatedAt);
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);

    return StatisticalReportResult(
      file: file,
      fileName: fileName,
      sizeBytes: bytes.length,
      occurrenceCount: snapshot.totalOccurrences,
      generatedAt: generatedAt,
    );
  }

  Future<_StatisticalReportTheme> _loadReportTheme() async {
    final regular = await rootBundle.load('assets/fonts/roboto-regular.ttf');
    final bold = await rootBundle.load('assets/fonts/roboto-bold.ttf');
    return _StatisticalReportTheme(
      regularFont: pw.Font.ttf(regular),
      boldFont: pw.Font.ttf(bold),
    );
  }

  Future<Directory> _reportsDirectory() async {
    final base = await _outputDirectoryProvider();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}sicro_operacional'
      '${Platform.pathSeparator}reports',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  pw.Widget _buildHeader(_StatisticalReportTheme theme) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('GOVERNO DO ESTADO DO AMAPA', style: theme.header),
        pw.Text(
          'POLICIA CIENTIFICA DO ESTADO DO AMAPA - PCA',
          style: theme.header,
        ),
        pw.Text('SICRO OPERACIONAL', style: theme.header),
        pw.SizedBox(height: 12),
        pw.Text(
          'RELAT\u00d3RIO ESTAT\u00cdSTICO OPERACIONAL',
          style: theme.title,
        ),
      ],
    );
  }

  pw.Widget _buildIdentification(
    _StatisticalReportTheme theme,
    OperationalStatisticsSnapshot snapshot,
    ExpertProfile profile,
    DateTime generatedAt,
  ) {
    return _box(
      theme,
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _labelValue(theme, 'PERITO', _fallback(profile.name)),
          pw.SizedBox(height: 5),
          _labelValue(theme, 'FUNCAO', _fallback(profile.role)),
          pw.SizedBox(height: 5),
          _labelValue(theme, 'ORGAO/UNIDADE', _organization(profile)),
          pw.SizedBox(height: 5),
          _labelValue(theme, 'PERIODO ANALISADO', _periodLabel(snapshot)),
          pw.SizedBox(height: 5),
          _labelValue(theme, 'FILTROS', _filtersLabel(snapshot.filter)),
          pw.SizedBox(height: 5),
          _labelValue(theme, 'GERADO EM', _dateTime(generatedAt)),
        ],
      ),
    );
  }

  pw.Widget _buildSummary(
    _StatisticalReportTheme theme,
    OperationalStatisticsSnapshot snapshot,
  ) {
    final rows = [
      ['Total de pericias', '${snapshot.totalOccurrences}'],
      ['Pericias concluidas', '${snapshot.completedOccurrences}'],
      ['Pericias exportadas', '${snapshot.exportedOccurrences}'],
      [
        'Tempo medio de atendimento',
        _duration(snapshot.averageDurationSeconds),
      ],
      ['Total de horas em atendimento', _hours(snapshot.totalDurationSeconds)],
      ['Total de fotos', '${snapshot.totalPhotos}'],
      ['Total de vitimas/corpos', '${snapshot.totalVictims}'],
      ['Total de veiculos', '${snapshot.totalVehicles}'],
      ['Total de vestigios', '${snapshot.totalTraces}'],
      ['Total de medicoes', '${snapshot.totalMeasurements}'],
      ['Total de observacoes', '${snapshot.totalNotes}'],
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: theme.border, width: 0.7),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.4),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: theme.headerFill),
          children: [
            _tableCell(theme, 'INDICADOR', header: true),
            _tableCell(theme, 'VALOR', header: true, alignRight: true),
          ],
        ),
        for (final row in rows)
          pw.TableRow(
            children: [
              _tableCell(theme, row[0]),
              _tableCell(theme, row[1], alignRight: true),
            ],
          ),
      ],
    );
  }

  pw.Widget _buildDistributionTable(
    _StatisticalReportTheme theme, {
    required String title,
    required List<DistributionEntry> entries,
  }) {
    final visible = entries.isEmpty
        ? const [DistributionEntry(label: 'Sem dados', count: 0)]
        : entries.take(12).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: theme.border, width: 0.7),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.7),
        1: pw.FlexColumnWidth(0.7),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: theme.headerFill),
          children: [
            _tableCell(theme, title, header: true),
            _tableCell(theme, 'QTD', header: true, alignRight: true),
          ],
        ),
        for (final entry in visible)
          pw.TableRow(
            children: [
              _tableCell(theme, entry.label),
              _tableCell(theme, '${entry.count}', alignRight: true),
            ],
          ),
      ],
    );
  }

  pw.Widget _buildFooter(_StatisticalReportTheme theme, DateTime generatedAt) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'Relatorio gerado pelo SICRO Operacional em ${_dateTime(generatedAt)}.',
        style: theme.small,
      ),
    );
  }

  pw.Widget _box(_StatisticalReportTheme theme, pw.Widget child) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: theme.border)),
      child: child,
    );
  }

  pw.Widget _labelValue(
    _StatisticalReportTheme theme,
    String label,
    String value,
  ) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(text: '$label: ', style: theme.label),
          pw.TextSpan(text: value, style: theme.body),
        ],
      ),
    );
  }

  pw.Widget _tableCell(
    _StatisticalReportTheme theme,
    String value, {
    bool header = false,
    bool alignRight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      child: pw.Text(
        value,
        style: header ? theme.tableHeader : theme.tableBody,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  String _fileName(DateTime generatedAt) {
    final local = generatedAt.toLocal();
    return 'Relatorio_Estatistico_${local.year}${_two(local.month)}'
        '${_two(local.day)}_${_two(local.hour)}${_two(local.minute)}.pdf';
  }
}

class _StatisticalReportTheme {
  _StatisticalReportTheme({required this.regularFont, required this.boldFont});

  final pw.Font regularFont;
  final pw.Font boldFont;
  final navy = PdfColor.fromHex('#0B172A');
  final border = PdfColor.fromHex('#26344D');
  final headerFill = PdfColor.fromHex('#E9EEF7');

  late final header = pw.TextStyle(
    font: boldFont,
    color: navy,
    fontSize: 10,
    fontWeight: pw.FontWeight.bold,
  );
  late final title = pw.TextStyle(
    font: boldFont,
    color: navy,
    fontSize: 14,
    fontWeight: pw.FontWeight.bold,
  );
  late final label = pw.TextStyle(
    font: boldFont,
    color: navy,
    fontSize: 9,
    fontWeight: pw.FontWeight.bold,
  );
  late final body = pw.TextStyle(font: regularFont, color: navy, fontSize: 9);
  late final small = pw.TextStyle(font: regularFont, color: navy, fontSize: 8);
  late final tableHeader = pw.TextStyle(
    font: boldFont,
    color: navy,
    fontSize: 8.5,
    fontWeight: pw.FontWeight.bold,
  );
  late final tableBody = pw.TextStyle(
    font: regularFont,
    color: navy,
    fontSize: 8.5,
  );
}

String _periodLabel(OperationalStatisticsSnapshot snapshot) {
  final range = snapshot.filter.dateRange(snapshot.generatedAt);
  final start = range.start;
  final endExclusive = range.endExclusive;
  if (start == null && endExclusive == null) {
    return snapshot.filter.period.label;
  }
  final end = endExclusive?.subtract(const Duration(days: 1));
  if (start != null && end != null) {
    return '${_date(start)} a ${_date(end)}';
  }
  if (start != null) {
    return 'A partir de ${_date(start)}';
  }
  return 'Ate ${_date(end!)}';
}

String _filtersLabel(StatisticsFilter filter) {
  final parts = <String>[
    'Periodo: ${filter.period.label}',
    'Tipo: ${filter.type?.label ?? 'Todos'}',
    'Status: ${filter.status?.label ?? 'Todos'}',
  ];
  return parts.join(' | ');
}

String _organization(ExpertProfile profile) {
  final parts = [
    profile.organization,
    profile.unit,
  ].where((part) => part.trim().isNotEmpty).map((part) => part.trim()).toList();
  return parts.isEmpty ? '-' : parts.join(' - ');
}

String _fallback(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '-' : trimmed;
}

String _date(DateTime value) {
  final local = value.toLocal();
  return '${_two(local.day)}/${_two(local.month)}/${local.year}';
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  return '${_date(local)} ${_two(local.hour)}:${_two(local.minute)}';
}

String _duration(int seconds) {
  if (seconds <= 0) {
    return '0 min';
  }
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours == 0) {
    return '${minutes < 1 ? 1 : minutes} min';
  }
  if (minutes == 0) {
    return '${hours}h';
  }
  return '${hours}h ${_two(minutes)}min';
}

String _hours(int seconds) {
  return '${(seconds / 3600).toStringAsFixed(1)} h';
}

String _two(int value) => value.toString().padLeft(2, '0');
