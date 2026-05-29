import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/models/checklist_item.dart';
import '../../domain/models/forensic_case_metadata.dart';
import '../../domain/models/occurrence.dart';

enum DutyReportTemplate {
  operational('operacional_sicro', 'Operacional SICRO'),
  classic('classico', 'Classico institucional');

  const DutyReportTemplate(this.code, this.label);

  final String code;
  final String label;
}

class DutyReportData {
  const DutyReportData({
    required this.expertName,
    required this.role,
    required this.dutyScale,
    required this.startedAt,
    required this.finishedAt,
    required this.observations,
    required this.occurrences,
    this.template = DutyReportTemplate.classic,
  });

  final String expertName;
  final String role;
  final String dutyScale;
  final DateTime startedAt;
  final DateTime finishedAt;
  final String observations;
  final List<FieldOccurrence> occurrences;
  final DutyReportTemplate template;
}

class DutyReportResult {
  const DutyReportResult({
    required this.file,
    required this.fileName,
    required this.sizeBytes,
    required this.occurrenceCount,
    required this.generatedAt,
    required this.template,
  });

  final File file;
  final String fileName;
  final int sizeBytes;
  final int occurrenceCount;
  final DateTime generatedAt;
  final DutyReportTemplate template;
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
    final thumbnails = data.template == DutyReportTemplate.operational
        ? await _loadOccurrenceThumbnails(occurrences)
        : const <String, pw.MemoryImage>{};
    final document = pw.Document(
      title: 'Relatorio de atividade de plantao',
      author: 'SICRO Operacional',
      creator: 'Ecossistema SICRO',
    );

    switch (data.template) {
      case DutyReportTemplate.classic:
        _addClassicPage(document, theme, data, occurrences);
      case DutyReportTemplate.operational:
        _addOperationalPage(document, theme, data, occurrences, thumbnails);
    }

