import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:travelist/main_page.dart';
import 'package:travelist/pages/auth/login_page.dart';
import 'auth_bloc.dart';
import 'auth_state.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationBloc, AuthenticationState>(
      builder: (context, state) {
        if (state is AuthenticationInitial) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is Authenticated) {
          return const MainPage();
        } else if (state is Unauthenticated) {
          return LoginPage();
        } else {
          return const Center(child: Text('Unknown state'));
        }
      },
    );
  }
}
