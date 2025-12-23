import 'dart:io';
import 'dart:typed_data';
import 'dart:convert' show utf8;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../core/models.dart';
import '../utils/path_helper.dart';

class FileEmailService {
  // ========== Excel 템플릿 생성 ==========

  static Future<File> generateExcelTemplate(
    String clientName, {
    String? bizId,
    required String basePath,
    bool useClientSubfolders = true,
    required int year,
    required int month,
  }) async {
    final excel = Excel.createExcel();
    
    // 급여대장 시트 생성
    final sheet = excel['급여대장'];
    
    // Sheet1 삭제 (생성 후 삭제)
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // 거래처 정보
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('거래처명');
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue(clientName);
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue('사업자등록번호');
    sheet.cell(CellIndex.indexByString('B2')).value = TextCellValue(bizId ?? '');

    // 안내 문구 (3행)
    sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('※ 안내');
    sheet.cell(CellIndex.indexByString('B3')).value = TextCellValue('월급제: 월급란에 금액 입력 (시급란은 0 또는 빈칸)');
    sheet.cell(CellIndex.indexByString('G3')).value = TextCellValue('시급제: 시급란에 금액 입력 (월급란은 0 또는 빈칸)');

    // 헤더 (4행) - 기본 정보만
    final headers = [
      '이름',
      '생년월일(YYMMDD)',
      '입사일(YYYY-MM-DD)',
      '퇴사일(YYYY-MM-DD)',
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

    // 직원 데이터는 사용자가 직접 입력하도록 빈 템플릿 제공
    // (매달 변경되는 값들은 DB에서 가져오지 않음)

    final bytes = excel.encode();
    
    // 자동 저장 경로 생성
    String folderPath;
    if (useClientSubfolders) {
      folderPath = PathHelper.getClientFolderPath(
        basePath: basePath,
        clientName: clientName,
        year: year,
        month: month,
      );
    } else {
      folderPath = basePath;
    }
    
    // 폴더가 없으면 생성
    await PathHelper.ensureDirectoryExists(folderPath);
    
    final fileName = '${clientName}_${year}년${month.toString().padLeft(2, '0')}월_급여대장_템플릿.xlsx';
    final outputPath = path.join(folderPath, fileName);

    final file = File(outputPath);
    await file.writeAsBytes(bytes!);

    // Windows 탐색기에서 열기
    if (Platform.isWindows) {
      await Process.run('explorer', ['/select,', file.path]);
    }

    return file;
  }

  // ========== Excel 파싱 ==========

  static Future<Map<String, dynamic>> parseExcelFile(String filePath) async {
    try {
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
        final joinDate = row[2]?.value?.toString() ?? ''; // 입사일
        final resignDate = row[3]?.value?.toString() ?? ''; // 퇴사일
        final monthlySalary = int.tryParse(row[4]?.value?.toString() ?? '0') ?? 0;
        final hourlyRate = int.tryParse(row[5]?.value?.toString() ?? '0') ?? 0;
        final weeklyHours = double.tryParse(row[6]?.value?.toString() ?? '40') ?? 40;
        final normalHours = double.tryParse(row[7]?.value?.toString() ?? '209') ?? 209;
        final overtimeHours = double.tryParse(row[8]?.value?.toString() ?? '0') ?? 0;
        final nightHours = double.tryParse(row[9]?.value?.toString() ?? '0') ?? 0;
        final holidayHours = double.tryParse(row[10]?.value?.toString() ?? '0') ?? 0;
        final weekCount = int.tryParse(row[11]?.value?.toString() ?? '4') ?? 4;
        final bonus = int.tryParse(row[12]?.value?.toString() ?? '0') ?? 0;
        final additionalPay1 = int.tryParse(row[13]?.value?.toString() ?? '0') ?? 0;
        final additionalPay2 = int.tryParse(row[14]?.value?.toString() ?? '0') ?? 0;
        final additionalDeduct1 = int.tryParse(row[15]?.value?.toString() ?? '0') ?? 0;
        final additionalDeduct2 = int.tryParse(row[16]?.value?.toString() ?? '0') ?? 0;

        workers.add({
          'name': name,
          'birthDate': birthDate,
          'joinDate': joinDate.isNotEmpty ? joinDate : null,
          'resignDate': resignDate.isNotEmpty ? resignDate : null,
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
    } catch (e) {
      // Excel 파싱 에러 상세 정보 제공
      throw Exception('Excel 파일 읽기 실패: $e\n\n'
          '가능한 원인:\n'
          '1. 파일이 손상되었거나 형식이 올바르지 않습니다.\n'
          '2. Excel 파일이 아닌 다른 형식의 파일입니다.\n'
          '3. 파일에 지원하지 않는 서식이 포함되어 있습니다.\n\n'
          '해결 방법:\n'
          '- 템플릿을 다시 다운로드하여 사용해주세요.\n'
          '- Excel에서 다른 이름으로 저장 시 "Excel 통합 문서(*.xlsx)" 형식을 선택하세요.\n'
          '- 복잡한 서식(조건부 서식, 매크로 등)을 제거하고 다시 시도하세요.');
    }
  }

  // ========== CSV 급여대장 내보내기 ==========

  static Future<File> exportPayrollCsv({
    required String clientName,
    required int year,
    required int month,
    required List<SalaryResult> results,
    required String basePath, // 기본 경로 필수
    bool useClientSubfolders = true,
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
    
    // 자동 경로 생성
    final filePath = PathHelper.getFilePath(
      basePath: basePath,
      clientName: clientName,
      year: year,
      month: month,
      fileType: 'csv',
      useClientSubfolders: useClientSubfolders,
    );
    
    // 폴더 생성
    final directory = Directory(filePath).parent;
    await PathHelper.ensureDirectoryExists(directory.path);

    // 파일 저장 (덮어쓰기)
    final file = File(filePath);
    await file.writeAsString('\uFEFF$csv'); // UTF-8 BOM

    return file;
  }

  // ========== 급여대장 PDF 생성 ==========

  static Future<File> exportPayrollRegisterPdf({
    required String clientName,
    required String bizId,
    required int year,
    required int month,
    required List<SalaryResult> results,
    required String basePath,
    bool useClientSubfolders = true,
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
    
    // 자동 저장 경로 생성
    final outputPath = PathHelper.getFilePath(
      basePath: basePath,
      clientName: clientName,
      year: year,
      month: month,
      fileType: 'pdf_register',
      useClientSubfolders: useClientSubfolders,
    );
    
    // 폴더가 없으면 생성
    await PathHelper.ensureDirectoryExists(File(outputPath).parent.path);

    final file = File(outputPath);
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
    required String basePath, // 기본 경로 필수
    bool useClientSubfolders = true,
  }) async {
    final pdfBytes = await _generatePdfBytes(
      client: client,
      result: result,
      year: year,
      month: month,
    );

    // 자동 경로 생성
    final filePath = PathHelper.getFilePath(
      basePath: basePath,
      clientName: client.name,
      year: year,
      month: month,
      fileType: 'pdf_payslip',
      workerName: result.workerName,
      birthDate: result.birthDate, // 동명이인 구분용
      useClientSubfolders: useClientSubfolders,
    );
    
    // 폴더 생성
    final directory = Directory(filePath).parent;
    await PathHelper.ensureDirectoryExists(directory.path);

    // 파일 저장 (덮어쓰기)
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);

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

  /// HTML 명세서 생성
  static Future<File> generatePayslipHtml({
    required ClientModel client,
    required SalaryResult result,
    required int year,
    required int month,
    required String basePath,
    bool useClientSubfolders = true,
  }) async {
    final htmlContent = _generateHtmlContent(
      client: client,
      result: result,
      year: year,
      month: month,
    );

    // 자동 경로 생성
    final filePath = PathHelper.getFilePath(
      basePath: basePath,
      clientName: client.name,
      year: year,
      month: month,
      fileType: 'html_payslip',
      workerName: result.workerName,
      birthDate: result.birthDate, // 동명이인 구분용
      useClientSubfolders: useClientSubfolders,
    );
    
    // 폴더 생성
    final directory = Directory(filePath).parent;
    await PathHelper.ensureDirectoryExists(directory.path);

    // 파일 저장 (덮어쓰기)
    final file = File(filePath);
    await file.writeAsString(htmlContent, encoding: utf8);

    return file;
  }

  /// HTML 컨텐츠 생성
  static String _generateHtmlContent({
    required ClientModel client,
    required SalaryResult result,
    required int year,
    required int month,
  }) {
    // HTML 템플릿
    return '''
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>급여명세서 - ${result.workerName}</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      font-family: 'Malgun Gothic', sans-serif;
      padding: 40px 20px;
      background-color: #f5f5f5;
    }
    /* 인증 모달 스타일 */
    .auth-overlay {
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background-color: rgba(0, 0, 0, 0.8);
      display: flex;
      justify-content: center;
      align-items: center;
      z-index: 9999;
    }
    .auth-modal {
      background-color: white;
      padding: 40px;
      border-radius: 12px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.3);
      max-width: 400px;
      width: 90%;
    }
    .auth-modal h2 {
      margin-bottom: 10px;
      color: #333;
      font-size: 24px;
    }
    .auth-modal p {
      color: #666;
      margin-bottom: 20px;
      font-size: 14px;
    }
    .auth-input {
      width: 100%;
      padding: 12px;
      font-size: 16px;
      border: 2px solid #ddd;
      border-radius: 6px;
      margin-bottom: 20px;
      font-family: 'Malgun Gothic', sans-serif;
    }
    .auth-input:focus {
      outline: none;
      border-color: #2196F3;
    }
    .auth-button {
      width: 100%;
      padding: 12px;
      background-color: #2196F3;
      color: white;
      border: none;
      border-radius: 6px;
      font-size: 16px;
      font-weight: bold;
      cursor: pointer;
      font-family: 'Malgun Gothic', sans-serif;
    }
    .auth-button:hover {
      background-color: #1976D2;
    }
    .auth-error {
      color: #f44336;
      font-size: 14px;
      margin-top: 10px;
      display: none;
    }
    .content-hidden {
      display: none;
    }
    .container {
      max-width: 800px;
      margin: 0 auto;
      background-color: white;
      padding: 40px;
      border-radius: 8px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
      border: 2px solid #2196F3;
    }
    .banner {
      background-color: #E3F2FD;
      padding: 12px;
      margin-bottom: 20px;
      border-radius: 8px;
      display: flex;
      align-items: center;
    }
    .banner-icon {
      color: #1976D2;
      margin-right: 8px;
      font-size: 20px;
    }
    .banner-text {
      color: #0D47A1;
      font-weight: 500;
    }
    .title {
      text-align: center;
      font-size: 28px;
      font-weight: bold;
      margin-bottom: 30px;
      color: #0D47A1;
    }
    .section {
      margin-bottom: 30px;
    }
    .section-title {
      font-size: 16px;
      font-weight: bold;
      color: #666;
      margin-bottom: 12px;
    }
    .info-row {
      display: flex;
      padding: 8px 0;
    }
    .info-label {
      width: 150px;
      color: #999;
    }
    .info-value {
      flex: 1;
      font-weight: 500;
    }
    .divider {
      height: 2px;
      background-color: #333;
      margin: 24px 0;
    }
    .amount-section {
      margin-bottom: 24px;
    }
    .amount-title {
      font-size: 16px;
      font-weight: bold;
      margin-bottom: 12px;
    }
    .amount-title.payment {
      color: #1976D2;
    }
    .amount-title.deduction {
      color: #D32F2F;
    }
    .amount-table {
      border: 1px solid #ddd;
      border-radius: 8px;
      overflow: hidden;
    }
    .amount-row {
      display: flex;
      justify-content: space-between;
      padding: 12px 16px;
      border-bottom: 1px solid #eee;
    }
    .amount-row:last-child {
      border-bottom: none;
    }
    .amount-formula {
      font-size: 12px;
      color: #999;
      margin-top: 4px;
    }
    .amount-total {
      background-color: #E3F2FD;
      padding: 12px 16px;
      display: flex;
      justify-content: space-between;
      font-weight: bold;
    }
    .amount-total.payment {
      background-color: #E3F2FD;
      color: #0D47A1;
    }
    .amount-total.deduction {
      background-color: #FFEBEE;
      color: #B71C1C;
    }
    .net-payment {
      background-color: #C8E6C9;
      border: 3px solid #388E3C;
      border-radius: 8px;
      padding: 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin: 32px 0;
    }
    .net-payment-label {
      font-size: 20px;
      font-weight: bold;
      color: #1B5E20;
    }
    .net-payment-amount {
      font-size: 28px;
      font-weight: bold;
      color: #1B5E20;
    }
    @media print {
      body {
        background-color: white;
        padding: 0;
      }
      .container {
        box-shadow: none;
        border: none;
      }
    }
  </style>
</head>
<body>
  <!-- 생년월일 인증 모달 -->
  <div class="auth-overlay" id="authOverlay">
    <div class="auth-modal">
      <h2>🔐 본인 인증</h2>
      <p>급여명세서를 확인하려면 생년월일을 입력하세요.</p>
      <input 
        type="text" 
        class="auth-input" 
        id="birthdateInput" 
        placeholder="생년월일 6자리 (예: 900101)"
        maxlength="6"
        autocomplete="off"
      />
      <button class="auth-button" onclick="verifyBirthdate()">확인</button>
      <div class="auth-error" id="authError">생년월일이 일치하지 않습니다. 다시 시도해주세요.</div>
    </div>
  </div>

  <!-- 명세서 내용 (인증 후 표시) -->
  <div class="container content-hidden" id="payslipContent">
    <div class="banner">
      <span class="banner-icon">🌐</span>
      <span class="banner-text">HTML 형식으로 표시 중 (웹 브라우저 호환)</span>
    </div>
    
    <h1 class="title">급여명세서</h1>
    
    <div class="section">
      <div class="section-title">회사 정보</div>
      <div class="info-row">
        <span class="info-label">회사명</span>
        <span class="info-value">${client.name}</span>
      </div>
      <div class="info-row">
        <span class="info-label">사업자등록번호</span>
        <span class="info-value">${client.bizId}</span>
      </div>
      <div class="info-row">
        <span class="info-label">지급 연월</span>
        <span class="info-value">${year}년 ${month}월</span>
      </div>
    </div>
    
    <div class="section">
      <div class="section-title">직원 정보</div>
      <div class="info-row">
        <span class="info-label">성명</span>
        <span class="info-value">${result.workerName}</span>
      </div>
      <div class="info-row">
        <span class="info-label">생년월일</span>
        <span class="info-value">${result.birthDate}</span>
      </div>
      <div class="info-row">
        <span class="info-label">구분</span>
        <span class="info-value">${result.employmentType == 'regular' ? '근로소득' : '사업소득'}</span>
      </div>
    </div>
    
    <div class="divider"></div>
    
    <div class="amount-section">
      <div class="amount-title payment">지급 항목</div>
      <div class="amount-table">
        <div class="amount-row">
          <div>
            <div>기본급</div>
            ${result.baseSalaryFormula.isNotEmpty ? '<div class="amount-formula">계산: ${result.baseSalaryFormula}</div>' : ''}
          </div>
          <div>${_formatNumber(result.baseSalary)}원</div>
        </div>
        ${result.overtimePay > 0 ? '''
        <div class="amount-row">
          <div>
            <div>연장수당</div>
            ${result.overtimeFormula.isNotEmpty ? '<div class="amount-formula">계산: ${result.overtimeFormula}</div>' : ''}
          </div>
          <div>${_formatNumber(result.overtimePay)}원</div>
        </div>
        ''' : ''}
        ${result.nightPay > 0 ? '''
        <div class="amount-row">
          <div>
            <div>야간수당</div>
            ${result.nightFormula.isNotEmpty ? '<div class="amount-formula">계산: ${result.nightFormula}</div>' : ''}
          </div>
          <div>${_formatNumber(result.nightPay)}원</div>
        </div>
        ''' : ''}
        ${result.holidayPay > 0 ? '''
        <div class="amount-row">
          <div>
            <div>휴일수당</div>
            ${result.holidayFormula.isNotEmpty ? '<div class="amount-formula">계산: ${result.holidayFormula}</div>' : ''}
          </div>
          <div>${_formatNumber(result.holidayPay)}원</div>
        </div>
        ''' : ''}
        ${result.weeklyHolidayPay > 0 ? '''
        <div class="amount-row">
          <div>
            <div>주휴수당</div>
            ${result.weeklyHolidayFormula.isNotEmpty ? '<div class="amount-formula">계산: ${result.weeklyHolidayFormula}</div>' : ''}
          </div>
          <div>${_formatNumber(result.weeklyHolidayPay)}원</div>
        </div>
        ''' : ''}
        ${result.bonus > 0 ? '''
        <div class="amount-row">
          <div>상여금</div>
          <div>${_formatNumber(result.bonus)}원</div>
        </div>
        ''' : ''}
        <div class="amount-total payment">
          <span>합계</span>
          <span>${_formatNumber(result.totalPayment)}원</span>
        </div>
      </div>
    </div>
    
    <div class="amount-section">
      <div class="amount-title deduction">공제 항목</div>
      <div class="amount-table">
        ${result.nationalPension > 0 ? '''
        <div class="amount-row">
          <div>
            <div>국민연금</div>
            ${result.pensionFormula.isNotEmpty ? '<div class="amount-formula">계산: ${result.pensionFormula}</div>' : ''}
          </div>
          <div>${_formatNumber(result.nationalPension)}원</div>
        </div>
        ''' : ''}
        ${result.healthInsurance > 0 ? '''
        <div class="amount-row">
          <div>
            <div>건강보험</div>
            ${result.healthFormula.isNotEmpty ? '<div class="amount-formula">계산: ${result.healthFormula}</div>' : ''}
          </div>
          <div>${_formatNumber(result.healthInsurance)}원</div>
        </div>
        ''' : ''}
        ${result.longTermCare > 0 ? '''
        <div class="amount-row">
          <div>
            <div>장기요양</div>
            ${result.longTermCareFormula.isNotEmpty ? '<div class="amount-formula">계산: ${result.longTermCareFormula}</div>' : ''}
          </div>
          <div>${_formatNumber(result.longTermCare)}원</div>
        </div>
        ''' : ''}
        ${result.employmentInsurance > 0 ? '''
        <div class="amount-row">
          <div>
            <div>고용보험</div>
            ${result.employmentFormula.isNotEmpty ? '<div class="amount-formula">계산: ${result.employmentFormula}</div>' : ''}
          </div>
          <div>${_formatNumber(result.employmentInsurance)}원</div>
        </div>
        ''' : ''}
        ${result.incomeTax > 0 ? '''
        <div class="amount-row">
          <div>
            <div>소득세</div>
            ${result.incomeTaxFormula.isNotEmpty ? '<div class="amount-formula">계산: ${result.incomeTaxFormula}</div>' : ''}
          </div>
          <div>${_formatNumber(result.incomeTax)}원</div>
        </div>
        ''' : ''}
        ${result.localIncomeTax > 0 ? '''
        <div class="amount-row">
          <div>
            <div>지방소득세</div>
            ${result.localTaxFormula.isNotEmpty ? '<div class="amount-formula">계산: ${result.localTaxFormula}</div>' : ''}
          </div>
          <div>${_formatNumber(result.localIncomeTax)}원</div>
        </div>
        ''' : ''}
        <div class="amount-total deduction">
          <span>합계</span>
          <span>${_formatNumber(result.totalDeduction)}원</span>
        </div>
      </div>
    </div>
    
    <div class="divider"></div>
    
    <div class="net-payment">
      <span class="net-payment-label">실수령액</span>
      <span class="net-payment-amount">${_formatNumber(result.netPayment)}원</span>
    </div>
  </div>

  <script>
    // 실제 생년월일 (YYMMDD)
    const correctBirthdate = '${result.birthDate}';
    
    // 페이지 로드 시 입력창에 포커스
    document.getElementById('birthdateInput').focus();
    
    // 엔터키로도 확인 가능
    document.getElementById('birthdateInput').addEventListener('keypress', function(e) {
      if (e.key === 'Enter') {
        verifyBirthdate();
      }
    });
    
    // 생년월일 인증 함수
    function verifyBirthdate() {
      const input = document.getElementById('birthdateInput').value.trim();
      const errorDiv = document.getElementById('authError');
      
      if (input === correctBirthdate) {
        // 인증 성공
        document.getElementById('authOverlay').style.display = 'none';
        document.getElementById('payslipContent').classList.remove('content-hidden');
      } else {
        // 인증 실패
        errorDiv.style.display = 'block';
        document.getElementById('birthdateInput').value = '';
        document.getElementById('birthdateInput').focus();
        
        // 3초 후 에러 메시지 숨기기
        setTimeout(function() {
          errorDiv.style.display = 'none';
        }, 3000);
      }
    }
  </script>
</body>
</html>
''';
  }

  /// 이메일로 HTML 명세서 발송
  static Future<void> sendPayslipEmailAsHtml({
    required ClientModel client,
    required WorkerModel worker,
    required SalaryResult result,
    required int year,
    required int month,
    required SmtpConfig smtpConfig,
    required String basePath,
    bool useClientSubfolders = true,
  }) async {
    if (worker.emailTo == null || worker.emailTo!.isEmpty) {
      throw Exception('이메일 주소가 설정되지 않았습니다.');
    }

    // HTML 파일 생성
    final htmlFile = await generatePayslipHtml(
      client: client,
      result: result,
      year: year,
      month: month,
      basePath: basePath,
      useClientSubfolders: useClientSubfolders,
    );

    final smtpServer = SmtpServer(
      smtpConfig.host,
      port: smtpConfig.port,
      username: smtpConfig.username,
      password: smtpConfig.password,
      ssl: smtpConfig.useSSL,
    );

    final subject = client.emailSubjectTemplate
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
      ..attachments.add(FileAttachment(htmlFile));

    if (worker.emailCc != null && worker.emailCc!.isNotEmpty) {
      message.ccRecipients.add(worker.emailCc!);
    }

    await send(message, smtpServer);
  }

  /// 숫자 포맷팅 (천단위 콤마)
  static String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
