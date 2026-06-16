// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'meet_sunny_page.dart';



class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  late AnimationController _leafController;
  late AnimationController _windController;
  late AnimationController _sunController;
  late AnimationController _fitCastController;

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
  final int leafCount = 40;

  String _password = '';
  String _confirmPassword = '';
  bool hasUppercase = false;
  bool hasLowercase = false;
  bool hasDigit = false;
  bool hasSpecialChar = false;
  bool hasMinLength = false;
  bool _showPasswordRules = false;
  bool _showPasswordMatchError = false;

  bool isPasswordStrong(String password) {
    final passwordRegex =
        RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[!@#\$&*~]).{8,}$');
    return passwordRegex.hasMatch(password);
  }

  @override
  void initState() {
    super.initState();

    _leafController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _windController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    _sunController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _fitCastController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();

    final random = Random();
    _leafData = List.generate(leafCount, (i) {
      return _LeafData(
        image: leaves[i % leaves.length],
        startX: random.nextDouble() * 500,
        startY: random.nextDouble() * 800,
        fallSpeed: 25 + random.nextDouble() * 10,
        swaySpeed: 0.4 + random.nextDouble() * 0.15,
        swayRange: 25 + random.nextDouble() * 10,
        offset: random.nextDouble() * 2 * pi,
        size: 30 + random.nextInt(20).toDouble(),
      );
    });
  }

  @override
  void dispose() {
    _leafController.dispose();
    _windController.dispose();
    _sunController.dispose();
    _fitCastController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF5CC), Color(0xFFFAD29E)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF5A3E1B), size: 24),
             onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),

          AnimatedBuilder(
            animation: _windController,
            builder: (context, _) {
              final progress = _windController.value;
              return Stack(
                children: List.generate(winds.length * 3, (index) {
                  final wind = winds[index % winds.length];
                  final opacity = 0.08 + 0.08 * sin(progress * 2 * pi + index);
                  final offsetX =
                      (progress * screenWidth * 1.1 + index * 90) %
                          (screenWidth + 100);
                  final verticalZones = [0.15, 0.45, 0.75];
                  final zone = verticalZones[index % verticalZones.length];
                  final offsetY =
                      screenHeight * zone + sin(progress * 2 * pi + index) * 25;

                  return Positioned(
                    left: offsetX - 120,
                    top: offsetY,
                    child: Opacity(
                      opacity: opacity,
                      child: Image.asset(wind, width: 120),
                    ),
                  );
                }),
              );
            },
          ),

          AnimatedBuilder(
            animation: _leafController,
            builder: (context, _) {
              final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
              final random = Random();

              return Stack(
                children: _leafData.map((leaf) {
                  leaf.startY += leaf.fallSpeed * 0.02;
                  final y = leaf.startY;
                  final x = (leaf.startX +
                          sin(time * leaf.swaySpeed + leaf.offset) *
                              leaf.swayRange) %
                      screenWidth;

                  if (y > screenHeight + 150) {
                    leaf.startY = -random.nextDouble() * 200 - 100;
                    leaf.startX = random.nextDouble() * screenWidth;
                  }

                  final rotation = sin(time * 1.5 + leaf.offset) * 0.4;
                  return Positioned(
                    top: y - 80,
                    left: x,
                    child: Transform.rotate(
                      angle: rotation,
                      child: Opacity(
                        opacity: 0.6,
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
                  top: screenHeight * 0.09 - rise,
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

          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              screenWidth * 0.1,
              screenHeight * 0.08,
              screenWidth * 0.1,
              40,
            ),
            child: Column(
              children: [
                SizedBox(height: screenHeight * 0.25),
                Text(
                  "Create your account!",
                  style: GoogleFonts.inter(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF5A3E1B),
                  ),
                ),

                const SizedBox(height: 25),

                _modernInput("Email", Icons.email_outlined, _emailController),
                const SizedBox(height: 16),

                _modernInput(
                  "Password",
                  Icons.lock_outline,
                  _passwordController,
                  obscure: true,
                  onChanged: (value) {
                    setState(() {
                      _password = value;
                      hasUppercase = value.contains(RegExp(r'[A-Z]'));
                      hasLowercase = value.contains(RegExp(r'[a-z]'));
                      hasDigit = value.contains(RegExp(r'[0-9]'));
                      hasSpecialChar =
                          value.contains(RegExp(r'[!@#\$&*~]'));
                      hasMinLength = value.length >= 8;
                    });
                  },
                ),
                const SizedBox(height: 16),

                _modernInput(
                  "Confirm Password",
                  Icons.lock_outline,
                  _confirmPasswordController,
                  obscure: true,
                  onChanged: (value) =>
                      setState(() => _confirmPassword = value),
                ),

                if (_showPasswordMatchError) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.cancel_rounded,
                          color: Colors.redAccent, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        "Passwords don't match",
                        style: GoogleFonts.inter(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],

                if (_showPasswordRules) ...[
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPasswordRule(
                          'At least 8 characters', hasMinLength),
                      _buildPasswordRule(
                          'Uppercase letter', hasUppercase),
                      _buildPasswordRule(
                          'Lowercase letter', hasLowercase),
                      _buildPasswordRule('A number', hasDigit),
                      _buildPasswordRule(
                          'Special character (!@#\$&*~)',
                          hasSpecialChar),
                    ],
                  ),
                ],

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _createAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE35D3B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    minimumSize: Size(screenWidth * 0.7, 54),
                    elevation: 0,
                  ),
                  child: Text(
                    'Create Account',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernInput(
      String label,
      IconData icon,
      TextEditingController controller,
      {bool obscure = false,
      Function(String)? onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        onChanged: onChanged,
        cursorColor: const Color(0xFFE35D3B),
        style: GoogleFonts.inter(
          color: Colors.brown.shade800,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: GoogleFonts.inter(
            color: Colors.brown.withOpacity(0.4),
            fontSize: 15,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 4),
            child: Icon(icon, color: const Color(0xFFE35D3B), size: 22),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        ),
      ),
    );
  }

  Widget _buildPasswordRule(String text, bool conditionMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            conditionMet
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: conditionMet ? Colors.green : Colors.grey.shade400,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: conditionMet
                  ? Colors.green.shade800
                  : Colors.brown.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _createAccount() async {
  FocusScope.of(context).unfocus();

  final email = _emailController.text.trim();
  final confirmPassword = _confirmPasswordController.text.trim();

  setState(() {
    _showPasswordMatchError = false;
  });

  if (!isPasswordStrong(_password)) {
    setState(() => _showPasswordRules = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please meet all password requirements.'),
        backgroundColor: Colors.redAccent,
      ),
    );
    return;
  } else {
    setState(() => _showPasswordRules = false);
  }

  if (_password != confirmPassword) {
    setState(() => _showPasswordMatchError = true);
    return;
  }

  try {
    final userCredential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: _password,
    );

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userCredential.user!.uid)
        .set({
      'email': email,
      'hasSeenMeetSunny': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // ✅ GO TO SUNNY AFTER SIGN UP
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MeetSunnyPage()),
    );

  } on FirebaseAuthException catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.message ?? 'An error occurred.'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}





}

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
