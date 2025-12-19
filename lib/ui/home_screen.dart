import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'main_screen.dart';
import 'employee_management_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const MainScreenContent(),
    const EmployeeManagementScreen(),
    const SettingsScreen(),
  ];

  final List<String> _titles = [
    'Durantax 급여관리 - 대시보드',
    'Durantax 급여관리 - 급여계산',
    'Durantax 급여관리 - 직원관리',
    'Durantax 급여관리 - 설정',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // 새로고침 로직
            },
            tooltip: '새로고침',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: '대시보드',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate),
            label: '급여계산',
          ),
          NavigationDestination(
            icon: Icon(Icons.people),
            label: '직원관리',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
