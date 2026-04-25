import 'package:flutter/material.dart';
import '../constants/colors.dart';

class DashboardBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const DashboardBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: kTeal,
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      elevation: 0,
      padding: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      child: SizedBox(
        height: 36,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              index: 0,
              selectedIndex: selectedIndex,
              onTap: onTap,
            ),
            _NavItem(
              icon: Icons.calendar_month_rounded,
              index: 1,
              selectedIndex: selectedIndex,
              onTap: onTap,
            ),
            const SizedBox(width: 72),
            _NavItem(
              icon: Icons.group_rounded,
              index: 2,
              selectedIndex: selectedIndex,
              onTap: onTap,
            ),
            _NavItem(
              icon: Icons.account_balance_wallet_rounded,
              index: 3,
              selectedIndex: selectedIndex,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final int index;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.index,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool selected = index == selectedIndex;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        transform: Matrix4.translationValues(0, selected ? -14 : 0, 0),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: selected ? kWhite : Colors.transparent,
            shape: BoxShape.circle,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Icon(
            icon,
            size: 30,
            color: selected ? kTeal : kNavyDark.withOpacity(0.7),
          ),
        ),
      ),
    );
  }
}

class DashboardFAB extends StatelessWidget {
  const DashboardFAB({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kNavyDark,
        boxShadow: [
          BoxShadow(
            color: kNavyDark.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: const CircleBorder(
          side: BorderSide(color: kWhite, width: 3),
        ),
        child: const Icon(
          Icons.add_rounded,
          color: kWhite,
          size: 32,
        ),
      ),
    );
  }
}