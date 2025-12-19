import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../core/models.dart';

class FileEmailService {
  // ========== Excel 템플릿 생성 ==========

  static Future<File> generateExcelTemplate(String clientName) async {
    final excel = Excel.createExcel();
    
    // Sheet1 삭제하고 급여대장만 사용
    excel.delete('Sheet1');
    final sheet = excel['급여대장'];

    // 거래처 정보
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('거래처명');
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue(clientName);
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue('사업자등록번호');
    sheet.cell(CellIndex.indexByString('B2')).value = TextCellValue('');

    // 헤더 (4행)
    final headers = [
      '이름',
      '생년월일(YYMMDD)',
      '월급',
      '시급',
      '주소정근로시간',
      '정상근로시간',
      '연장',
      '야간',
      '휴일',
      '개근주수',
      '상여',
      '추가수당1',
      '추가수당2',
      '추가공제1',
      '추가공제2',
    ];

    for (var i = 0; i < headers.length; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3))
          .value = TextCellValue(headers[i]);
    }

    // 샘플 데이터 (추가수당/공제는 기본값 0)
    final sampleRow = [
      '홍길동',
      '900101',
      '3000000',
      '14500',
      '40',
      '209',
      '0',
      '0',
      '0',
      '4',
      '0',
      '0',
      '0',
      '0',
      '0',
    ];

    for (var i = 0; i < sampleRow.length; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4))
          .value = TextCellValue(sampleRow[i]);
    }

    final bytes = excel.encode();
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/${clientName}_급여대장_템플릿.xlsx');
    await file.writeAsBytes(bytes!);

    // Windows 탐색기에서 열기
    if (Platform.isWindows) {
      await Process.run('explorer', ['/select,', file.path]);
    }

    return file;
  }

  // ========== Excel 파싱 ==========

  static Future<Map<String, dynamic>> parseExcelFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    String clientName = '';
    String bizId = '';
    final workers = <Map<String, dynamic>>[];

    for (var table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null) continue;

      // 거래처 정보 읽기 (A1, B1, A2, B2)
      if (sheet.maxRows >= 2) {
        final nameCell = sheet.cell(CellIndex.indexByString('B1')).value;
        clientName = nameCell?.toString() ?? '';

        final bizCell = sheet.cell(CellIndex.indexByString('B2')).value;
        bizId = bizCell?.toString() ?? '';
      }

      // 직원 데이터 읽기 (5행부터)
      for (var rowIndex = 4; rowIndex < sheet.maxRows; rowIndex++) {
        final row = sheet.row(rowIndex);
        if (row.isEmpty) continue;

        final name = row[0]?.value?.toString() ?? '';
        if (name.isEmpty) continue;

        final birthDate = row[1]?.value?.toString() ?? '';
        final monthlySalary = int.tryParse(row[2]?.value?.toString() ?? '0') ?? 0;
        final hourlyRate = int.tryParse(row[3]?.value?.toString() ?? '0') ?? 0;
        final weeklyHours = double.tryParse(row[4]?.value?.toString() ?? '40') ?? 40;
        final normalHours = double.tryParse(row[5]?.value?.toString() ?? '209') ?? 209;
        final overtimeHours = double.tryParse(row[6]?.value?.toString() ?? '0') ?? 0;
        final nightHours = double.tryParse(row[7]?.value?.toString() ?? '0') ?? 0;
        final holidayHours = double.tryParse(row[8]?.value?.toString() ?? '0') ?? 0;
        final weekCount = int.tryParse(row[9]?.value?.toString() ?? '4') ?? 4;
        final bonus = int.tryParse(row[10]?.value?.toString() ?? '0') ?? 0;
        final additionalPay1 = int.tryParse(row[11]?.value?.toString() ?? '0') ?? 0;
        final additionalPay2 = int.tryParse(row[12]?.value?.toString() ?? '0') ?? 0;
        final additionalDeduct1 = int.tryParse(row[13]?.value?.toString() ?? '0') ?? 0;
        final additionalDeduct2 = int.tryParse(row[14]?.value?.toString() ?? '0') ?? 0;

        workers.add({
          'name': name,
          'birthDate': birthDate,
          'monthlySalary': monthlySalary,
          'hourlyRate': hourlyRate,
          'weeklyHours': weeklyHours,
          'normalHours': normalHours,
          'overtimeHours': overtimeHours,
          'nightHours': nightHours,
          'holidayHours': holidayHours,
          'weekCount': weekCount,
          'bonus': bonus,
          'additionalPay1': additionalPay1,
          'additionalPay2': additionalPay2,
          'additionalDeduct1': additionalDeduct1,
          'additionalDeduct2': additionalDeduct2,
        });
      }

      break; // 첫 번째 시트만 읽기
    }

    return {
      'clientName': clientName,
      'bizId': bizId,
      'workers': workers,
    };
  }

  // ========== CSV 급여대장 내보내기 ==========

  static Future<File> exportPayrollCsv({
    required String clientName,
    required int year,
    required int month,
    required List<SalaryResult> results,
  }) async {
    final rows = <List<String>>[];

    // 헤더
    rows.add([
      '이름',
      '구분',
      '기본급',
      '연장수당',
      '야간수당',
      '휴일수당',
      '주휴수당',
      '상여금',
      '지급총액',
      '국민연금',
      '건강보험',
      '장기요양',
      '고용보험',
      '소득세',
      '지방소득세',
      '공제총액',
      '실수령액',
    ]);

    // 데이터
    for (var result in results) {
      rows.add([
        result.workerName,
        result.employmentType == 'regular' ? '근로소득' : '사업소득',
        result.baseSalary.toString(),
        result.overtimePay.toString(),
        result.nightPay.toString(),
        result.holidayPay.toString(),
        result.weeklyHolidayPay.toString(),
        result.bonus.toString(),
        result.totalPayment.toString(),
        result.nationalPension.toString(),
        result.healthInsurance.toString(),
        result.longTermCare.toString(),
        result.employmentInsurance.toString(),
        result.incomeTax.toString(),
        result.localIncomeTax.toString(),
        result.totalDeduction.toString(),
        result.netPayment.toString(),
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/${clientName}_${year}년${month}월_급여대장.csv');
    await file.writeAsString('\uFEFF$csv'); // UTF-8 BOM

    if (Platform.isWindows) {
      await Process.run('explorer', ['/select,', file.path]);
    }

    return file;
  }

  // ========== 급여대장 PDF 생성 ==========

  static Future<File> exportPayrollRegisterPdf({
    required String clientName,
    required String bizId,
    required int year,
    required int month,
    required List<SalaryResult> results,
  }) async {
    final pdf = pw.Document();

    // 한글 폰트 로드
    final fontData = await rootBundle.load('assets/fonts/NanumGothic-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);
    final boldFontData = await rootBundle.load('assets/fonts/NanumGothic-Bold.ttf');
    final ttfBold = pw.Font.ttf(boldFontData);

    // 합계 계산
    int totalBaseSalary = 0;
    int totalOvertimePay = 0;
    int totalNightPay = 0;
    int totalHolidayPay = 0;
    int totalWeeklyHolidayPay = 0;
    int totalBonus = 0;
    int totalPayment = 0;
    int totalNationalPension = 0;
    int totalHealthInsurance = 0;
    int totalLongTermCare = 0;
    int totalEmploymentInsurance = 0;
    int totalIncomeTax = 0;
    int totalLocalIncomeTax = 0;
    int totalDeduction = 0;
    int totalNetPayment = 0;

    for (var result in results) {
      totalBaseSalary += result.baseSalary;
      totalOvertimePay += result.overtimePay;
      totalNightPay += result.nightPay;
      totalHolidayPay += result.holidayPay;
      totalWeeklyHolidayPay += result.weeklyHolidayPay;
      totalBonus += result.bonus;
      totalPayment += result.totalPayment;
      totalNationalPension += result.nationalPension;
      totalHealthInsurance += result.healthInsurance;
      totalLongTermCare += result.longTermCare;
      totalEmploymentInsurance += result.employmentInsurance;
      totalIncomeTax += result.incomeTax;
      totalLocalIncomeTax += result.localIncomeTax;
      totalDeduction += result.totalDeduction;
      totalNetPayment += result.netPayment;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          // 제목
          pw.Center(
            child: pw.Text(
              '급여대장',
              style: pw.TextStyle(font: ttfBold, fontSize: 20),
            ),
          ),
          pw.SizedBox(height: 10),
          
          // 기본정보
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('사업장: $clientName', style: pw.TextStyle(font: ttf, fontSize: 10)),
              pw.Text('사업자등록번호: $bizId', style: pw.TextStyle(font: ttf, fontSize: 10)),
              pw.Text('귀속: $year년 $month월', style: pw.TextStyle(font: ttf, fontSize: 10)),
            ],
          ),
          pw.SizedBox(height: 15),

          // 급여대장 테이블
          _buildPayrollRegisterTable(results, ttf, ttfBold,
            totalBaseSalary, totalOvertimePay, totalNightPay, totalHolidayPay,
            totalWeeklyHolidayPay, totalBonus, totalPayment,
            totalNationalPension, totalHealthInsurance, totalLongTermCare,
            totalEmploymentInsurance, totalIncomeTax, totalLocalIncomeTax,
            totalDeduction, totalNetPayment),
        ],
      ),
    );

    final pdfBytes = await pdf.save();
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${clientName}_${year}년${month}월_급여대장.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(pdfBytes);

    // Windows 기본 뷰어로 열기
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', file.path], runInShell: true);
    }

    return file;
  }

  static pw.Widget _buildPayrollRegisterTable(
    List<SalaryResult> results,
    pw.Font font,
    pw.Font boldFont,
    int totalBaseSalary,
    int totalOvertimePay,
    int totalNightPay,
    int totalHolidayPay,
    int totalWeeklyHolidayPay,
    int totalBonus,
    int totalPayment,
    int totalNationalPension,
    int totalHealthInsurance,
    int totalLongTermCare,
    int totalEmploymentInsurance,
    int totalIncomeTax,
    int totalLocalIncomeTax,
    int totalDeduction,
    int totalNetPayment,
  ) {
    final headers = ['이름', '구분', '기본급', '연장', '야간', '휴일', '주휴', '상여', '지급계', 
                     '국민연금', '건강보험', '장기요양', '고용보험', '소득세', '지방세', '공제계', '실수령액'];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey800, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(40),  // 이름
        1: const pw.FixedColumnWidth(35),  // 구분
        2: const pw.FixedColumnWidth(50),  // 기본급
        3: const pw.FixedColumnWidth(35),  // 연장
        4: const pw.FixedColumnWidth(35),  // 야간
        5: const pw.FixedColumnWidth(35),  // 휴일
        6: const pw.FixedColumnWidth(40),  // 주휴
        7: const pw.FixedColumnWidth(35),  // 상여
        8: const pw.FixedColumnWidth(50),  // 지급계
        9: const pw.FixedColumnWidth(40),  // 국민연금
        10: const pw.FixedColumnWidth(40), // 건강보험
        11: const pw.FixedColumnWidth(35), // 장기요양
        12: const pw.FixedColumnWidth(40), // 고용보험
        13: const pw.FixedColumnWidth(35), // 소득세
        14: const pw.FixedColumnWidth(35), // 지방세
        15: const pw.FixedColumnWidth(45), // 공제계
        16: const pw.FixedColumnWidth(50), // 실수령액
      },
      children: [
        // 헤더
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: headers.map((h) => pw.Padding(
            padding: const pw.EdgeInsets.all(3),
            child: pw.Text(h, style: pw.TextStyle(font: boldFont, fontSize: 7), textAlign: pw.TextAlign.center),
          )).toList(),
        ),
        // 데이터
        ...results.map((result) => pw.TableRow(
          children: [
            _buildCell(result.workerName, font, 7),
            _buildCell(result.employmentType == 'regular' ? '근로' : '사업', font, 6),
            _buildCell(formatMoney(result.baseSalary), font, 7, align: pw.TextAlign.right),
            _buildCell(result.overtimePay > 0 ? formatMoney(result.overtimePay) : '', font, 7, align: pw.TextAlign.right),
            _buildCell(result.nightPay > 0 ? formatMoney(result.nightPay) : '', font, 7, align: pw.TextAlign.right),
            _buildCell(result.holidayPay > 0 ? formatMoney(result.holidayPay) : '', font, 7, align: pw.TextAlign.right),
            _buildCell(formatMoney(result.weeklyHolidayPay), font, 7, align: pw.TextAlign.right),
            _buildCell(result.bonus > 0 ? formatMoney(result.bonus) : '', font, 7, align: pw.TextAlign.right),
            _buildCell(formatMoney(result.totalPayment), font, 7, align: pw.TextAlign.right),
            _buildCell(result.nationalPension > 0 ? formatMoney(result.nationalPension) : '', font, 7, align: pw.TextAlign.right),
            _buildCell(result.healthInsurance > 0 ? formatMoney(result.healthInsurance) : '', font, 7, align: pw.TextAlign.right),
            _buildCell(result.longTermCare > 0 ? formatMoney(result.longTermCare) : '', font, 7, align: pw.TextAlign.right),
            _buildCell(result.employmentInsurance > 0 ? formatMoney(result.employmentInsurance) : '', font, 7, align: pw.TextAlign.right),
            _buildCell(formatMoney(result.incomeTax), font, 7, align: pw.TextAlign.right),
            _buildCell(result.localIncomeTax > 0 ? formatMoney(result.localIncomeTax) : '', font, 7, align: pw.TextAlign.right),
            _buildCell(formatMoney(result.totalDeduction), font, 7, align: pw.TextAlign.right),
            _buildCell(formatMoney(result.netPayment), font, 7, align: pw.TextAlign.right),
          ],
        )).toList(),
        // 합계
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildCell('합계', boldFont, 7),
            _buildCell('', font, 7),
            _buildCell(formatMoney(totalBaseSalary), boldFont, 7, align: pw.TextAlign.right),
            _buildCell(totalOvertimePay > 0 ? formatMoney(totalOvertimePay) : '', boldFont, 7, align: pw.TextAlign.right),
            _buildCell(totalNightPay > 0 ? formatMoney(totalNightPay) : '', boldFont, 7, align: pw.TextAlign.right),
            _buildCell(totalHolidayPay > 0 ? formatMoney(totalHolidayPay) : '', boldFont, 7, align: pw.TextAlign.right),
            _buildCell(formatMoney(totalWeeklyHolidayPay), boldFont, 7, align: pw.TextAlign.right),
            _buildCell(totalBonus > 0 ? formatMoney(totalBonus) : '', boldFont, 7, align: pw.TextAlign.right),
            _buildCell(formatMoney(totalPayment), boldFont, 7, align: pw.TextAlign.right),
            _buildCell(totalNationalPension > 0 ? formatMoney(totalNationalPension) : '', boldFont, 7, align: pw.TextAlign.right),
            _buildCell(totalHealthInsurance > 0 ? formatMoney(totalHealthInsurance) : '', boldFont, 7, align: pw.TextAlign.right),
            _buildCell(totalLongTermCare > 0 ? formatMoney(totalLongTermCare) : '', boldFont, 7, align: pw.TextAlign.right),
            _buildCell(totalEmploymentInsurance > 0 ? formatMoney(totalEmploymentInsurance) : '', boldFont, 7, align: pw.TextAlign.right),
            _buildCell(formatMoney(totalIncomeTax), boldFont, 7, align: pw.TextAlign.right),
            _buildCell(totalLocalIncomeTax > 0 ? formatMoney(totalLocalIncomeTax) : '', boldFont, 7, align: pw.TextAlign.right),
            _buildCell(formatMoney(totalDeduction), boldFont, 7, align: pw.TextAlign.right),
            _buildCell(formatMoney(totalNetPayment), boldFont, 7, align: pw.TextAlign.right),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildCell(String text, pw.Font font, double fontSize, {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: fontSize), textAlign: align),
    );
  }

  // ========== PDF 생성 ==========

  static Future<File> generatePayslipPdf({
    required ClientModel client,
    required SalaryResult result,
    required int year,
    required int month,
  }) async {
    final pdfBytes = await _generatePdfBytes(
      client: client,
      result: result,
      year: year,
      month: month,
    );

    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${client.name}_${result.workerName}_${year}년${month}월_급여명세서.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(pdfBytes);

    // Windows 기본 뷰어로 열기
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', file.path], runInShell: true);
    }

    return file;
  }

  static Future<Uint8List> _generatePdfBytes({
    required ClientModel client,
    required SalaryResult result,
    required int year,
    required int month,
  }) async {
    final pdf = pw.Document();

    // 한글 폰트 로드
    final fontData = await rootBundle.load('assets/fonts/NanumGothic-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);
    final boldFontData = await rootBundle.load('assets/fonts/NanumGothic-Bold.ttf');
    final ttfBold = pw.Font.ttf(boldFontData);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 제목
                pw.Center(
                  child: pw.Text(
                    '급여명세서',
                    style: pw.TextStyle(font: ttfBold, fontSize: 24),
                  ),
                ),
                pw.SizedBox(height: 20),

                // 기본정보
                pw.Text('거래처: ${client.name} (${client.bizId})',
                    style: pw.TextStyle(font: ttf, fontSize: 12)),
                pw.Text('성명: ${result.workerName}',
                    style: pw.TextStyle(font: ttf, fontSize: 12)),
                pw.Text('귀속연월: $year년 $month월',
                    style: pw.TextStyle(font: ttf, fontSize: 12)),
                pw.SizedBox(height: 20),

                // 지급내역
                pw.Text('【 지급내역 】', style: pw.TextStyle(font: ttfBold, fontSize: 14)),
                pw.SizedBox(height: 10),
                _buildPaymentTable(result, ttf),
                pw.SizedBox(height: 20),

                // 공제내역
                pw.Text('【 공제내역 】', style: pw.TextStyle(font: ttfBold, fontSize: 14)),
                pw.SizedBox(height: 10),
                _buildDeductionTable(result, ttf),
                pw.SizedBox(height: 20),

                // 실수령액
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('실수령액', style: pw.TextStyle(font: ttfBold, fontSize: 16)),
                    pw.Text(
                      '${formatMoney(result.netPayment)}원',
                      style: pw.TextStyle(font: ttfBold, fontSize: 16),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  '※ 본 문서는 기밀 정보를 포함하고 있습니다.',
                  style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
          );
        },
      ),
    );

    // PDF 저장
    // 참고: pdf 패키지 버전에 따라 암호화 기능이 지원되지 않을 수 있음
    return pdf.save();
  }

  static pw.Widget _buildPaymentTable(SalaryResult result, pw.Font font) {
    final rows = <List<String>>[];

    rows.add(['기본급', result.baseSalaryFormula, _formatAmount(result.baseSalary)]);

    if (result.overtimePay > 0) {
      rows.add(['연장수당', result.overtimeFormula, _formatAmount(result.overtimePay)]);
    }
    if (result.nightPay > 0) {
      rows.add(['야간수당', result.nightFormula, _formatAmount(result.nightPay)]);
    }
    if (result.holidayPay > 0) {
      rows.add(['휴일수당', result.holidayFormula, _formatAmount(result.holidayPay)]);
    }
    if (result.weeklyHolidayPay > 0) {
      rows.add(['주휴수당', result.weeklyHolidayFormula, _formatAmount(result.weeklyHolidayPay)]);
    }
    if (result.bonus > 0) {
      rows.add(['상여금', '', _formatAmount(result.bonus)]);
    }
    if (result.additionalPay1 > 0) {
      rows.add([result.additionalPay1Name, '(추가수당)', _formatAmount(result.additionalPay1)]);
    }
    if (result.additionalPay2 > 0) {
      rows.add([result.additionalPay2Name, '(추가수당)', _formatAmount(result.additionalPay2)]);
    }
    if (result.additionalPay3 > 0) {
      rows.add([result.additionalPay3Name, '(추가수당)', _formatAmount(result.additionalPay3)]);
    }

    rows.add(['지급계', '', _formatAmount(result.totalPayment)]);

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FixedColumnWidth(100),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FixedColumnWidth(100),
      },
      children: rows.map((row) {
        return pw.TableRow(
          children: row.map((cell) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(cell, style: pw.TextStyle(font: font, fontSize: 10)),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildDeductionTable(SalaryResult result, pw.Font font) {
    final rows = <List<String>>[];

    if (result.nationalPension > 0) {
      rows.add(['국민연금', result.pensionFormula, _formatAmount(result.nationalPension)]);
    }
    if (result.healthInsurance > 0) {
      rows.add(['건강보험', result.healthFormula, _formatAmount(result.healthInsurance)]);
    }
    if (result.longTermCare > 0) {
      rows.add(['장기요양', result.longTermCareFormula, _formatAmount(result.longTermCare)]);
    }
    if (result.employmentInsurance > 0) {
      rows.add(['고용보험', result.employmentFormula, _formatAmount(result.employmentInsurance)]);
    }
    if (result.incomeTax > 0) {
      rows.add(['소득세', result.incomeTaxFormula, _formatAmount(result.incomeTax)]);
    }
    if (result.localIncomeTax > 0) {
      rows.add(['지방소득세', result.localTaxFormula, _formatAmount(result.localIncomeTax)]);
    }
    if (result.additionalDeduct1 > 0) {
      rows.add([result.additionalDeduct1Name, '(추가공제)', _formatAmount(result.additionalDeduct1)]);
    }
    if (result.additionalDeduct2 > 0) {
      rows.add([result.additionalDeduct2Name, '(추가공제)', _formatAmount(result.additionalDeduct2)]);
    }
    if (result.additionalDeduct3 > 0) {
      rows.add([result.additionalDeduct3Name, '(추가공제)', _formatAmount(result.additionalDeduct3)]);
    }

    rows.add(['공제계', '', _formatAmount(result.totalDeduction)]);

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FixedColumnWidth(100),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FixedColumnWidth(100),
      },
      children: rows.map((row) {
        return pw.TableRow(
          children: row.map((cell) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(cell, style: pw.TextStyle(font: font, fontSize: 10)),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  static String _formatAmount(int amount) {
    return '${formatMoney(amount)}원';
  }

  // ========== 이메일 발송 ==========

  static Future<void> sendPayslipEmail({
    required SmtpConfig smtpConfig,
    required ClientModel client,
    required WorkerModel worker,
    required int year,
    required int month,
    required File pdfFile,
  }) async {
    final smtpServer = SmtpServer(
      smtpConfig.host,
      port: smtpConfig.port,
      username: smtpConfig.username,
      password: smtpConfig.password,
      ssl: smtpConfig.useSSL,
    );

    // 이메일 템플릿 변수 치환
    final subject = client.emailSubjectTemplate
        .replaceAll('{clientName}', client.name)
        .replaceAll('{year}', year.toString())
        .replaceAll('{month}', month.toString())
        .replaceAll('{workerName}', worker.name);

    final body = client.emailBodyTemplate
        .replaceAll('{clientName}', client.name)
        .replaceAll('{year}', year.toString())
        .replaceAll('{month}', month.toString())
        .replaceAll('{workerName}', worker.name);

    final message = Message()
      ..from = Address(smtpConfig.username)
      ..recipients.add(worker.emailTo!)
      ..subject = subject
      ..text = body
      ..attachments.add(FileAttachment(pdfFile));

    if (worker.emailCc != null && worker.emailCc!.isNotEmpty) {
      message.ccRecipients.add(worker.emailCc!);
    }

    await send(message, smtpServer);
  }
}
