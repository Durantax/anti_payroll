import 'dart:io';
import 'dart:convert'; // ✅ utf8 사용하려면 필요
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:csv/csv.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '세무회계 두란 급여관리',
      home: PayrollScreen(),
    );
  }
}

// ==========================================
// 1. 데이터 모델 & 거래처 관리
// ==========================================

class ClientInfo {
  String name;
  String businessId;
  ClientInfo({required this.name, required this.businessId});
}

class ClientRepository {
  static final List<ClientInfo> clients = [
    ClientInfo(name: "(주)맛있는김치", businessId: "123-45-67890"),
    ClientInfo(name: "세무회계 두란", businessId: "101-12-34567"),
  ];

  static String? findCompanyName(String bizId) {
    String cleanId = bizId.replaceAll(RegExp(r'[^0-9]'), '');
    try {
      final client = clients.firstWhere(
              (c) => c.businessId.replaceAll(RegExp(r'[^0-9]'), '') == cleanId
      );
      return client.name;
    } catch (e) {
      return null;
    }
  }
}

enum WorkerType { freelance, regular }
enum HealthInsBasis { reported, actual }

class Worker {
  String name;
  String email;
  String birthDate;
  WorkerType type;

  double hourlyRate;
  double normalHours;
  double overtimeHours;
  double nightHours;
  double holidayHours;

  double foodAllowance;
  double carAllowance;
  double reportedMonthlyIncome;
  HealthInsBasis healthBasis;
  int familyCount;
  int childCount;

  SalaryResult? result;

  Worker({
    required this.name, required this.email, required this.birthDate,
    this.type = WorkerType.regular,
    this.hourlyRate = 9860, this.normalHours = 209,
    this.overtimeHours = 0, this.nightHours = 0, this.holidayHours = 0,
    this.foodAllowance = 0, this.carAllowance = 0,
    this.reportedMonthlyIncome = 0, this.healthBasis = HealthInsBasis.reported,
    this.familyCount = 1, this.childCount = 0,
  });
}

class SalaryResult {
  double basePay, overtimePay, nightPay, holidayPay, weeklyHolidayPay;
  double totalPay, taxablePay;
  double taxIncome, taxLocal, nationalPension, healthInsurance, careInsurance, empInsurance, tax33;
  double totalDeduction, netPay;

  SalaryResult({
    this.basePay=0, this.overtimePay=0, this.nightPay=0, this.holidayPay=0, this.weeklyHolidayPay=0,
    this.totalPay=0, this.taxablePay=0,
    this.taxIncome=0, this.taxLocal=0, this.nationalPension=0, this.healthInsurance=0,
    this.careInsurance=0, this.empInsurance=0, this.tax33=0,
    this.totalDeduction=0, this.netPay=0,
  });
}

