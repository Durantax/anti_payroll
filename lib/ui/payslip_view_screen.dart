import 'package:flutter/material.dart';
import '../core/models.dart';

class PayslipViewScreen extends StatelessWidget {
  final WorkerModel worker;
  final SalaryResult salaryResult;
  final MonthlyData? monthlyData;
  final int year;
  final int month;
  final String clientName;
  final String bizId;

  const PayslipViewScreen({
    Key? key,
    required this.worker,
    required this.salaryResult,
    this.monthlyData,
    required this.year,
    required this.month,
    required this.clientName,
    required this.bizId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${worker.name} 급여명세서'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              // PDF 생성 로직 호출
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF 생성 기능은 기존 버튼을 사용하세요')),
              );
            },
            tooltip: 'PDF 생성',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목
                Center(
                  child: Text(
                    '급여명세서',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(height: 24),

                // 회사 및 기간 정보
                _buildInfoSection(
                  context,
                  '회사 정보',
                  [
                    _InfoRow('회사명', clientName),
                    _InfoRow('사업자등록번호', bizId),
                    _InfoRow('지급 연월', '$year년 $month월'),
                  ],
                ),
                const SizedBox(height: 24),

                // 직원 정보
                _buildInfoSection(
                  context,
                  '직원 정보',
                  [
                    _InfoRow('성명', worker.name),
                    _InfoRow('생년월일', worker.birthDate),
                    _InfoRow(
                      '구분',
                      worker.employmentType == 'regular' ? '근로소득' : '사업소득',
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
                    _AmountRow('기본급', salaryResult.baseSalary),
                    if (salaryResult.overtimePay > 0)
                      _AmountRow('연장수당', salaryResult.overtimePay),
                    if (salaryResult.nightPay > 0)
                      _AmountRow('야간수당', salaryResult.nightPay),
                    if (salaryResult.holidayPay > 0)
                      _AmountRow('휴일수당', salaryResult.holidayPay),
                    if (salaryResult.weeklyHolidayPay > 0)
                      _AmountRow('주휴수당', salaryResult.weeklyHolidayPay),
                    if (salaryResult.bonus > 0)
                      _AmountRow('상여금', salaryResult.bonus),
                  ],
                  salaryResult.totalPayment,
                  Colors.blue,
                ),
                const SizedBox(height: 24),

                // 공제 항목
                _buildAmountSection(
                  context,
                  '공제 항목',
                  [
                    if (salaryResult.nationalPension > 0)
                      _AmountRow('국민연금', salaryResult.nationalPension),
                    if (salaryResult.healthInsurance > 0)
                      _AmountRow('건강보험', salaryResult.healthInsurance),
                    if (salaryResult.longTermCare > 0)
                      _AmountRow('장기요양', salaryResult.longTermCare),
                    if (salaryResult.employmentInsurance > 0)
                      _AmountRow('고용보험', salaryResult.employmentInsurance),
                    if (salaryResult.incomeTax > 0)
                      _AmountRow('소득세', salaryResult.incomeTax),
                    if (salaryResult.localIncomeTax > 0)
                      _AmountRow('지방소득세', salaryResult.localIncomeTax),
                  ],
                  salaryResult.totalDeduction,
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
                    border: Border.all(color: Colors.green, width: 2),
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
                        '${_formatNumber(salaryResult.netPayment)}원',
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
                if (worker.employmentType == 'regular')
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(row.label),
                      Text(
                        '${_formatNumber(row.amount)}원',
                        style: const TextStyle(fontWeight: FontWeight.w500),
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
    if (monthlyData == null) return const SizedBox.shrink();
    
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
              _InfoRow('정상 근로시간', '${monthlyData!.normalHours}시간'),
              if (monthlyData!.overtimeHours > 0)
                _InfoRow('연장 근로시간', '${monthlyData!.overtimeHours}시간'),
              if (monthlyData!.nightHours > 0)
                _InfoRow('야간 근로시간', '${monthlyData!.nightHours}시간'),
              if (monthlyData!.holidayHours > 0)
                _InfoRow('휴일 근로시간', '${monthlyData!.holidayHours}시간'),
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

  _AmountRow(this.label, this.amount);
}
