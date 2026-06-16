import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sign_up_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'meet_sunny_page.dart';
import 'outfit_suggestion_screen.dart';


class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late AnimationController _leafController;
  late AnimationController _windController;
  late AnimationController _sunController;
  late AnimationController _titleGlowController;

  final List<String> leaves = [
    'assets/images/leaf1.png',
    'assets/images/leaf2.png',
    'assets/images/leaf3.png',
    'assets/images/leaf4.png',
  ];

  final List<String> winds = [
    'assets/images/wind1.png',
    'assets/images/wind2.png',
    'assets/images/wind3.png',
    'assets/images/wind4.png',
    'assets/images/wind5.png',
    'assets/images/wind6.png',
  ];

  late List<_LeafData> _leafData;
  final int leafCount = 45;

  @override
  void initState() {
    super.initState();

    _leafController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _windController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 35),
    )..repeat();

    _sunController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _titleGlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    final random = Random();
    _leafData = List.generate(leafCount, (i) {
      return _LeafData(
        image: leaves[i % leaves.length],
        startX: random.nextDouble() * 500,
        startY: random.nextDouble() * 800, // already mid-fall 🍂
        fallSpeed: 25 + random.nextDouble() * 12,
        swaySpeed: 0.5 + random.nextDouble() * 0.3,
        swayRange: 25 + random.nextDouble() * 12,
        offset: random.nextDouble() * 2 * pi,
        size: 30 + random.nextInt(25).toDouble(),
      );
    });
  }

  @override
  void dispose() {
    _leafController.dispose();
    _windController.dispose();
    _sunController.dispose();
    _titleGlowController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 🌅 Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF5CC), Color(0xFFFAD29E)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // 🌬 Wind curls
          AnimatedBuilder(
            animation: _windController,
            builder: (context, _) {
              final progress = _windController.value;
              final random = Random(12);
              return Stack(
                children: List.generate(winds.length * 3, (index) {
                  final wind = winds[index % winds.length];
                  final opacity = 0.06 + 0.06 * sin(progress * 2 * pi + index);
                  final offsetX =
                      (progress * screenWidth * 1.1 + index * 120) %
                          (screenWidth + 100);
                  final offsetY = random.nextDouble() * screenHeight;
                  return Positioned(
                    left: offsetX - 120,
                    top: offsetY,
                    child: Opacity(
                      opacity: opacity,
                      child: Image.asset(wind, width: 110, fit: BoxFit.contain),
                    ),
                  );
                }),
              );
            },
          ),

          // 🍂 Falling leaves
          AnimatedBuilder(
            animation: _leafController,
            builder: (context, _) {
              final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
              final random = Random();

              return Stack(
                children: _leafData.map((leaf) {
                  leaf.startY += leaf.fallSpeed * 0.02;
                  if (leaf.startY > screenHeight + 100) {
                    leaf.startY = -random.nextDouble() * 150;
                    leaf.startX = random.nextDouble() * screenWidth;
                  }

                  final y = leaf.startY;
                  final x = (leaf.startX +
                          sin(time * leaf.swaySpeed + leaf.offset) *
                              leaf.swayRange) %
                      screenWidth;
                  final rotation = sin(time * 1.5 + leaf.offset) * 0.4;

                  double opacity = 0.6;
                  if (y < screenHeight * 0.1) {
                    opacity = 0.5;
                  } else if (y > screenHeight * 0.9) {
                    opacity = 0.3;
                  }

                  return Positioned(
                    top: y - 80,
                    left: x,
                    child: Transform.rotate(
                      angle: rotation,
                      child: Opacity(
                        opacity: opacity,
                        child: Image.asset(
                          leaf.image,
                          width: leaf.size,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          // ☀️ Floating sun
          AnimatedBuilder(
            animation: _sunController,
            builder: (context, _) {
              final progress = _sunController.value;
              final rise = sin(progress * pi) * 8;
              final glow = 0.9 + 0.1 * sin(progress * pi);

              return Positioned(
                top: screenHeight * 0.12 - rise,
                child: Opacity(
                  opacity: glow,
                  child: Image.asset(
                    'assets/images/sunFall.png',
                    width: screenWidth * 0.55,
                  ),
                ),
              );
            },
          ),

          // 🌤 FitCast Title (no shadow, subtle glow)
          AnimatedBuilder(
            animation: _titleGlowController,
            builder: (context, _) {
              final glowOpacity = 0.6 + 0.4 * sin(_titleGlowController.value * 2 * pi);
              return Positioned(
                top: screenHeight * 0.08,
                child: Text(
                  "FitCast",
                  style: GoogleFonts.poppins(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF5A3E1B),
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        color: Colors.orange.withOpacity(glowOpacity * 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 🧡 Login Form
          SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: screenHeight * 0.5),
                Text(
                  'Welcome back!',
                  style: GoogleFonts.rubik(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF5A3E1B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Log in to continue your sunny journey ☀️',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.rubik(
                    color: Colors.brown.shade500,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 35),

                _modernInput('Email', Icons.email_outlined, _emailController),
                const SizedBox(height: 18),
                _modernInput('Password', Icons.lock_outline, _passwordController,
                    obscure: true),
                const SizedBox(height: 30),

                // ☀️ Clean constant color Sign In button (no gradient)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE35D3B),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    minimumSize: Size(
                      MediaQuery.of(context).size.width * 0.7,
                      54,
                    ),
                    elevation: 6,
                    shadowColor: Colors.transparent,
                  ),
                  onPressed: () async {
                        try {
                          final userCredential =
                              await FirebaseAuth.instance.signInWithEmailAndPassword(
                            email: _emailController.text.trim(),
                            password: _passwordController.text.trim(),
                          );

                          final uid = userCredential.user!.uid;

                          final userDoc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .get();

                          final hasSeenMeetSunny =
                              userDoc.data()?['hasSeenMeetSunny'] ?? false;

                          if (!context.mounted) return;

                          if (hasSeenMeetSunny) {
                            // ✅ User already met Sunny → go to outfit suggestions
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>  OutfitSuggestionScreen(),
                              ),
                            );
                          } else {
                            // ☀️ First time → go to Sunny
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MeetSunnyPage(),
                              ),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Login failed: $e')),
                          );
                        }
                      },

                  child: Text(
                    'Sign In',
                    style: GoogleFonts.rubik(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account?",
                        style: GoogleFonts.rubik(color: Colors.grey.shade700)),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignUpPage()),
                        );
                      },
                      child: Text(
                        'Sign Up',
                        style: GoogleFonts.rubik(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF7D4F20),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernInput(String label, IconData icon, TextEditingController controller,
    {bool obscure = false}) {
  return Container(
    decoration: BoxDecoration(
      // ignore: deprecated_member_use
      color: Colors.white.withOpacity(0.85), // soft white background
      borderRadius: BorderRadius.circular(22), // smooth Apple-like curve
      boxShadow: [
        BoxShadow(
          // ignore: deprecated_member_use
          color: Colors.black.withOpacity(0.05), // very light shadow
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: TextField(
      controller: controller,
      obscureText: obscure,
      cursorColor: const Color(0xFFE35D3B),
      style: GoogleFonts.rubik(
        color: Colors.brown.shade800,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: GoogleFonts.rubik(
          // ignore: deprecated_member_use
          color: Colors.brown.withOpacity(0.4),
          fontSize: 15,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 4),
          child: Icon(
            icon,
            color: const Color(0xFFE35D3B), // matches sun/scarf
            size: 22,
          ),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 40, maxHeight: 28),
        border: InputBorder.none, // ❌ no outline — pure iOS look
        contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      ),
    ),
  );
}

}

// 🍁 Leaf model
class _LeafData {
  final String image;
  double startX;
  double startY;
  final double fallSpeed;
  final double swaySpeed;
  final double swayRange;
  final double offset;
  final double size;

  _LeafData({
    required this.image,
    required this.startX,
    required this.startY,
    required this.fallSpeed,
    required this.swaySpeed,
    required this.swayRange,
    required this.offset,
    required this.size,
  });
}
