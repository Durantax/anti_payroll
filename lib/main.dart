import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData;

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:http/http.dart' as http;

import 'package:excel/excel.dart' hide Border; // ✅ Border 충돌 방지
import 'package:csv/csv.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:dotted_border/dotted_border.dart';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

// ==========================================
// 0. 메인
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Windows Desktop SQLite(ffi)
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = LocalDatabaseService();
  await db.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PayrollProvider(db)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '세무회계 두란 급여관리 (Windows Desktop)',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        fontFamily: 'NanumGothic',
      ),
      home: const MainLayout(),
    );
  }
}

// ==========================================
// 1. 모델
// ==========================================
class ClientModel {
  final int id;
  final String name;
  final String bizId;

  ClientModel({required this.id, required this.name, required this.bizId});

  factory ClientModel.fromApi(Map<String, dynamic> row) {
    return ClientModel(
      id: (row['id'] ?? 0) is int ? (row['id'] ?? 0) as int : int.tryParse('${row['id']}') ?? 0,
      name: (row['name'] ?? '').toString(),
      bizId: (row['bizId'] ?? '').toString(),
    );
  }
}

String salaryTypeToText(String v) {
  if (v.toUpperCase() == 'HOURLY') return '시급';
  return '월급';
}

String salaryTypeFromCell(dynamic cellValue) {
  final s = (cellValue ?? '').toString().trim();
  if (s == '시급' || s.toUpperCase() == 'HOURLY') return 'HOURLY';
  if (s == '월급' || s.toUpperCase() == 'MONTHLY') return 'MONTHLY';
  return 'MONTHLY';
}

class WorkerModel {
  int? id; // local Workers PK
  int clientRefId;

  String name;
  String birthDate; // YYMMDD or YYYYMMDD

  String type; // regular | freelance

  String salaryType; // MONTHLY | HOURLY
  double baseSalary;
  double hourlyRate;
  double normalHours;

  double foodAllowance;
  double carAllowance;

  // ✅ 월별 변동값(WorkerMonthly)
  double workHours;
  double bonus;
  double overtimeHours;
  double nightHours;
  double holidayHours;

  SalaryResult? result;

  WorkerModel({
    this.id,
    required this.clientRefId,
    required this.name,
    required this.birthDate,
    this.type = 'regular',
    this.salaryType = 'MONTHLY',
    this.baseSalary = 0,
    this.hourlyRate = 9860,
    this.normalHours = 209,
    this.foodAllowance = 0,
    this.carAllowance = 0,
    this.workHours = 0,
    this.bonus = 0,
    this.overtimeHours = 0,
    this.nightHours = 0,
    this.holidayHours = 0,
  });

  Map<String, dynamic> toBaseSqlMap() => {
        'id': id,
        'clientRefId': clientRefId,
        'name': name,
        'birthDate': birthDate,
        'type': type,
        'salaryType': salaryType,
        'baseSalary': baseSalary,
        'hourlyRate': hourlyRate,
        'normalHours': normalHours,
        'foodAllowance': foodAllowance,
        'carAllowance': carAllowance,
      };

  factory WorkerModel.fromJoinedMap(Map<String, dynamic> map) {
    return WorkerModel(
      id: map['id'] as int?,
      clientRefId: (map['clientRefId'] ?? 0) is int ? (map['clientRefId'] ?? 0) as int : int.tryParse('${map['clientRefId']}') ?? 0,
      name: (map['name'] ?? '').toString(),
      birthDate: (map['birthDate'] ?? '').toString(),
      type: (map['type'] ?? 'regular').toString(),
      salaryType: (map['salaryType'] ?? 'MONTHLY').toString(),
      baseSalary: _toDoubleAny(map['baseSalary']),
      hourlyRate: _toDoubleAny(map['hourlyRate'], defaultValue: 9860),
      normalHours: _toDoubleAny(map['normalHours'], defaultValue: 209),
      foodAllowance: _toDoubleAny(map['foodAllowance']),
      carAllowance: _toDoubleAny(map['carAllowance']),
      workHours: _toDoubleAny(map['workHours']),
      bonus: _toDoubleAny(map['bonus']),
      overtimeHours: _toDoubleAny(map['overtimeHours']),
      nightHours: _toDoubleAny(map['nightHours']),
      holidayHours: _toDoubleAny(map['holidayHours']),
    );
  }

  static double _toDoubleAny(dynamic v, {double defaultValue = 0}) {
    if (v == null) return defaultValue;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '').trim()) ?? defaultValue;
  }
}

class SalaryResult {
  double netPay = 0, totalPay = 0, totalDeduction = 0;
  double basePay = 0, overtimePay = 0, nightPay = 0, holidayPay = 0;

  double nationalPension = 0, healthInsurance = 0, careInsurance = 0, empInsurance = 0;
  double taxIncome = 0, taxLocal = 0, tax33 = 0;
}

class PayrollMeta {
  final DateTime? slipDeadline;
  final DateTime? registerDeadline;
  final String notice;

  PayrollMeta({
    required this.slipDeadline,
    required this.registerDeadline,
    required this.notice,
  });

  factory PayrollMeta.fromApi(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    return PayrollMeta(
      slipDeadline: parseDt(json['slipDeadline']),
      registerDeadline: parseDt(json['registerDeadline']),
      notice: (json['notice'] ?? '').toString(),
    );
  }
}

class SendStatusModel {
  final String name;
  final String birthDate;
  final String status; // SENT | FAILED | PENDING | UNKNOWN
  final DateTime? updatedAt;
  final String? lastError;

  SendStatusModel({
    required this.name,
    required this.birthDate,
    required this.status,
    required this.updatedAt,
    required this.lastError,
  });

  factory SendStatusModel.fromApi(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    return SendStatusModel(
      name: (json['name'] ?? '').toString(),
      birthDate: (json['birthDate'] ?? '').toString(),
      status: (json['status'] ?? 'UNKNOWN').toString(),
      updatedAt: parseDt(json['updatedAt']),
      lastError: json['lastError']?.toString(),
    );
  }
}

// ==========================================
// 2. 리포지토리(서버) + 로컬DB(SQLite)
// ==========================================
class RemoteRepository {
  final String baseUrl;
  RemoteRepository(this.baseUrl);

  Future<List<ClientModel>> fetchClients() async {
    final uri = Uri.parse('$baseUrl/clients');
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('거래처 조회 실패: ${res.statusCode}\n${res.body}');
    }
    final List<dynamic> data = jsonDecode(res.body);
    return data.map((e) => ClientModel.fromApi(e as Map<String, dynamic>)).toList();
  }

  Future<PayrollMeta> fetchPayrollMeta(int clientId, String ym) async {
    final uri = Uri.parse('$baseUrl/clients/$clientId/payroll-meta?ym=$ym');
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('마감/알림 조회 실패: ${res.statusCode}\n${res.body}');
    }
    return PayrollMeta.fromApi(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<SendStatusModel>> fetchSendStatuses(int clientId, String ym) async {
    final uri = Uri.parse('$baseUrl/clients/$clientId/send-status?ym=$ym');
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('발송상태 조회 실패: ${res.statusCode}\n${res.body}');
    }
    final List<dynamic> data = jsonDecode(res.body);
    return data.map((e) => SendStatusModel.fromApi(e as Map<String, dynamic>)).toList();
  }

  Future<void> sendSlip(int clientId, String ym, {required String name, required String birthDate}) async {
    final uri = Uri.parse('$baseUrl/clients/$clientId/send-slip?ym=$ym');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'name': name, 'birthDate': birthDate}),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('발송 요청 실패: ${res.statusCode}\n${res.body}');
    }
  }
}

