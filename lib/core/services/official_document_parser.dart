import '../../domain/models/official_document.dart';

class OfficialDocumentExtraction {
  const OfficialDocumentExtraction({
    this.documentNumber = '',
    this.boNumber = '',
    this.protocol = '',
    this.requestingUnit = '',
    this.recipient = '',
    this.subject = '',
    this.requestedExam = '',
    this.documentDateText = '',
    this.eventDateTimeText = '',
    this.municipality = '',
    this.district = '',
    this.address = '',
    this.vehicles = const [],
  });

  final String documentNumber;
  final String boNumber;
  final String protocol;
  final String requestingUnit;
  final String recipient;
  final String subject;
  final String requestedExam;
  final String documentDateText;
  final String eventDateTimeText;
  final String municipality;
  final String district;
  final String address;
  final List<OfficialDocumentVehicle> vehicles;
}

class OfficialDocumentParser {
  const OfficialDocumentParser();

  OfficialDocumentExtraction parse(String text) {
    final compact = _compact(text);
    final folded = _fold(compact);
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    return OfficialDocumentExtraction(
      documentNumber: _firstMatch(
        compact,
        RegExp(
          r'of.cio\s*n.?\s*[:\-]?\s*([0-9]{1,8}\s*/\s*[0-9]{2,4})',
          caseSensitive: false,
        ),
      ),
      boNumber: _firstMatch(
        compact,
        RegExp(
          r'\bbo\s*n.?\s*[:\-]?\s*([0-9]{1,8}\s*/\s*[0-9]{2,4})',
          caseSensitive: false,
        ),
      ),
      protocol: _firstMatch(
        compact,
        RegExp(
          r'protocolo\s*n.?\s*[:\-]?\s*([0-9]{1,8}\s*/?\s*[0-9]{0,4})',
          caseSensitive: false,
        ),
      ),
      requestingUnit: _requestingUnit(lines),
      recipient: _recipient(lines),
      subject: _lineAfterLabel(lines, 'assunto'),
      requestedExam: _requestedExam(folded),
      documentDateText: _documentDate(compact),
      eventDateTimeText: _eventDateTime(folded),
      municipality: _municipality(folded),
      district: _district(folded),
      address: _address(compact),
      vehicles: _vehicles(text),
    );
  }