    final bytes = await document.save();
    final directory = await _reportsDirectory();
    final fileName = _fileName(data.startedAt, data.template);
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);

    return DutyReportResult(
      file: file,
      fileName: fileName,
      sizeBytes: bytes.length,
      occurrenceCount: occurrences.length,
      generatedAt: generatedAt,
      template: data.template,
    );
  }

  void _addClassicPage(
    pw.Document document,
    _ReportTheme theme,
    DutyReportData data,
    List<FieldOccurrence> occurrences,
  ) {
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(24, 20, 24, 22),
        build: (context) {
          return [
            _buildInstitutionalHeader(theme),
            pw.SizedBox(height: 14),
            _buildClassicIdentification(theme, data),
            pw.SizedBox(height: 12),
            _buildClassicTable(theme, occurrences),
            pw.SizedBox(height: 14),
            _buildObservations(theme, data.observations),
            pw.SizedBox(height: 20),
            _buildDateFooter(theme, data.finishedAt),
          ];
        },
      ),
    );
  }

  void _addOperationalPage(
    pw.Document document,
    _ReportTheme theme,
    DutyReportData data,
    List<FieldOccurrence> occurrences,
    Map<String, pw.MemoryImage> thumbnails,
  ) {
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 24, 30, 26),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Gerado no ecossistema SICRO', style: theme.footer),
            pw.Text(
              'Pagina ${context.pageNumber}/${context.pagesCount}',
              style: theme.footer,
            ),
          ],
        ),
        build: (context) {
          return [
            _buildInstitutionalHeader(theme),
            pw.SizedBox(height: 10),
            _buildSicroNotice(theme),
            pw.SizedBox(height: 10),
            _buildOperationalIdentification(theme, data),
            pw.SizedBox(height: 12),
            _buildOperationalSummary(theme, occurrences),
            pw.SizedBox(height: 12),
            _buildOperationalTable(theme, occurrences),
            pw.SizedBox(height: 12),
            pw.Text('DOSSIE DAS OCORRENCIAS', style: theme.sectionTitle),
            pw.SizedBox(height: 8),
            for (var index = 0; index < occurrences.length; index++) ...[
              _buildOccurrenceCard(
                theme,
                index + 1,
                occurrences[index],
                thumbnails[occurrences[index].id],
              ),
              pw.SizedBox(height: 8),
            ],
            _buildObservations(theme, data.observations),
            pw.SizedBox(height: 16),
            _buildDateFooter(theme, data.finishedAt),
          ];
        },
      ),
    );
  }

  Future<Map<String, pw.MemoryImage>> _loadOccurrenceThumbnails(
    List<FieldOccurrence> occurrences,
  ) async {
    final thumbnails = <String, pw.MemoryImage>{};
    for (final occurrence in occurrences) {
      final photoPath = _thumbnailPhotoPath(occurrence);
      if (photoPath.isEmpty) {
        continue;
      }
      try {
        final bytes = await File(photoPath).readAsBytes();
        thumbnails[occurrence.id] = pw.MemoryImage(bytes);
      } catch (_) {
        continue;
      }
    }
    return thumbnails;
  }

  Future<_ReportTheme> _loadReportTheme() async {
    final regular = await rootBundle.load('assets/fonts/roboto-regular.ttf');
    final bold = await rootBundle.load('assets/fonts/roboto-bold.ttf');
    final governmentLogo = await _loadOptionalImage([
      'assets/brand/governo_amapa.png',
      'assets/brand/governo_amapa.jpg',
      'assets/brand/governo_amapa.jpeg',
    ]);
    final policeLogo = await _loadOptionalImage([
      'assets/brand/policia_cientifica.png',
      'assets/brand/policia_cientifica.jpg',
      'assets/brand/policia_cientifica.jpeg',
    ]);
    return _ReportTheme(
      regularFont: pw.Font.ttf(regular),
      boldFont: pw.Font.ttf(bold),
      governmentLogo: governmentLogo,
      policeLogo: policeLogo,
    );
  }

  Future<pw.MemoryImage?> _loadOptionalImage(List<String> paths) async {
    for (final path in paths) {
      try {
        final data = await rootBundle.load(path);
        return pw.MemoryImage(data.buffer.asUint8List());
      } catch (_) {
        continue;
      }
    }
    return null;
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

  pw.Widget _buildInstitutionalHeader(_ReportTheme theme) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            _logoBox(
              image: theme.governmentLogo,
              fallback: 'GOVERNO DO\nAMAPA',
              width: 118,
              height: 50,
              theme: theme,
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('GOVERNO DO ESTADO DO AMAPA', style: theme.header),
                  pw.Text(
                    'POLICIA CIENTIFICA DO ESTADO DO AMAPA - PCA',
                    style: theme.header,
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    'DEPARTAMENTO DE CRIMINALISTICA',
                    style: theme.header,
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
            _logoBox(
              image: theme.policeLogo,
              fallback: 'POLICIA\nCIENTIFICA',
              width: 72,
              height: 58,
              theme: theme,
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Text('RELATORIO DE ATIVIDADE DE PLANTAO', style: theme.title),
      ],
    );
  }

  pw.Widget _logoBox({
    required pw.MemoryImage? image,
    required String fallback,
    required double width,
    required double height,
    required _ReportTheme theme,
  }) {
    if (image != null) {
      return pw.SizedBox(
        width: width,
        height: height,
        child: pw.Image(image, fit: pw.BoxFit.contain),
      );
    }
    return pw.Container(
      width: width,
      height: height,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: theme.borderSoft, width: 0.7),
      ),
      child: pw.Text(
        fallback,
        textAlign: pw.TextAlign.center,
        style: theme.logoFallback,
      ),
    );
  }

  pw.Widget _buildSicroNotice(_ReportTheme theme) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: theme.sicroFill,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: theme.borderSoft),
      ),
      child: pw.Text(
        'Relatorio operacional consolidado a partir dos dossies registrados no ecossistema SICRO.',
        textAlign: pw.TextAlign.center,
        style: theme.smallBold,
      ),
    );
  }

  pw.Widget _buildClassicIdentification(
    _ReportTheme theme,
    DutyReportData data,
  ) {
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
                child: _labelValue(theme, 'FUNCAO', _fallback(data.role)),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          _labelValue(theme, 'ESCALA DE PLANTAO', _fallback(data.dutyScale)),
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

  pw.Widget _buildOperationalIdentification(
    _ReportTheme theme,
    DutyReportData data,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: theme.borderSoft),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: _compactLabelValue(
                  theme,
                  'Perito',
                  _fallback(data.expertName),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _compactLabelValue(
                  theme,
                  'Funcao',
                  _fallback(data.role),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(
                child: _compactLabelValue(
                  theme,
                  'Escala',
                  _fallback(data.dutyScale),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _compactLabelValue(
                  theme,
                  'Periodo',
                  _dutyRange(data.startedAt, data.finishedAt),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildClassicTable(
    _ReportTheme theme,
    List<FieldOccurrence> occurrences,
  ) {
    final rows = <List<String>>[
      [
        'ITEM',
        'DATA',
        'HORARIO',
        'TIPO DE EXAME',
        'ENDERECO',
        'OFICIO',
        'DELEGACIA',
        'PROTOCOLO',
        'N LAUDO',
      ],
      for (var index = 0; index < occurrences.length; index++)
        _classicRowFor(index + 1, occurrences[index]),
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

  pw.Widget _buildOperationalSummary(
    _ReportTheme theme,
    List<FieldOccurrence> occurrences,
  ) {
    final totalPhotos = occurrences.fold<int>(
      0,
      (sum, occurrence) => sum + occurrence.photos.length,
    );
    final totalTraces = occurrences.fold<int>(
      0,
      (sum, occurrence) => sum + occurrence.traces.length,
    );
    final totalMeasurements = occurrences.fold<int>(
      0,
      (sum, occurrence) => sum + occurrence.measurements.length,
    );
    final totalDuration = occurrences.fold<int>(
      0,
      (sum, occurrence) => sum + occurrence.durationSeconds,
    );
    final withVictims = occurrences
        .where(
          (occurrence) =>
              _hasVictimResult(occurrence) || occurrence.victims.isNotEmpty,
        )
        .length;
    final noVictim = occurrences
        .where(
          (occurrence) =>
              occurrence.metadata.result == OccurrenceResult.noVictim,
        )
        .length;
    final officialVehicles = occurrences
        .where((occurrence) => occurrence.metadata.officialVehicleInvolved)
        .length;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('RESUMO DO PLANTAO', style: theme.sectionTitle),
        pw.SizedBox(height: 8),
        _summaryRow(theme, [
          _SummaryStat('Ocorrencias', '${occurrences.length}'),
          _SummaryStat('Com vitima', '$withVictims'),
          _SummaryStat('Sem vitima', '$noVictim'),
          _SummaryStat('Carro oficial', '$officialVehicles'),
        ]),
        pw.SizedBox(height: 6),
        _summaryRow(theme, [
          _SummaryStat('Fotos', '$totalPhotos'),
          _SummaryStat('Vestigios', '$totalTraces'),
          _SummaryStat('Medicoes', '$totalMeasurements'),
          _SummaryStat('Tempo em atendimento', _durationLabel(totalDuration)),
        ]),
      ],
    );
  }

  pw.Widget _summaryRow(_ReportTheme theme, List<_SummaryStat> items) {
    return pw.Row(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) pw.SizedBox(width: 6),
          pw.Expanded(child: _summaryBox(theme, items[index])),
        ],
      ],
    );
  }

  pw.Widget _summaryBox(_ReportTheme theme, _SummaryStat stat) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: theme.summaryFill,
        border: pw.Border.all(color: theme.borderSoft),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(stat.label, style: theme.tinyMuted),
          pw.SizedBox(height: 3),
          pw.Text(stat.value, style: theme.metric),
        ],
      ),
    );
  }

  pw.Widget _buildOperationalTable(
    _ReportTheme theme,
    List<FieldOccurrence> occurrences,
  ) {
    final rows = <List<String>>[
      ['ITEM', 'HORARIO', 'TIPO/NATUREZA', 'RESULTADO', 'LOCAL', 'REGISTROS'],
      for (var index = 0; index < occurrences.length; index++)
        _operationalRowFor(index + 1, occurrences[index]),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: theme.borderSoft, width: 0.6),
      columnWidths: const {
        0: pw.FixedColumnWidth(26),
        1: pw.FixedColumnWidth(44),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.1),
        4: pw.FlexColumnWidth(1.4),
        5: pw.FlexColumnWidth(1.2),
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
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    value,
                    style: rowIndex == 0
                        ? theme.operationalTableHeader
                        : theme.operationalTableBody,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  pw.Widget _buildOccurrenceCard(
    _ReportTheme theme,
    int index,
    FieldOccurrence occurrence,
    pw.MemoryImage? thumbnail,
  ) {
    final date = _occurrenceDate(occurrence);
    final title = '$index. ${occurrence.metadata.summary}';
    final gps = occurrence.bestGpsLocation;
    final gpsText = gps == null
        ? 'GPS nao registrado'
        : 'GPS OK (${gps.accuracyMeters?.toStringAsFixed(1) ?? '-'} m)';
    final note = _mainNote(occurrence);

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: theme.borderSoft),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _occurrenceThumbnail(theme, occurrence, thumbnail),
              pw.SizedBox(width: 9),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(title, style: theme.cardTitle),
                    pw.SizedBox(height: 5),
                    pw.Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _pill(theme, '${_shortDate(date)} ${_time(date)}'),
                        _pill(theme, occurrence.status.label),
                        _pill(theme, occurrence.metadata.result.label),
                        if (occurrence.metadata.officialVehicleInvolved)
                          _pill(theme, 'Carro oficial'),
                        _pill(theme, gpsText),
                        _pill(theme, _sketchSummary(occurrence)),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    _detailLine(theme, 'Local', _address(occurrence)),
                    _detailLine(
                      theme,
                      'Coordenadas',
                      _gpsCoordinateSummary(occurrence),
                    ),
                    _detailLine(
                      theme,
                      'Registros',
                      '${occurrence.photos.length} foto(s), '
                          '${occurrence.vehicles.length} veiculo(s), '
                          '${occurrence.victims.length} vitima(s)/corpo(s), '
                          '${occurrence.traces.length} vestigio(s), '
                          '${occurrence.measurements.length} medicao(oes)',
                    ),
                    if (note.isNotEmpty) _detailLine(theme, 'Observacao', note),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _occurrenceThumbnail(
    _ReportTheme theme,
    FieldOccurrence occurrence,
    pw.MemoryImage? thumbnail,
  ) {
    return pw.Container(
      width: 68,
      height: 86,
      decoration: pw.BoxDecoration(
        color: theme.summaryFill,
        border: pw.Border.all(color: theme.borderSoft, width: 0.7),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: thumbnail == null
          ? pw.Center(
              child: pw.Text(
                _thumbnailFallbackLabel(occurrence),
                textAlign: pw.TextAlign.center,
                style: theme.logoFallback,
              ),
            )
          : pw.ClipRRect(
              horizontalRadius: 4,
              verticalRadius: 4,
              child: pw.Image(thumbnail, fit: pw.BoxFit.cover),
            ),
    );
  }

  pw.Widget _pill(_ReportTheme theme, String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: pw.BoxDecoration(
        color: theme.pillFill,
        borderRadius: pw.BorderRadius.circular(3),
        border: pw.Border.all(color: theme.borderSoft),
      ),
      child: pw.Text(text, style: theme.pill),
    );
  }

  pw.Widget _detailLine(_ReportTheme theme, String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 3),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: '$label: ', style: theme.smallBold),
            pw.TextSpan(text: _fallback(value), style: theme.small),
          ],
        ),
      ),
    );
  }

  List<String> _classicRowFor(int index, FieldOccurrence occurrence) {
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
      '',
    ];
  }

  List<String> _operationalRowFor(int index, FieldOccurrence occurrence) {
    final date = _occurrenceDate(occurrence);
    return [
      '$index',
      _time(date),
      _compactSummary(occurrence),
      _resultSummary(occurrence),
      _address(occurrence),
      '${occurrence.photos.length} foto(s); '
          '${occurrence.traces.length} vest.; '
          '${occurrence.measurements.length} med.',
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
          pw.Text('OBSERVACOES', style: theme.label),
          pw.SizedBox(height: 6),
          pw.Text(
            observations.trim().isEmpty ? ' ' : observations.trim(),
            style: theme.body,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildDateFooter(_ReportTheme theme, DateTime finishedAt) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('Macapa-AP, ${_longDate(finishedAt)}.', style: theme.body),
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

  pw.Widget _compactLabelValue(_ReportTheme theme, String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(text: '$label: ', style: theme.smallBold),
          pw.TextSpan(text: value, style: theme.small),
        ],
      ),
    );
  }

  String _fileName(DateTime startedAt, DutyReportTemplate template) {
    final local = startedAt.toLocal();
    final date = '${local.year}${_two(local.month)}${_two(local.day)}';
    if (template == DutyReportTemplate.operational) {
      return 'Relatorio_Plantao_SICRO_$date.pdf';
    }
    return 'Relatorio_Plantao_$date.pdf';
  }
}

