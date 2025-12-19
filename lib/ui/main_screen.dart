import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../core/models.dart';
import '../providers/app_provider.dart';
import 'worker_dialog.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().syncClients();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏢 Durantax 급여관리 시스템'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_sync),
            onPressed: _syncClients,
            tooltip: '서버 동기화',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => showDialog(context: context, builder: (_) => const SettingsScreen()),
            tooltip: '설정',
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(provider.errorMessage!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: provider.clearError,
                    child: const Text('확인'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              _buildTopBar(provider),
              const Divider(height: 1),
              _buildExcelBar(provider),
              const Divider(height: 1),
              Expanded(child: _buildWorkerTable(provider)),
              const Divider(height: 1),
              _buildSummaryBar(provider),
              const Divider(height: 1),
              _buildSendStatusBar(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBar(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<ClientModel>(
              value: provider.selectedClient,
              decoration: const InputDecoration(
                labelText: '거래처',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: provider.clients.map((client) {
                return DropdownMenuItem(value: client, child: Text(client.name));
              }).toList(),
              onChanged: (client) => provider.selectClient(client),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 120,
            child: DropdownButtonFormField<int>(
              value: provider.selectedYear,
              decoration: const InputDecoration(
                labelText: '연도',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: List.generate(5, (index) {
                final year = DateTime.now().year - 2 + index;
                return DropdownMenuItem(value: year, child: Text('$year년'));
              }),
              onChanged: (year) {
                if (year != null) {
                  provider.selectDate(DateTime(year, provider.selectedMonth));
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 100,
            child: DropdownButtonFormField<int>(
              value: provider.selectedMonth,
              decoration: const InputDecoration(
                labelText: '월',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: List.generate(12, (index) {
                return DropdownMenuItem(value: index + 1, child: Text('${index + 1}월'));
              }),
              onChanged: (month) {
                if (month != null) {
                  provider.selectDate(DateTime(provider.selectedYear, month));
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          if (provider.selectedClient != null)
            ElevatedButton.icon(
              onPressed: () => _showClientSettings(provider.selectedClient!),
              icon: const Icon(Icons.business_center),
              label: const Text('거래처 설정'),
            ),
        ],
      ),
    );
  }

  Widget _buildExcelBar(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          const Text('📂 Excel 관리', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: provider.selectedClient == null ? null : () => provider.exportExcelTemplate(),
            icon: const Icon(Icons.download),
            label: const Text('템플릿 다운로드'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: provider.selectedClient == null ? null : _importExcel,
            icon: const Icon(Icons.upload_file),
            label: const Text('Excel 업로드'),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerTable(AppProvider provider) {
    if (provider.selectedClient == null) {
      return const Center(child: Text('거래처를 선택하세요', style: TextStyle(fontSize: 18)));
    }

    final workers = provider.currentWorkers;

    if (workers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('등록된 직원이 없습니다', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showWorkerDialog(null),
              icon: const Icon(Icons.add),
              label: const Text('직원 추가'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('이름')),
            DataColumn(label: Text('생년월일')),
            DataColumn(label: Text('구분')),
            DataColumn(label: Text('월급여')),
            DataColumn(label: Text('시급')),
            DataColumn(label: Text('지급총액')),
            DataColumn(label: Text('공제총액')),
            DataColumn(label: Text('실수령액')),
            DataColumn(label: Text('관리')),
          ],
          rows: workers.map((worker) {
            final result = provider.getSalaryResult(worker.id!);

            return DataRow(cells: [
              DataCell(Text(worker.name)),
              DataCell(Text(worker.birthDate)),
              DataCell(Text(worker.employmentType == 'regular' ? '근로소득' : '사업소득')),
              DataCell(Text('${formatMoney(worker.monthlySalary)}원')),
              DataCell(Text('${formatMoney(worker.hourlyRate)}원')),
              DataCell(Text(result != null ? '${formatMoney(result.totalPayment)}원' : '-')),
              DataCell(Text(result != null ? '${formatMoney(result.totalDeduction)}원' : '-')),
              DataCell(Text(result != null ? '${formatMoney(result.netPayment)}원' : '-')),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showWorkerDialog(worker),
                      tooltip: '수정',
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, size: 20),
                      onPressed: result != null ? () => _generatePdf(worker.id!) : null,
                      tooltip: 'PDF 생성',
                    ),
                    IconButton(
                      icon: const Icon(Icons.email, size: 20),
                      onPressed: result != null && worker.useEmail ? () => _sendEmail(worker.id!) : null,
                      tooltip: '이메일 발송',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                      onPressed: () => _deleteWorker(worker),
                      tooltip: '삭제',
                    ),
                  ],
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSummaryBar(AppProvider provider) {
    if (provider.selectedClient == null || provider.salaryResults.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📊 급여 계산 결과', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('지급총액: ${formatMoney(provider.totalPayment)}원', style: const TextStyle(fontSize: 14)),
              ),
              Expanded(
                child: Text('공제총액: ${formatMoney(provider.totalDeduction)}원', style: const TextStyle(fontSize: 14)),
              ),
              Expanded(
                child: Text('실수령액: ${formatMoney(provider.totalNetPayment)}원',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => provider.exportCsv(),
                icon: const Icon(Icons.table_chart),
                label: const Text('급여대장 내보내기'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => provider.generateAllPdfs(),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('PDF 일괄생성'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: provider.smtpConfig != null ? () => provider.sendAllEmails() : null,
                icon: const Icon(Icons.email),
                label: const Text('일괄발송'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSendStatusBar(AppProvider provider) {
    if (provider.selectedClient == null) return const SizedBox.shrink();

    final status = provider.sendStatus;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.green.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📧 발송 현황 (실시간)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => provider.loadSendStatus(),
                tooltip: '새로고침',
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (status != null) ...[
            LinearProgressIndicator(
              value: status.totalTargets > 0 ? status.sentTargets / status.totalTargets : 0,
              minHeight: 20,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(status.isDone ? Colors.green : Colors.blue),
            ),
            const SizedBox(height: 8),
            Text('${status.sentTargets} / ${status.totalTargets} (${_getPercentage(status)}%)'),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('✅ 발송완료: ${status.sentTargets}명'),
                const SizedBox(width: 16),
                Text('⏳ 대기중: ${status.totalTargets - status.sentTargets}명'),
                const Spacer(),
                if (!status.isDone) ...[
                  ElevatedButton.icon(
                    onPressed: () => provider.sendAllEmails(),
                    icon: const Icon(Icons.send),
                    label: const Text('선택 발송'),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton.icon(
                  onPressed: () => provider.retryFailedEmails(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('실패건 재발송'),
                ),
              ],
            ),
          ] else ...[
            const Text('발송 현황을 불러오는 중...'),
          ],
        ],
      ),
    );
  }

  String _getPercentage(ClientSendStatus status) {
    if (status.totalTargets == 0) return '0';
    return ((status.sentTargets / status.totalTargets) * 100).toStringAsFixed(0);
  }

  // ========== 액션 메서드 ==========

  Future<void> _syncClients() async {
    await context.read<AppProvider>().syncClients();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('거래처 목록이 동기화되었습니다')),
      );
    }
  }

  void _showClientSettings(ClientModel client) {
    showDialog(
      context: context,
      builder: (_) => ClientSettingsDialog(client: client),
    );
  }

  void _showWorkerDialog(WorkerModel? worker) {
    final provider = context.read<AppProvider>();
    final clientId = provider.selectedClient?.id;

    if (clientId == null) return;

    final monthlyData = worker?.id != null ? provider.getMonthlyData(worker!.id!) : null;

    showDialog(
      context: context,
      builder: (_) => WorkerDialog(
        clientId: clientId,
        worker: worker,
        monthlyData: monthlyData,
        onSave: (newWorker, monthly) async {
          try {
            await provider.saveWorker(newWorker);

            // 월별 데이터 저장
            if (newWorker.id != null) {
              provider.updateMonthlyData(newWorker.id!, monthly.copyWith(employeeId: newWorker.id!));
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${newWorker.name} 저장 완료')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('저장 실패: $e')),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _importExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result == null || result.files.single.path == null) return;

    try {
      await context.read<AppProvider>().importFromExcel(result.files.single.path!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel 데이터를 가져왔습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel 가져오기 실패: $e')),
        );
      }
    }
  }

  Future<void> _generatePdf(int workerId) async {
    try {
      await context.read<AppProvider>().generatePdf(workerId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF가 생성되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF 생성 실패: $e')),
        );
      }
    }
  }

  Future<void> _sendEmail(int workerId) async {
    try {
      await context.read<AppProvider>().sendEmail(workerId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이메일이 발송되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이메일 발송 실패: $e')),
        );
      }
    }
  }

  Future<void> _deleteWorker(WorkerModel worker) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('직원 삭제'),
        content: Text('${worker.name} 직원을 삭제하시겠습니까?'),
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

    if (confirm != true) return;

    try {
      await context.read<AppProvider>().deleteWorker(worker.clientId, worker.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${worker.name} 삭제 완료')),
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

extension on MonthlyData {
  MonthlyData copyWith({int? employeeId}) {
    return MonthlyData(
      employeeId: employeeId ?? this.employeeId,
      ym: ym,
      normalHours: normalHours,
      overtimeHours: overtimeHours,
      nightHours: nightHours,
      holidayHours: holidayHours,
      weeklyHours: weeklyHours,
      weekCount: weekCount,
      bonus: bonus,
      additionalPay1: additionalPay1,
      additionalPay1Name: additionalPay1Name,
      additionalPay2: additionalPay2,
      additionalPay2Name: additionalPay2Name,
      additionalPay3: additionalPay3,
      additionalPay3Name: additionalPay3Name,
      additionalDeduct1: additionalDeduct1,
      additionalDeduct1Name: additionalDeduct1Name,
      additionalDeduct2: additionalDeduct2,
      additionalDeduct2Name: additionalDeduct2Name,
      additionalDeduct3: additionalDeduct3,
      additionalDeduct3Name: additionalDeduct3Name,
    );
  }
}