  static String _compact(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _firstMatch(String text, RegExp regex) {
    final match = regex.firstMatch(text);
    if (match == null || match.groupCount < 1) {
      return '';
    }
    return _clean(match.group(1) ?? '');
  }

  static String _requestingUnit(List<String> lines) {
    final selected = lines.where((line) {
      final lower = _fold(line);
      return lower.contains('delegacia') ||
          lower.contains('policia civil') ||
          lower.contains('repressao a delitos de transito');
    }).toList();
    if (selected.isEmpty) {
      return '';
    }
    return selected.take(3).join(' - ');
  }

  static String _recipient(List<String> lines) {
    final index = lines.indexWhere((line) => _fold(line).startsWith('ao'));
    if (index == -1) {
      return '';
    }
    final buffer = <String>[];
    for (var i = index + 1; i < lines.length && buffer.length < 3; i++) {
      final lower = _fold(lines[i]);
      if (lower.startsWith('assunto') || lower.startsWith('senhor')) {
        break;
      }
      buffer.add(lines[i]);
    }
    return buffer.join(' - ');
  }

  static String _lineAfterLabel(List<String> lines, String label) {
    final normalizedLabel = _fold(label);
    for (final line in lines) {
      final normalized = _fold(line);
      final index = normalized.indexOf('$normalizedLabel:');
      if (index >= 0) {
        final rawIndex = line.indexOf(':');
        if (rawIndex >= 0 && rawIndex < line.length - 1) {
          return _clean(line.substring(rawIndex + 1));
        }
      }
    }
    return '';
  }

  static String _requestedExam(String folded) {
    if (folded.contains('laudo em local de acidente de transito')) {
      return 'Laudo em local de acidente de transito';
    }
    if (folded.contains('laudo pericial')) {
      return 'Laudo pericial';
    }
    return '';
  }

  static String _documentDate(String compact) {
    final match = RegExp(
      '[A-Za-z\\u00C0-\\u017F]+\\s*[-\\u2013]\\s*AP,\\s*'
      '([0-9]{1,2}\\s+de\\s+[A-Za-z\\u00C0-\\u017F]+\\s+de\\s+[0-9]{4})',
      caseSensitive: false,
    ).firstMatch(compact);
    return _clean(match?.group(1) ?? '');
  }

  static String _eventDateTime(String folded) {
    final match = RegExp(
      r'realizado\s+no\s+dia\s*([0-9]{1,2}/[0-9]{1,2}/[0-9]{2,4})\s*as?\s*([0-9]{1,2}[:h][0-9]{2})',
      caseSensitive: false,
    ).firstMatch(folded);
    if (match == null) {
      return '';
    }
    return '${_clean(match.group(1) ?? '')} ${_clean(match.group(2) ?? '')}';
  }

  static String _municipality(String folded) {
    if (folded.contains('macapa')) {
      return 'Macapa';
    }
    return '';
  }

  static String _district(String folded) {
    final district = _firstMatch(
      folded,
      RegExp(r'\bbairro\s+([a-z0-9 ]+?)\s+tendo\b', caseSensitive: false),
    );
    if (district == 'central') {
      return 'Central';
    }
    return district;
  }

  static String _address(String compact) {
    final folded = _fold(compact);
    final start = folded.indexOf('no(a) ');
    final end = folded.indexOf(' tendo como objeto');
    if (start >= 0 && end > start) {
      final rawStart = start + 'no(a) '.length;
      return _clean(compact.substring(rawStart, end));
    }
    final fallback = RegExp(
      r'((?:rua|av\.?|avenida|rodovia|travessa)\s+.+?)(?:\s+tendo|\s+como\s+objeto|$)',
      caseSensitive: false,
    ).firstMatch(compact);
    return _clean(fallback?.group(1) ?? '');
  }

  static List<OfficialDocumentVehicle> _vehicles(String text) {
    final compact = _compact(text);
    final chunks =
        RegExp(
              r'\*\s*([^*]+?)(?=\s*\*|\s*O\s+Laudo\s+Pericial|$)',
              caseSensitive: false,
            )
            .allMatches(compact)
            .map((match) => match.group(1) ?? '')
            .where((chunk) => chunk.trim().isNotEmpty)
            .toList();
    return chunks.map(_vehicleFromChunk).where(_hasVehicleData).toList();
  }

  static OfficialDocumentVehicle _vehicleFromChunk(String chunk) {
    final plate = _firstMatch(
      chunk,
      RegExp(
        r'placa\s*[:\-]?\s*([A-Z]{3}[0-9A-Z][0-9A-Z]{3})',
        caseSensitive: false,
      ),
    ).toUpperCase();
    final renavam = _firstMatch(
      chunk,
      RegExp(r'renavam\s*[:\-]?\s*([0-9]{5,})', caseSensitive: false),
    );
    final chassis = _firstMatch(
      chunk,
      RegExp(r'chassi\s*[:\-]?\s*([A-Z0-9*]{6,})', caseSensitive: false),
    ).toUpperCase();
    final color = _firstMatch(
      chunk,
      RegExp(r'cor\s*[:\-]?\s*([^,.;]+)', caseSensitive: false),
    );
    final brand = _firstMatch(
      chunk,
      RegExp(r'marca/modelo\s*[:\-]?\s*([^,.;]+)', caseSensitive: false),
    );
    final owner = _firstMatch(
      chunk,
      RegExp(
        r'nome\s+do\s+propriet.rio\s*[:\-]?\s*(.+)$',
        caseSensitive: false,
      ),
    );
    final type = chunk.split(',').first.trim();
    return OfficialDocumentVehicle(
      type: _clean(type),
      plate: plate,
      renavam: renavam,
      chassis: chassis,
      brandModel: brand,
      color: color,
      owner: owner,
    );
  }

  static bool _hasVehicleData(OfficialDocumentVehicle vehicle) {
    return vehicle.plate.isNotEmpty ||
        vehicle.chassis.isNotEmpty ||
        vehicle.renavam.isNotEmpty ||
        vehicle.owner.isNotEmpty;
  }

  static String _clean(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s:;\-]+|[\s:;\-]+$'), '')
        .trim();
  }

  static String _fold(String value) {
    return value
        .toLowerCase()
        .replaceAll('\u00e1', 'a')
        .replaceAll('\u00e0', 'a')
        .replaceAll('\u00e3', 'a')
        .replaceAll('\u00e2', 'a')
        .replaceAll('\u00e9', 'e')
        .replaceAll('\u00ea', 'e')
        .replaceAll('\u00ed', 'i')
        .replaceAll('\u00f3', 'o')
        .replaceAll('\u00f4', 'o')
        .replaceAll('\u00f5', 'o')
        .replaceAll('\u00fa', 'u')
        .replaceAll('\u00e7', 'c');
  }
}
