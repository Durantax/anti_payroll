import 'dart:io';
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

class _SettingsScreenState extends State<SettingsScreen> {
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
            // SMTP 설정만 표시 (파일 경로는 자동)
            Expanded(
              child: _SmtpSettingsTab(),
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
