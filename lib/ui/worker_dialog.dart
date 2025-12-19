import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models.dart';

class WorkerDialog extends StatefulWidget {
  final int clientId;
  final WorkerModel? worker;
  final MonthlyData? monthlyData;
  final Function(WorkerModel, MonthlyData) onSave;

  const WorkerDialog({
    Key? key,
    required this.clientId,
    this.worker,
    this.monthlyData,
    required this.onSave,
  }) : super(key: key);

  @override
  State<WorkerDialog> createState() => _WorkerDialogState();
}

class _WorkerDialogState extends State<WorkerDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // 기본정보
  late TextEditingController _nameController;
  late TextEditingController _birthDateController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  // 급여 정보
  late TextEditingController _monthlySalaryController;
  late TextEditingController _hourlyRateController;
  late TextEditingController _weeklyHoursController;
  late TextEditingController _normalHoursController;
  late TextEditingController _overtimeHoursController;
  late TextEditingController _nightHoursController;
  late TextEditingController _holidayHoursController;
  late TextEditingController _weekCountController;
  late TextEditingController _bonusController;

  // 추가 수당/공제
  late TextEditingController _additionalPay1Controller;
  late TextEditingController _additionalPay1NameController;
  late TextEditingController _additionalPay2Controller;
  late TextEditingController _additionalPay2NameController;
  late TextEditingController _additionalPay3Controller;
  late TextEditingController _additionalPay3NameController;

  late TextEditingController _additionalDeduct1Controller;
  late TextEditingController _additionalDeduct1NameController;
  late TextEditingController _additionalDeduct2Controller;
  late TextEditingController _additionalDeduct2NameController;
  late TextEditingController _additionalDeduct3Controller;
  late TextEditingController _additionalDeduct3NameController;

  // 4대보험
  late TextEditingController _pensionInsurableWageController;
  late bool _hasNationalPension;
  late bool _hasHealthInsurance;
  late bool _hasEmploymentInsurance;
  late String _healthInsuranceBasis;

  // 이메일
  late TextEditingController _emailToController;
  late TextEditingController _emailCcController;
  late bool _useEmail;

  // 구분
  late String _employmentType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    final worker = widget.worker;
    final monthly = widget.monthlyData;

    // 기본정보
    _nameController = TextEditingController(text: worker?.name ?? '');
    _birthDateController = TextEditingController(text: worker?.birthDate ?? '');
    _phoneController = TextEditingController(text: worker?.phoneNumber ?? '');
    _emailController = TextEditingController(text: worker?.email ?? '');

    // 급여 정보
    _monthlySalaryController = TextEditingController(text: worker?.monthlySalary.toString() ?? '0');
    _hourlyRateController = TextEditingController(text: worker?.hourlyRate.toString() ?? '0');
    _weeklyHoursController = TextEditingController(text: monthly?.weeklyHours.toString() ?? '40');
    _normalHoursController = TextEditingController(text: monthly?.normalHours.toString() ?? '209');
    _overtimeHoursController = TextEditingController(text: monthly?.overtimeHours.toString() ?? '0');
    _nightHoursController = TextEditingController(text: monthly?.nightHours.toString() ?? '0');
    _holidayHoursController = TextEditingController(text: monthly?.holidayHours.toString() ?? '0');
    _weekCountController = TextEditingController(text: monthly?.weekCount.toString() ?? '4');
    _bonusController = TextEditingController(text: monthly?.bonus.toString() ?? '0');

    // 추가 수당/공제
    _additionalPay1Controller = TextEditingController(text: monthly?.additionalPay1.toString() ?? '0');
    _additionalPay1NameController = TextEditingController(text: monthly?.additionalPay1Name ?? '');
    _additionalPay2Controller = TextEditingController(text: monthly?.additionalPay2.toString() ?? '0');
    _additionalPay2NameController = TextEditingController(text: monthly?.additionalPay2Name ?? '');
    _additionalPay3Controller = TextEditingController(text: monthly?.additionalPay3.toString() ?? '0');
    _additionalPay3NameController = TextEditingController(text: monthly?.additionalPay3Name ?? '');

    _additionalDeduct1Controller = TextEditingController(text: monthly?.additionalDeduct1.toString() ?? '0');
    _additionalDeduct1NameController = TextEditingController(text: monthly?.additionalDeduct1Name ?? '');
    _additionalDeduct2Controller = TextEditingController(text: monthly?.additionalDeduct2.toString() ?? '0');
    _additionalDeduct2NameController = TextEditingController(text: monthly?.additionalDeduct2Name ?? '');
    _additionalDeduct3Controller = TextEditingController(text: monthly?.additionalDeduct3.toString() ?? '0');
    _additionalDeduct3NameController = TextEditingController(text: monthly?.additionalDeduct3Name ?? '');

    // 4대보험
    _pensionInsurableWageController = TextEditingController(text: worker?.pensionInsurableWage?.toString() ?? '');
    _hasNationalPension = worker?.hasNationalPension ?? true;
    _hasHealthInsurance = worker?.hasHealthInsurance ?? true;
    _hasEmploymentInsurance = worker?.hasEmploymentInsurance ?? true;
    _healthInsuranceBasis = worker?.healthInsuranceBasis ?? 'salary';

    // 이메일
    _emailToController = TextEditingController(text: worker?.emailTo ?? '');
    _emailCcController = TextEditingController(text: worker?.emailCc ?? '');
    _useEmail = worker?.useEmail ?? false;

    // 구분
    _employmentType = worker?.employmentType ?? 'regular';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _monthlySalaryController.dispose();
    _hourlyRateController.dispose();
    _weeklyHoursController.dispose();
    _normalHoursController.dispose();
    _overtimeHoursController.dispose();
    _nightHoursController.dispose();
    _holidayHoursController.dispose();
    _weekCountController.dispose();
    _bonusController.dispose();
    _additionalPay1Controller.dispose();
    _additionalPay1NameController.dispose();
    _additionalPay2Controller.dispose();
    _additionalPay2NameController.dispose();
    _additionalPay3Controller.dispose();
    _additionalPay3NameController.dispose();
    _additionalDeduct1Controller.dispose();
    _additionalDeduct1NameController.dispose();
    _additionalDeduct2Controller.dispose();
    _additionalDeduct2NameController.dispose();
    _additionalDeduct3Controller.dispose();
    _additionalDeduct3NameController.dispose();
    _pensionInsurableWageController.dispose();
    _emailToController.dispose();
    _emailCcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFreelancer = _employmentType == 'freelance';

    return Dialog(
      child: Container(
        width: 700,
        height: 800,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.worker == null ? '직원 추가' : '직원 정보 - ${widget.worker!.name}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '기본정보'),
                  Tab(text: '급여'),
                  Tab(text: '4대보험'),
                  Tab(text: '이메일'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBasicInfoTab(),
                    _buildSalaryTab(isFreelancer),
                    _buildInsuranceTab(isFreelancer),
                    _buildEmailTab(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _employmentType,
            decoration: const InputDecoration(labelText: '* 구분', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'regular', child: Text('정규직')),
              DropdownMenuItem(value: 'freelance', child: Text('프리랜서(3.3%)')),
            ],
            onChanged: (value) {
              setState(() {
                _employmentType = value!;
                if (value == 'freelance') {
                  _hasNationalPension = false;
                  _hasHealthInsurance = false;
                  _hasEmploymentInsurance = false;
                }
              });
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '* 이름', border: OutlineInputBorder()),
            validator: (v) => v?.isEmpty ?? true ? '이름을 입력하세요' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _birthDateController,
            decoration: const InputDecoration(
              labelText: '* 생년월일 (YYMMDD)',
              border: OutlineInputBorder(),
              hintText: '901231',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v?.isEmpty ?? true) return '생년월일을 입력하세요';
              if (v!.length != 6) return '6자리로 입력하세요';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: '전화번호', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: '이메일', border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryTab(bool isFreelancer) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('━━━ 기본 정보 ━━━', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _monthlySalaryController,
            decoration: const InputDecoration(labelText: '* 월급여', border: OutlineInputBorder(), suffixText: '원'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _hourlyRateController,
            decoration: const InputDecoration(labelText: '* 시급', border: OutlineInputBorder(), suffixText: '원'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _weeklyHoursController,
            decoration: const InputDecoration(labelText: '주소정근로시간', border: OutlineInputBorder(), suffixText: '시간'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 24),
          const Text('━━━ 이번 달 근무 ━━━', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _normalHoursController,
            decoration: const InputDecoration(labelText: '정상근로시간', border: OutlineInputBorder(), suffixText: '시간'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _overtimeHoursController,
            decoration: const InputDecoration(labelText: '연장시간', border: OutlineInputBorder(), suffixText: '시간'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nightHoursController,
            decoration: const InputDecoration(labelText: '야간시간', border: OutlineInputBorder(), suffixText: '시간'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _holidayHoursController,
            decoration: const InputDecoration(labelText: '휴일시간', border: OutlineInputBorder(), suffixText: '시간'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _weekCountController,
            decoration: const InputDecoration(labelText: '개근주수', border: OutlineInputBorder(), suffixText: '주'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bonusController,
            decoration: const InputDecoration(labelText: '상여금', border: OutlineInputBorder(), suffixText: '원'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 24),
          const Text('━━━ 추가 수당 ━━━', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _additionalPay1Controller,
                  decoration: const InputDecoration(labelText: '추가수당1', border: OutlineInputBorder(), suffixText: '원'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _additionalPay1NameController,
                  decoration: const InputDecoration(labelText: '항목명', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _additionalPay2Controller,
                  decoration: const InputDecoration(labelText: '추가수당2', border: OutlineInputBorder(), suffixText: '원'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _additionalPay2NameController,
                  decoration: const InputDecoration(labelText: '항목명', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _additionalPay3Controller,
                  decoration: const InputDecoration(labelText: '추가수당3', border: OutlineInputBorder(), suffixText: '원'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _additionalPay3NameController,
                  decoration: const InputDecoration(labelText: '항목명', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('━━━ 추가 공제 ━━━', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _additionalDeduct1Controller,
                  decoration: const InputDecoration(labelText: '추가공제1', border: OutlineInputBorder(), suffixText: '원'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _additionalDeduct1NameController,
                  decoration: const InputDecoration(labelText: '항목명', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _additionalDeduct2Controller,
                  decoration: const InputDecoration(labelText: '추가공제2', border: OutlineInputBorder(), suffixText: '원'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _additionalDeduct2NameController,
                  decoration: const InputDecoration(labelText: '항목명', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _additionalDeduct3Controller,
                  decoration: const InputDecoration(labelText: '추가공제3', border: OutlineInputBorder(), suffixText: '원'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _additionalDeduct3NameController,
                  decoration: const InputDecoration(labelText: '항목명', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsuranceTab(bool isFreelancer) {
    if (isFreelancer) {
      return const Center(
        Card(
        color: Colors.orange[50],  // ✅
        child: const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
            '프리랜서(3.3%)는 4대보험이 적용되지 않습니다.',
            style: TextStyle(color: Colors.orange, fontSize: 16),
            ),
        ),
        )
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            title: const Text('국민연금 가입'),
            value: _hasNationalPension,
            onChanged: (value) => setState(() => _hasNationalPension = value ?? false),
          ),
          if (_hasNationalPension) ...[
            const Padding(
              padding: EdgeInsets.only(left: 16),
              child: Text('기준보수 (선택사항)'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pensionInsurableWageController,
              decoration: const InputDecoration(
                labelText: '기준보수',
                border: OutlineInputBorder(),
                suffixText: '원',
                hintText: '미입력 시 월급여 기준',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
          ],
          CheckboxListTile(
            title: const Text('건강보험 가입'),
            value: _hasHealthInsurance,
            onChanged: (value) => setState(() => _hasHealthInsurance = value ?? false),
          ),
          if (_hasHealthInsurance) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: DropdownButtonFormField<String>(
                value: _healthInsuranceBasis,
                decoration: const InputDecoration(
                  labelText: '건강보험 계산 기준',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'salary', child: Text('월급여 기준')),
                  DropdownMenuItem(value: 'insurable', child: Text('기준보수 기준')),
                ],
                onChanged: (value) => setState(() => _healthInsuranceBasis = value!),
              ),
            ),
            const SizedBox(height: 16),
          ],
          CheckboxListTile(
            title: const Text('고용보험 가입'),
            value: _hasEmploymentInsurance,
            onChanged: (value) => setState(() => _hasEmploymentInsurance = value ?? false),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            title: const Text('이메일 발송 사용'),
            value: _useEmail,
            onChanged: (value) => setState(() => _useEmail = value ?? false),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailToController,
            decoration: const InputDecoration(labelText: '받는사람 (To)', border: OutlineInputBorder()),
            enabled: _useEmail,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailCcController,
            decoration: const InputDecoration(labelText: '참조 (CC)', border: OutlineInputBorder()),
            enabled: _useEmail,
          ),
        ],
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final isFreelancer = _employmentType == 'freelance';

    final worker = WorkerModel(
      id: widget.worker?.id,
      clientId: widget.clientId,
      name: _nameController.text,
      birthDate: _birthDateController.text,
      phoneNumber: _phoneController.text,
      email: _emailController.text,
      employmentType: _employmentType,
      monthlySalary: int.tryParse(_monthlySalaryController.text) ?? 0,
      hourlyRate: int.tryParse(_hourlyRateController.text) ?? 0,
      hasNationalPension: isFreelancer ? false : _hasNationalPension,
      hasHealthInsurance: isFreelancer ? false : _hasHealthInsurance,
      hasEmploymentInsurance: isFreelancer ? false : _hasEmploymentInsurance,
      healthInsuranceBasis: _healthInsuranceBasis,
      pensionInsurableWage: _pensionInsurableWageController.text.isNotEmpty
          ? int.tryParse(_pensionInsurableWageController.text)
          : null,
      emailTo: _emailToController.text.isNotEmpty ? _emailToController.text : null,
      emailCc: _emailCcController.text.isNotEmpty ? _emailCcController.text : null,
      useEmail: _useEmail,
    );

    final monthlyData = MonthlyData(
      employeeId: worker.id ?? 0,
      ym: '',
      normalHours: double.tryParse(_normalHoursController.text) ?? 209,
      overtimeHours: double.tryParse(_overtimeHoursController.text) ?? 0,
      nightHours: double.tryParse(_nightHoursController.text) ?? 0,
      holidayHours: double.tryParse(_holidayHoursController.text) ?? 0,
      weeklyHours: double.tryParse(_weeklyHoursController.text) ?? 40,
      weekCount: int.tryParse(_weekCountController.text) ?? 4,
      bonus: int.tryParse(_bonusController.text) ?? 0,
      additionalPay1: int.tryParse(_additionalPay1Controller.text) ?? 0,
      additionalPay1Name: _additionalPay1NameController.text,
      additionalPay2: int.tryParse(_additionalPay2Controller.text) ?? 0,
      additionalPay2Name: _additionalPay2NameController.text,
      additionalPay3: int.tryParse(_additionalPay3Controller.text) ?? 0,
      additionalPay3Name: _additionalPay3NameController.text,
      additionalDeduct1: int.tryParse(_additionalDeduct1Controller.text) ?? 0,
      additionalDeduct1Name: _additionalDeduct1NameController.text,
      additionalDeduct2: int.tryParse(_additionalDeduct2Controller.text) ?? 0,
      additionalDeduct2Name: _additionalDeduct2NameController.text,
      additionalDeduct3: int.tryParse(_additionalDeduct3Controller.text) ?? 0,
      additionalDeduct3Name: _additionalDeduct3NameController.text,
    );

    widget.onSave(worker, monthlyData);
    Navigator.pop(context);
  }
}
