import 'package:flutter/material.dart';
import 'constants/colors.dart';
import 'screens/home_screen.dart';
import 'widgets/dashboard_appbar.dart';
import 'widgets/dashboard_bottom_nav.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: kNavyDark,
        fontFamily: 'SF Pro Display',
      ),
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    Center(child: Text('Calendar', style: TextStyle(color: Colors.white))),
    Center(child: Text('Groups', style: TextStyle(color: Colors.white))),
    Center(child: Text('Wallet', style: TextStyle(color: Colors.white))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: kNavyDark,
      appBar: const DashboardAppBar(),
      body: _pages[_selectedIndex],
      bottomNavigationBar: MediaQuery(
        // This removes the system bottom padding that makes the bar look taller
        data: MediaQuery.of(context).copyWith(padding: EdgeInsets.zero),
        child: DashboardBottomNav(
          selectedIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
        ),
      ),
      floatingActionButton: const DashboardFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}