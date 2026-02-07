import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../login/login_sreen.dart';
import '../auth_bloc/auth_bloc_bloc.dart';
import '../auth_bloc/auth_bloc_event.dart';
import '../auth_bloc/auth_bloc_state.dart';
import '../../near_me/Screen/nearme_screen.dart';

class RegisterForm extends StatefulWidget {
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;

  const RegisterForm({
    super.key,
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.passwordController,
  });

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    
    // Responsive padding - increased to fill space
    final horizontalPadding = isSmallScreen ? 24.0 : 28.0;
    final verticalPadding = isSmallScreen ? 20.0 : 24.0;
    
    // Responsive font sizes - increased to fill space
    final titleFontSize = isSmallScreen ? 24.0 : 28.0;
    final labelFontSize = isSmallScreen ? 15.0 : 16.0;
    final inputFontSize = isSmallScreen ? 17.0 : 18.0;
    
    // Responsive spacing - increased to fill space
    final topSpacing = isSmallScreen ? 16.0 : 20.0;
    final titleSpacing = isSmallScreen ? 20.0 : 24.0;
    final fieldSpacing = isSmallScreen ? 20.0 : 24.0;
    
    return BlocListener<AuthBlocBloc, AuthBlocState>(
      listener: (context, state) {
        if (state.isAuthenticated && state.user != null) {
          // Navigate to near me screen on successful registration
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
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: topSpacing),
            // Title
            Center(
              child: Text(
                'Create account',
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),
            SizedBox(height: titleSpacing),
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
                        margin: EdgeInsets.only(bottom: fieldSpacing),
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
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: labelFontSize,
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
            // First Name and Last Name - always side by side
            Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'First Name',
                              style: TextStyle(
                                fontSize: labelFontSize,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: isSmallScreen ? 56.0 : 60.0,
                              child: TextField(
                                controller: widget.firstNameController,
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
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Last Name',
                              style: TextStyle(
                                fontSize: labelFontSize,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: isSmallScreen ? 56.0 : 60.0,
                              child: TextField(
                                controller: widget.lastNameController,
                                style: TextStyle(fontSize: inputFontSize),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  hintText: 'Last name',
                                  hintStyle: TextStyle(
                                    color: const Color(0xFF9CA3AF),
                                    fontSize: inputFontSize,
                                  ),
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
                          ],
                        ),
                      ),
                    ],
                  ),
            SizedBox(height: fieldSpacing),
            // Email Input
            Text(
              'Email',
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: isSmallScreen ? 56.0 : 60.0,
              child: TextField(
                controller: widget.emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(fontSize: inputFontSize),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Email address',
                hintStyle: TextStyle(
                  color: const Color(0xFF9CA3AF),
                  fontSize: inputFontSize,
                ),
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
          // Create Password Input
          Text(
            'Create Password',
            style: TextStyle(
              fontSize: labelFontSize,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: isSmallScreen ? 56.0 : 60.0,
            child: TextField(
              controller: widget.passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(fontSize: inputFontSize),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Create password',
                hintStyle: TextStyle(
                  color: const Color(0xFF9CA3AF),
                  fontSize: inputFontSize,
                ),
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
                    size: isSmallScreen ? 20.0 : 22.0,
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
          const SizedBox(height: 20),
          // Create Button
          BlocBuilder<AuthBlocBloc, AuthBlocState>(
            builder: (context, state) {
              return SizedBox(
                width: double.infinity,
                height: isSmallScreen ? 56.0 : 60.0,
                child: ElevatedButton(
                  onPressed: state.isLoading
                      ? null
                      : () {
                          setState(() {
                            _validationError = null;
                          });
                          
                          if (widget.firstNameController.text.isEmpty ||
                              widget.lastNameController.text.isEmpty ||
                              widget.emailController.text.isEmpty ||
                              widget.passwordController.text.isEmpty) {
                            setState(() {
                              _validationError = 'Please fill in all fields';
                            });
                            _scrollToError();
                            return;
                          }
                          context.read<AuthBlocBloc>().add(
                                RegisterEvent(
                                  email: widget.emailController.text,
                                  password: widget.passwordController.text,
                                  firstName: widget.firstNameController.text,
                                  lastName: widget.lastNameController.text,
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
                          'Create',
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
          const SizedBox(height: 20),
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
                  'Or, Sign Up With',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: labelFontSize,
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
          SizedBox(height: isSmallScreen ? 24.0 : 28.0),
          // Sign Up with Google Button
          BlocBuilder<AuthBlocBloc, AuthBlocState>(
            builder: (context, state) {
              return SizedBox(
                width: double.infinity,
                height: isSmallScreen ? 56.0 : 60.0,
                child: OutlinedButton(
                  onPressed: state.isLoading
                      ? null
                      : () {
                          context.read<AuthBlocBloc>().add(GoogleSignUpEvent());
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
                    width: isSmallScreen ? 18.0 : 20.0,
                    height: isSmallScreen ? 18.0 : 20.0,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback if image fails to load
                      return Container(
                        width: isSmallScreen ? 18.0 : 20.0,
                        height: isSmallScreen ? 18.0 : 20.0,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            'G',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14.0 : 16.0,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF4285F4),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(width: isSmallScreen ? 10.0 : 12.0),
                  Flexible(
                    child: Text(
                      'Sign Up with Google',
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
          SizedBox(height: isSmallScreen ? 28.0 : 32.0),
          // Sign In Link - Separate navigation element
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: labelFontSize,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to Login Screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
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
                    'Sign In',
                    style: TextStyle(
                      color: const Color(0xFF3B82F6),
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isSmallScreen ? 16.0 : 18.0),
            ],
          ),
        ),
      ),
    );
  }
}
