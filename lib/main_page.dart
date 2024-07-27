import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:travelist/pages/chat/chat_list.dart';
import 'package:travelist/pages/home_page.dart';
import 'package:travelist/pages/lists.dart';
import 'package:travelist/pages/user/profile.dart';
import 'package:travelist/services/auth/auth_bloc.dart';
import 'package:travelist/services/auth/auth_event.dart';
import 'package:travelist/services/widgets/bottom_navbar.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  void _onLogoutTapped() {
    BlocProvider.of<AuthenticationBloc>(context).add(LoggedOut());
  }

  void navigateToPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        key: PageStorageKey<String>('MainPageView'),
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: [
          HomePage(key: PageStorageKey<String>('HomePage')),
          ListsPage(key: PageStorageKey<String>('ListsPage')),
          ChatList(key: PageStorageKey<String>('ChatList')),
          UserProfilePage(key: PageStorageKey<String>('UserProfilePage')),
          // Include ListDetailsPage here if you want to navigate back to it
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
        onLogoutTapped: _onLogoutTapped,
      ),
    );
  }
}
