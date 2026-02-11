import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'login_form.dart';
import '../auth_bloc/auth_bloc_bloc.dart';
import '../auth_bloc/auth_bloc_provider.dart';
import '../../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController(
    text: 'kentflores@gmail.com',
  );
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 900;
    
    // Responsive logo size - zoomed in
    final logoWidth = isSmallScreen ? screenWidth * 0.85 : (isMediumScreen ? 500.0 : 600.0);
    final logoHeight = isSmallScreen ? screenWidth * 0.68 : (isMediumScreen ? 400.0 : 480.0);
    
    // Responsive header height
    final headerHeight = isSmallScreen ? screenHeight * 0.35 : screenHeight * 0.4;
    
    // Responsive form start position - moved lower
    final formTop = isSmallScreen ? screenHeight * 0.40 : screenHeight * 0.48;
    
    // Responsive border radius
    final borderRadius = isSmallScreen ? 30.0 : 50.0;

    return BlocProvider(
      create: (context) => AuthBlocBloc(
        provider: AuthBlocProvider(
          authService: AuthService(),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1E3A8A),
        body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Header background - only covers top portion
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: headerHeight,
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFF1E3A8A),
                    child: Center(
                      child: Image.asset(
                        'assets/images/logo/logo1.png',
                        width: logoWidth,
                        height: logoHeight,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // Login form - positioned lower, extends to bottom
                Positioned(
                  top: formTop,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(borderRadius),
                      topRight: Radius.circular(borderRadius),
                    ),
                    child: LoginForm(
                      emailController: _emailController,
                      passwordController: _passwordController,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      ),
    );
  }
}
