import 'package:flutter/material.dart';
import '../features/auth/login/login_sreen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    // Responsive scaling factors
    final double scaleFactor = screenWidth / 375; // Base width (iPhone X)
    final double minScale = 0.8;
    final double maxScale = 1.5;
    final double effectiveScale = (scaleFactor.clamp(minScale, maxScale));
    
    // Responsive dimensions
    final double horizontalPadding = screenWidth * 0.06; // 6% of screen width
    final double verticalPadding = screenHeight * 0.04; // 4% of screen height
    final double titleFontSize = 28 * effectiveScale;
    final double descriptionFontSize = 16 * effectiveScale;
    final double buttonHeight = 50 * effectiveScale;
    final double buttonFontSize = 16 * effectiveScale;
    final double borderRadius = 12 * effectiveScale;
    
    return Scaffold(
      body: Column(
        children: [
          // Image at the top - Responsive (stretched to show more)
          Expanded(
            flex: 4,
            child: Image.asset(
              'assets/images/splashscreen/spalshscreen.png',
              fit: BoxFit.cover,
              width: screenWidth,
            ),
          ),
          // Bottom Section with Text and Buttons - Responsive
          ClipPath(
            clipper: WavyClipper(),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E3A8A), // Dark blue
              ),
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: screenHeight * 0.02),
                  // Tagline - Responsive
                  Text(
                    'Smarter commuting starts here.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  // Description - Responsive
                  Text(
                    'GoBus finds nearby buses in real time, so you wait less and ride smarter.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: descriptionFontSize,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.04),
                  // Log In Button - Responsive
                  SizedBox(
                    width: double.infinity,
                    height: buttonHeight,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6), // Blue
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Log In',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: buttonFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  // Sign Up Button - Responsive
                  SizedBox(
                    width: double.infinity,
                    height: buttonHeight,
                    child: OutlinedButton(
                      onPressed: () {
                        // Handle sign up navigation
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.white,
                          width: 2 * effectiveScale,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                      ),
                      child: Text(
                        'Sign Up',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: buttonFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.025),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom clipper for straight top edge
class WavyClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();

    // Simple straight line across the top
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

