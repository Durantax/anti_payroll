import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

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
  late TextEditingController _joinDateController;
  late TextEditingController _resignDateController;
  late TextEditingController _phoneController;

  // 세금 정보
  late TextEditingController _taxDependentsController;
  late TextEditingController _childrenCountController;
  late TextEditingController _taxFreeMealController;
  late TextEditingController _taxFreeCarMaintenanceController;
  late TextEditingController _otherTaxFreeController;
  late int _incomeTaxRate;

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
  late bool _additionalPay1IsTaxFree;
  late TextEditingController _additionalPay2Controller;
  late TextEditingController _additionalPay2NameController;
  late bool _additionalPay2IsTaxFree;
  late TextEditingController _additionalPay3Controller;
  late TextEditingController _additionalPay3NameController;
  late bool _additionalPay3IsTaxFree;

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
  
  // 두루누리 지원
  late bool _isDurunuri;

  // 이메일
  late TextEditingController _emailToController;
  late TextEditingController _emailCcController;
  late bool _useEmail;

  // 구분
  late String _employmentType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    final worker = widget.worker;
    final monthly = widget.monthlyData;

    // 기본정보
    _nameController = TextEditingController(text: worker?.name ?? '');
    _birthDateController = TextEditingController(text: worker?.birthDate ?? '');
    _joinDateController = TextEditingController(text: worker?.joinDate ?? '');
    _resignDateController = TextEditingController(text: worker?.resignDate ?? '');
    _phoneController = TextEditingController(text: worker?.phoneNumber ?? '');

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
    _additionalPay1IsTaxFree = monthly?.additionalPay1IsTaxFree ?? false;
    _additionalPay2Controller = TextEditingController(text: monthly?.additionalPay2.toString() ?? '0');
    _additionalPay2NameController = TextEditingController(text: monthly?.additionalPay2Name ?? '');
    _additionalPay2IsTaxFree = monthly?.additionalPay2IsTaxFree ?? false;
    _additionalPay3Controller = TextEditingController(text: monthly?.additionalPay3.toString() ?? '0');
    _additionalPay3NameController = TextEditingController(text: monthly?.additionalPay3Name ?? '');
    _additionalPay3IsTaxFree = monthly?.additionalPay3IsTaxFree ?? false;

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
    
    // 두루누리 지원
    _isDurunuri = monthly?.isDurunuri ?? false;

    // 이메일
    _emailToController = TextEditingController(text: worker?.emailTo ?? '');
    _emailCcController = TextEditingController(text: worker?.emailCc ?? '');
    _useEmail = worker?.useEmail ?? false;

    // 구분
    _employmentType = worker?.employmentType ?? 'labor';

    // 세금 정보
    _taxDependentsController = TextEditingController(text: worker?.taxDependents.toString() ?? '1');
    _childrenCountController = TextEditingController(text: worker?.childrenCount.toString() ?? '0');
    _taxFreeMealController = TextEditingController(text: worker?.taxFreeMeal.toString() ?? '0');
    _taxFreeCarMaintenanceController = TextEditingController(text: worker?.taxFreeCarMaintenance.toString() ?? '0');
    _otherTaxFreeController = TextEditingController(text: worker?.otherTaxFree.toString() ?? '0');
    _incomeTaxRate = worker?.incomeTaxRate ?? 100;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _birthDateController.dispose();
    _joinDateController.dispose();
    _resignDateController.dispose();
    _phoneController.dispose();
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
    _taxDependentsController.dispose();
    _childrenCountController.dispose();
    _taxFreeMealController.dispose();
    _taxFreeCarMaintenanceController.dispose();
    _otherTaxFreeController.dispose();
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
                isScrollable: true,
                tabs: const [
                  Tab(text: '기본정보'),
                  Tab(text: '급여'),
                  Tab(text: '4대보험'),
                  Tab(text: '세금'),
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
                    _buildTaxTab(isFreelancer),
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
              DropdownMenuItem(value: 'labor', child: Text('근로소듍')),
              DropdownMenuItem(value: 'business', child: Text('사업소듍(3.3%)')),
            ],
            onChanged: (value) {
              setState(() {
                _employmentType = value!;
                if (value == 'business') {
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
          // 사번 (읽기 전용, 서버에서 자동부여)
          if (widget.worker?.empNo != null)
            TextFormField(
              initialValue: widget.worker?.empNo ?? '',
              decoration: const InputDecoration(
                labelText: '사번 (자동부여)',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Color(0xFFF5F5F5),
              ),
              enabled: false, // 읽기 전용
              style: const TextStyle(color: Colors.black54),
            ),
          if (widget.worker?.empNo != null) const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: '전화번호', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _joinDateController,
            decoration: const InputDecoration(
              labelText: '입사일 (YYYY-MM-DD)',
              border: OutlineInputBorder(),
              hintText: '2024-01-15',
            ),
            keyboardType: TextInputType.datetime,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _resignDateController,
            decoration: const InputDecoration(
              labelText: '퇴사일 (YYYY-MM-DD)',
              border: OutlineInputBorder(),
              hintText: '미입력 시 재직중',
            ),
            keyboardType: TextInputType.datetime,
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
          // 전월 복사 버튼
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _copyFromPreviousMonth,
                  icon: const Icon(Icons.copy),
                  label: const Text('전월 급여 복사'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 두루누리 지원 체크박스
          if (!isFreelancer)
            Card(
              color: Colors.orange.shade50,
              child: CheckboxListTile(
                title: const Text('두루누리 지원 (국민연금·고용보험 80% 지원)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('당월만 적용됩니다. 해당 월에 두루누리 지원을 받는 경우 체크하세요.'),
                value: _isDurunuri,
                onChanged: (v) => setState(() => _isDurunuri = v ?? false),
              ),
            ),
          if (!isFreelancer) const SizedBox(height: 16),
          const Text('━━━ 기본 정보 ━━━', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          // 💡 급여형태 자동 판단 안내
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '💡 시급이 0원이면 자동으로 월급제로 계산됩니다',
                    style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _monthlySalaryController,
            decoration: const InputDecoration(
              labelText: '* 월급여',
              border: OutlineInputBorder(),
              suffixText: '원',
              helperText: '월급제 직원의 고정 월급',
              helperMaxLines: 2,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _hourlyRateController,
            decoration: const InputDecoration(
              labelText: '* 시급',
              border: OutlineInputBorder(),
              suffixText: '원',
              helperText: '시급제는 입력 / 월급제는 0원 입력 (자동 계산됨)',
              helperMaxLines: 2,
            ),
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
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: CheckboxListTile(
                  dense: true,
                  title: const Text('비과세', style: TextStyle(fontSize: 12)),
                  value: _additionalPay1IsTaxFree,
                  onChanged: (v) => setState(() => _additionalPay1IsTaxFree = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
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
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: CheckboxListTile(
                  dense: true,
                  title: const Text('비과세', style: TextStyle(fontSize: 12)),
                  value: _additionalPay2IsTaxFree,
                  onChanged: (v) => setState(() => _additionalPay2IsTaxFree = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
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
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: CheckboxListTile(
                  dense: true,
                  title: const Text('비과세', style: TextStyle(fontSize: 12)),
                  value: _additionalPay3IsTaxFree,
                  onChanged: (v) => setState(() => _additionalPay3IsTaxFree = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
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
      return Center(
        child: Card(
        color: Colors.orange[50],  // ✅
        child: const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
            '사업소듍(3.3%)은 4대보험이 적용되지 않습니다.',
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

  Widget _buildTaxTab(bool isFreelancer) {
    if (isFreelancer) {
      return Center(
        child: Card(
          color: Colors.orange[50],
          child: const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '사업소듍(3.3%)은 소듍세가 자동 계산됩니다.',
              style: TextStyle(color: Colors.orange, fontSize: 16),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('━━━ 간이세액표 공제 ━━━', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _taxDependentsController,
            decoration: const InputDecoration(
              labelText: '* 공제대상 가족수 (본인 포함)',
              border: OutlineInputBorder(),
              suffixText: '명',
              hintText: '본인만 있으면 1명',
              helperText: '배우자, 자녀, 부모님 등 부양가족 포함',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              final val = int.tryParse(v ?? '');
              if (val == null || val < 1) return '최소 1명 이상';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _childrenCountController,
            decoration: const InputDecoration(
              labelText: '8세~20세 자녀 수',
              border: OutlineInputBorder(),
              suffixText: '명',
              helperText: '자녀세액공제 대상 (8세 이상 20세 이하)',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _incomeTaxRate,
            decoration: const InputDecoration(
              labelText: '소득세율',
              border: OutlineInputBorder(),
              helperText: '기본 100%, 2자녀 이상 80%, 부양가족 많으면 120%',
            ),
            items: const [
              DropdownMenuItem(value: 80, child: Text('80% (세금 적게)')),
              DropdownMenuItem(value: 100, child: Text('100% (기본)')),
              DropdownMenuItem(value: 120, child: Text('120% (세금 많이)')),
            ],
            onChanged: (value) => setState(() => _incomeTaxRate = value!),
          ),
          const SizedBox(height: 24),
          const Text('━━━ 비과세 항목 ━━━', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            '비과세 항목은 4대보험과 소득세 계산에서 제외됩니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _taxFreeMealController,
            decoration: const InputDecoration(
              labelText: '비과세 식대',
              border: OutlineInputBorder(),
              suffixText: '원',
              helperText: '월 20만원까지 비과세 (식사 제공 시 월 10만원)',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _taxFreeCarMaintenanceController,
            decoration: const InputDecoration(
              labelText: '비과세 차량유지비',
              border: OutlineInputBorder(),
              suffixText: '원',
              helperText: '월 20만원까지 비과세 (본인 차량 업무 사용 시)',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _otherTaxFreeController,
            decoration: const InputDecoration(
              labelText: '기타 비과세',
              border: OutlineInputBorder(),
              suffixText: '원',
              helperText: '자가운전보조금, 출산/육아수당 등',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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

  Future<void> _copyFromPreviousMonth() async {
    if (widget.worker?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신규 직원은 전월 복사를 사용할 수 없습니다')),
      );
      return;
    }

    final provider = context.read<AppProvider>();
    final currentYm = provider.selectedYm;
    
    // 전월 계산 (예: 202501 -> 202412)
    final year = int.parse(currentYm.substring(0, 4));
    final month = int.parse(currentYm.substring(4, 6));
    final prevYear = month == 1 ? year - 1 : year;
    final prevMonth = month == 1 ? 12 : month - 1;
    final prevYm = '$prevYear${prevMonth.toString().padLeft(2, '0')}';

    try {
      // API 호출하여 전월 데이터 가져오기
      final prevData = await provider.apiService.getMonthlyData(
        employeeId: widget.worker!.id!,
        ym: prevYm,
      );

      if (prevData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$prevYear년 ${prevMonth}월 급여 데이터가 없습니다')),
          );
        }
        return;
      }

      // 전월 데이터를 현재 컨트롤러에 복사
      setState(() {
        _normalHoursController.text = prevData.normalHours.toString();
        _overtimeHoursController.text = prevData.overtimeHours.toString();
        _nightHoursController.text = prevData.nightHours.toString();
        _holidayHoursController.text = prevData.holidayHours.toString();
        _weeklyHoursController.text = prevData.weeklyHours.toString();
        _weekCountController.text = prevData.weekCount.toString();
        _bonusController.text = prevData.bonus.toString();
        
        // 추가 수당
        _additionalPay1Controller.text = prevData.additionalPay1.toString();
        _additionalPay1NameController.text = prevData.additionalPay1Name ?? '';
        _additionalPay1IsTaxFree = prevData.additionalPay1IsTaxFree;
        
        _additionalPay2Controller.text = prevData.additionalPay2.toString();
        _additionalPay2NameController.text = prevData.additionalPay2Name ?? '';
        _additionalPay2IsTaxFree = prevData.additionalPay2IsTaxFree;
        
        _additionalPay3Controller.text = prevData.additionalPay3.toString();
        _additionalPay3NameController.text = prevData.additionalPay3Name ?? '';
        _additionalPay3IsTaxFree = prevData.additionalPay3IsTaxFree;
        
        // 추가 공제
        _additionalDeduct1Controller.text = prevData.additionalDeduct1.toString();
        _additionalDeduct1NameController.text = prevData.additionalDeduct1Name ?? '';
        
        _additionalDeduct2Controller.text = prevData.additionalDeduct2.toString();
        _additionalDeduct2NameController.text = prevData.additionalDeduct2Name ?? '';
        
        _additionalDeduct3Controller.text = prevData.additionalDeduct3.toString();
        _additionalDeduct3NameController.text = prevData.additionalDeduct3Name ?? '';
        
        // 두루누리는 월별로 다를 수 있으므로 복사하지 않음 (또는 필요시 복사)
        // _isDurunuri = prevData.isDurunuri;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$prevYear년 ${prevMonth}월 급여를 복사했습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('전월 급여 복사 실패: $e')),
        );
      }
    }
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
      // 이메일은 이메일 탭에서만 입력 (서버 DB에는 emailTo만 있음)
      emailTo: _emailToController.text.isNotEmpty ? _emailToController.text : null,
      emailCc: _emailCcController.text.isNotEmpty ? _emailCcController.text : null,
      useEmail: _useEmail,
      // 세금 정보
      taxDependents: int.tryParse(_taxDependentsController.text) ?? 1,
      childrenCount: int.tryParse(_childrenCountController.text) ?? 0,
      taxFreeMeal: int.tryParse(_taxFreeMealController.text) ?? 0,
      taxFreeCarMaintenance: int.tryParse(_taxFreeCarMaintenanceController.text) ?? 0,
      otherTaxFree: int.tryParse(_otherTaxFreeController.text) ?? 0,
      incomeTaxRate: _incomeTaxRate,
      // 입사/퇴사일
      joinDate: _joinDateController.text.isNotEmpty ? _joinDateController.text : null,
      resignDate: _resignDateController.text.isNotEmpty ? _resignDateController.text : null,
    );

    final provider = context.read<AppProvider>();
    final currentYm = provider.selectedYm;

    final monthlyData = MonthlyData(
      employeeId: worker.id ?? 0,
      ym: currentYm,
      normalHours: double.tryParse(_normalHoursController.text) ?? 209,
      overtimeHours: double.tryParse(_overtimeHoursController.text) ?? 0,
      nightHours: double.tryParse(_nightHoursController.text) ?? 0,
      holidayHours: double.tryParse(_holidayHoursController.text) ?? 0,
      weeklyHours: double.tryParse(_weeklyHoursController.text) ?? 40,
      weekCount: int.tryParse(_weekCountController.text) ?? 4,
      bonus: int.tryParse(_bonusController.text) ?? 0,
      additionalPay1: int.tryParse(_additionalPay1Controller.text) ?? 0,
      additionalPay1Name: _additionalPay1NameController.text,
      additionalPay1IsTaxFree: _additionalPay1IsTaxFree,
      additionalPay2: int.tryParse(_additionalPay2Controller.text) ?? 0,
      additionalPay2Name: _additionalPay2NameController.text,
      additionalPay2IsTaxFree: _additionalPay2IsTaxFree,
      additionalPay3: int.tryParse(_additionalPay3Controller.text) ?? 0,
      additionalPay3Name: _additionalPay3NameController.text,
      additionalPay3IsTaxFree: _additionalPay3IsTaxFree,
      additionalDeduct1: int.tryParse(_additionalDeduct1Controller.text) ?? 0,
      additionalDeduct1Name: _additionalDeduct1NameController.text,
      additionalDeduct2: int.tryParse(_additionalDeduct2Controller.text) ?? 0,
      additionalDeduct2Name: _additionalDeduct2NameController.text,
      additionalDeduct3: int.tryParse(_additionalDeduct3Controller.text) ?? 0,
      additionalDeduct3Name: _additionalDeduct3NameController.text,
      isDurunuri: _isDurunuri,
    );

    widget.onSave(worker, monthlyData);
    Navigator.pop(context);
  }
}
