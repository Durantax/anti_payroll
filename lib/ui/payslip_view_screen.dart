import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models.dart';

class PayslipViewScreen extends StatefulWidget {
  final WorkerModel worker;
  final SalaryResult salaryResult;
  final MonthlyData? monthlyData;
  final int year;
  final int month;
  final String clientName;
  final String bizId;
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
    this.requireBirthdateAuth = false,
  }) : super(key: key);

  @override
  State<PayslipViewScreen> createState() => _PayslipViewScreenState();
}

class _PayslipViewScreenState extends State<PayslipViewScreen> {
  bool _isAuthenticated = false;
  bool _isHtmlView = false;

  @override
  void initState() {
    super.initState();
    _isAuthenticated = !widget.requireBirthdateAuth;
    
    if (widget.requireBirthdateAuth) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBirthdateAuthDialog();
      });
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
                    _AmountRow('기본급', widget.salaryResult.baseSalary, widget.salaryResult.baseSalaryFormula),
                    if (widget.salaryResult.overtimePay > 0)
                      _AmountRow('연장수당', widget.salaryResult.overtimePay, widget.salaryResult.overtimeFormula),
                    if (widget.salaryResult.nightPay > 0)
                      _AmountRow('야간수당', widget.salaryResult.nightPay, widget.salaryResult.nightFormula),
                    if (widget.salaryResult.holidayPay > 0)
                      _AmountRow('휴일수당', widget.salaryResult.holidayPay, widget.salaryResult.holidayFormula),
                    if (widget.salaryResult.weeklyHolidayPay > 0)
                      _AmountRow('주휴수당', widget.salaryResult.weeklyHolidayPay, widget.salaryResult.weeklyHolidayFormula),
                    if (widget.salaryResult.bonus > 0)
                      _AmountRow('상여금', widget.salaryResult.bonus, ''),
                  ],
                  widget.salaryResult.totalPayment,
                  Colors.blue,
                ),
                const SizedBox(height: 24),

                // 공제 항목
                _buildAmountSection(
                  context,
                  '공제 항목',
                  [
                    if (widget.salaryResult.nationalPension > 0)
                      _AmountRow('국민연금', widget.salaryResult.nationalPension, widget.salaryResult.pensionFormula),
                    if (widget.salaryResult.healthInsurance > 0)
                      _AmountRow('건강보험', widget.salaryResult.healthInsurance, widget.salaryResult.healthFormula),
                    if (widget.salaryResult.longTermCare > 0)
                      _AmountRow('장기요양', widget.salaryResult.longTermCare, widget.salaryResult.longTermCareFormula),
                    if (widget.salaryResult.employmentInsurance > 0)
                      _AmountRow('고용보험', widget.salaryResult.employmentInsurance, widget.salaryResult.employmentFormula),
                    if (widget.salaryResult.incomeTax > 0)
                      _AmountRow('소득세', widget.salaryResult.incomeTax, widget.salaryResult.incomeTaxFormula),
                    if (widget.salaryResult.localIncomeTax > 0)
                      _AmountRow('지방소득세', widget.salaryResult.localIncomeTax, widget.salaryResult.localTaxFormula),
                  ],
                  widget.salaryResult.totalDeduction,
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
                        '${_formatNumber(widget.salaryResult.netPayment)}원',
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
                          Text(
                            '${_formatNumber(row.amount)}원',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      if (row.formula.isNotEmpty)
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
