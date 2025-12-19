import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../core/models.dart';
import 'worker_dialog.dart';

class EmployeeManagementScreen extends StatelessWidget {
  const EmployeeManagementScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          body: Column(
            children: [
              // 거래처 선택
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Text(
                      '거래처 선택:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Autocomplete<ClientModel>(
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return provider.clients;
                          }
                          return provider.clients.where((client) {
                            final searchLower = textEditingValue.text.toLowerCase();
                            return client.name.toLowerCase().contains(searchLower) ||
                                client.bizId.toLowerCase().contains(searchLower);
                          });
                        },
                        displayStringForOption: (client) =>
                            '${client.name} (${client.bizId})',
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          // 선택된 거래처 표시
                          if (provider.selectedClient != null &&
                              controller.text.isEmpty) {
                            controller.text =
                                '${provider.selectedClient!.name} (${provider.selectedClient!.bizId})';
                          }
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              hintText: '거래처명 또는 사업자번호 검색',
                              border: OutlineInputBorder(),
                            ),
                          );
                        },
                        onSelected: (client) {
                          provider.selectClient(client);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddWorkerDialog(context, provider),
                      icon: const Icon(Icons.person_add),
                      label: const Text('직원 추가'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // 직원 목록
              Expanded(
                child: provider.selectedClient == null
                    ? const Center(
                        child: Text(
                          '거래처를 선택하세요',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : provider.currentWorkers.isEmpty
                        ? const Center(
                            child: Text(
                              '등록된 직원이 없습니다',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: provider.currentWorkers.length,
                            itemBuilder: (context, index) {
                              final worker = provider.currentWorkers[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: worker.employmentType == 'regular'
                                        ? Colors.blue
                                        : Colors.orange,
                                    child: Text(
                                      worker.name.isNotEmpty ? worker.name[0] : '?',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(
                                    worker.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('생년월일: ${worker.birthDate}'),
                                      Text(
                                        '구분: ${worker.employmentType == 'regular' ? '근로소득' : '사업소득'}',
                                      ),
                                      Text(
                                        worker.salaryType == 'monthly'
                                            ? '월급: ${_formatNumber(worker.monthlySalary)}원'
                                            : '시급: ${_formatNumber(worker.hourlyRate)}원',
                                      ),
                                      if (worker.emailTo != null && worker.emailTo!.isNotEmpty)
                                        Text('이메일: ${worker.emailTo}'),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _showEditWorkerDialog(
                                          context,
                                          provider,
                                          worker,
                                        ),
                                        tooltip: '수정',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _showDeleteConfirmDialog(
                                          context,
                                          provider,
                                          worker,
                                        ),
                                        tooltip: '삭제 (퇴사)',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  void _showAddWorkerDialog(BuildContext context, AppProvider provider) async {
    if (provider.selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('거래처를 먼저 선택하세요')),
      );
      return;
    }

    final result = await showDialog<WorkerModel>(
      context: context,
      builder: (context) => WorkerDialog(
        clientId: provider.selectedClient!.id,
      ),
    );

    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.name} 직원이 추가되었습니다')),
      );
    }
  }

  void _showEditWorkerDialog(
    BuildContext context,
    AppProvider provider,
    WorkerModel worker,
  ) async {
    final monthlyData = provider.getMonthlyDataForWorker(worker.id!);

    final result = await showDialog<WorkerModel>(
      context: context,
      builder: (context) => WorkerDialog(
        clientId: provider.selectedClient!.id,
        worker: worker,
        monthlyData: monthlyData,
      ),
    );

    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.name} 정보가 수정되었습니다')),
      );
    }
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    AppProvider provider,
    WorkerModel worker,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('직원 삭제 (퇴사)'),
        content: Text(
          '${worker.name} 직원을 삭제하시겠습니까?\n\n'
          '삭제 후에는:\n'
          '- Excel 업로드 시 해당 직원 데이터가 무시됩니다\n'
          '- 기존 급여 데이터는 보존됩니다',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await provider.deleteWorker(worker.id!);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${worker.name} 직원이 삭제되었습니다')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('삭제 실패: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}
