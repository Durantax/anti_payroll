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
        width: 800,
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
                Tab(text: '수당/공제 관리'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _SmtpSettingsTab(),
                  _AllowanceDeductionManagementTab(),
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

// ============================================================================
// 수당/공제 관리 탭
// ============================================================================
class _AllowanceDeductionManagementTab extends StatefulWidget {
  @override
  State<_AllowanceDeductionManagementTab> createState() => _AllowanceDeductionManagementTabState();
}

class _AllowanceDeductionManagementTabState extends State<_AllowanceDeductionManagementTab> {
  List<AllowanceMaster> _allowances = [];
  List<DeductionMaster> _deductions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<AppProvider>();
    final selectedClient = provider.selectedClient;
    
    if (selectedClient == null) {
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final allowances = await provider.apiService.getAllowanceMasters(selectedClient.id);
      final deductions = await provider.apiService.getDeductionMasters(selectedClient.id);
      
      setState(() {
        _allowances = allowances;
        _deductions = deductions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 로드 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final selectedClient = provider.selectedClient;

    if (selectedClient == null) {
      return const Center(
        child: Text('거래처를 먼저 선택하세요'),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.business, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  '현재 거래처: ${selectedClient.name}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildAllowanceSection(selectedClient.id),
          const SizedBox(height: 32),
          _buildDeductionSection(selectedClient.id),
        ],
      ),
    );
  }

  Widget _buildAllowanceSection(int clientId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '💰 수당 항목',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddAllowanceDialog(clientId),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('수당 추가'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_allowances.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: Text('등록된 수당 항목이 없습니다')),
          )
        else
          ..._allowances.map((allowance) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: allowance.isTaxFree ? Colors.orange.shade100 : Colors.blue.shade100,
                child: Icon(
                  Icons.attach_money,
                  color: allowance.isTaxFree ? Colors.orange.shade700 : Colors.blue.shade700,
                ),
              ),
              title: Text(allowance.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (allowance.isTaxFree)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('비과세', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  if (allowance.defaultAmount != null)
                    Text('기본 금액: ${formatMoney(allowance.defaultAmount!)}원'),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _showEditAllowanceDialog(allowance),
                    tooltip: '수정',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () => _deleteAllowance(allowance),
                    tooltip: '삭제',
                  ),
                ],
              ),
            ),
          )),
      ],
    );
  }

  Widget _buildDeductionSection(int clientId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '📉 공제 항목',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddDeductionDialog(clientId),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('공제 추가'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_deductions.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: Text('등록된 공제 항목이 없습니다')),
          )
        else
          ..._deductions.map((deduction) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red.shade100,
                child: Icon(Icons.remove_circle_outline, color: Colors.red.shade700),
              ),
              title: Text(deduction.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: deduction.defaultAmount != null
                  ? Text('기본 금액: ${formatMoney(deduction.defaultAmount!)}원')
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _showEditDeductionDialog(deduction),
                    tooltip: '수정',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () => _deleteDeduction(deduction),
                    tooltip: '삭제',
                  ),
                ],
              ),
            ),
          )),
      ],
    );
  }

  Future<void> _showAddAllowanceDialog(int clientId) async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    bool isTaxFree = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('수당 항목 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '수당 항목명',
                  hintText: '예: 야간수당, 교통비, 식대',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: '기본 금액 (선택)',
                  hintText: '0',
                  border: OutlineInputBorder(),
                  suffixText: '원',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('비과세 항목'),
                subtitle: const Text('식대, 차량유지비 등'),
                value: isTaxFree,
                onChanged: (value) {
                  setDialogState(() {
                    isTaxFree = value ?? false;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('항목명을 입력하세요')),
                  );
                  return;
                }
                _addAllowance(
                  clientId,
                  nameController.text,
                  isTaxFree,
                  amountController.text.isEmpty ? null : int.parse(amountController.text),
                );
                Navigator.pop(context);
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addAllowance(int clientId, String name, bool isTaxFree, int? defaultAmount) async {
    try {
      final provider = context.read<AppProvider>();
      final newAllowance = await provider.apiService.createAllowanceMaster(
        clientId: clientId,
        name: name,
        isTaxFree: isTaxFree,
        defaultAmount: defaultAmount,
      );
      
      setState(() {
        _allowances.add(newAllowance);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('수당 항목이 추가되었습니다'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('추가 실패: $e')),
        );
      }
    }
  }

  Future<void> _showEditAllowanceDialog(AllowanceMaster allowance) async {
    final nameController = TextEditingController(text: allowance.name);
    final amountController = TextEditingController(text: allowance.defaultAmount?.toString() ?? '');
    bool isTaxFree = allowance.isTaxFree;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('수당 항목 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '수당 항목명', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: '기본 금액 (선택)',
                  border: OutlineInputBorder(),
                  suffixText: '원',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('비과세 항목'),
                value: isTaxFree,
                onChanged: (value) {
                  setDialogState(() {
                    isTaxFree = value ?? false;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateAllowance(
                  allowance.id!,
                  nameController.text,
                  isTaxFree,
                  amountController.text.isEmpty ? null : int.parse(amountController.text),
                );
                Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateAllowance(int id, String name, bool isTaxFree, int? defaultAmount) async {
    try {
      final provider = context.read<AppProvider>();
      final updatedAllowance = await provider.apiService.updateAllowanceMaster(
        allowanceId: id,
        name: name,
        isTaxFree: isTaxFree,
        defaultAmount: defaultAmount,
      );
      
      setState(() {
        final index = _allowances.indexWhere((a) => a.id == id);
        if (index != -1) {
          _allowances[index] = updatedAllowance;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('수당 항목이 수정되었습니다'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('수정 실패: $e')),
        );
      }
    }
  }

  Future<void> _deleteAllowance(AllowanceMaster allowance) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('수당 항목 삭제'),
        content: Text('\'${allowance.name}\' 항목을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final provider = context.read<AppProvider>();
        await provider.apiService.deleteAllowanceMaster(allowance.id!);
        
        setState(() {
          _allowances.removeWhere((a) => a.id == allowance.id);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('수당 항목이 삭제되었습니다')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')),
          );
        }
      }
    }
  }

  Future<void> _showAddDeductionDialog(int clientId) async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('공제 항목 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '공제 항목명',
                hintText: '예: 조퇴, 결근공제, 기타공제',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: '기본 금액 (선택)',
                hintText: '0',
                border: OutlineInputBorder(),
                suffixText: '원',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('항목명을 입력하세요')),
                );
                return;
              }
              _addDeduction(
                clientId,
                nameController.text,
                amountController.text.isEmpty ? null : int.parse(amountController.text),
              );
              Navigator.pop(context);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  Future<void> _addDeduction(int clientId, String name, int? defaultAmount) async {
    try {
      final provider = context.read<AppProvider>();
      final newDeduction = await provider.apiService.createDeductionMaster(
        clientId: clientId,
        name: name,
        defaultAmount: defaultAmount,
      );
      
      setState(() {
        _deductions.add(newDeduction);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공제 항목이 추가되었습니다'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('추가 실패: $e')),
        );
      }
    }
  }

  Future<void> _showEditDeductionDialog(DeductionMaster deduction) async {
    final nameController = TextEditingController(text: deduction.name);
    final amountController = TextEditingController(text: deduction.defaultAmount?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('공제 항목 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '공제 항목명', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: '기본 금액 (선택)',
                border: OutlineInputBorder(),
                suffixText: '원',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateDeduction(
                deduction.id!,
                nameController.text,
                amountController.text.isEmpty ? null : int.parse(amountController.text),
              );
              Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateDeduction(int id, String name, int? defaultAmount) async {
    try {
      final provider = context.read<AppProvider>();
      final updatedDeduction = await provider.apiService.updateDeductionMaster(
        deductionId: id,
        name: name,
        defaultAmount: defaultAmount,
      );
      
      setState(() {
        final index = _deductions.indexWhere((d) => d.id == id);
        if (index != -1) {
          _deductions[index] = updatedDeduction;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공제 항목이 수정되었습니다'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('수정 실패: $e')),
        );
      }
    }
  }

  Future<void> _deleteDeduction(DeductionMaster deduction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('공제 항목 삭제'),
        content: Text('\'${deduction.name}\' 항목을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final provider = context.read<AppProvider>();
        await provider.apiService.deleteDeductionMaster(deduction.id!);
        
        setState(() {
          _deductions.removeWhere((d) => d.id == deduction.id);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('공제 항목이 삭제되었습니다')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')),
          );
        }
      }
    }
  }
}
