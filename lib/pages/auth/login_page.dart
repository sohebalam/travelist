import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:travelist/pages/auth/reg_page.dart';
import 'package:travelist/services/auth/auth_bloc.dart';
import 'package:travelist/services/auth/auth_event.dart';
import 'package:travelist/services/auth/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';
import 'package:travelist/services/styles.dart';
import 'package:travelist/services/widgets/google.dart';

class LoginPage extends StatefulWidget {
  LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;

  void _login(BuildContext context) async {
    final authService = AuthService();
    final email = _emailController.text;
    final password = _passwordController.text;

    try {
      final user = await authService.signInWithEmail(email, password);
      if (user != null) {
        context.read<AuthenticationBloc>().add(LoggedIn());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Login failed. Please check your credentials.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred.')),
      );
    }
  }

  void _loginWithGoogle(BuildContext context) async {
    final authService = AuthService();

    try {
      final user = await authService.signInWithGoogle();
      if (user != null) {
        context.read<AuthenticationBloc>().add(LoggedIn());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Google sign-in failed. Please try again.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred.')),
      );
    }
  }

  void _resetPassword(BuildContext context) async {
    final authService = AuthService();
    final email = _emailController.text;

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter your email to reset password.')),
      );
      return;
    }

    try {
      await authService.resetPassword(email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset failed: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred.')),
      );
    }
  }

  void _register(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textScaleFactor = MediaQuery.maybeTextScalerOf(context)?.scale(1);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Semantics(
          label: 'Login Page',
          child: Container(
            child: Column(
              children: <Widget>[
                const SizedBox(
                  height: 120,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Semantics(
                    label: 'Travelist Logo',
                    child: Container(
                      height: 240,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/Logo.png'),
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    children: <Widget>[
                      FadeInUp(
                        duration: const Duration(milliseconds: 1800),
                        child: Semantics(
                          label: 'Login form',
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.primaryColor,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color.fromRGBO(143, 148, 251, .2),
                                  blurRadius: 20.0,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: <Widget>[
                                Semantics(
                                  label: 'Email input field',
                                  child: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: AppColors.primaryColor,
                                        ),
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _emailController,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: "Email",
                                        hintStyle: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize:
                                              14 * (textScaleFactor ?? 1.0),
                                        ),
                                      ),
                                      style: TextStyle(
                                        fontSize: 14 * (textScaleFactor ?? 1.0),
                                      ),
                                    ),
                                  ),
                                ),
                                Semantics(
                                  label: 'Password input field',
                                  child: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    child: TextField(
                                      controller: _passwordController,
                                      obscureText: _obscureText,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: "Password",
                                        hintStyle: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize:
                                              14 * (textScaleFactor ?? 1.0),
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureText
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: _obscureText
                                                ? AppColors.tertiryColor
                                                : AppColors.primaryColor,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscureText = !_obscureText;
                                            });
                                          },
                                        ),
                                      ),
                                      style: TextStyle(
                                        fontSize: 14 * (textScaleFactor ?? 1.0),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 30,
                      ),
                      FadeInUp(
                        duration: const Duration(milliseconds: 1900),
                        child: Semantics(
                          label: 'Login button',
                          button: true,
                          child: GestureDetector(
                            onTap: () => _login(context),
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primaryColor,
                                    AppColors.secondaryColor,
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  "Login",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16 * (textScaleFactor ?? 1.0),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 30,
                      ),
                      Semantics(
                        label: 'Login with Google button',
                        button: true,
                        child: CustomGoogleButton(
                          onPressed: () {
                            _loginWithGoogle(context);
                          },
                        ),
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      FadeInUp(
                        duration: const Duration(milliseconds: 2000),
                        child: Semantics(
                          label: 'Forgot Password button',
                          button: true,
                          child: TextButton(
                            onPressed: () => _resetPassword(context),
                            child: Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: AppColors.secondaryColor,
                                fontSize: 16 * (textScaleFactor ?? 1.0),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 0,
                      ),
                      FadeInUp(
                        duration: const Duration(milliseconds: 2000),
                        child: Semantics(
                          label: 'Register button',
                          button: true,
                          child: TextButton(
                            onPressed: () => _register(context),
                            child: Text(
                              "Register",
                              style: TextStyle(
                                color: AppColors.secondaryColor,
                                fontSize: 16 * (textScaleFactor ?? 1.0),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