// ==========================================
// 2. 급여 계산 엔진
// ==========================================
class PayrollEngine {
  static void calculate(Worker worker) {
    double base = worker.normalHours * worker.hourlyRate;
    double overtime = worker.overtimeHours * worker.hourlyRate * 1.5;
    double night = worker.nightHours * worker.hourlyRate * 0.5;

    double h8 = (worker.holidayHours > 8) ? 8 : worker.holidayHours;
    double hOver = (worker.holidayHours > 8) ? worker.holidayHours - 8 : 0;
    double holiday = (h8 * 1.5 + hOver * 2.0) * worker.hourlyRate;

    double weeklyHoliday = 0;
    if (worker.type == WorkerType.regular && worker.normalHours >= 60) {
      weeklyHoliday = 35 * worker.hourlyRate;
    }

    double total = base + overtime + night + holiday + weeklyHoliday;
    double taxFree = worker.foodAllowance + worker.carAllowance;
    double taxable = total - taxFree;
    if (taxable < 0) taxable = 0;

    SalaryResult res = SalaryResult(
      basePay: base, overtimePay: overtime, nightPay: night, holidayPay: holiday, weeklyHolidayPay: weeklyHoliday,
      totalPay: total, taxablePay: taxable,
    );

    if (worker.type == WorkerType.freelance) {
      res.tax33 = (total * 0.033).floorToDouble();
      res.tax33 = (res.tax33 / 10).floor() * 10.0;
      res.totalDeduction = res.tax33;
    } else {
      double pensionBase = (worker.reportedMonthlyIncome > 0) ? worker.reportedMonthlyIncome : taxable;
      res.nationalPension = (pensionBase * 0.045 / 10).floor() * 10.0;

      double healthBase = 0;
      if (worker.healthBasis == HealthInsBasis.reported && worker.reportedMonthlyIncome > 0) {
        healthBase = worker.reportedMonthlyIncome;
      } else {
        healthBase = taxable;
      }
      res.healthInsurance = (healthBase * 0.03545 / 10).floor() * 10.0;
      res.careInsurance = (res.healthInsurance * 0.1295 / 10).floor() * 10.0;
      res.empInsurance = (taxable * 0.009 / 10).floor() * 10.0;

      res.taxIncome = _calculateIncomeTax(taxable, worker.familyCount, worker.childCount);
      res.taxLocal = (res.taxIncome * 0.1 / 10).floor() * 10.0;

      res.totalDeduction = res.nationalPension + res.healthInsurance + res.careInsurance + res.empInsurance + res.taxIncome + res.taxLocal;
    }
    res.netPay = total - res.totalDeduction;
    worker.result = res;
  }

  static double _calculateIncomeTax(double monthly, int family, int children) {
    double annual = monthly * 12;
    double tax = 0;
    if (annual <= 14000000) return 0;
    if (annual <= 30000000) {
      if (family == 1) tax = 3100000 + annual * 0.04;
      else if (family == 2) tax = 3600000 + annual * 0.04;
      else tax = 5000000 + annual * 0.07;
    } else if (annual <= 45000000) {
      tax = 3100000 + annual * 0.04 + (annual - 30000000) * 0.05;
    } else {
      tax = 3600000 + (annual - 30000000) * 0.15;
    }
    double monthlyTax = tax / 12;
    if (children >= 1) monthlyTax -= 12500;
    if (children >= 2) monthlyTax -= 29160;
    if (monthlyTax < 0) return 0;
    return (monthlyTax / 10).floor() * 10.0;
  }
}

// ==========================================
// 3. 엑셀 파싱 및 양식 생성
// ==========================================

class TemplateGenerator {
  static Future<void> downloadTemplate() async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Sheet1'];

    List<String> headers = [
      "이름", "생년월일(6자리)", "시급", "정상근로(시간)", "연장근로(시간)",
      "야간근로(시간)", "휴일근로(시간)", "식대(비과세)", "차량유지비(비과세)",
      "사업자등록번호(선택)"
    ];

    sheet.appendRow(headers.map((e) => TextCellValue(e)).toList());

    sheet.appendRow([
      TextCellValue("홍길동"), TextCellValue("800101"), IntCellValue(9860), IntCellValue(209), IntCellValue(10),
      IntCellValue(0), IntCellValue(0), IntCellValue(200000), IntCellValue(0),
      TextCellValue("123-45-67890")
    ]);

    sheet.appendRow([TextCellValue("※ 위 예시를 지우고 작성해주세요. 사업자번호는 첫 줄에만 적어도 됩니다.")]);

    var fileBytes = excel.save();
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: '표준 급여 양식 다운로드',
      fileName: '세무회계두란_급여요청양식.xlsx',
    );

    if (outputFile != null && fileBytes != null) {
      File(outputFile)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
    }
  }
}

class SmartExcelParser {
  static String _parseBirthDate(String input) {
    String numbers = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (numbers.isEmpty) return "000000";
    if (numbers.length == 8) return numbers.substring(2, 8);
    if (numbers.length >= 6) return numbers.substring(0, 6);
    return numbers.padRight(6, '0');
  }

