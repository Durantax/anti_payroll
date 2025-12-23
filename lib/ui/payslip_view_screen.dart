import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/models.dart';
import '../providers/app_provider.dart';

class PayslipViewScreen extends StatefulWidget {
  final WorkerModel worker;
  final SalaryResult salaryResult;
  final MonthlyData? monthlyData;
  final int year;
  final int month;
  final String clientName;
  final String bizId;
  final int clientId;
  final bool requireBirthdateAuth;

  const PayslipViewScreen({
    Key? key,
    required this.worker,
    required this.salaryResult,
    this.monthlyData,
    required this.year,
    required this.month,
    required this.clientName,
    required this.bizId,
    required this.clientId,
    this.requireBirthdateAuth = false,
  }) : super(key: key);

  @override
  State<PayslipViewScreen> createState() => _PayslipViewScreenState();
}

class _PayslipViewScreenState extends State<PayslipViewScreen> {
  bool _isAuthenticated = false;
  bool _isHtmlView = false;
  bool _isEditMode = false;
  
  // 편집 가능한 값들
  late int _editBaseSalary;
  late int _editOvertimePay;
  late int _editNightPay;
  late int _editHolidayPay;
  late int _editWeeklyHolidayPay;
  late int _editBonus;
  late int _editNationalPension;
  late int _editHealthInsurance;
  late int _editLongTermCare;
  late int _editEmploymentInsurance;
  late int _editIncomeTax;
  late int _editLocalIncomeTax;

