import 'package:flutter/material.dart';
import 'constants/colors.dart';
import 'screens/home_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/spaces_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'widgets/app_drawer.dart';
import 'widgets/dashboard_appbar.dart';
import 'widgets/dashboard_bottom_nav.dart';

class ScrollBehaviorNoGlow extends ScrollBehavior {
  const ScrollBehaviorNoGlow();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nibble',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: kNavyDark,
        fontFamily: 'SF Pro Display',
        scrollbarTheme: const ScrollbarThemeData(),
      ),
      scrollBehavior: const ScrollBehaviorNoGlow(),
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/main': (_) => const MainScaffold(),
      },
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── Persisted calendar time range ────────────────────────
  int _calStartHour = 6;
  int _calEndHour   = 22;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(),
      CalendarScreen(
        calStartHour: _calStartHour,
        calEndHour: _calEndHour,
        onRangeChanged: (s, e) => setState(() {
          _calStartHour = s;
          _calEndHour   = e;
        }),
      ),
      const SpacesScreen(),
      const WalletScreen(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      backgroundColor: kNavyDark,
      appBar: DashboardAppBar(
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      drawer: const AppDrawer(),
      body: pages[_selectedIndex],
      bottomNavigationBar: MediaQuery(
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