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
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _errorKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_errorKey.currentContext != null) {
        Scrollable.ensureVisible(
          _errorKey.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1, // Show error near the top
        );
      }
    });
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
        // Scroll to error when it appears
        if (state.error != null) {
          _scrollToError();
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
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
            const SizedBox(height: 12),
          // Title
          const Text(
            'Login your account',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 18),
          // Error Message (if any)
          Builder(
            builder: (context) {
              return BlocBuilder<AuthBlocBloc, AuthBlocState>(
                builder: (context, state) {
                  final errorMessage = _validationError ?? 
                    (state.error != null 
                      ? state.error.toString().replaceFirst('Exception: ', '')
                      : null);
                  
                  if (errorMessage != null) {
                    return Container(
                      key: _errorKey,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
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
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
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
          // Email Input
          const Text(
            'Email',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 60,
            child: TextField(
                controller: widget.emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 17),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF3B82F6), // Light blue
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF3B82F6), // Light blue
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF3B82F6), // Light blue
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          // Password Input
          const Text(
            'Password',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 60,
            child: TextField(
                controller: widget.passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(fontSize: 17),
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
                  hintStyle: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 17,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: const Color(0xFF6B7280),
                      size: 24,
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
          const SizedBox(height: 6),
          // Forgot Password Link
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
                onPressed: () {
                  // Handle forgot password
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: Color(0xFF3B82F6),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Log In Button
          BlocBuilder<AuthBlocBloc, AuthBlocState>(
            builder: (context, state) {
              return SizedBox(
                width: double.infinity,
                height: 50,
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
                            _scrollToError();
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
                    backgroundColor: const Color(0xFF3B82F6), // Blue
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: state.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Log in',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Or, Sign In With',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
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
          const SizedBox(height: 16),
          // Log In with Google Button
          BlocBuilder<AuthBlocBloc, AuthBlocState>(
            builder: (context, state) {
              return SizedBox(
                width: double.infinity,
                height: 50,
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
                      width: 22,
                      height: 22,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback if image fails to load
                        return Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Center(
                            child: Text(
                              'G',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4285F4),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 14),
                    Flexible(
                      child: Text(
                        'Log in with Google',
                        style: const TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 17,
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
          const SizedBox(height: 14),
          // Sign Up Link
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  Text(
                    'Don\'t have an account? ',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Sign up',
                      style: TextStyle(
                        color: Color(0xFF3B82F6),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
