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
import 'store/task_store.dart';
import 'store/space_store.dart';
import 'store/space_chat_store.dart';
import 'store/auth_store.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load auth first so we know if there's an active session.
  await AuthStore.instance.load();

  // Register callbacks so AuthStore can reload/clear stores on login & logout
  // without creating a circular import.
  AuthStore.instance.registerStoreCallbacks(
    onLogin: () async {
      await TaskStore.instance.reload();
      await SpaceStore.instance.reload();
      await SpaceChatStore.instance.reload(
        SpaceStore.instance.spaces.map((s) => s.inviteCode).toList(),
      );
    },
    onLogout: () async {
      await TaskStore.instance.reload();
      await SpaceStore.instance.reload();
      await SpaceChatStore.instance.reload([]);
    },
  );

  // Load persisted data before showing any UI.
  await TaskStore.instance.load();
  await SpaceStore.instance.load();
  // Chat messages are keyed per space; load for all already-persisted spaces.
  await SpaceChatStore.instance.load(
    SpaceStore.instance.spaces.map((s) => s.inviteCode).toList(),
  );

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
  final GlobalKey<SpacesScreenState> _spacesKey = GlobalKey<SpacesScreenState>();

  // ── Persisted calendar time range ────────────────────────
  int _calStartHour = 6;
  int _calEndHour   = 22;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomeScreen(),
      CalendarScreen(
        calStartHour: _calStartHour,
        calEndHour: _calEndHour,
        onRangeChanged: (s, e) => setState(() {
          _calStartHour = s;
          _calEndHour   = e;
        }),
      ),
      SpacesScreen(key: _spacesKey),
      const WalletScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      backgroundColor: kNavyDark,
      appBar: DashboardAppBar(
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: MediaQuery(
        data: MediaQuery.of(context).copyWith(padding: EdgeInsets.zero),
        child: DashboardBottomNav(
          selectedIndex: _selectedIndex,
          onTap: (i) {
            setState(() => _selectedIndex = i);
            // Drain cross-user notifications every time the home tab is opened
            // so chat message notifications appear immediately.
            if (i == 0) TaskStore.instance.drainSharedInbox();
          },
        ),
      ),
      floatingActionButton: DashboardFAB(
        onNavigateToCalendar: () => setState(() => _selectedIndex = 1),
        onNavigateToSpaces: () => setState(() => _selectedIndex = 2),
        onSpaceSaved: (result) {
          _spacesKey.currentState?.addSpace(result);
          setState(() => _selectedIndex = 2);
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}