class _ReportTheme {
  _ReportTheme({
    required this.regularFont,
    required this.boldFont,
    required this.governmentLogo,
    required this.policeLogo,
  });

  final pw.Font regularFont;
  final pw.Font boldFont;
  final pw.MemoryImage? governmentLogo;
  final pw.MemoryImage? policeLogo;
  final navy = PdfColor.fromHex('#0B172A');
  final muted = PdfColor.fromHex('#526071');
  final border = PdfColor.fromHex('#26344D');
  final borderSoft = PdfColor.fromHex('#A7B0C0');
  final headerFill = PdfColor.fromHex('#E9EEF7');
  final summaryFill = PdfColor.fromHex('#F4F7FB');
  final sicroFill = PdfColor.fromHex('#EEF4FF');
  final pillFill = PdfColor.fromHex('#F7F9FC');

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
    decoration: pw.TextDecoration.underline,
  );
  late final sectionTitle = pw.TextStyle(
    font: boldFont,
    color: navy,
    fontSize: 10,
    fontWeight: pw.FontWeight.bold,
  );
  late final cardTitle = pw.TextStyle(
    font: boldFont,
    color: navy,
    fontSize: 9.5,
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
  late final smallBold = pw.TextStyle(
    font: boldFont,
    color: navy,
    fontSize: 8,
    fontWeight: pw.FontWeight.bold,
  );
  late final tinyMuted = pw.TextStyle(
    font: regularFont,
    color: muted,
    fontSize: 6.8,
  );
  late final metric = pw.TextStyle(
    font: boldFont,
    color: navy,
    fontSize: 12,
    fontWeight: pw.FontWeight.bold,
  );
  late final footer = pw.TextStyle(
    font: regularFont,
    color: muted,
    fontSize: 7,
  );
  late final logoFallback = pw.TextStyle(
    font: boldFont,
    color: muted,
    fontSize: 7,
    fontWeight: pw.FontWeight.bold,
  );
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
  late final operationalTableHeader = pw.TextStyle(
    font: boldFont,
    color: navy,
    fontSize: 6.8,
    fontWeight: pw.FontWeight.bold,
  );
  late final operationalTableBody = pw.TextStyle(
    font: regularFont,
    color: navy,
    fontSize: 6.6,
  );
  late final pill = pw.TextStyle(
    font: boldFont,
    color: navy,
    fontSize: 6.8,
    fontWeight: pw.FontWeight.bold,
  );
}