  static Future<Map<String, dynamic>> parse(File file) async {
    var bytes = file.readAsBytesSync();
    var excel = Excel.decodeBytes(bytes);

    List<Worker> loadedWorkers = [];
    String? matchedCompanyName;
    String? foundBizId;

    for (var table in excel.tables.keys) {
      var sheet = excel.tables[table]!;

      for (var row in sheet.rows) {
        for (var cell in row) {
          if (cell == null) continue;
          String val = cell.value.toString();
          if (foundBizId == null && val.contains("사업자")) {
            int index = row.indexOf(cell);
            for(int k=index+1; k<row.length; k++) {
              String? potentialId = row[k]?.value.toString();
              if(potentialId != null && potentialId.replaceAll(RegExp(r'[^0-9]'), '').length >= 10) {
                foundBizId = potentialId;
                matchedCompanyName = ClientRepository.findCompanyName(foundBizId!);
                break;
              }
            }
          }
        }
      }

      int headerRowIndex = -1;
      Map<String, int> colMap = {};

      for (int i = 0; i < sheet.rows.length; i++) {
        var row = sheet.rows[i];
        bool hasName = row.any((c) => c?.value.toString().contains("이름") ?? false);
        bool hasBirth = row.any((c) => (c?.value.toString().contains("생년") ?? false) || (c?.value.toString().contains("주민") ?? false));

        if (hasName && hasBirth) {
          headerRowIndex = i;
          for (int j = 0; j < row.length; j++) {
            String header = row[j]?.value.toString().replaceAll(" ", "") ?? "";
            if (header.contains("이름")) colMap['name'] = j;
            if (header.contains("생년") || header.contains("주민")) colMap['id'] = j;
            if (header.contains("시급")) colMap['pay'] = j;
            if (header.contains("정상")) colMap['normal'] = j;
            if (header.contains("연장")) colMap['over'] = j;
            if (header.contains("휴일")) colMap['holi'] = j;
            if (header.contains("야간")) colMap['night'] = j;
            if (header.contains("식대")) colMap['food'] = j;
            if (header.contains("차량")) colMap['car'] = j;
          }
          break;
        }
      }

      if (headerRowIndex != -1) {
        for (int i = headerRowIndex + 1; i < sheet.rows.length; i++) {
          var row = sheet.rows[i];
          if (row.isEmpty || row[colMap['name']!] == null) continue;

          String name = row[colMap['name']!]?.value.toString() ?? "";
          if (name.isEmpty || name.contains("예시")) continue;

          String rawId = row[colMap['id']!]?.value.toString() ?? "000000";

          loadedWorkers.add(Worker(
            name: name,
            birthDate: _parseBirthDate(rawId),
            email: "",
            hourlyRate: double.tryParse(row[colMap['pay']!]?.value.toString() ?? "9860") ?? 9860,
            normalHours: double.tryParse(row[colMap['normal']!]?.value.toString() ?? "0") ?? 0,
            overtimeHours: double.tryParse(row[colMap['over']!]?.value.toString() ?? "0") ?? 0,
            holidayHours: double.tryParse(row[colMap['holi']!]?.value.toString() ?? "0") ?? 0,
            nightHours: double.tryParse(row[colMap['night']!]?.value.toString() ?? "0") ?? 0,
            foodAllowance: colMap.containsKey('food') ? (double.tryParse(row[colMap['food']!]?.value.toString() ?? "0") ?? 0) : 0,
            carAllowance: colMap.containsKey('car') ? (double.tryParse(row[colMap['car']!]?.value.toString() ?? "0") ?? 0) : 0,
            type: WorkerType.regular,
          ));
        }
      }
    }

    return {
      "success": true,
      "companyName": matchedCompanyName,
      "bizId": foundBizId,
      "workers": loadedWorkers,
    };
  }
}

