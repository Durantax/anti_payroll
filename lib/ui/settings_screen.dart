import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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
    _tabController = TabController(length: 2, vsync: this);
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
                Tab(text: '서버 설정'),
                Tab(text: 'SMTP 설정'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ServerSettingsTab(),
                  _SmtpSettingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== 서버 설정 탭 ==========

class _ServerSettingsTab extends StatefulWidget {
  @override
  State<_ServerSettingsTab> createState() => _ServerSettingsTabState();
}

class _ServerSettingsTabState extends State<_ServerSettingsTab> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _serverUrlController;
  late TextEditingController _apiKeyController;
  bool _isTestingConnection = false;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    _serverUrlController = TextEditingController(text: provider.appSettings?.serverUrl ?? '');
    _apiKeyController = TextEditingController(text: provider.appSettings?.apiKey ?? '');
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _apiKeyController.dispose();
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
            const Text('API 서버 설정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _serverUrlController,
              decoration: const InputDecoration(
                labelText: 'API 서버 주소',
                border: OutlineInputBorder(),
                hintText: 'http://25.2.89.129:8000',
              ),
              validator: (v) {
                if (v?.isEmpty ?? true) return '서버 주소를 입력하세요';
                if (!v!.startsWith('http://') && !v.startsWith('https://')) {
                  return 'http:// 또는 https://로 시작해야 합니다';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key (선택)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isTestingConnection ? null : _testConnection,
              icon: _isTestingConnection
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle),
              label: const Text('연결 테스트'),
            ),
            if (_connectionStatus != null) ...[
              const SizedBox(height: 16),
              Card(
                color: _connectionStatus!.contains('성공') ? Colors.green.shade50 : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        _connectionStatus!.contains('성공') ? Icons.check_circle : Icons.error,
                        color: _connectionStatus!.contains('성공') ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_connectionStatus!)),
                    ],
                  ),
                ),
              ),
            ],
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

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });

    try {
      final provider = context.read<AppProvider>();
      
      // 임시로 설정 변경
      provider.updateSettings(_serverUrlController.text, _apiKeyController.text);
      
      final isConnected = await provider.testServerConnection();

      setState(() {
        _connectionStatus = isConnected ? '✅ 서버 연결 성공' : '❌ 서버 연결 실패';
      });
    } catch (e) {
      setState(() {
        _connectionStatus = '❌ 연결 실패: $e';
      });
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await context.read<AppProvider>().saveAppSettings(
            _serverUrlController.text,
            _apiKeyController.text,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('설정이 저장되었습니다')),
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

// ========== SMTP 설정 탭 ==========

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