  @override
  void initState() {
    super.initState();
    _isAuthenticated = !widget.requireBirthdateAuth;
    
    // 초기값 설정
    _initEditValues();
    
    if (widget.requireBirthdateAuth) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBirthdateAuthDialog();
      });
    }
  }

  void _initEditValues() {
    _editBaseSalary = widget.salaryResult.baseSalary;
    _editOvertimePay = widget.salaryResult.overtimePay;
    _editNightPay = widget.salaryResult.nightPay;
    _editHolidayPay = widget.salaryResult.holidayPay;
    _editWeeklyHolidayPay = widget.salaryResult.weeklyHolidayPay;
    _editBonus = widget.salaryResult.bonus;
    _editNationalPension = widget.salaryResult.nationalPension;
    _editHealthInsurance = widget.salaryResult.healthInsurance;
    _editLongTermCare = widget.salaryResult.longTermCare;
    _editEmploymentInsurance = widget.salaryResult.employmentInsurance;
    _editIncomeTax = widget.salaryResult.incomeTax;
    _editLocalIncomeTax = widget.salaryResult.localIncomeTax;
  }

  int get _editTotalPayment => _editBaseSalary + _editOvertimePay + _editNightPay + 
      _editHolidayPay + _editWeeklyHolidayPay + _editBonus;
  
  int get _editTotalDeduction => _editNationalPension + _editHealthInsurance + 
      _editLongTermCare + _editEmploymentInsurance + _editIncomeTax + _editLocalIncomeTax;
  
  int get _editNetPayment => _editTotalPayment - _editTotalDeduction;

  Future<void> _saveChanges() async {
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      
      // 명세서 수정 데이터 저장
      await provider.apiService.savePayrollResult(
        employeeId: widget.worker.id!,
        clientId: widget.clientId,
        year: widget.year,
        month: widget.month,
        salaryData: {
          'baseSalary': _editBaseSalary,
          'overtimePay': _editOvertimePay,
          'nightPay': _editNightPay,
          'holidayPay': _editHolidayPay,
          'weeklyHolidayPay': _editWeeklyHolidayPay,
          'bonus': _editBonus,
          'totalPayment': _editTotalPayment,
          'nationalPension': _editNationalPension,
          'healthInsurance': _editHealthInsurance,
          'longTermCare': _editLongTermCare,
          'employmentInsurance': _editEmploymentInsurance,
          'incomeTax': _editIncomeTax,
          'localIncomeTax': _editLocalIncomeTax,
          'totalDeduction': _editTotalDeduction,
          'netPayment': _editNetPayment,
        },
        calculatedBy: 'manual', // 수동 수정으로 표시
      );
      
      // 수정된 데이터로 widget.salaryResult를 업데이트
      // (읽기 전용이므로 실제로는 화면을 다시 로드해야 함)
      
      setState(() {
        _isEditMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('명세서가 수정되었습니다'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // 데이터 다시 로드
        await provider.loadWorkers(provider.selectedClient!.id!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showBirthdateAuthDialog() async {
    final birthdateController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('본인 인증'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('급여명세서를 확인하려면 생년월일을 입력하세요.'),
            const SizedBox(height: 16),
            TextFormField(
              controller: birthdateController,
              decoration: const InputDecoration(
                labelText: '생년월일 (YYMMDD)',
                border: OutlineInputBorder(),
                hintText: '901231',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final input = birthdateController.text;
              if (input == widget.worker.birthDate) {
                Navigator.of(context).pop(true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('생년월일이 일치하지 않습니다'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _isAuthenticated = true;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('급여명세서')),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.worker.name} 급여명세서'),
        actions: [
          // PDF/HTML 토글 버튼
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                label: Text('PDF 형식'),
                icon: Icon(Icons.picture_as_pdf, size: 18),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('HTML 형식'),
                icon: Icon(Icons.web, size: 18),
              ),
            ],
            selected: {_isHtmlView},
            onSelectionChanged: (Set<bool> newSelection) {
              setState(() {
                _isHtmlView = newSelection.first;
              });
            },
          ),
          const SizedBox(width: 16),
          // 편집 버튼
          IconButton(
            icon: Icon(_isEditMode ? Icons.check : Icons.edit),
            onPressed: () {
              if (_isEditMode) {
                // 저장 로직
                _saveChanges();
              } else {
                setState(() {
                  _isEditMode = true;
                });
              }
            },
            tooltip: _isEditMode ? '저장' : '수정',
          ),
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isEditMode = false;
                  _initEditValues(); // 원래 값으로 되돌리기
                });
              },
              tooltip: '취소',
            ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isHtmlView 
                    ? 'HTML 명세서는 브라우저 인쇄 기능을 사용하세요' 
                    : 'PDF 생성 기능은 기존 버튼을 사용하세요'),
                ),
              );
            },
            tooltip: '인쇄',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            decoration: BoxDecoration(
              color: _isHtmlView ? Colors.white : Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: _isHtmlView 
                ? Border.all(color: Colors.blue.shade200, width: 2)
                : null,
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HTML 뷰 표시
                if (_isHtmlView)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.web, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'HTML 형식으로 표시 중 (웹 브라우저 호환)',
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // 제목
                Center(
                  child: Text(
                    '급여명세서',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _isHtmlView ? Colors.blue.shade900 : null,
                        ),
                  ),
                ),
                const SizedBox(height: 24),

                // 회사 및 기간 정보
                _buildInfoSection(
                  context,
                  '회사 정보',
                  [
                    _InfoRow('회사명', widget.clientName),
                    _InfoRow('사업자등록번호', widget.bizId),
                    _InfoRow('지급 연월', '${widget.year}년 ${widget.month}월'),
                  ],
                ),
                const SizedBox(height: 24),

                // 직원 정보
                _buildInfoSection(
                  context,
                  '직원 정보',
                  [
                    _InfoRow('성명', widget.worker.name),
                    _InfoRow('생년월일', widget.worker.birthDate),
                    _InfoRow(
                      '구분',
                      widget.worker.employmentType == 'regular' ? '근로소득' : '사업소득',
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                const Divider(thickness: 2),
                const SizedBox(height: 16),

                // 지급 항목
                _buildAmountSection(
                  context,
                  '지급 항목',
                  [
                    _EditableAmountRow('기본급', _isEditMode, _editBaseSalary, widget.salaryResult.baseSalaryFormula, (v) => setState(() => _editBaseSalary = v)),
                    if (!_isEditMode && widget.salaryResult.overtimePay > 0 || _isEditMode)
                      _EditableAmountRow('연장수당', _isEditMode, _editOvertimePay, widget.salaryResult.overtimeFormula, (v) => setState(() => _editOvertimePay = v)),
                    if (!_isEditMode && widget.salaryResult.nightPay > 0 || _isEditMode)
                      _EditableAmountRow('야간수당', _isEditMode, _editNightPay, widget.salaryResult.nightFormula, (v) => setState(() => _editNightPay = v)),
                    if (!_isEditMode && widget.salaryResult.holidayPay > 0 || _isEditMode)
                      _EditableAmountRow('휴일수당', _isEditMode, _editHolidayPay, widget.salaryResult.holidayFormula, (v) => setState(() => _editHolidayPay = v)),
                    if (!_isEditMode && widget.salaryResult.weeklyHolidayPay > 0 || _isEditMode)
                      _EditableAmountRow('주휴수당', _isEditMode, _editWeeklyHolidayPay, widget.salaryResult.weeklyHolidayFormula, (v) => setState(() => _editWeeklyHolidayPay = v)),
                    if (!_isEditMode && widget.salaryResult.bonus > 0 || _isEditMode)
                      _EditableAmountRow('상여금', _isEditMode, _editBonus, '', (v) => setState(() => _editBonus = v)),
                  ],
                  _isEditMode ? _editTotalPayment : widget.salaryResult.totalPayment,
                  Colors.blue,
                ),
                const SizedBox(height: 24),

                // 공제 항목
                _buildAmountSection(
                  context,
                  '공제 항목',
                  [
                    if (!_isEditMode && widget.salaryResult.nationalPension > 0 || _isEditMode)
                      _EditableAmountRow('국민연금', _isEditMode, _editNationalPension, widget.salaryResult.pensionFormula, (v) => setState(() => _editNationalPension = v)),
                    if (!_isEditMode && widget.salaryResult.healthInsurance > 0 || _isEditMode)
                      _EditableAmountRow('건강보험', _isEditMode, _editHealthInsurance, widget.salaryResult.healthFormula, (v) => setState(() => _editHealthInsurance = v)),
                    if (!_isEditMode && widget.salaryResult.longTermCare > 0 || _isEditMode)
                      _EditableAmountRow('장기요양', _isEditMode, _editLongTermCare, widget.salaryResult.longTermCareFormula, (v) => setState(() => _editLongTermCare = v)),
                    if (!_isEditMode && widget.salaryResult.employmentInsurance > 0 || _isEditMode)
                      _EditableAmountRow('고용보험', _isEditMode, _editEmploymentInsurance, widget.salaryResult.employmentFormula, (v) => setState(() => _editEmploymentInsurance = v)),
                    if (!_isEditMode && widget.salaryResult.incomeTax > 0 || _isEditMode)
                      _EditableAmountRow('소득세', _isEditMode, _editIncomeTax, widget.salaryResult.incomeTaxFormula, (v) => setState(() => _editIncomeTax = v)),
                    if (!_isEditMode && widget.salaryResult.localIncomeTax > 0 || _isEditMode)
                      _EditableAmountRow('지방소득세', _isEditMode, _editLocalIncomeTax, widget.salaryResult.localTaxFormula, (v) => setState(() => _editLocalIncomeTax = v)),
                  ],
                  _isEditMode ? _editTotalDeduction : widget.salaryResult.totalDeduction,
                  Colors.red,
                ),
                const SizedBox(height: 32),

                const Divider(thickness: 3),
                const SizedBox(height: 16),

                // 실수령액
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isHtmlView ? Colors.green.shade700 : Colors.green, 
                      width: _isHtmlView ? 3 : 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '실수령액',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                      ),
                      Text(
                        '${_formatNumber(_isEditMode ? _editNetPayment : widget.salaryResult.netPayment)}원',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 근무 정보
                if (widget.worker.employmentType == 'regular')
                  _buildWorkInfoSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context,
    String title,
    List<_InfoRow> rows,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
        ),
        const SizedBox(height: 12),
        ...rows.map((row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(
                      row.label,
                      style: const TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildAmountSection(
    BuildContext context,
    String title,
    List<_AmountRow> rows,
    int total,
    MaterialColor color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color.shade700,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              ...rows.asMap().entries.map((entry) {
                final isLast = entry.key == rows.length - 1;
                final row = entry.value;
                final isEditable = row is _EditableAmountRow;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(row.label),
                          if (isEditable && (row as _EditableAmountRow).isEditMode)
                            SizedBox(
                              width: 150,
                              child: TextFormField(
                                initialValue: row.amount.toString(),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.right,
                                decoration: InputDecoration(
                                  suffix: const Text('원'),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, 
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                onChanged: (value) {
                                  final amount = int.tryParse(value.replaceAll(',', '')) ?? 0;
                                  row.onChanged(amount);
                                },
                              ),
                            )
                          else
                            Text(
                              '${_formatNumber(row.amount)}원',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                        ],
                      ),
                      if (row.formula.isNotEmpty && !(isEditable && (row as _EditableAmountRow).isEditMode))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '계산: ${row.formula}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: color.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '합계',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color.shade900,
                      ),
                    ),
                    Text(
                      '${_formatNumber(total)}원',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: color.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkInfoSection(BuildContext context) {
    if (widget.monthlyData == null) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '근무 정보',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              _InfoRow('정상 근로시간', '${widget.monthlyData!.normalHours}시간'),
              if (widget.monthlyData!.overtimeHours > 0)
                _InfoRow('연장 근로시간', '${widget.monthlyData!.overtimeHours}시간'),
              if (widget.monthlyData!.nightHours > 0)
                _InfoRow('야간 근로시간', '${widget.monthlyData!.nightHours}시간'),
              if (widget.monthlyData!.holidayHours > 0)
                _InfoRow('휴일 근로시간', '${widget.monthlyData!.holidayHours}시간'),
            ].map((row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(
                      row.label,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

class _InfoRow {
  final String label;
  final String value;

  _InfoRow(this.label, this.value);
}

class _AmountRow {
  final String label;
  final int amount;
  final String formula;

  _AmountRow(this.label, this.amount, this.formula);
}

class _EditableAmountRow extends _AmountRow {
  final bool isEditMode;
  final ValueChanged<int> onChanged;
  
  _EditableAmountRow(
    String label, 
    this.isEditMode, 
    int amount, 
    String formula,
    this.onChanged,
  ) : super(label, amount, formula);
}
