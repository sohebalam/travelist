import 'package:flutter/material.dart';
import 'package:travelist/services/styles.dart';

class BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final VoidCallback onLogoutTapped;

  BottomNavBar({
    required this.selectedIndex,
    required this.onItemTapped,
    required this.onLogoutTapped,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list),
          label: 'Lists',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat),
          label: 'Chat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.logout),
          label: 'Logout',
        ),
      ],
      currentIndex: selectedIndex,
      selectedItemColor: AppColors.primaryColor,
      unselectedItemColor: AppColors.tertiryColor,
      onTap: (index) {
        if (index == 3) {
          onLogoutTapped();
        } else {
          onItemTapped(index);
        }
      },
    );
  }
}
