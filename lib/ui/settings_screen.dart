import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../core/models.dart';
import '../providers/app_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '시스템 설정',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'SMTP 설정'),
                Tab(text: '파일 저장 경로'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _SmtpSettingsTab(),
                  _FilePathSettingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _SmtpSettingsTab extends StatefulWidget {
  @override
  State<_SmtpSettingsTab> createState() => _SmtpSettingsTabState();
}

class _SmtpSettingsTabState extends State<_SmtpSettingsTab> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  bool _useSSL = true;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    final config = provider.smtpConfig;

    _hostController = TextEditingController(text: config?.host ?? '');
    _portController = TextEditingController(text: config?.port.toString() ?? '587');
    _usernameController = TextEditingController(text: config?.username ?? '');
    _passwordController = TextEditingController(text: config?.password ?? '');
    _useSSL = config?.useSSL ?? true;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SMTP 서버 설정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'SMTP 서버',
                border: OutlineInputBorder(),
                hintText: 'smtp.gmail.com',
              ),
              validator: (v) => v?.isEmpty ?? true ? 'SMTP 서버를 입력하세요' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: '포트',
                border: OutlineInputBorder(),
                hintText: '587',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) => v?.isEmpty ?? true ? '포트를 입력하세요' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '이메일 주소',
                border: OutlineInputBorder(),
                hintText: 'admin@duran.com',
              ),
              validator: (v) => v?.isEmpty ?? true ? '이메일 주소를 입력하세요' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '비밀번호 (앱 비밀번호)',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (v) => v?.isEmpty ?? true ? '비밀번호를 입력하세요' : null,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('SSL 사용'),
              value: _useSSL,
              onChanged: (value) => setState(() => _useSSL = value ?? true),
            ),
            const SizedBox(height: 24),
            Card(
            color: Colors.blue[50],  // ✅
            child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text('⚠️ Gmail 사용 시:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('1. Google 계정 → 보안 → 2단계 인증 활성화'),
                    Text('2. 앱 비밀번호 생성 (16자리)'),
                    Text('3. 생성된 앱 비밀번호를 위에 입력'),
                ],
                ),
            ),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _save,
                  child: const Text('저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final config = SmtpConfig(
        host: _hostController.text,
        port: int.tryParse(_portController.text) ?? 587,
        username: _usernameController.text,
        password: _passwordController.text,
        useSSL: _useSSL,
      );

      await context.read<AppProvider>().saveSmtpConfig(config);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMTP 설정이 저장되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    }
  }
}

// ========== 파일 저장 경로 설정 탭 ==========

class _FilePathSettingsTab extends StatefulWidget {
  @override
  State<_FilePathSettingsTab> createState() => _FilePathSettingsTabState();
}

