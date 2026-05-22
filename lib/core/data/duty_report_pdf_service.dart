import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/models/forensic_case_metadata.dart';
import '../../domain/models/occurrence.dart';

class DutyReportData {
  const DutyReportData({
    required this.expertName,
    required this.role,
    required this.dutyScale,
    required this.startedAt,
    required this.finishedAt,
    required this.observations,
    required this.occurrences,
  });

  final String expertName;
  final String role;
  final String dutyScale;
  final DateTime startedAt;
  final DateTime finishedAt;
  final String observations;
  final List<FieldOccurrence> occurrences;
}

class DutyReportResult {
  const DutyReportResult({
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

class DutyReportPdfService {
  DutyReportPdfService({
    Future<Directory> Function()? outputDirectoryProvider,
    DateTime Function()? clock,
  }) : _outputDirectoryProvider =
           outputDirectoryProvider ?? getApplicationDocumentsDirectory,
       _clock = clock ?? DateTime.now;

  final Future<Directory> Function() _outputDirectoryProvider;
  final DateTime Function() _clock;

  Future<DutyReportResult> generate(DutyReportData data) async {
    final generatedAt = _clock();
    final occurrences = [...data.occurrences]
      ..sort((a, b) => _occurrenceDate(a).compareTo(_occurrenceDate(b)));
    final theme = await _loadReportTheme();
    final document = pw.Document(
      title: 'Relatório de atividade de plantão',
      author: 'SICRO Operacional',
      creator: 'SICRO Operacional',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(24, 20, 24, 22),
        build: (context) {
          return [
            _buildHeader(theme),
            pw.SizedBox(height: 14),
            _buildIdentification(theme, data),
            pw.SizedBox(height: 12),
            _buildTable(theme, occurrences),
            pw.SizedBox(height: 14),
            _buildObservations(theme, data.observations),
            pw.SizedBox(height: 20),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Macapá-AP, ${_longDate(data.finishedAt)}.',
                style: theme.body,
              ),
            ),
          ];
        },
      ),
    );

    final bytes = await document.save();
    final directory = await _reportsDirectory();
    final fileName = _fileName(data.startedAt);
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);

    return DutyReportResult(
      file: file,
      fileName: fileName,
      sizeBytes: bytes.length,
      occurrenceCount: occurrences.length,
      generatedAt: generatedAt,
    );
  }

  Future<_ReportTheme> _loadReportTheme() async {
    final regular = await rootBundle.load('assets/fonts/roboto-regular.ttf');
    final bold = await rootBundle.load('assets/fonts/roboto-bold.ttf');
    return _ReportTheme(
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

  pw.Widget _buildHeader(_ReportTheme theme) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('GOVERNO DO ESTADO DO AMAPÁ', style: theme.header),
        pw.Text(
          'POLÍCIA CIENTÍFICA DO ESTADO DO AMAPÁ - PCA',
          style: theme.header,
        ),
        pw.Text('DEPARTAMENTO DE CRIMINALÍSTICA', style: theme.header),
        pw.SizedBox(height: 12),
        pw.Text('RELATÓRIO DE ATIVIDADE DE PLANTÃO', style: theme.title),
      ],
    );
  }

  pw.Widget _buildIdentification(_ReportTheme theme, DutyReportData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: theme.border)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: _labelValue(theme, 'NOME', _fallback(data.expertName)),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 2,
                child: _labelValue(theme, 'FUNÇÃO', _fallback(data.role)),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          _labelValue(theme, 'ESCALA DE PLANTÃO', _fallback(data.dutyScale)),
          pw.SizedBox(height: 6),
          _labelValue(
            theme,
            'DATA',
            _dutyRange(data.startedAt, data.finishedAt),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTable(_ReportTheme theme, List<FieldOccurrence> occurrences) {
    final rows = <List<String>>[
      [
        'ITEM',
        'DATA',
        'HORÁRIO',
        'TIPO DE EXAME',
        'ENDEREÇO',
        'OFÍCIO',
        'DELEGACIA',
        'PROTOCOLO',
        'Nº LAUDO',
      ],
      for (var index = 0; index < occurrences.length; index++)
        _rowFor(index + 1, occurrences[index]),
    ];

    while (rows.length < 11) {
      rows.add(['${rows.length}', '', '', '', '', '', '', '', '']);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: theme.border, width: 0.7),
      columnWidths: const {
        0: pw.FixedColumnWidth(32),
        1: pw.FixedColumnWidth(56),
        2: pw.FixedColumnWidth(58),
        3: pw.FlexColumnWidth(1.7),
        4: pw.FlexColumnWidth(1.8),
        5: pw.FlexColumnWidth(1),
        6: pw.FlexColumnWidth(1),
        7: pw.FlexColumnWidth(0.9),
        8: pw.FlexColumnWidth(0.9),
      },
      children: [
        for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
          pw.TableRow(
            decoration: rowIndex == 0
                ? pw.BoxDecoration(color: theme.headerFill)
                : null,
            children: [
              for (final value in rows[rowIndex])
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 5,
                  ),
                  child: pw.Text(
                    value,
                    style: rowIndex == 0 ? theme.tableHeader : theme.tableBody,
                    textAlign: rowIndex == 0
                        ? pw.TextAlign.center
                        : pw.TextAlign.left,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  List<String> _rowFor(int index, FieldOccurrence occurrence) {
    final date = _occurrenceDate(occurrence);
    final data = occurrence.caseData;
    return [
      '$index',
      _shortDateWithDots(date),
      _time(date),
      _examType(occurrence),
      _address(occurrence),
      data.requisition.trim(),
      data.policeUnit.trim(),
      data.protocol.trim(),
      data.protocol.trim(),
    ];
  }

  pw.Widget _buildObservations(_ReportTheme theme, String observations) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: theme.border)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Obs:', style: theme.label),
          pw.SizedBox(height: 6),
          pw.Text(
            observations.trim().isEmpty ? ' ' : observations.trim(),
            style: theme.body,
          ),
        ],
      ),
    );
  }

  pw.Widget _labelValue(_ReportTheme theme, String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(text: '$label: ', style: theme.label),
          pw.TextSpan(text: value, style: theme.body),
        ],
      ),
    );
  }

  String _fileName(DateTime startedAt) {
    final local = startedAt.toLocal();
    return 'Relatorio_Plantao_${local.year}${_two(local.month)}'
        '${_two(local.day)}.pdf';
  }
}

