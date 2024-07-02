import 'package:flutter/material.dart';
import 'package:travelist/services/styles.dart';

class BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  BottomNavBar({
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list),
          label: 'Lists',
        ),
      ],
      currentIndex: selectedIndex,
      selectedItemColor: AppColors.primaryColor,
      onTap: onItemTapped,
    );
  }
}
