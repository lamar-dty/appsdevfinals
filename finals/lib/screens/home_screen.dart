import 'package:flutter/material.dart';
import '../constants/colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double _snapPeek = 0.20;
  static const double _snapHalf = 0.50;
  static const double _snapFull = 1.0;

  late DraggableScrollableController _sheetController;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── BACKGROUND — header + stat cards ─────────────────
        Positioned.fill(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── HEADER ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Welcome back, User!',
                        style: TextStyle(
                          color: kWhite,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Here's your overview for today",
                        style: TextStyle(color: kSubtitle, fontSize: 14),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── STAT CARDS ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        children: const [
                          _HomeStatCard(
                            icon: Icons.check_circle_outline_rounded,
                            iconColor: Color(0xFFE87070),
                            title: 'Completed Tasks',
                            value: '0%',
                            subtitle: 'No tasks yet',
                          ),
                          SizedBox(width: 10),
                          _HomeStatCard(
                            icon: Icons.account_balance_wallet_rounded,
                            iconColor: Color(0xFF3BBFA3),
                            title: 'Wallet Balance',
                            value: '₱0.00',
                            subtitle: 'Current balance',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: const [
                          _HomeStatCard(
                            icon: Icons.group_rounded,
                            iconColor: Color(0xFF7070D8),
                            title: 'Active Spaces',
                            value: '0',
                            subtitle: 'No spaces yet',
                          ),
                          SizedBox(width: 10),
                          _HomeStatCard(
                            icon: Icons.trending_up_rounded,
                            iconColor: Color(0xFF9B88E8),
                            title: 'Savings Increase',
                            value: '0%',
                            subtitle: 'vs last month',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── DRAGGABLE NOTIFICATION SHEET ─────────────────────
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: _snapPeek,
          minChildSize: _snapPeek,
          maxChildSize: _snapFull,
          snap: true,
          snapSizes: const [_snapPeek, _snapHalf, _snapFull],
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const ClampingScrollPhysics(),
                child: const _NotificationSheet(),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Wallet-style stat card ────────────────────────────────────
class _HomeStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;

  const _HomeStatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kNavyMid,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kWhite.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + title row
            Row(
              children: [
                Icon(icon, color: iconColor, size: 14),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: kWhite.withOpacity(0.65),
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Value
            Text(
              value,
              style: const TextStyle(
                color: kWhite,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            // Subtitle
            Text(
              subtitle,
              style: TextStyle(
                color: kWhite.withOpacity(0.45),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Notification sheet ────────────────────────────────────────
class _NotificationSheet extends StatelessWidget {
  const _NotificationSheet();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Notifications',
                style: TextStyle(
                  color: kNavyDark,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Row(
                  children: const [
                    Text(
                      'Sorted by',
                      style: TextStyle(
                          color: Color(0xFF6B7A99), fontSize: 13),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down,
                        color: Color(0xFF6B7A99), size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),

        // Empty state
        Center(
          child: Column(
            children: [
              Icon(
                Icons.notifications_none_rounded,
                size: 72,
                color: kNavyDark.withOpacity(0.12),
              ),
              const SizedBox(height: 14),
              Text(
                'No notifications yet',
                style: TextStyle(
                  color: kNavyDark.withOpacity(0.4),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "You're all caught up!",
                style: TextStyle(
                  color: kNavyDark.withOpacity(0.28),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }
}