class _ReportTheme {
  _ReportTheme({required this.regularFont, required this.boldFont});

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
    fontSize: 13,
    fontWeight: pw.FontWeight.bold,
  );
  late final label = pw.TextStyle(
    font: boldFont,
    color: navy,
    fontSize: 9,
    fontWeight: pw.FontWeight.bold,
  );
  late final body = pw.TextStyle(font: regularFont, color: navy, fontSize: 9);
  late final tableHeader = pw.TextStyle(
    font: boldFont,
    color: navy,
    fontSize: 7.5,
    fontWeight: pw.FontWeight.bold,
  );
  late final tableBody = pw.TextStyle(
    font: regularFont,
    color: navy,
    fontSize: 7.5,
  );
}

DateTime _occurrenceDate(FieldOccurrence occurrence) {
  return occurrence.caseData.arrivedAt ??
      occurrence.caseData.calledAt ??
      occurrence.startedAt ??
      occurrence.createdAt;
}

String _examType(FieldOccurrence occurrence) {
  final metadata = occurrence.metadata;
  final summary = metadata.summary.trim();
  return switch (metadata.type) {
    ForensicCaseType.traffic =>
      metadata.trafficNature == null
          ? 'Perícia em local de acidente de trânsito'
          : 'Perícia em local de acidente de trânsito - ${metadata.trafficNature!.label}',
    ForensicCaseType.violentDeath =>
      metadata.violentDeathNature == null
          ? 'Perícia em local de morte violenta'
          : 'Perícia em local de morte violenta - ${metadata.violentDeathNature!.label}',
    ForensicCaseType.property =>
      summary.isEmpty
          ? 'Perícia de patrimônio'
          : 'Perícia de ${summary.toLowerCase()}',
  };
}

String _address(FieldOccurrence occurrence) {
  final data = occurrence.caseData;
  final parts = [
    data.street,
    data.district,
    data.municipality,
  ].where((part) => part.trim().isNotEmpty).toList();
  if (parts.isEmpty) {
    return data.reference.trim();
  }
  return parts.join(' - ');
}

String _fallback(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '-' : trimmed;
}

String _dutyRange(DateTime startedAt, DateTime finishedAt) {
  return 'Das ${_time(startedAt)} do dia ${_shortDate(startedAt)} '
      'às ${_time(finishedAt)} do dia ${_shortDate(finishedAt)}';
}

String _shortDate(DateTime value) {
  final local = value.toLocal();
  return '${_two(local.day)}/${_two(local.month)}';
}

String _shortDateWithDots(DateTime value) {
  final local = value.toLocal();
  return '${_two(local.day)}.${_two(local.month)}.${_two(local.year % 100)}';
}

String _time(DateTime value) {
  final local = value.toLocal();
  return '${_two(local.hour)}:${_two(local.minute)}';
}

String _longDate(DateTime value) {
  final local = value.toLocal();
  const months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  return '${local.day} de ${months[local.month - 1]} de ${local.year}';
}

String _two(int value) => value.toString().padLeft(2, '0');
