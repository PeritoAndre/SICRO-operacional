import 'package:flutter_test/flutter_test.dart';
import 'package:sicro_campo/core/services/official_document_parser.dart';

void main() {
  test('extracts main traffic office fields from OCR text', () {
    const text = '''
GOVERNO DO ESTADO DO AMAPA
POLICIA CIVIL
DELEGACIA ESPECIALIZADA DE REPRESSAO A DELITOS DE TRANSITO - MACAPA - AP

Oficio N: 8971/2026 - BO N 17333/2026
MACAPA - AP, 10 de Marco de 2026.

Ao Senhor
DIRETORA DA POLICIA CIENTIFICA DO AMAPA

Assunto: Solicitacao de Laudo Pericial.

solicitamos a confeccao do LAUDO PERICIAL, LAUDO EM LOCAL DE ACIDENTE DE TRANSITO cujo exame foi realizado no dia 05/03/2026 as 10:36, no(a) RUA PROFESSOR TOSTES COM AV. HENRIQUE GALUCIO - BAIRRO CENTRAL tendo como objeto(s) PERICIADOS:
* Motocicleta/Motoneta, Codigo RENAVAM: 299585719, Placa: NEY1342, Chassi: 9C6KE1520B0031597, Cor: PRETA, Marca/Modelo: YAMAHA/FACTOR YBR125 K, Nome do proprietario: JOSE QUEIROZ.
* Automovel Caminhonete, Codigo RENAVAM: 1357529330, Placa: SAL8D01, Chassi: 9BGEB43B0RB148332, Cor: BRANCA, Marca/Modelo: CHEV/MONTANA T LT, Nome do proprietario: LUCAS WALLACE BARBOSA ARAGAO.
''';

    final extraction = const OfficialDocumentParser().parse(text);

    expect(extraction.documentNumber, '8971/2026');
    expect(extraction.boNumber, '17333/2026');
    expect(extraction.requestingUnit, contains('DELEGACIA ESPECIALIZADA'));
    expect(extraction.subject, 'Solicitacao de Laudo Pericial.');
    expect(extraction.requestedExam, 'Laudo em local de acidente de transito');
    expect(extraction.documentDateText, '10 de Marco de 2026');
    expect(extraction.eventDateTimeText, '05/03/2026 10:36');
    expect(extraction.municipality, 'Macapa');
    expect(extraction.district, 'Central');
    expect(extraction.address, contains('RUA PROFESSOR TOSTES'));
    expect(extraction.vehicles, hasLength(2));
    expect(extraction.vehicles.first.plate, 'NEY1342');
    expect(extraction.vehicles.last.plate, 'SAL8D01');
  });
}
