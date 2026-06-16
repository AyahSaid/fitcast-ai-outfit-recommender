import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:outfit_app/screens/sign_in_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'meet_sunny_page.dart';
import 'outfit_suggestion_screen.dart';
import 'main_navigation_wrapper.dart'; // Add this line



class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _cloud1Controller;
  late AnimationController _cloud2Controller;
  late AnimationController _sunController;
  late Animation<Offset> _cloud1Offset;
  late Animation<Offset> _cloud2Offset;
  late Animation<double> _sunFloat;
  late Animation<double> _sunRotate;

  @override
  void initState() { //runs once when the screen first loads.
    super.initState();

    // ☁️ Cloud 1 — small top cloud
    _cloud1Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _cloud1Offset = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0.03, 0.05),
    ).chain(CurveTween(curve: Curves.easeInOutSine)).animate(_cloud1Controller);

    // ☁️ Cloud 2 — big lower cloud
    _cloud2Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _cloud2Offset = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(-0.0, -0.04),
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(_cloud2Controller);

    // ☀️ Sun subtle float + rotation
    _sunController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _sunFloat = Tween<double>(begin: 0, end: 2)
        .chain(CurveTween(curve: Curves.easeInOutSine))
        .animate(_sunController);

    _sunRotate = Tween<double>(begin: -0.02, end: 0.03)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_sunController);
  }

  @override
  void dispose() {
    _cloud1Controller.dispose();  //This stops and cleans up the animation controllers when the screen closes, to prevent memory leaks.
    _cloud2Controller.dispose();
    _sunController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.49, -1.16),
            end: Alignment(1.00, 1.06),
            colors: [Color(0xFF86B8FC), Color(0xFFD5E1F9)],
          ),
        ),
        child: Stack(
          children: [
            // 🌙 Background Circles
            Positioned(
              left: 253.06,
              top: 184.10,
              child: Container(
                width: 179.88,
                height: 167.80,
                decoration: ShapeDecoration(
                  shape: OvalBorder(
                    side: BorderSide(
                      width: 1,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 138.59,
              top: 77.31,
              child: Container(
                width: 408.82,
                height: 381.37,
                decoration: ShapeDecoration(
                  shape: OvalBorder(
                    side: BorderSide(
                      width: 1,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 32.29,
              top: -21.84,
              child: Container(
                width: 621.41,
                height: 579.69,
                decoration: ShapeDecoration(
                  shape: OvalBorder(
                    side: BorderSide(
                      width: 1,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: -74,
              top: -121,
              child: Container(
                width: 834,
                height: 778,
                decoration: ShapeDecoration(
                  shape: OvalBorder(
                    side: BorderSide(
                      width: 1,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
            ),

            // ☀️ Animated Sun
            Positioned(
              left: 10,
              top: screenHeight * 0.14,
              child: AnimatedBuilder(
                animation: _sunController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _sunFloat.value),
                    child: Transform.rotate(
                      angle: _sunRotate.value,
                      child: child,
                    ),
                  );
                },
                child: Image.asset(
                  "assets/images/sunAndClouds.png",
                  width: 250,
                  height: 250,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // 🌥️ Small top cloud (floating)
            Positioned(
              right: 2,
              top: screenHeight * 0.1,
              child: SlideTransition(
                position: _cloud1Offset,
                child: Image.asset(
                  "assets/images/smallcloud1.png",
                  width: 139,
                  height: 139,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // 🌥️ Big lower cloud (floating)
            Positioned(
              right: 0,
              top: screenHeight * 0.32,
              child: SlideTransition(
                position: _cloud2Offset,
                child: Image.asset(
                  "assets/images/bigcloud2.png",
                  width: 200,
                  height: 190,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // 🌤️ Title
            Positioned(
              left: 139,
              top: screenHeight * 0.085,
              child: Text(
                'FitCast',
                style: GoogleFonts.rubik(
                  color: const Color.fromARGB(255, 247, 226, 152),
                  fontSize: 45,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.9,
                  
                ),
              ),
            ),

            // ☁️ Text Cloud background + text
            Positioned(
              left: -screenWidth * 0.45,
              top: screenHeight * 0.50,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Image.asset(
                    'assets/images/textCloud.png',
                    width: screenWidth * 1.8,
                    height: screenHeight * 0.33,
                    fit: BoxFit.contain,
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: screenWidth * 0.47,
                      top: screenHeight * 0.05,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Be prepared for\nany weather !',
                          style: GoogleFonts.rubik(
                            color: const Color(0xFF1A4D9E),
                            fontSize: screenWidth * 0.08,
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                            letterSpacing: -1.2,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.015),
                        SizedBox(
                          width: screenWidth * 0.75,
                          child: Text(
                            'FitCast keeps you comfy, confident, and ready for whatever the sky brings.',
                            style: GoogleFonts.rubik(
                              color: const Color(0xFF3A74C3),
                              fontSize: screenWidth * 0.045,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 🔵 “Get started” button
            Positioned( //is part of the Stack layout — it lets you place the button exactly where you want it on the screen.
              left: screenWidth * 0.15,
              bottom: safeBottom + 40,
              child: GestureDetector(
                onTap: () async {
                        final user = FirebaseAuth.instance.currentUser;

                        // ❌ Not logged in
                        if (user == null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SignInPage()),
                          );
                          return;
                        }

                        // ✅ Logged in → check Sunny
                        final doc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .get();

                        final hasSeenMeetSunny = doc.data()?['hasSeenMeetSunny'] ?? false;

                        if (!hasSeenMeetSunny) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MeetSunnyPage()),
                          );
                        } else {
                          /*Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) =>  OutfitSuggestionScreen()),
                          );*/
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MainNavigationWrapper()),
                          );
                        }
                      },

                child: Container(
                  width: screenWidth * 0.7,
                  height: 56,
                  decoration: ShapeDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment(-0.00, -0.99),
                      end: Alignment(1.03, 1.93),
                      colors: [Color(0xFF0B5184), Color(0xFF0A609F)],
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(24)),
                    ),
                    shadows: [
                      BoxShadow(
                        // ignore: deprecated_member_use
                        color: Colors.black.withOpacity(0.2),
                        offset: const Offset(0, 4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Get started',
                      style: GoogleFonts.rubik(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
