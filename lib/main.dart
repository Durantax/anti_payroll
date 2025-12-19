import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'ui/home_screen.dart';

void main() {
  runApp(const PayrollApp());
}

class PayrollApp extends StatelessWidget {
  const PayrollApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: 'Durantax 급여관리 시스템',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 1,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