// ==========================================
// 4. PDF 및 엑셀 출력
// ==========================================
class RegisterExporter {
  static Future<void> exportToCsv(String companyName, String attribution, String payment, List<Worker> workers) async {
    List<List<dynamic>> rows = [];
    rows.add(["[세무회계 두란] 급여대장"]);
    rows.add(["귀속월", attribution, "지급월", payment]);
    rows.add([]);
    rows.add([
      "성명", "실수령액", "유형", "지급총액", "공제총액",
      "기본급", "연장", "야간", "휴일", "주휴", "식대", "차량",
      "국민", "건강", "요양", "고용", "소득세", "지방세", "3.3%"
    ]);

    for (var w in workers) {
      if(w.result == null) PayrollEngine.calculate(w);
      var r = w.result!;
      rows.add([
        w.name, r.netPay, w.type == WorkerType.regular ? "정규직" : "3.3%",
        r.totalPay, r.totalDeduction,
        r.basePay, r.overtimePay, r.nightPay, r.holidayPay, r.weeklyHolidayPay, w.foodAllowance, w.carAllowance,
        r.nationalPension, r.healthInsurance, r.careInsurance, r.empInsurance, r.taxIncome, r.taxLocal, r.tax33,
      ]);
    }

    String csvContent = const ListToCsvConverter().convert(rows);
    final List<int> excelBytes = [0xEF, 0xBB, 0xBF] + utf8.encode(csvContent);

    String fileName = '${companyName}_${attribution}귀속_${payment}지급_급여대장.csv';
    String? outputFile = await FilePicker.platform.saveFile(dialogTitle: '저장', fileName: fileName);

    if (outputFile != null) {
      File file = File(outputFile);
      await file.writeAsBytes(excelBytes);
    }
  }
}

class PdfGenerator {
  static Future<Uint8List> makePdf(Worker worker, String companyName, String attribution, String payment) async {
    final pdf = pw.Document();

    // 폰트 파일 로드 시도
    pw.Font ttf;
    try {
      final fontData = await rootBundle.load("assets/fonts/NanumGothic.ttf");
      ttf = pw.Font.ttf(fontData);
    } catch (e) {
      // 폰트 없을 경우 기본 영문 폰트 사용 (한글 깨짐 주의)
      ttf = pw.Font.courier();
    }

    final fmt = NumberFormat("#,###");

    if (worker.result == null) PayrollEngine.calculate(worker);
    final res = worker.result!;

    pdf.addPage(pw.Page(
      theme: pw.ThemeData(defaultTextStyle: pw.TextStyle(font: ttf, fontSize: 11)),
      build: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Header(level: 0, child: pw.Center(child: pw.Text("급여(상여) 명세서", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)))),
        pw.SizedBox(height: 10),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text("귀속: $attribution / 지급: $payment"),
          pw.Text("상호: $companyName"),
        ]),
        pw.Divider(),
        pw.Row(children: [
          pw.Expanded(child: pw.Text("성명: ${worker.name}")),
          pw.Expanded(child: pw.Text("생년월일: ${worker.birthDate}")),
        ]),
        pw.SizedBox(height: 20),

        pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text("지급 내역", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text("공제 내역", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)))),
              ]),
              pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  _row("기본급", res.basePay, fmt),
                  if(res.overtimePay > 0) _row("연장수당", res.overtimePay, fmt),
                  if(res.nightPay > 0) _row("야간수당", res.nightPay, fmt),
                  if(res.holidayPay > 0) _row("휴일수당", res.holidayPay, fmt),
                  if(res.weeklyHolidayPay > 0) _row("주휴수당", res.weeklyHolidayPay, fmt),
                  if(worker.foodAllowance > 0) _row("식대", worker.foodAllowance, fmt),
                  if(worker.carAllowance > 0) _row("자가운전", worker.carAllowance, fmt),
                  pw.Divider(),
                  _row("지급계", res.totalPay, fmt, isBold: true),
                ])),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  if(worker.type == WorkerType.freelance) ...[
                    _row("사업소득세", res.tax33, fmt),
                  ] else ...[
                    _row("국민연금", res.nationalPension, fmt),
                    _row("건강보험", res.healthInsurance, fmt),
                    _row("장기요양", res.careInsurance, fmt),
                    _row("고용보험", res.empInsurance, fmt),
                    _row("소득세", res.taxIncome, fmt),
                    _row("지방소득세", res.taxLocal, fmt),
                  ],
                  pw.Divider(),
                  _row("공제계", res.totalDeduction, fmt, isBold: true),
                ])),
              ])
            ]
        ),
        pw.SizedBox(height: 20),
        pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all()),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text("실 수 령 액", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text("${fmt.format(res.netPay.toInt())} 원", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ])
        ),
      ]),
    ));
    return pdf.save();
  }

  static pw.Widget _row(String label, double val, NumberFormat fmt, {bool isBold = false}) {
    return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label, style: isBold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
      pw.Text(fmt.format(val.toInt()), style: isBold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
    ]));
  }
}

