import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../register/register_screen.dart';
import '../auth_bloc/auth_bloc_bloc.dart';
import '../auth_bloc/auth_bloc_event.dart';
import '../auth_bloc/auth_bloc_state.dart';
import '../../near_me/Screen/nearme_screen.dart';

class LoginForm extends StatefulWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;

  const LoginForm({
    super.key,
    required this.emailController,
    required this.passwordController,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  bool _obscurePassword = true;
  String? _validationError;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBlocBloc, AuthBlocState>(
      listener: (context, state) {
        if (state.isAuthenticated && state.user != null) {
          // Navigate to near me screen on successful login
          // Use a post-frame callback to ensure navigation happens after build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const NearMeScreen(),
              ),
              (route) => false, // Remove all previous routes
            );
          });
        }
        // Clear validation error when auth state changes
        if (state.error != null || state.isAuthenticated) {
          setState(() {
            _validationError = null;
          });
        }
      },
      child: Container(
        color: const Color(0xFFF5F5F5),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = MediaQuery.of(context).size.width;
            final isSmallScreen = screenWidth < 600;
            
            // Calculate available height for form
            final availableHeight = constraints.maxHeight;
            
            // Responsive values
            final horizontalPadding = isSmallScreen ? 24.0 : 28.0;
            final verticalPadding = isSmallScreen ? 12.0 : 16.0;
            final titleFontSize = isSmallScreen ? 22.0 : 24.0;
            final labelFontSize = isSmallScreen ? 14.0 : 15.0;
            final inputFontSize = isSmallScreen ? 16.0 : 17.0;
            final fieldHeight = isSmallScreen ? 56.0 : 60.0;
            final buttonHeight = isSmallScreen ? 48.0 : 50.0;
            
            // Dynamic spacing based on available height
            final baseSpacing = availableHeight < 600 ? 8.0 : (availableHeight < 700 ? 12.0 : 16.0);
            final titleSpacing = availableHeight < 600 ? 8.0 : (availableHeight < 700 ? 12.0 : 18.0);
            final fieldSpacing = availableHeight < 600 ? 10.0 : (availableHeight < 700 ? 12.0 : 16.0);
            
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: baseSpacing),
                  // Title
                  Text(
                    'Login your account',
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: titleSpacing),
                  // Error Message (if any) - Flexible to prevent overflow
                  Flexible(
                    child: Builder(
                      builder: (context) {
                        return BlocBuilder<AuthBlocBloc, AuthBlocState>(
                          builder: (context, state) {
                            final errorMessage = _validationError ?? 
                              (state.error != null 
                                ? state.error.toString().replaceFirst('Exception: ', '')
                                : null);
                            
                            if (errorMessage != null) {
                              return Container(
                                margin: EdgeInsets.only(bottom: fieldSpacing),
                                padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red.shade700,
                                      size: isSmallScreen ? 18.0 : 20.0,
                                    ),
                                    SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                                    Expanded(
                                      child: Text(
                                        errorMessage,
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: isSmallScreen ? 12.0 : 14.0,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        );
                      },
                    ),
                  ),
                  // Email Input
                  Text(
                    'Email',
                    style: TextStyle(
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: baseSpacing),
                  SizedBox(
                    height: fieldHeight,
                    child: TextField(
                      controller: widget.emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(fontSize: inputFontSize),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF3B82F6),
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF3B82F6),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF3B82F6),
                            width: 2,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: isSmallScreen ? 16.0 : 18.0,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: fieldSpacing),
                  // Password Input
                  Text(
                    'Password',
                    style: TextStyle(
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: baseSpacing),
                  SizedBox(
                    height: fieldHeight,
                    child: TextField(
                      controller: widget.passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(fontSize: inputFontSize),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF3B82F6),
                            width: 2,
                          ),
                        ),
                        hintText: 'Enter your password',
                        hintStyle: TextStyle(
                          color: const Color(0xFF9CA3AF),
                          fontSize: inputFontSize,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: isSmallScreen ? 16.0 : 18.0,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: const Color(0xFF6B7280),
                            size: isSmallScreen ? 20.0 : 24.0,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: availableHeight < 600 ? 4.0 : 6.0),
                  // Forgot Password Link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // Handle forgot password
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 4.0 : 4.0,
                          vertical: isSmallScreen ? 4.0 : 4.0,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: const Color(0xFF3B82F6),
                          fontSize: isSmallScreen ? 12.0 : 14.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: fieldSpacing),
                  // Log In Button
                  BlocBuilder<AuthBlocBloc, AuthBlocState>(
                    builder: (context, state) {
                      return SizedBox(
                        width: double.infinity,
                        height: buttonHeight,
                        child: ElevatedButton(
                          onPressed: state.isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _validationError = null;
                                  });
                                  
                                  if (widget.emailController.text.isEmpty ||
                                      widget.passwordController.text.isEmpty) {
                                    setState(() {
                                      _validationError = 'Please fill in all fields';
                                    });
                                    return;
                                  }
                                  context.read<AuthBlocBloc>().add(
                                        LoginEvent(
                                          email: widget.emailController.text,
                                          password: widget.passwordController.text,
                                        ),
                                      );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: state.isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  'Log in',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: inputFontSize,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: fieldSpacing),
                  // Separator
                  Row(
                    children: [
                      const Expanded(
                        child: Divider(
                          color: Color(0xFFD1D5DB),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12.0 : 16.0),
                        child: Text(
                          'Or, Sign In With',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: isSmallScreen ? 12.0 : 14.0,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Divider(
                          color: Color(0xFFD1D5DB),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: fieldSpacing),
                  // Log In with Google Button
                  BlocBuilder<AuthBlocBloc, AuthBlocState>(
                    builder: (context, state) {
                      return SizedBox(
                        width: double.infinity,
                        height: buttonHeight,
                        child: OutlinedButton(
                          onPressed: state.isLoading
                              ? null
                              : () {
                                  context.read<AuthBlocBloc>().add(GoogleSignInEvent());
                                },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                              color: Color(0xFFE5E7EB),
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Google Logo
                              Image.asset(
                                'assets/images/logo/google-logo.png',
                                width: isSmallScreen ? 18.0 : 22.0,
                                height: isSmallScreen ? 18.0 : 22.0,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: isSmallScreen ? 18.0 : 22.0,
                                    height: isSmallScreen ? 18.0 : 22.0,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'G',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 14.0 : 18.0,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF4285F4),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(width: isSmallScreen ? 10.0 : 14.0),
                              Flexible(
                                child: Text(
                                  'Log in with Google',
                                  style: TextStyle(
                                    color: const Color(0xFF374151),
                                    fontSize: inputFontSize,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: availableHeight < 600 ? 8.0 : 14.0),
                  // Sign Up Link
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Don\'t have an account? ',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: isSmallScreen ? 12.0 : 14.0,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 4.0 : 8.0,
                              vertical: isSmallScreen ? 4.0 : 8.0,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Sign up',
                            style: TextStyle(
                              color: const Color(0xFF3B82F6),
                              fontSize: isSmallScreen ? 12.0 : 14.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: baseSpacing),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