class _SummaryStat {
  const _SummaryStat(this.label, this.value);

  final String label;
  final String value;
}

DateTime _occurrenceDate(FieldOccurrence occurrence) {
  return occurrence.caseData.arrivedAt ??
      occurrence.caseData.calledAt ??
      occurrence.startedAt ??
      occurrence.createdAt;
}

bool _hasVictimResult(FieldOccurrence occurrence) {
  return switch (occurrence.metadata.result) {
    OccurrenceResult.injuredVictim ||
    OccurrenceResult.fatalVictim ||
    OccurrenceResult.multipleVictims => true,
    OccurrenceResult.noVictim || OccurrenceResult.notInformed => false,
  };
}

String _examType(FieldOccurrence occurrence) {
  final metadata = occurrence.metadata;
  final summary = metadata.summary.trim();
  return switch (metadata.type) {
    ForensicCaseType.traffic =>
      metadata.trafficNature == null
          ? 'Pericia em local de acidente de transito'
          : 'Pericia em local de acidente de transito - ${metadata.trafficNature!.label}',
    ForensicCaseType.violentDeath =>
      metadata.violentDeathNature == null
          ? 'Pericia em local de crime contra a vida'
          : 'Pericia em local de crime contra a vida - ${metadata.violentDeathNature!.label}',
    ForensicCaseType.property =>
      summary.isEmpty ? 'Pericia de patrimonio' : 'Pericia de $summary',
    ForensicCaseType.environmental =>
      metadata.environmentalNature == null
          ? 'Pericia ambiental'
          : 'Pericia ambiental - ${metadata.environmentalNature!.label}',
    ForensicCaseType.ballistics =>
      metadata.ballisticsNature == null
          ? 'Pericia de Balistica Forense'
          : 'Pericia de Balistica Forense - ${metadata.ballisticsNature!.label}',
    ForensicCaseType.audioImage =>
      metadata.audioImageNature == null
          ? 'Pericia de Audio e Imagem'
          : 'Pericia de Audio e Imagem - ${metadata.audioImageNature!.label}',
    ForensicCaseType.papiloscopy =>
      metadata.papiloscopyNature == null
          ? 'Pericia Papiloscopica'
          : 'Pericia Papiloscopica - ${metadata.papiloscopyNature!.label}',
  };
}