class EmailSender {
  static Future<void> sendSalaryMail(Worker worker, Uint8List pdfBytes, String company, String month) async {
    String username = 'YOUR_EMAIL@gmail.com';
    String password = 'YOUR_APP_PASSWORD';

    // 임시 파일로 저장 후 첨부
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${worker.name}_급여명세서.pdf');
    await file.writeAsBytes(pdfBytes);

    final smtpServer = gmail(username, password);
    final message = Message()
      ..from = Address(username, '세무회계 두란')
      ..recipients.add(worker.email)
      ..subject = '[$company] $month 급여명세서 안내'
      ..text = '안녕하세요, ${worker.name}님.\n요청하신 급여명세서 송부드립니다.'
      ..attachments.add(FileAttachment(file));

    // 실제 전송은 아래 주석 해제 필요
    // await send(message, smtpServer);
  }
}

// ==========================================
// 5. 메인 UI
// ==========================================
class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});
  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  List<Worker> workers = [];
  bool isLoading = false;
  bool _dragging = false;
  String companyName = "";
  String matchedBizId = "";

  DateTime attributionDate = DateTime.now();
  DateTime paymentDate = DateTime.now();

  Future<bool> _promptDates() async {
    bool confirmed = false;
    await showDialog(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text("급여 귀속/지급월 설정"),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              title: const Text("귀속년월 (일한 달)"),
              subtitle: Text(DateFormat('yyyy-MM').format(attributionDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: attributionDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                if (d != null) setState(() => attributionDate = d);
              },
            ),
            ListTile(
              title: const Text("지급년월 (돈 주는 달)"),
              subtitle: Text(DateFormat('yyyy-MM').format(paymentDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: paymentDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                if (d != null) setState(() => paymentDate = d);
              },
            ),
          ]),
          actions: [
            ElevatedButton(onPressed: () { confirmed = true; Navigator.pop(context); }, child: const Text("확인"))
          ],
        );
      });
    });
    return confirmed;
  }

  Future<void> _processFile(File file) async {
    if (!mounted) return;
    bool go = await _promptDates();
    if (!go) return;

    setState(() => isLoading = true);
    var parseResult = await SmartExcelParser.parse(file);

    if (!mounted) return;
    setState(() {
      isLoading = false;
      workers = parseResult['workers'];
      matchedBizId = parseResult['bizId'] ?? "식별불가";
      companyName = parseResult['companyName'] ?? "거래처 미등록($matchedBizId)";
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("로딩 완료: ${workers.length}명")));
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
    if (result != null) {
      await _processFile(File(result.files.single.path!));
    }
  }

  Future<void> _exportRegister() async {
    if (workers.isEmpty) return;
    String attStr = DateFormat('yyyy-MM').format(attributionDate);
    String payStr = DateFormat('yyyy-MM').format(paymentDate);
    await RegisterExporter.exportToCsv(companyName, attStr, payStr, workers);
  }

  Future<void> _sendAll() async {
    setState(() => isLoading = true);
    String attStr = DateFormat('yyyy-MM').format(attributionDate);
    String payStr = DateFormat('yyyy-MM').format(paymentDate);
    int success = 0;
    for (var w in workers) {
      try {
        var pdfData = await PdfGenerator.makePdf(w, companyName, attStr, payStr);
        await EmailSender.sendSalaryMail(w, pdfData, companyName, payStr);
        success++;
      } catch (e) {
        // 전송 실패 로그
      }
    }
    setState(() => isLoading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$success명 처리 완료")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("세무회계 두란 - 급여 자동화"),
        actions: [
          TextButton.icon(
            onPressed: TemplateGenerator.downloadTemplate,
            icon: const Icon(Icons.download_for_offline, color: Colors.blue),
            label: const Text("표준양식 다운로드", style: TextStyle(color: Colors.blue)),
          )
        ],
      ),
      body: DropTarget(
        onDragDone: (detail) async {
          if (detail.files.isNotEmpty) {
            await _processFile(File(detail.files.first.path));
          }
        },
        onDragEntered: (detail) => setState(() => _dragging = true),
        onDragExited: (detail) => setState(() => _dragging = false),
        child: Stack(
          children: [
            Column(children: [
              Container(
                padding: const EdgeInsets.all(15), color: Colors.indigo[50],
                child: Column(children: [
                  Row(children: [
                    const Icon(Icons.business, color: Colors.indigo),
                    const SizedBox(width: 10),
                    Text(companyName.isEmpty ? "파일을 드래그하거나 업로드하세요." : companyName,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: companyName.contains("미등록") ? Colors.red : Colors.black)),
                  ]),
                  if(companyName.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text("사업자번호: $matchedBizId  |  귀속: ${DateFormat('yyyy-MM').format(attributionDate)}  |  지급: ${DateFormat('yyyy-MM').format(paymentDate)}"),
                  ]
                ]),
              ),

              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  Expanded(child: ElevatedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.upload_file), label: const Text("엑셀 파일 선택"), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)))),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(onPressed: workers.isEmpty ? null : _exportRegister, icon: const Icon(Icons.save), label: const Text("급여대장 저장"), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), backgroundColor: Colors.green, foregroundColor: Colors.white))),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(onPressed: workers.isEmpty ? null : _sendAll, icon: const Icon(Icons.mail), label: const Text("명세서 발송"), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white))),
                ]),
              ),

              if (isLoading) const LinearProgressIndicator(),

              Expanded(
                child: workers.isEmpty ?
                Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
                      Icon(Icons.cloud_upload_outlined, size: 80, color: Colors.grey),
                      SizedBox(height: 20),
                      Text("요청받은 엑셀 파일을 여기에 끌어다 놓으세요.\n(Drag & Drop)", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16))
                    ])
                )
                    : ListView.separated(
                  itemCount: workers.length,
                  separatorBuilder: (_,__) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final w = workers[i];
                    if (w.result == null) PayrollEngine.calculate(w);
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: w.type == WorkerType.regular ? Colors.blue[100] : Colors.orange[100],
                          child: Text(w.type == WorkerType.regular ? "정" : "3.3", style: const TextStyle(fontSize: 12, color: Colors.black))),
                      title: Text("${w.name} (${w.birthDate})"),
                      subtitle: Text("기본:${w.normalHours}h / 연장:${w.overtimeHours}h / 식대:${w.foodAllowance}"),
                      trailing: Text("${NumberFormat("#,###").format(w.result?.netPay)}원", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    );
                  },
                ),
              )
            ]),

            if (_dragging)
              Container(
                color: Colors.black.withValues(alpha: 0.5), // withOpacity 대체 (Dart 3.x)
                child: Center(
                  child: DottedBorder(
                    color: Colors.white, strokeWidth: 3, dashPattern: const [10, 10], borderType: BorderType.RRect, radius: const Radius.circular(20),
                    child: Container(
                      width: 300, height: 200,
                      alignment: Alignment.center,
                      child: const Text("여기에 파일을 놓으세요!", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}