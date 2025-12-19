import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../core/models.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📊 급여관리 대시보드',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _buildTodaySendSection(provider),
              const SizedBox(height: 24),
              _buildUpcomingSendSection(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTodaySendSection(AppProvider provider) {
    final today = DateTime.now().day;
    final todayClients = provider.clients.where((client) {
      return client.slipSendDay == today || client.registerSendDay == today;
    }).toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.today, color: Colors.red, size: 28),
                const SizedBox(width: 8),
                Text(
                  '오늘 발송 예정 (${DateTime.now().month}월 ${DateTime.now().day}일)',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            if (todayClients.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    '오늘 발송 예정인 거래처가 없습니다',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              )
            else
              ...todayClients.map((client) => _buildClientCard(client, today)),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingSendSection(AppProvider provider) {
    final currentMonth = DateTime.now().month;
    final daysInMonth = DateTime(DateTime.now().year, currentMonth + 1, 0).day;
    
    // 날짜별로 그룹화
    final Map<int, List<ClientModel>> clientsByDay = {};
    for (var client in provider.clients) {
      if (client.slipSendDay != null && client.slipSendDay! > 0 && client.slipSendDay! <= daysInMonth) {
        clientsByDay.putIfAbsent(client.slipSendDay!, () => []).add(client);
      }
      if (client.registerSendDay != null && 
          client.registerSendDay! > 0 && 
          client.registerSendDay! <= daysInMonth &&
          client.registerSendDay != client.slipSendDay) {
        clientsByDay.putIfAbsent(client.registerSendDay!, () => []).add(client);
      }
    }

    final sortedDays = clientsByDay.keys.toList()..sort();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.blue, size: 28),
                const SizedBox(width: 8),
                Text(
                  '${currentMonth}월 발송 일정',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            if (sortedDays.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    '발송 일정이 설정된 거래처가 없습니다',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              )
            else
              ...sortedDays.map((day) => _buildDaySection(day, clientsByDay[day]!)),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySection(int day, List<ClientModel> clients) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${day}일',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${clients.length}개 거래처',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...clients.map((client) => _buildClientCard(client, day)),
        ],
      ),
    );
  }

  Widget _buildClientCard(ClientModel client, int day) {
    final isSlipDay = client.slipSendDay == day;
    final isRegisterDay = client.registerSendDay == day;
    
    List<String> sendTypes = [];
    if (isSlipDay) sendTypes.add('명세서');
    if (isRegisterDay) sendTypes.add('급여대장');

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(
            Icons.business,
            color: Colors.blue.shade400,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sendTypes.join(', ') + ' 발송',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Text(
              sendTypes.join('+'),
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
