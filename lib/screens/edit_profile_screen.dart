// ignore_for_file: deprecated_member_use
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:country_picker/country_picker.dart';
import 'package:outfit_app/services/weather_service.dart';

class EditProfileScreen extends StatefulWidget {
  EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final WeatherService _weatherService = WeatherService();
  
  String _selectedGender = "female";
  bool _isLoading = false;
  late AnimationController _floatController;

  // Location State
  String _selectedCountryName = "Select Country";
  String _selectedCountryCode = "";
  String _selectedCountryEmoji = "🌍";

  // Password validation states
  bool hasUppercase = false;
  bool hasLowercase = false;
  bool hasDigit = false;
  bool hasSpecialChar = false;
  bool hasMinLength = false;
  bool _showPasswordRules = false;
  bool _showPasswordMatchError = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatController.forward();
  }

  void _updatePasswordValidation(String value) {
    setState(() {
      hasUppercase = value.contains(RegExp(r'[A-Z]'));
      hasLowercase = value.contains(RegExp(r'[a-z]'));
      hasDigit = value.contains(RegExp(r'[0-9]'));
      hasSpecialChar = value.contains(RegExp(r'[!@#\$&*~]'));
      hasMinLength = value.length >= 8;
      _showPasswordRules = value.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _floatController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _emailController.text = user.email ?? "";
    final doc = await FirebaseFirestore.instance.collection("user_preferences").doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _nameController.text = data["name"] ?? "";
        _selectedGender = data["gender"]?.toString().toLowerCase() ?? "female";
        _cityController.text = data["city"] ?? "";
        _selectedCountryName = data["country"] ?? "Select Country";
        _selectedCountryCode = data["countryCode"] ?? "";
      });
    }
  }

  void _showIOSToast(String message, bool isError) {
    OverlayState? overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  color: isError ? Colors.red.withOpacity(0.8) : Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isError ? Icons.error_outline : Icons.check_circle_outline,
                      color: isError ? Colors.white : const Color(0xFF1A4D9E),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: GoogleFonts.rubik(
                          color: isError ? Colors.white : const Color(0xFF1A4D9E),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlayState.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () => overlayEntry.remove());
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
      _showPasswordMatchError = false;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      if (_selectedCountryCode.isEmpty || _cityController.text.isEmpty) {
        _showIOSToast("Please select a country and city", true);
        setState(() => _isLoading = false);
        return;
      }

      final validatedCity = await _weatherService.validateCity(
        _cityController.text.trim(), 
        _selectedCountryCode
      );

      if (validatedCity == null) {
        _showIOSToast("City not found in $_selectedCountryName", true);
        setState(() => _isLoading = false);
        return;
      }

      if (_passwordController.text.isNotEmpty) {
        if (!RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[!@#\$&*~]).{8,}$').hasMatch(_passwordController.text)) {
          _showIOSToast("Password too weak", true);
          setState(() => _isLoading = false);
          return;
        }
        if (_passwordController.text != _confirmPasswordController.text) {
          setState(() {
            _showPasswordMatchError = true;
            _isLoading = false;
          });
          return;
        }
        await user.updatePassword(_passwordController.text.trim());
      }

      if (_emailController.text.trim() != user.email) {
        await user.updateEmail(_emailController.text.trim());
      }

      await FirebaseFirestore.instance.collection("user_preferences").doc(user.uid).set({
        "name": _nameController.text.trim(),
        "gender": _selectedGender,
        "city": validatedCity,
        "country": _selectedCountryName,
        "countryCode": _selectedCountryCode,
      }, SetOptions(merge: true));

      _showIOSToast("Profile updated successfully", false);
      Future.delayed(const Duration(milliseconds: 800), () => Navigator.pop(context, true));

    } on FirebaseAuthException catch (e) {
      _showIOSToast(e.message ?? "Auth error", true);
    } catch (e) {
      _showIOSToast("Error saving changes", true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A4D9E)),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text("Profile Settings", style: GoogleFonts.rubik(fontWeight: FontWeight.w600, color: const Color(0xFF1A4D9E))),
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.49, -1.16),
                end: Alignment(1.00, 1.06),
                colors: [Color(0xFF86B8FC), Color(0xFFD5E1F9)],
              ),
            ),
          ),
          
          // Sunny peek-a-boo
          Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _floatController,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, 10 * _floatController.value),
                  child: child,
                ),
                child: Image.asset(
                  "assets/images/sunAndClouds.png", 
                  width: 200, 
                ),
              ),
            ),
          ),

          // Main Content
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).size.height * 0.26, 24, 40),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildInput("Name", _nameController, false),
                        const SizedBox(height: 16),
                        _buildInput("Email Address", _emailController, false),
                        const SizedBox(height: 16),
                        
                        _buildLocationPicker(),
                        const SizedBox(height: 16),
                        
                        _buildInput("New Password", _passwordController, true, onChanged: _updatePasswordValidation),
                        if (_showPasswordRules) ...[
                          const SizedBox(height: 8),
                          _buildPasswordRule('At least 8 characters', hasMinLength),
                          _buildPasswordRule('Uppercase letter', hasUppercase),
                          _buildPasswordRule('Lowercase letter', hasLowercase),
                          _buildPasswordRule('A number', hasDigit),
                          _buildPasswordRule('Special character (!@#\$&*~)', hasSpecialChar),
                        ],
                        const SizedBox(height: 16),
                        _buildInput("Confirm New Password", _confirmPasswordController, true),
                        if (_showPasswordMatchError) ...[
                          const SizedBox(height: 8),
                          Text("Passwords don't match", style: GoogleFonts.rubik(color: Colors.redAccent, fontSize: 12)),
                        ],
                        const SizedBox(height: 24),
                        _buildGenderSelector(),
                        const SizedBox(height: 40),
                        _buildIOSButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Location", style: GoogleFonts.rubik(fontSize: 14, color: const Color(0xFF1A4D9E), fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            showCountryPicker(
              context: context,
              // ✨ BUTTER YELLOW / BLUE THEME
              countryListTheme: CountryListThemeData(
                backgroundColor: const Color(0xFFFFF9C4), // Light Butter Yellow
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                textStyle: GoogleFonts.rubik(fontSize: 16, color: const Color(0xFF1A4D9E)),
                searchTextStyle: GoogleFonts.rubik(fontSize: 16, color: const Color(0xFF1A4D9E)),
                inputDecoration: InputDecoration(
                  labelText: 'Search Country',
                  labelStyle: GoogleFonts.rubik(color: const Color(0xFF1A4D9E).withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF1A4D9E)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              onSelect: (Country country) {
                setState(() {
                  _selectedCountryName = country.name;
                  _selectedCountryCode = country.countryCode;
                  _selectedCountryEmoji = country.flagEmoji;
                });
              },
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(_selectedCountryEmoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Text(_selectedCountryName, style: GoogleFonts.rubik(color: Colors.black87, fontSize: 15)),
                const Spacer(),
                const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1A4D9E), size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _cityController,
            style: GoogleFonts.rubik(color: Colors.black87, fontSize: 15),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
              hintText: "Enter City",
              hintStyle: TextStyle(fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInput(String label, TextEditingController controller, bool isPassword, {Function(String)? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.rubik(fontSize: 14, color: const Color(0xFF1A4D9E), fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            onChanged: onChanged,
            style: GoogleFonts.rubik(color: Colors.black87, fontSize: 15),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
              hintText: label.contains("Password") ? "Leave blank to keep current" : null,
              hintStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordRule(String text, bool conditionMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            conditionMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: conditionMet ? Colors.green : Colors.grey.withOpacity(0.5),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.rubik(
              fontSize: 12,
              color: conditionMet ? Colors.green.shade700 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Gender Preference", style: GoogleFonts.rubik(fontSize: 14, color: const Color(0xFF1A4D9E), fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          children: [
            _genderButton("Male", "male"),
            const SizedBox(width: 15),
            _genderButton("Female", "female"),
          ],
        ),
      ],
    );
  }

  Widget _genderButton(String title, String val) {
    bool isSelected = _selectedGender == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1A4D9E) : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(title, style: GoogleFonts.rubik(color: isSelected ? Colors.white : const Color(0xFF1A4D9E), fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  Widget _buildIOSButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _saveProfile,
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0B5184), Color(0xFF0A609F)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: _isLoading 
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text("Save Changes", style: GoogleFonts.rubik(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}