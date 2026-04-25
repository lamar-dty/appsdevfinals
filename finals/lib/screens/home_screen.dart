import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../widgets/stat_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final appBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
    final bottomNavHeight = kBottomNavigationBarHeight;

    // Height available for the white panel = full screen minus navy top section
    final navyTopHeight = 320.0; // approx height of header + cards + indicator
    final whitePanelMin = screenHeight - appBarHeight - bottomNavHeight - navyTopHeight;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── HEADER ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
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
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        // ── STAT CARDS ────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: const [
                    StatCard(
                      icon: Icons.check_circle_outline_rounded,
                      iconBgColor: Color(0xFFFFECEC),
                      iconColor: Color(0xFFE87070),
                      value: '0%',
                      label: 'Completed Tasks',
                    ),
                    StatCard(
                      icon: Icons.attach_money_rounded,
                      iconBgColor: Color(0xFFE6F9F5),
                      iconColor: Color(0xFF3BBFA3),
                      value: '₱0.00',
                      label: 'Wallet Balance',
                    ),
                  ],
                ),
                Row(
                  children: const [
                    StatCard(
                      icon: Icons.group_rounded,
                      iconBgColor: Color(0xFFEEEEFF),
                      iconColor: Color(0xFF7070D8),
                      value: '0',
                      label: 'Active Spaces',
                    ),
                    StatCard(
                      icon: Icons.trending_up_rounded,
                      iconBgColor: Color(0xFFF0EEFF),
                      iconColor: Color(0xFF9B88E8),
                      value: '0%',
                      label: 'Savings Increase',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── PAGE INDICATOR ────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kWhite.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),

        // ── NOTIFICATIONS PANEL ───────────────────────────
        // SliverFillRemaining ensures the white panel always
        // fills the rest of the screen — no stretching, no gaps.
        SliverFillRemaining(
          hasScrollBody: false,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ────────────────────────────
                Row(
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
                      onTap: () {
                        // TODO: sort options
                      },
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

                // ── Empty State ───────────────────────────
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}