class _FilePathSettingsTabState extends State<_FilePathSettingsTab> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _pathController;
  bool _useClientSubfolders = true;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    final settings = provider.settings;
    
    _pathController = TextEditingController(
      text: settings?.downloadBasePath ?? _getDefaultPath(),
    );
    _useClientSubfolders = settings?.useClientSubfolders ?? true;
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  String _getDefaultPath() {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Default';
      
      // OneDrive 문서 폴더 우선 (한글 "문서" 먼저, 그 다음 영문 "Documents")
      final oneDriveKorean = '$userProfile\\OneDrive\\문서\\급여관리프로그램';
      final oneDriveEnglish = '$userProfile\\OneDrive\\Documents\\급여관리프로그램';
      final regularDocs = '$userProfile\\Documents\\급여관리프로그램';
      
      if (Directory(oneDriveKorean).parent.existsSync()) {
        return oneDriveKorean;
      } else if (Directory(oneDriveEnglish).parent.existsSync()) {
        return oneDriveEnglish;
      } else {
        return regularDocs;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '파일 저장 경로 설정',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'PDF, CSV 파일을 자동으로 저장할 기본 경로를 설정합니다.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            
            // 경로 입력
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _pathController,
                    decoration: const InputDecoration(
                      labelText: '기본 저장 경로',
                      border: OutlineInputBorder(),
                      hintText: 'C:\\Users\\사용자\\Documents\\급여관리프로그램',
                      helperText: '파일이 자동으로 저장될 폴더를 선택하세요',
                    ),
                    validator: (v) {
                      if (v?.isEmpty ?? true) return '경로를 입력하세요';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _selectFolder,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('폴더 선택'),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // 거래처 하위 폴더 옵션
            Card(
              child: CheckboxListTile(
                title: const Text('거래처별 하위 폴더 생성'),
                subtitle: const Text('예: 급여관리프로그램\\삼성전자\\2025\\'),
                value: _useClientSubfolders,
                onChanged: (value) {
                  setState(() => _useClientSubfolders = value ?? true);
                  _autoSave(); // 자동 저장
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 안내 정보
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          '파일 저장 구조',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_useClientSubfolders) ...[
                      const Text('✅ 거래처 하위 폴더 사용 시:'),
                      const SizedBox(height: 4),
                      Text(
                        '${_pathController.text}\\거래처명\\연도\\파일명',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      const Text('예시:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '${_pathController.text}\\삼성전자\\2025\\',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                      const Text(
                        '  ├─ 삼성전자_2025년12월_급여대장.csv',
                        style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                      ),
                      const Text(
                        '  ├─ 삼성전자_2025년12월_급여대장.pdf',
                        style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                      ),
                      const Text(
                        '  └─ 삼성전자_홍길동_2025년12월_급여명세서.pdf',
                        style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                      ),
                    ] else ...[
                      const Text('❌ 거래처 하위 폴더 미사용 시:'),
                      const SizedBox(height: 4),
                      Text(
                        '${_pathController.text}\\파일명',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      const Text('모든 파일이 한 폴더에 저장됩니다.'),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // OneDrive 안내
            Card(
              color: Colors.green[50],
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'OneDrive 공유 폴더 사용 가능',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('✅ OneDrive 폴더를 경로로 설정하면 자동 동기화됩니다'),
                    Text('✅ 여러 컴퓨터에서 동일한 파일 접근 가능'),
                    SizedBox(height: 8),
                    Text(
                      '예: C:\\Users\\사용자\\OneDrive\\급여관리프로그램',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '⚠️ 주의: 동시 작업 시 충돌 가능 (한 번에 한 컴퓨터만 사용)',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _resetToDefault,
                  icon: const Icon(Icons.refresh),
                  label: const Text('기본값으로'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectFolder() async {
    final selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '파일 저장 경로 선택',
      initialDirectory: _pathController.text.isNotEmpty ? _pathController.text : null,
    );

    if (selectedDirectory != null) {
      setState(() {
        _pathController.text = selectedDirectory;
      });
      _autoSave(); // 자동 저장
    }
  }

  void _resetToDefault() {
    setState(() {
      _pathController.text = _getDefaultPath();
      _useClientSubfolders = true;
    });
    _autoSave(); // 자동 저장
  }

  void _autoSave() {
    // 경로가 비어있으면 저장하지 않음
    if (_pathController.text.isEmpty) return;
    
    // 폴더가 없으면 자동 생성
    final directory = Directory(_pathController.text);
    if (!directory.existsSync()) {
      try {
        directory.createSync(recursive: true);
      } catch (e) {
        // 생성 실패 시 무시 (다음에 다시 시도)
        return;
      }
    }
    
    // 저장 (비동기이지만 기다리지 않음 - 백그라운드에서 처리)
    context.read<AppProvider>().updateDownloadPath(
      _pathController.text,
      _useClientSubfolders,
    );
  }
}

// ========== 거래처 설정 다이얼로그 ==========

class ClientSettingsDialog extends StatefulWidget {
  final ClientModel client;

  const ClientSettingsDialog({Key? key, required this.client}) : super(key: key);

  @override
  State<ClientSettingsDialog> createState() => _ClientSettingsDialogState();
}

class _ClientSettingsDialogState extends State<ClientSettingsDialog> {
  late TextEditingController _subjectController;
  late TextEditingController _bodyController;
  late bool _has5OrMoreWorkers;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(text: widget.client.emailSubjectTemplate);
    _bodyController = TextEditingController(text: widget.client.emailBodyTemplate);
    _has5OrMoreWorkers = widget.client.has5OrMoreWorkers;
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.client.name} 설정',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              const Text('【 이메일 템플릿 】', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('사용 가능한 변수: {clientName}, {year}, {month}, {workerName}'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: '이메일 제목',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: '이메일 본문',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 24),
              const Text('【 급여 계산 기준 】', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('5인 이상 사업장'),
                subtitle: const Text('연장/야간/휴일 가산수당 지급 (1.5배, 0.5배)'),
                value: _has5OrMoreWorkers,
                onChanged: (value) => setState(() => _has5OrMoreWorkers = value ?? false),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    child: const Text('저장'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    try {
      await context.read<AppProvider>().updateClientSettings(
            has5OrMoreWorkers: _has5OrMoreWorkers,
            emailSubjectTemplate: _subjectController.text,
            emailBodyTemplate: _bodyController.text,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('거래처 설정이 저장되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    }
  }
}