String _compactSummary(FieldOccurrence occurrence) {
  final parts = occurrence.metadata.summary
      .split(' - ')
      .where((part) => part.trim().isNotEmpty)
      .toList();
  if (parts.length <= 1) {
    return occurrence.metadata.type.label;
  }
  return parts.skip(1).take(3).join(' - ');
}

String _resultSummary(FieldOccurrence occurrence) {
  final result = occurrence.metadata.result;
  if (occurrence.metadata.officialVehicleInvolved) {
    return '${result.label} / carro oficial';
  }
  return result.label;
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

String _mainNote(FieldOccurrence occurrence) {
  if (occurrence.notes.isEmpty) {
    return '';
  }
  final critical = occurrence.notes.where(
    (note) => note.priority.code != 'normal',
  );
  final selected = critical.isNotEmpty
      ? critical.first
      : occurrence.notes.first;
  return selected.text.trim();
}

String _thumbnailPhotoPath(FieldOccurrence occurrence) {
  for (final photo in occurrence.photos) {
    final path = photo.filePath.trim();
    if (path.isEmpty) {
      continue;
    }
    if (File(path).existsSync()) {
      return path;
    }
  }
  return '';
}

String _thumbnailFallbackLabel(FieldOccurrence occurrence) {
  final parts = occurrence.metadata.summary
      .split(' - ')
      .where((part) => part.trim().isNotEmpty)
      .toList();
  if (parts.length > 1) {
    return parts.skip(1).take(2).join('\n').toUpperCase();
  }
  return occurrence.metadata.type.label.toUpperCase();
}

String _gpsCoordinateSummary(FieldOccurrence occurrence) {
  final location = occurrence.bestGpsLocation;
  if (location == null || !location.hasCoordinates) {
    return 'Coordenada nao registrada';
  }
  final capturedAt = location.capturedAt == null
      ? ''
      : ' - ${_shortDate(location.capturedAt!)} ${_time(location.capturedAt!)}';
  return '${location.coordinateLabel} - ${location.accuracyLabel}$capturedAt';
}

String _sketchSummary(FieldOccurrence occurrence) {
  final drone = _checklistAnswer(occurrence, 'levantamento_drone_realizado');
  final manual = _checklistAnswer(occurrence, 'croqui_manual_trena');
  final method = occurrence.checklist.where(
    (item) => item.id == 'metodo_croqui_registrado',
  );
  final methodNote = method.isEmpty ? '' : method.first.note.trim();
  final parts = <String>[
    if (drone == ChecklistAnswer.yes) 'Drone',
    if (manual == ChecklistAnswer.yes) 'Trena/manual',
    if (methodNote.isNotEmpty) methodNote,
  ];
  return parts.isEmpty ? 'Croqui nao informado' : 'Croqui: ${parts.join(', ')}';
}

ChecklistAnswer? _checklistAnswer(FieldOccurrence occurrence, String itemId) {
  for (final item in occurrence.checklist) {
    if (item.id == itemId) {
      return item.answer;
    }
  }
  return null;
}

String _fallback(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '-' : trimmed;
}

String _dutyRange(DateTime startedAt, DateTime finishedAt) {
  return 'Das ${_time(startedAt)} do dia ${_shortDate(startedAt)} '
      'as ${_time(finishedAt)} do dia ${_shortDate(finishedAt)}';
}

String _durationLabel(int seconds) {
  if (seconds <= 0) {
    return '-';
  }
  final minutes = (seconds / 60).round();
  if (minutes < 60) {
    return '${minutes}min';
  }
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '${hours}h' : '${hours}h${_two(rest)}';
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
    'marco',
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
