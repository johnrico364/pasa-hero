import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'register_form.dart';
import '../auth_bloc/auth_bloc_bloc.dart';
import '../auth_bloc/auth_bloc_provider.dart';
import '../../../core/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _firstNameController = TextEditingController(
    text: 'John Anthony',
  );
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
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
    
    // Responsive logo size - zoomed in (matching login screen)
    final logoWidth = isSmallScreen ? screenWidth * 0.85 : (isMediumScreen ? 500.0 : 600.0);
    final logoHeight = isSmallScreen ? screenWidth * 0.68 : (isMediumScreen ? 400.0 : 480.0);
    
    // Responsive header height
    final headerHeight = isSmallScreen ? screenHeight * 0.35 : screenHeight * 0.4;
    
    // Responsive form start position
    final formTop = isSmallScreen ? screenHeight * 0.28 : screenHeight * 0.32;
    
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

                // Register form - positioned to overlap header
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
                    child: RegisterForm(
                      firstNameController: _firstNameController,
                      lastNameController: _lastNameController,
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