class LocalDatabaseService {
  late Database _db;

  static const int _dbVersion = 5;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'duran_payroll_v5.db');

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async => _createAll(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 5) {
          await _safeExec(db, '''
            CREATE TABLE IF NOT EXISTS SendRetryLog (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              workerId INTEGER NOT NULL,
              ym TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'UNKNOWN',
              attemptCount INTEGER NOT NULL DEFAULT 0,
              lastAttemptAt TEXT,
              nextRetryAt TEXT,
              lastError TEXT,
              updatedAt TEXT,
              UNIQUE(workerId, ym)
            )
          ''');
          await _safeExec(db, "CREATE UNIQUE INDEX IF NOT EXISTS UX_SendRetryLog_worker_ym ON SendRetryLog(workerId, ym)");
        }
      },
    );
  }

  Future<void> _createAll(Database db) async {
    await db.execute('''
      CREATE TABLE Workers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clientRefId INTEGER NOT NULL,
        name TEXT NOT NULL,
        birthDate TEXT NOT NULL,
        type TEXT NOT NULL,
        salaryType TEXT NOT NULL,
        baseSalary REAL NOT NULL DEFAULT 0,
        hourlyRate REAL NOT NULL DEFAULT 9860,
        normalHours REAL NOT NULL DEFAULT 209,
        foodAllowance REAL NOT NULL DEFAULT 0,
        carAllowance REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE WorkerMonthly (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workerId INTEGER NOT NULL,
        ym TEXT NOT NULL,
        workHours REAL NOT NULL DEFAULT 0,
        bonus REAL NOT NULL DEFAULT 0,
        overtimeHours REAL NOT NULL DEFAULT 0,
        nightHours REAL NOT NULL DEFAULT 0,
        holidayHours REAL NOT NULL DEFAULT 0,
        updatedAt TEXT,
        UNIQUE(workerId, ym)
      )
    ''');

    await db.execute('''
      CREATE TABLE AppSettings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE SendRetryLog (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workerId INTEGER NOT NULL,
        ym TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'UNKNOWN',
        attemptCount INTEGER NOT NULL DEFAULT 0,
        lastAttemptAt TEXT,
        nextRetryAt TEXT,
        lastError TEXT,
        updatedAt TEXT,
        UNIQUE(workerId, ym)
      )
    ''');

    await db.execute("CREATE UNIQUE INDEX IF NOT EXISTS UX_Workers_Client_Name_Birth ON Workers(clientRefId, name, birthDate)");
    await db.execute("CREATE UNIQUE INDEX IF NOT EXISTS UX_WorkerMonthly_worker_ym ON WorkerMonthly(workerId, ym)");
    await db.execute("CREATE UNIQUE INDEX IF NOT EXISTS UX_SendRetryLog_worker_ym ON SendRetryLog(workerId, ym)");
  }

  Future<void> _safeExec(Database db, String sql) async {
    try {
      await db.execute(sql);
    } catch (_) {}
  }

  // AppSettings
  Future<String> getSetting(String key, {required String defaultValue}) async {
    final rows = await _db.query('AppSettings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return defaultValue;
    return (rows.first['value'] ?? defaultValue).toString();
  }

  Future<void> setSetting(String key, String value) async {
    await _db.insert(
      'AppSettings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Workers + Monthly
  Future<List<WorkerModel>> getWorkersWithMonthly(int clientRefId, String ym) async {
    final rows = await _db.rawQuery('''
      SELECT 
        w.id, w.clientRefId, w.name, w.birthDate, w.type, 
        w.salaryType, w.baseSalary, w.hourlyRate, w.normalHours,
        w.foodAllowance, w.carAllowance,
        m.workHours, m.bonus, m.overtimeHours, m.nightHours, m.holidayHours
      FROM Workers w
      LEFT JOIN WorkerMonthly m 
        ON m.workerId = w.id AND m.ym = ?
      WHERE w.clientRefId = ?
      ORDER BY w.name COLLATE NOCASE
    ''', [ym, clientRefId]);

    return rows.map((e) => WorkerModel.fromJoinedMap(e)).toList();
  }

  Future<int> upsertWorkerBase(WorkerModel worker) async {
    if (worker.id != null) {
      await _db.update('Workers', worker.toBaseSqlMap(), where: 'id = ?', whereArgs: [worker.id]);
      return worker.id!;
    }

    final exist = await _db.query(
      'Workers',
      columns: ['id'],
      where: 'clientRefId = ? AND name = ? AND birthDate = ?',
      whereArgs: [worker.clientRefId, worker.name, worker.birthDate],
      limit: 1,
    );

    if (exist.isNotEmpty) {
      final id = exist.first['id'] as int;
      worker.id = id;
      await _db.update('Workers', worker.toBaseSqlMap(), where: 'id = ?', whereArgs: [id]);
      return id;
    }

    final newId = await _db.insert('Workers', worker.toBaseSqlMap());
    worker.id = newId;
    return newId;
  }

  Future<void> upsertWorkerMonthly({
    required int workerId,
    required String ym,
    required WorkerModel worker,
  }) async {
    await _db.insert(
      'WorkerMonthly',
      {
        'workerId': workerId,
        'ym': ym,
        'workHours': worker.workHours,
        'bonus': worker.bonus,
        'overtimeHours': worker.overtimeHours,
        'nightHours': worker.nightHours,
        'holidayHours': worker.holidayHours,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertWorkerForYm(WorkerModel worker, String ym) async {
    final workerId = await upsertWorkerBase(worker);
    await upsertWorkerMonthly(workerId: workerId, ym: ym, worker: worker);
  }

  Future<void> deleteWorker(int workerId) async {
    await _db.delete('WorkerMonthly', where: 'workerId = ?', whereArgs: [workerId]);
    await _db.delete('SendRetryLog', where: 'workerId = ?', whereArgs: [workerId]);
    await _db.delete('Workers', where: 'id = ?', whereArgs: [workerId]);
  }

  // SendRetryLog
  Future<void> upsertSendLog({
    required int workerId,
    required String ym,
    required String status,
    String? lastError,
    DateTime? nextRetryAt,
    bool incrementAttempt = false,
  }) async {
    final now = DateTime.now().toIso8601String();

    int attempt = 0;
    final exist = await _db.query(
      'SendRetryLog',
      columns: ['attemptCount'],
      where: 'workerId = ? AND ym = ?',
      whereArgs: [workerId, ym],
      limit: 1,
    );
    if (exist.isNotEmpty) {
      attempt = (exist.first['attemptCount'] as int?) ?? 0;
    }
    if (incrementAttempt) attempt += 1;

    await _db.insert(
      'SendRetryLog',
      {
        'workerId': workerId,
        'ym': ym,
        'status': status,
        'attemptCount': attempt,
        'lastAttemptAt': now,
        'nextRetryAt': nextRetryAt?.toIso8601String(),
        'lastError': lastError,
        'updatedAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<int, Map<String, dynamic>>> getSendLogsByYm(String ym) async {
    final rows = await _db.query('SendRetryLog', where: 'ym = ?', whereArgs: [ym]);
    final out = <int, Map<String, dynamic>>{};
    for (final r in rows) {
      out[(r['workerId'] as int)] = r;
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> getDueRetries(String ym, DateTime now) async {
    final rows = await _db.query(
      'SendRetryLog',
      where: "ym = ? AND status = 'FAILED' AND nextRetryAt IS NOT NULL AND nextRetryAt <= ?",
      whereArgs: [ym, now.toIso8601String()],
    );
    return rows;
  }
}

// ==========================================
// 3. Provider
// ==========================================
class PayrollProvider extends ChangeNotifier {
  final LocalDatabaseService db;

  PayrollProvider(this.db) {
    _bootstrap();
  }

  String baseUrl = 'http://127.0.0.1:8000';

  bool isLoading = false;
  String? lastError;

  List<ClientModel> clients = [];
  List<WorkerModel> workers = [];
  ClientModel? selectedClient;

  DateTime attributionDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime paymentDate = DateTime(DateTime.now().year, DateTime.now().month, 1);

  String get currentYm => DateFormat('yyyy-MM').format(attributionDate);

  PayrollMeta? payrollMeta;

  Map<int, Map<String, dynamic>> sendLogs = {};

  Timer? _retryTimer;
  Timer? _pollTimer;

  String sendFilter = 'ALL'; // ALL | FAILED | SENT | PENDING | UNKNOWN

  Future<void> _bootstrap() async {
    baseUrl = await db.getSetting('baseUrl', defaultValue: baseUrl);
    await loadRemoteClients();

    _retryTimer = Timer.periodic(const Duration(minutes: 1), (_) => _processRetries());
    _pollTimer = Timer.periodic(const Duration(minutes: 2), (_) => refreshSendStatus());
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> setBaseUrl(String url) async {
    baseUrl = url.trim();
    await db.setSetting('baseUrl', baseUrl);
    notifyListeners();
    await loadRemoteClients();
  }

  Future<void> loadRemoteClients() async {
    isLoading = true;
    lastError = null;
    notifyListeners();

    try {
      final repo = RemoteRepository(baseUrl);
      clients = await repo.fetchClients();
    } catch (e) {
      lastError = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectClient(ClientModel client) async {
    selectedClient = client;
    await reloadWorkers();
    await refreshMeta();
    await refreshSendStatus();
  }

  Future<void> reloadWorkers() async {
    if (selectedClient == null) return;

    isLoading = true;
    lastError = null;
    notifyListeners();

    try {
      workers = await db.getWorkersWithMonthly(selectedClient!.id, currentYm);
      _recalculateAll();
      sendLogs = await db.getSendLogsByYm(currentYm);
    } catch (e) {
      lastError = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _recalculateAll() {
    for (final w in workers) {
      PayrollEngine.calculate(w);
    }
  }

  Future<void> updateDate(DateTime att, DateTime pay) async {
    attributionDate = DateTime(att.year, att.month, 1);
    paymentDate = DateTime(pay.year, pay.month, 1);
    notifyListeners();
    await reloadWorkers();
    await refreshMeta();
    await refreshSendStatus();
  }

  Future<void> upsertWorker(WorkerModel worker) async {
    if (selectedClient == null) return;

    isLoading = true;
    lastError = null;
    notifyListeners();

    try {
      await db.upsertWorkerForYm(worker, currentYm);
      await reloadWorkers();
    } catch (e) {
      lastError = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteWorker(int workerId) async {
    isLoading = true;
    lastError = null;
    notifyListeners();

    try {
      await db.deleteWorker(workerId);
      await reloadWorkers();
    } catch (e) {
      lastError = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // 서버: 마감/알림
  Future<void> refreshMeta() async {
    if (selectedClient == null) return;
    try {
      final repo = RemoteRepository(baseUrl);
      payrollMeta = await repo.fetchPayrollMeta(selectedClient!.id, currentYm);
      notifyListeners();
    } catch (_) {
      payrollMeta = PayrollMeta(slipDeadline: null, registerDeadline: null, notice: '');
      notifyListeners();
    }
  }

  // 서버: 발송상태
  Future<void> refreshSendStatus() async {
    if (selectedClient == null) return;

    try {
      final repo = RemoteRepository(baseUrl);
      final list = await repo.fetchSendStatuses(selectedClient!.id, currentYm);

      final map = <String, SendStatusModel>{};
      for (final s in list) {
        map['${s.name}|${s.birthDate}'] = s;
      }

      for (final w in workers) {
        if (w.id == null) continue;
        final key = '${w.name}|${w.birthDate}';
        final s = map[key];
        if (s == null) continue;

        final normalized = s.status.toUpperCase();
        if (normalized == 'FAILED') {
          await db.upsertSendLog(
            workerId: w.id!,
            ym: currentYm,
            status: 'FAILED',
            lastError: s.lastError,
            nextRetryAt: DateTime.now().add(const Duration(hours: 1)),
            incrementAttempt: false,
          );
        } else if (normalized == 'SENT') {
          await db.upsertSendLog(
            workerId: w.id!,
            ym: currentYm,
            status: 'SENT',
            lastError: null,
            nextRetryAt: null,
            incrementAttempt: false,
          );
        } else if (normalized == 'PENDING') {
          await db.upsertSendLog(
            workerId: w.id!,
            ym: currentYm,
            status: 'PENDING',
            lastError: null,
            nextRetryAt: null,
            incrementAttempt: false,
          );
        } else {
          await db.upsertSendLog(
            workerId: w.id!,
            ym: currentYm,
            status: 'UNKNOWN',
            lastError: s.lastError,
            nextRetryAt: null,
            incrementAttempt: false,
          );
        }
      }

      sendLogs = await db.getSendLogsByYm(currentYm);
      notifyListeners();
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
    }
  }

  // 발송 요청(수동) + 실패시 1시간 후 예약
  Future<void> sendSlipNow(WorkerModel w) async {
    if (selectedClient == null || w.id == null) return;

    final repo = RemoteRepository(baseUrl);
    try {
      await repo.sendSlip(selectedClient!.id, currentYm, name: w.name, birthDate: w.birthDate);

      await db.upsertSendLog(
        workerId: w.id!,
        ym: currentYm,
        status: 'SENT',
        lastError: null,
        nextRetryAt: null,
        incrementAttempt: true,
      );
    } catch (e) {
      await db.upsertSendLog(
        workerId: w.id!,
        ym: currentYm,
        status: 'FAILED',
        lastError: e.toString(),
        nextRetryAt: DateTime.now().add(const Duration(hours: 1)),
        incrementAttempt: true,
      );
    }

    sendLogs = await db.getSendLogsByYm(currentYm);
    notifyListeners();
  }

  Future<void> sendAllFailedNow() async {
    final failed = failedWorkers;
    for (final w in failed) {
      await sendSlipNow(w);
    }
    await refreshSendStatus();
  }

  // 1시간 후 자동 재시도(앱 실행 중)
  Future<void> _processRetries() async {
    if (selectedClient == null) return;

    final due = await db.getDueRetries(currentYm, DateTime.now());
    if (due.isEmpty) return;

    final wmap = <int, WorkerModel>{};
    for (final w in workers) {
      if (w.id != null) wmap[w.id!] = w;
    }

    for (final row in due) {
      final workerId = row['workerId'] as int;
      final w = wmap[workerId];
      if (w == null) continue;
      await sendSlipNow(w);
    }
  }

  // 화면용 헬퍼
  String getSendStatus(WorkerModel w) {
    if (w.id == null) return 'UNKNOWN';
    final row = sendLogs[w.id!];
    return (row?['status'] ?? 'UNKNOWN').toString();
  }

  String? getSendError(WorkerModel w) {
    if (w.id == null) return null;
    final row = sendLogs[w.id!];
    final v = row?['lastError']?.toString();
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  List<WorkerModel> get failedWorkers => workers.where((w) => getSendStatus(w) == 'FAILED').toList();

  List<WorkerModel> get filteredWorkers {
    if (sendFilter == 'FAILED') return workers.where((w) => getSendStatus(w) == 'FAILED').toList();
    if (sendFilter == 'SENT') return workers.where((w) => getSendStatus(w) == 'SENT').toList();
    if (sendFilter == 'PENDING') return workers.where((w) => getSendStatus(w) == 'PENDING').toList();
    if (sendFilter == 'UNKNOWN') return workers.where((w) => getSendStatus(w) == 'UNKNOWN').toList();
    return workers;
  }

  void setSendFilter(String v) {
    sendFilter = v;
    notifyListeners();
  }

  // ==========================================
  // ✅ 엑셀 업로드 (기능 유지)
  // - 상단 2줄: 거래처명/사업자번호 가정(기존 방식)
  // - 3번째 줄: 헤더
  // ==========================================
  Future<void> processExcel(File file) async {
    isLoading = true;
    lastError = null;
    notifyListeners();

    try {
      final bytes = file.readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables[excel.tables.keys.first]!;
      if (sheet.maxRows < 3) {
        throw Exception('엑셀 형식이 올바르지 않습니다. (최소 3줄 필요)');
      }

      // 사업자번호(2번째 줄 1열)
      String fileBizId = '';
      final bizCell = sheet.rows[1].isNotEmpty ? sheet.rows[1][0] : null;
      fileBizId = (bizCell?.value ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');

      ClientModel? matched;
      try {
        matched = clients.firstWhere((c) => c.bizId.replaceAll(RegExp(r'[^0-9]'), '') == fileBizId);
      } catch (_) {
        if (selectedClient == null) {
          throw Exception('사업자번호($fileBizId) 거래처를 서버 목록에서 찾지 못했습니다.');
        }
        matched = selectedClient!;
      }

      selectedClient = matched;

      // 헤더 판별
      const headerRowIndex = 2;
      final headerRow = sheet.rows.length > headerRowIndex ? sheet.rows[headerRowIndex] : <Data?>[];
      final headerTexts = headerRow.map((c) => (c?.value ?? '').toString().trim()).toList();

      int idxOf(String contains) {
        for (int i = 0; i < headerTexts.length; i++) {
          if (headerTexts[i].contains(contains)) return i;
        }
        return -1;
      }

      final isSmart = headerTexts.any((h) => h.contains('급여구분'));

      final nameIdx = idxOf('이름') >= 0 ? idxOf('이름') : 0;
      final birthIdx = idxOf('생년월일') >= 0 ? idxOf('생년월일') : 1;

      final salaryTypeIdx = isSmart ? idxOf('급여구분') : -1;
      final baseSalaryIdx = isSmart ? idxOf('기본급') : -1;
      final hourlyIdx = isSmart ? idxOf('시급') : 2;
      final workHoursIdx = isSmart ? idxOf('근무시간') : -1;
      final bonusIdx = isSmart ? idxOf('상여') : -1;

      final normalHoursIdx = !isSmart ? 3 : -1;

      final otIdx = isSmart ? idxOf('연장근로') : 4;
      final nightIdx = isSmart ? idxOf('야간근로') : 5;
      final holIdx = isSmart ? idxOf('휴일근로') : 6;

      final foodIdx = isSmart ? idxOf('식대') : 7;
      final carIdx = isSmart ? idxOf('차량') : 8;

      final typeIdx = isSmart ? idxOf('고용') : -1;

      String cellStr(List<Data?> row, int idx) {
        if (idx < 0 || idx >= row.length) return '';
        return (row[idx]?.value ?? '').toString().trim();
      }

      dynamic cellRaw(List<Data?> row, int idx) {
        if (idx < 0 || idx >= row.length) return null;
        return row[idx]?.value;
      }

      double toDouble(String s) {
        if (s.trim().isEmpty) return 0;
        return double.tryParse(s.replaceAll(',', '').trim()) ?? 0;
      }

      for (int i = headerRowIndex + 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty) continue;

        final name = cellStr(row, nameIdx);
        if (name.isEmpty || name.contains('예시')) continue;

        final birth = cellStr(row, birthIdx).isEmpty ? '000000' : cellStr(row, birthIdx);

        final st = isSmart ? salaryTypeFromCell(cellRaw(row, salaryTypeIdx)) : 'HOURLY';

        String workerType = 'regular';
        if (isSmart && typeIdx >= 0) {
          final t = cellStr(row, typeIdx).toLowerCase();
          if (t.contains('프리') || t.contains('freelance')) workerType = 'freelance';
        }

        final foodAllowance = toDouble(cellStr(row, foodIdx));
        final carAllowance = toDouble(cellStr(row, carIdx));

        final double baseSalary = isSmart ? toDouble(cellStr(row, baseSalaryIdx)) : 0.0;
        final hourlyRate = toDouble(cellStr(row, hourlyIdx));

        final double workHours = isSmart ? toDouble(cellStr(row, workHoursIdx)) : 0.0;
        final double bonus = isSmart ? toDouble(cellStr(row, bonusIdx)) : 0.0;

        double normalHours = 209;
        if (!isSmart && normalHoursIdx >= 0) {
          final v = toDouble(cellStr(row, normalHoursIdx));
          normalHours = (v == 0) ? 209 : v;
        }

        final w = WorkerModel(
          clientRefId: matched.id,
          name: name,
          birthDate: birth,
          type: workerType,
          salaryType: st,
          baseSalary: baseSalary,
          hourlyRate: (hourlyRate == 0 && st == 'HOURLY') ? 9860 : hourlyRate,
          normalHours: normalHours,
          foodAllowance: foodAllowance,
          carAllowance: carAllowance,
          workHours: workHours,
          bonus: bonus,
        );

        w.overtimeHours = toDouble(cellStr(row, otIdx));
        w.nightHours = toDouble(cellStr(row, nightIdx));
        w.holidayHours = toDouble(cellStr(row, holIdx));

        await db.upsertWorkerForYm(w, currentYm);
      }

      await reloadWorkers();
      await refreshMeta();
      await refreshSendStatus();
    } catch (e) {
      lastError = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}

// ==========================================
// 4. 급여 계산 엔진
// ==========================================
class PayrollEngine {
  static void calculate(WorkerModel w) {
    w.result = SalaryResult();
    final r = w.result!;

    double standardHourly = w.hourlyRate;

    if (w.salaryType == 'MONTHLY') {
      if (w.normalHours > 0) {
        standardHourly = (w.baseSalary / w.normalHours);
      }
      r.basePay = w.baseSalary;
    } else {
      r.basePay = w.workHours * w.hourlyRate;
    }

    r.overtimePay = w.overtimeHours * standardHourly * 1.5;
    r.nightPay = w.nightHours * standardHourly * 0.5;
    r.holidayPay = w.holidayHours * standardHourly * 1.5;

    final monthlyBonus = (w.salaryType == 'MONTHLY') ? w.bonus : 0;

    r.totalPay = r.basePay + monthlyBonus + r.overtimePay + r.nightPay + r.holidayPay;
    r.totalPay = (r.totalPay / 10).floor() * 10.0;

    double taxable = r.totalPay - (w.foodAllowance + w.carAllowance);
    if (taxable < 0) taxable = 0;

    if (w.type == 'freelance') {
      r.tax33 = (r.totalPay * 0.033).floorToDouble();
      r.totalDeduction = r.tax33;
    } else {
      r.nationalPension = (taxable * 0.045 / 10).floor() * 10.0;
      r.healthInsurance = (taxable * 0.03545 / 10).floor() * 10.0;
      r.careInsurance = (r.healthInsurance * 0.1295 / 10).floor() * 10.0;
      r.empInsurance = (taxable * 0.009 / 10).floor() * 10.0;

      r.taxIncome = (taxable > 1060000) ? (taxable * 0.02).floorToDouble() : 0;
      r.taxLocal = (r.taxIncome * 0.1 / 10).floor() * 10.0;

      r.totalDeduction = r.nationalPension + r.healthInsurance + r.careInsurance + r.empInsurance + r.taxIncome + r.taxLocal;
    }

    r.netPay = r.totalPay - r.totalDeduction;
  }
}

// ==========================================
// 5. 파일 서비스(엑셀/CSV/PDF)
// ==========================================
class FileService {
  static pw.Font? _koreanFont;

  static Future<pw.Font> _loadKoreanFont() async {
    if (_koreanFont != null) return _koreanFont!;
    final ByteData bd = await rootBundle.load('assets/fonts/NanumGothic-Regular.ttf');
    _koreanFont = pw.Font.ttf(bd);
    return _koreanFont!;
  }

  static Future<void> downloadTemplate(ClientModel? client, List<WorkerModel> prevWorkers) async {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    sheet.appendRow([TextCellValue(client?.name ?? '거래처명')]);
    sheet.appendRow([TextCellValue(client?.bizId ?? '000-00-00000')]);

    final headers = [
      '이름',
      '생년월일',
      '급여구분',
      '기본급',
      '시급',
      '근무시간',
      '상여',
      '연장근로',
      '야간근로',
      '휴일근로',
      '식대',
      '차량유지비',
      '고용형태(선택)',
    ];
    sheet.appendRow(headers.map((e) => TextCellValue(e)).toList());

    for (final w in prevWorkers) {
      final isMonthly = (w.salaryType == 'MONTHLY');
      sheet.appendRow([
        TextCellValue(w.name),
        TextCellValue(w.birthDate),
        TextCellValue(isMonthly ? '월급' : '시급'),
        isMonthly ? IntCellValue(w.baseSalary.toInt()) : TextCellValue(''),
        (!isMonthly) ? IntCellValue(w.hourlyRate.toInt()) : TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        IntCellValue(w.foodAllowance.toInt()),
        IntCellValue(w.carAllowance.toInt()),
        TextCellValue(w.type == 'freelance' ? 'freelance' : 'regular'),
      ]);
    }

    final fName = '${client?.name ?? '공통'}_급여자료요청.xlsx';
    final out = await FilePicker.platform.saveFile(fileName: fName);
    if (out != null) {
      File(out)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.save()!);
    }
  }

  static Future<void> exportRegister(PayrollProvider pvd) async {
    if (pvd.selectedClient == null) return;

    final yymm = DateFormat('yy.MM').format(pvd.attributionDate);
    final fName = '${yymm}_${pvd.selectedClient!.name}_급여대장.csv';

    final rows = <List<dynamic>>[
      ['[급여대장] ${pvd.selectedClient!.name}'],
      ['귀속: ${DateFormat('yyyy-MM').format(pvd.attributionDate)}', '지급: ${DateFormat('yyyy-MM').format(pvd.paymentDate)}'],
      [],
      ['이름', '실수령액', '지급계', '공제계', '기본급', '연장', '야간', '휴일', '식대', '소득세', '지방세', '4대보험합계'],
    ];

    for (final w in pvd.workers) {
      final r = w.result ?? SalaryResult();
      rows.add([
        w.name,
        r.netPay,
        r.totalPay,
        r.totalDeduction,
        r.basePay,
        r.overtimePay,
        r.nightPay,
        r.holidayPay,
        w.foodAllowance,
        r.taxIncome,
        r.taxLocal,
        (r.nationalPension + r.healthInsurance + r.empInsurance),
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final out = await FilePicker.platform.saveFile(fileName: fName);
    if (out != null) {
      await File(out).writeAsBytes([0xEF, 0xBB, 0xBF] + utf8.encode(csvData));
    }
  }

  static Future<void> exportSlipPdf(PayrollProvider pvd, WorkerModel w) async {
    if (pvd.selectedClient == null || w.result == null) return;

    final client = pvd.selectedClient!;
    final r = w.result!;
    final doc = pw.Document();

    final font = await _loadKoreanFont();

    final yymm = DateFormat('yy.MM').format(pvd.attributionDate);
    final att = DateFormat('yyyy-MM').format(pvd.attributionDate);
    final pay = DateFormat('yyyy-MM').format(pvd.paymentDate);

    String money(num v) => NumberFormat('#,###').format(v);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) {
          return pw.DefaultTextStyle(
            style: pw.TextStyle(font: font, fontSize: 11),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('급여명세서', style: pw.TextStyle(font: font, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                pw.Text('거래처: ${client.name}'),
                pw.Text('사업자번호: ${client.bizId}'),
                pw.SizedBox(height: 6),
                pw.Text('귀속월: $att / 지급월: $pay'),
                pw.Divider(),
                pw.Text('직원: ${w.name} (${w.birthDate})'),
                pw.Text('급여구분: ${salaryTypeToText(w.salaryType)} / 고용형태: ${w.type}'),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(border: pw.Border.all()),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('지급내역', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 8),
                      _pdfRow(font, '기본급', money(r.basePay)),
                      _pdfRow(font, '연장수당', money(r.overtimePay)),
                      _pdfRow(font, '야간수당', money(r.nightPay)),
                      _pdfRow(font, '휴일수당', money(r.holidayPay)),
                      _pdfRow(font, '식대(비과세)', money(w.foodAllowance)),
                      _pdfRow(font, '차량보조(비과세)', money(w.carAllowance)),
                      if (w.salaryType == 'MONTHLY') _pdfRow(font, '상여', money(w.bonus)),
                      pw.Divider(),
                      _pdfRow(font, '지급계', money(r.totalPay), bold: true),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(border: pw.Border.all()),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('공제내역', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 8),
                      if (w.type == 'freelance') ...[
                        _pdfRow(font, '원천징수(3.3%)', money(r.tax33)),
                      ] else ...[
                        _pdfRow(font, '국민연금', money(r.nationalPension)),
                        _pdfRow(font, '건강보험', money(r.healthInsurance)),
                        _pdfRow(font, '장기요양', money(r.careInsurance)),
                        _pdfRow(font, '고용보험', money(r.empInsurance)),
                        _pdfRow(font, '소득세', money(r.taxIncome)),
                        _pdfRow(font, '지방세', money(r.taxLocal)),
                      ],
                      pw.Divider(),
                      _pdfRow(font, '공제계', money(r.totalDeduction), bold: true),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: pw.BoxDecoration(border: pw.Border.all(width: 2)),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('실수령액', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.Text('${money(r.netPay)} 원', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final safeClient = _safeFileName(client.name);
    final safeWorker = _safeFileName(w.name);
    final fName = '${yymm}_${safeClient}_급여명세서_${safeWorker}.pdf';

    final out = await FilePicker.platform.saveFile(fileName: fName);
    if (out != null) {
      await File(out).writeAsBytes(await doc.save());
    }
  }

  static pw.Widget _pdfRow(pw.Font font, String left, String right, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(left, style: pw.TextStyle(font: font, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(right, style: pw.TextStyle(font: font, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  static String _safeFileName(String s) => s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
}

// ==========================================
// 6. UI
// ==========================================
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final TextEditingController _clientSearch = TextEditingController();

  @override
  void dispose() {
    _clientSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pvd = context.watch<PayrollProvider>();

    final filteredClients = pvd.clients.where((c) {
      final q = _clientSearch.text.trim();
      if (q.isEmpty) return true;
      return c.name.contains(q) || c.bizId.replaceAll('-', '').contains(q.replaceAll('-', ''));
    }).toList();

    return Scaffold(
      body: Row(
        children: [
          // Left Panel
          Container(
            width: 330,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(right: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              children: [
                _leftHeader(context, pvd),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _clientSearch,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: '거래처 검색(상호/사업자번호)',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (pvd.lastError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(
                        pvd.lastError!,
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: pvd.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: filteredClients.length,
                          itemBuilder: (ctx, i) {
                            final c = filteredClients[i];
                            final isSel = c.id == pvd.selectedClient?.id;

                            return ListTile(
                              selected: isSel,
                              selectedTileColor: Colors.indigo[50],
                              leading: const Icon(Icons.apartment),
                              title: Text(
                                c.name,
                                style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal),
                              ),
                              subtitle: Text(c.bizId),
                              onTap: () => pvd.selectClient(c),
                            );
                          },
                        ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('거래처 목록 갱신'),
                  onTap: () => pvd.loadRemoteClients(),
                ),
              ],
            ),
          ),

          // Right Panel
          Expanded(
            child: pvd.selectedClient == null ? _emptyState(context, pvd) : _workSpace(context, pvd),
          ),
        ],
      ),
    );
  }

  Widget _leftHeader(BuildContext context, PayrollProvider pvd) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 36, 16, 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.indigo[700],
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '세무회계 두란',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Windows Desktop', style: TextStyle(color: Colors.white70)),
              const Spacer(),
              IconButton(
                tooltip: '서버 주소 설정',
                onPressed: () => _showServerSettingDialog(context, pvd),
                icon: const Icon(Icons.settings, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Server: ${pvd.baseUrl}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, PayrollProvider pvd) {
    return DropTarget(
      onDragDone: (detail) async {
        if (detail.files.isEmpty) return;
        await pvd.processExcel(File(detail.files.first.path));
        if (!mounted) return;
        _showSnack(context, '엑셀 업로드 처리 완료입니다.');
      },
      child: Container(
        color: Colors.white,
        child: Center(
          child: DottedBorder(
            dashPattern: const [8, 4],
            strokeWidth: 2,
            color: Colors.grey[300]!,
            borderType: BorderType.RRect,
            radius: const Radius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(42),
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.upload_file, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 18),
                  const Text(
                    '왼쪽에서 거래처를 선택하거나,\n요청받은 엑셀 파일을 여기에 끌어다 놓으시면 됩니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.upload),
                    label: const Text('엑셀 선택 업로드'),
                    onPressed: () async {
                      final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
                      if (res == null) return;
                      await pvd.processExcel(File(res.files.single.path!));
                      if (!mounted) return;
                      _showSnack(context, '엑셀 업로드 처리 완료입니다.');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _workSpace(BuildContext context, PayrollProvider pvd) {
    final client = pvd.selectedClient!;

    final totalNet = pvd.workers.fold<double>(0, (a, b) => a + (b.result?.netPay ?? 0));
    final totalPay = pvd.workers.fold<double>(0, (a, b) => a + (b.result?.totalPay ?? 0));
    final totalDed = pvd.workers.fold<double>(0, (a, b) => a + (b.result?.totalDeduction ?? 0));

    return Column(
      children: [
        // Top bar
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('사업자번호: ${client.bizId}', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),

              OutlinedButton.icon(
                icon: const Icon(Icons.sync),
                label: const Text('발송상태 새로고침'),
                onPressed: () async {
                  await pvd.refreshSendStatus();
                  if (!context.mounted) return;
                  _showSnack(context, '발송상태 갱신 완료입니다.');
                },
              ),
              const SizedBox(width: 10),

              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text('실패 재전송 (${pvd.failedWorkers.length})'),
                onPressed: pvd.failedWorkers.isEmpty
                    ? null
                    : () async {
                        await pvd.sendAllFailedNow();
                        if (!context.mounted) return;
                        _showSnack(context, '실패 건 재전송 완료입니다.');
                      },
              ),
              const SizedBox(width: 10),

              ElevatedButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('직원 추가'),
                onPressed: () async {
                  final empty = WorkerModel(clientRefId: client.id, name: '', birthDate: '');
                  final created = await showDialog<WorkerModel>(
                    context: context,
                    builder: (_) => WorkerEditDialog(
                      title: '직원 추가',
                      initialWorker: empty,
                      ym: pvd.currentYm,
                    ),
                  );
                  if (created != null) {
                    await pvd.upsertWorker(created);
                    if (!context.mounted) return;
                    _showSnack(context, '직원 저장 완료입니다.');
                  }
                },
              ),
              const SizedBox(width: 10),

              OutlinedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('양식 다운로드'),
                onPressed: () async => FileService.downloadTemplate(client, pvd.workers),
              ),
              const SizedBox(width: 10),

              OutlinedButton.icon(
                icon: const Icon(Icons.upload),
                label: const Text('엑셀 업로드'),
                onPressed: () async {
                  final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
                  if (res == null) return;
                  await pvd.processExcel(File(res.files.single.path!));
                  if (!context.mounted) return;
                  _showSnack(context, '엑셀 업로드 처리 완료입니다.');
                },
              ),
              const SizedBox(width: 10),

              ElevatedButton.icon(
                icon: const Icon(Icons.save_alt),
                label: const Text('급여대장 저장'),
                onPressed: () async => FileService.exportRegister(pvd),
              ),
            ],
          ),
        ),

        // Date bar + summary
        Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          color: Colors.grey[50],
          child: Row(
            children: [
              _monthButton(
                context: context,
                label: '귀속월',
                value: DateFormat('yyyy-MM').format(pvd.attributionDate),
                onPick: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: pvd.attributionDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (d == null) return;
                  await pvd.updateDate(DateTime(d.year, d.month, 1), pvd.paymentDate);
                },
              ),
              const SizedBox(width: 12),
              _monthButton(
                context: context,
                label: '지급월',
                value: DateFormat('yyyy-MM').format(pvd.paymentDate),
                onPick: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: pvd.paymentDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (d == null) return;
                  await pvd.updateDate(pvd.attributionDate, DateTime(d.year, d.month, 1));
                },
              ),

              const SizedBox(width: 14),

              // ✅ 실패 필터(요청사항)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ALL', label: Text('전체')),
                  ButtonSegment(value: 'FAILED', label: Text('실패')),
                  ButtonSegment(value: 'SENT', label: Text('완료')),
                  ButtonSegment(value: 'PENDING', label: Text('대기')),
                  ButtonSegment(value: 'UNKNOWN', label: Text('미확인')),
                ],
                selected: {pvd.sendFilter},
                onSelectionChanged: (s) => pvd.setSendFilter(s.first),
              ),

              const Spacer(),
              _summaryChip('직원', '${pvd.workers.length}명'),
              const SizedBox(width: 10),
              _summaryChip('지급계', NumberFormat('#,###').format(totalPay)),
              const SizedBox(width: 10),
              _summaryChip('공제계', NumberFormat('#,###').format(totalDed)),
              const SizedBox(width: 10),
              _summaryChip('실지급', NumberFormat('#,###').format(totalNet), strong: true),
            ],
          ),
        ),

        // ✅ 마감/알림 배너(요청사항)
        if (pvd.payrollMeta != null) _metaBanner(pvd),

        // Worker table
        Expanded(
          child: pvd.isLoading ? const Center(child: CircularProgressIndicator()) : _workerTable(context, pvd),
        ),
      ],
    );
  }

  Widget _metaBanner(PayrollProvider pvd) {
    final meta = pvd.payrollMeta!;
    final hasAny = (meta.notice.trim().isNotEmpty) || meta.slipDeadline != null || meta.registerDeadline != null;
    if (!hasAny) return const SizedBox.shrink();

    String fmt(DateTime dt) => DateFormat('MM/dd HH:mm').format(dt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber[50],
          border: Border.all(color: Colors.amber[200]!),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('마감/알림', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown[800])),
            const SizedBox(height: 6),
            Text(
              meta.notice.trim().isEmpty ? '서버 알림이 없습니다.' : meta.notice,
              style: TextStyle(color: Colors.brown[800]),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (meta.slipDeadline != null) Chip(label: Text('명세서 마감: ${fmt(meta.slipDeadline!)}')),
                if (meta.registerDeadline != null) Chip(label: Text('급여대장 마감: ${fmt(meta.registerDeadline!)}')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _workerTable(BuildContext context, PayrollProvider pvd) {
    final rows = pvd.filteredWorkers; // ✅ 필터 적용

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 46,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 64,
                columns: const [
                  DataColumn(label: Text('직원')),
                  DataColumn(label: Text('구분/형태')),
                  DataColumn(label: Text('기본/시간')),
                  DataColumn(label: Text('연장/야간/휴일')),
                  DataColumn(label: Text('비과세')),
                  DataColumn(label: Text('실수령')),
                  DataColumn(label: Text('발송상태')),
                  DataColumn(label: Text('작업')),
                ],
                rows: rows.map((w) {
                  final r = w.result ?? SalaryResult();
                  final money = NumberFormat('#,###');

                  final baseOrHours = (w.salaryType == 'MONTHLY')
                      ? '기본 ${money.format(r.basePay)}'
                      : '근무 ${w.workHours.toStringAsFixed(1)}h';

                  final overtimeSet =
                      '${w.overtimeHours.toStringAsFixed(1)} / ${w.nightHours.toStringAsFixed(1)} / ${w.holidayHours.toStringAsFixed(1)}';

                  final nonTax = '${money.format(w.foodAllowance)} / ${money.format(w.carAllowance)}';

                  final status = pvd.getSendStatus(w);
                  final err = pvd.getSendError(w);

                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(w.birthDate, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                        onTap: () => _openEditWorker(context, pvd, w),
                      ),
                      DataCell(Text('${salaryTypeToText(w.salaryType)} / ${w.type}'), onTap: () => _openEditWorker(context, pvd, w)),
                      DataCell(Text(baseOrHours), onTap: () => _openEditWorker(context, pvd, w)),
                      DataCell(Text(overtimeSet), onTap: () => _openEditWorker(context, pvd, w)),
                      DataCell(Text(nonTax), onTap: () => _openEditWorker(context, pvd, w)),
                      DataCell(
                        Text('${money.format(r.netPay)}원', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                      ),

                      // ✅ 발송상태 컬럼(요청사항)
                      DataCell(_SendStatusChip(status: status, error: err)),

                      // ✅ 작업 컬럼(요청사항: 재전송 버튼 포함)
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              tooltip: '명세서 PDF',
                              icon: const Icon(Icons.picture_as_pdf),
                              onPressed: () async => FileService.exportSlipPdf(pvd, w),
                            ),
                            IconButton(
                              tooltip: status == 'FAILED' ? '재전송' : '발송 요청',
                              icon: Icon(status == 'FAILED' ? Icons.refresh : Icons.send),
                              onPressed: () async {
                                await pvd.sendSlipNow(w);
                                if (!context.mounted) return;
                                _showSnack(context, status == 'FAILED' ? '재전송 요청 완료입니다.' : '발송 요청 완료입니다.');
                              },
                            ),
                            IconButton(
                              tooltip: '수정',
                              icon: const Icon(Icons.edit),
                              onPressed: () => _openEditWorker(context, pvd, w),
                            ),
                            IconButton(
                              tooltip: '삭제',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                if (w.id == null) return;
                                final ok = await _confirm(context, '삭제 확인', '${w.name} 직원을 삭제하시겠습니까?\n(해당 월의 변동값도 같이 삭제됩니다.)');
                                if (!ok) return;
                                await pvd.deleteWorker(w.id!);
                                if (!context.mounted) return;
                                _showSnack(context, '삭제 완료입니다.');
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEditWorker(BuildContext context, PayrollProvider pvd, WorkerModel w) async {
    final updated = await showDialog<WorkerModel>(
      context: context,
      builder: (_) => WorkerEditDialog(
        title: '직원 수정',
        initialWorker: w,
        ym: pvd.currentYm,
      ),
    );

    if (updated != null) {
      await pvd.upsertWorker(updated);
      if (!context.mounted) return;
      _showSnack(context, '저장 및 재계산 완료입니다.');
    }
  }

  Widget _monthButton({
    required BuildContext context,
    required String label,
    required String value,
    required Future<void> Function() onPick,
  }) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.date_range),
      label: Text('$label: $value'),
      onPressed: onPick,
    );
  }

  Widget _summaryChip(String label, String value, {bool strong = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: strong ? Colors.indigo[50] : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontWeight: strong ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _showServerSettingDialog(BuildContext context, PayrollProvider pvd) async {
    final controller = TextEditingController(text: pvd.baseUrl);

    final saved = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('서버 주소 설정'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '예) http://127.0.0.1:8000',
              hintText: 'FastAPI 서버 주소',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    if (saved == null) return;

    final url = saved.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      _showSnack(context, '서버 주소는 http:// 또는 https:// 로 시작해야 합니다.');
      return;
    }

    await pvd.setBaseUrl(url);
    if (!context.mounted) return;
    _showSnack(context, '서버 주소 저장 및 목록 갱신 완료입니다.');
  }

  Future<bool> _confirm(BuildContext context, String title, String message) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('확인')),
        ],
      ),
    );
    return res == true;
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }
}

// ✅ 발송상태 Chip
class _SendStatusChip extends StatelessWidget {
  final String status;
  final String? error;

  const _SendStatusChip({required this.status, required this.error});

  @override
  Widget build(BuildContext context) {
    String text;
    IconData icon;

    switch (status) {
      case 'SENT':
        text = '발송완료';
        icon = Icons.check_circle;
        break;
      case 'FAILED':
        text = '실패';
        icon = Icons.error;
        break;
      case 'PENDING':
        text = '대기';
        icon = Icons.hourglass_top;
        break;
      default:
        text = '미확인';
        icon = Icons.help;
    }

    final chip = Chip(
      avatar: Icon(icon, size: 18),
      label: Text(text),
    );

    if (status == 'FAILED' && (error ?? '').trim().isNotEmpty) {
      return Tooltip(message: error!, child: chip);
    }
    return chip;
  }
}

// ==========================================
// 7. 직원 수정/추가 다이얼로그(월별 변동값 포함)
// ==========================================
class WorkerEditDialog extends StatefulWidget {
  final String title;
  final WorkerModel initialWorker;
  final String ym;

  const WorkerEditDialog({
    super.key,
    required this.title,
    required this.initialWorker,
    required this.ym,
  });

  @override
  State<WorkerEditDialog> createState() => _WorkerEditDialogState();
}

class _WorkerEditDialogState extends State<WorkerEditDialog> {
  final _formKey = GlobalKey<FormState>();

  late int? _id;
  late int _clientRefId;

  late String _name;
  late String _birthDate;
  late String _type;

  late String _salaryType;

  late double _baseSalary;
  late double _hourlyRate;
  late double _normalHours;

  late double _food;
  late double _car;

  // 월별
  late double _workHours;
  late double _bonus;
  late double _ot;
  late double _night;
  late double _hol;

  @override
  void initState() {
    super.initState();

    final w = widget.initialWorker;

    _id = w.id;
    _clientRefId = w.clientRefId;

    _name = w.name;
    _birthDate = w.birthDate;
    _type = w.type;

    _salaryType = w.salaryType;

    _baseSalary = w.baseSalary;
    _hourlyRate = w.hourlyRate;
    _normalHours = w.normalHours;

    _food = w.foodAllowance;
    _car = w.carAllowance;

    _workHours = w.workHours;
    _bonus = w.bonus;
    _ot = w.overtimeHours;
    _night = w.nightHours;
    _hol = w.holidayHours;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.title}  (월: ${widget.ym})'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _sectionTitle('기본정보'),
                Row(
                  children: [
                    Expanded(child: _textInput('이름', _name, (v) => _name = v, requiredField: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _textInput('생년월일(YYMMDD)', _birthDate, (v) => _birthDate = v, requiredField: true)),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(labelText: '고용형태'),
                  items: const [
                    DropdownMenuItem(value: 'regular', child: Text('regular (근로소득)')),
                    DropdownMenuItem(value: 'freelance', child: Text('freelance (3.3%)')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'regular'),
                ),

                const SizedBox(height: 14),
                _sectionTitle('급여구분'),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('월급제'),
                        value: 'MONTHLY',
                        groupValue: _salaryType,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setState(() => _salaryType = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('시급제'),
                        value: 'HOURLY',
                        groupValue: _salaryType,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setState(() => _salaryType = v!),
                      ),
                    ),
                  ],
                ),

                const Divider(height: 28),

                if (_salaryType == 'MONTHLY') ...[
                  _numInput('월 기본급', _baseSalary, (v) => _baseSalary = v),
                  _numInput('통상근로시간(기본 209)', _normalHours, (v) => _normalHours = v),
                  _numInput('상여(월별)', _bonus, (v) => _bonus = v),
                ] else ...[
                  _numInput('시급', _hourlyRate, (v) => _hourlyRate = v),
                  _numInput('근무시간(월별)', _workHours, (v) => _workHours = v),
                ],

                const Divider(height: 28),

                _sectionTitle('변동 근무(월별)'),
                Row(
                  children: [
                    Expanded(child: _numInput('연장(시간)', _ot, (v) => _ot = v)),
                    const SizedBox(width: 10),
                    Expanded(child: _numInput('야간(시간)', _night, (v) => _night = v)),
                    const SizedBox(width: 10),
                    Expanded(child: _numInput('휴일(시간)', _hol, (v) => _hol = v)),
                  ],
                ),

                const Divider(height: 28),

                _sectionTitle('비과세(고정)'),
                Row(
                  children: [
                    Expanded(child: _numInput('식대', _food, (v) => _food = v)),
                    const SizedBox(width: 10),
                    Expanded(child: _numInput('차량유지비', _car, (v) => _car = v)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            _formKey.currentState!.save();

            final worker = WorkerModel(
              id: _id,
              clientRefId: _clientRefId,
              name: _name.trim(),
              birthDate: _birthDate.trim(),
              type: _type,
              salaryType: _salaryType,
              baseSalary: _baseSalary,
              hourlyRate: _hourlyRate == 0 ? 9860 : _hourlyRate,
              normalHours: _normalHours == 0 ? 209 : _normalHours,
              foodAllowance: _food,
              carAllowance: _car,
              workHours: _workHours,
              bonus: _bonus,
              overtimeHours: _ot,
              nightHours: _night,
              holidayHours: _hol,
            );

            Navigator.pop(context, worker);
          },
          child: const Text('저장 및 재계산'),
        ),
      ],
    );
  }

  Widget _sectionTitle(String t) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _textInput(String label, String init, void Function(String) onSave, {bool requiredField = false}) {
    return TextFormField(
      initialValue: init,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (!requiredField) return null;
        if (v == null || v.trim().isEmpty) return '$label 은(는) 필수입니다.';
        return null;
      },
      onSaved: (v) => onSave((v ?? '').trim()),
    );
  }

  Widget _numInput(String label, double initVal, void Function(double) onSave) {
    return TextFormField(
      initialValue: initVal == 0 ? '' : initVal.toStringAsFixed(0),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onSaved: (v) {
        if (v == null || v.trim().isEmpty) {
          onSave(0);
        } else {
          onSave(double.tryParse(v.replaceAll(',', '').trim()) ?? 0);
        }
      },
    );
  }
}
