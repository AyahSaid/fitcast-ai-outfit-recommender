// ignore_for_file: deprecated_member_use
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../widgets/avatar_builder.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A4D9E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "My Favorites",
          style: GoogleFonts.rubik(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A4D9E),
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF4FC3F7), Color(0xFFB3E5FC)],
              ),
            ),
          ),
          
          // --- BACKGROUND DECORATIONS ---
          Positioned(top: 20, left: -30, child: Opacity(opacity: 0.3, child: Image.asset("assets/images/smallcloud1.png", width: 200))),
          Positioned(top: 40, right: 40, child: Opacity(opacity: 0.6, child: Image.asset("assets/images/Suggestion_bg/night_bg/star2.png", width: 40))),
          Positioned(top: 120, left: 80, child: Opacity(opacity: 0.5, child: Image.asset("assets/images/Suggestion_bg/night_bg/star1.png", width: 15))),
          Positioned(top: 150, right: -20, child: Opacity(opacity: 0.4, child: Image.asset("assets/images/smallcloud1.png", width: 150))),
          Positioned(top: 280, left: -40, child: Opacity(opacity: 0.2, child: Image.asset("assets/images/smallcloud1.png", width: 250))),
          Positioned(top: 320, right: 30, child: Opacity(opacity: 0.7, child: Image.asset("assets/images/Suggestion_bg/night_bg/star1.png", width: 45))),
          Positioned(top: 450, left: 20, child: Opacity(opacity: 0.5, child: Image.asset("assets/images/Suggestion_bg/night_bg/star1.png", width: 30))),
          Positioned(top: 500, right: 10, child: Opacity(opacity: 0.3, child: Image.asset("assets/images/smallcloud1.png", width: 180))),
          Positioned(bottom: 180, left: 100, child: Opacity(opacity: 0.6, child: Image.asset("assets/images/Suggestion_bg/night_bg/star1.png", width: 20))),
          Positioned(bottom: 220, right: -60, child: Opacity(opacity: 0.5, child: Image.asset("assets/images/smallcloud1.png", width: 280))),
          Positioned(bottom: 80, left: 10, child: Opacity(opacity: 0.4, child: Image.asset("assets/images/smallcloud1.png", width: 160))),
          Positioned(bottom: 110, right: 50, child: Opacity(opacity: 0.7, child: Image.asset("assets/images/Suggestion_bg/night_bg/star1.png", width: 35))),
          Positioned(bottom: 40, left: 60, child: Opacity(opacity: 0.5, child: Image.asset("assets/images/Suggestion_bg/night_bg/star1.png", width: 25))),

          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('favorites')
                  .where('userId', isEqualTo: _uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(includeMetadataChanges: true),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error loading favorites", style: GoogleFonts.rubik(color: Colors.red)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1A4D9E)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final docs = snapshot.data!.docs;

                return PageView.builder(
                  controller: PageController(viewportFraction: 0.88),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id;
                    return _buildFavoriteCard(data, docId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> data, String docId) {
    String gender = data['gender'] ?? 'female';
    Map<String, String> outfit = Map<String, String>.from(data['outfit']);
    
    // 👇 Hijab Support
    bool isHijabi = data['isHijabi'] == true;

    // Date Logic
    String dateStr = "Recently";
    if (data['timestamp'] != null) {
      dateStr = DateFormat('MMM d, y').format((data['timestamp'] as Timestamp).toDate());
    }

    // Temperature Logic (Robust Check)
    String tempStr = "--°";
    if (data['temperature'] != null) {
      tempStr = "${(data['temperature'] as num).round()}°";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 30),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(color: Colors.white.withOpacity(0.4)),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    // 1. PUSH DOWN to clear Trash Icon space
                    const SizedBox(height: 60),

                    // 2. Date & Temp Row (Left Aligned for cleaner look)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildPill(Icons.calendar_today_rounded, dateStr),
                          const SizedBox(width: 8),
                          _buildPill(Icons.thermostat_rounded, tempStr),
                        ],
                      ),
                    ),

                    const SizedBox(height: 15),
                    Icon(Icons.favorite_rounded, color: Colors.redAccent.withOpacity(0.8), size: 36),
                    Text(
                      data['activity'] ?? "Perfect Look",
                      style: GoogleFonts.rubik(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A4D9E)),
                    ),
                    const Spacer(),
                    
                    // Avatar Call
                    AvatarBuilder.build(
                      gender: gender,
                      outfit: outfit,
                      height: MediaQuery.of(context).size.height * 0.42, 
                      isHijabi: isHijabi,
                    ),
                    
                    const Spacer(),
                    _buildDescription(outfit),
                    const SizedBox(height: 20),
                  ],
                ),
                
                // 3. Trash Icon (Fixed Top Right)
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
                      onPressed: () => _confirmDelete(docId),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1A4D9E).withOpacity(0.7)),
          const SizedBox(width: 5),
          Text(text, style: GoogleFonts.rubik(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1A4D9E))),
        ],
      ),
    );
  }

  Widget _buildDescription(Map<String, String> outfit) {
    String top = outfit['top']?.replaceAll('_', ' ') ?? 'top';
    String bottom = outfit['bottom']?.replaceAll('_', ' ') ?? 'bottom';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "Your favorite $top and $bottom combo.",
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
      ),
    );
  }

  Future<void> _confirmDelete(String docId) async {
    bool? del = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Remove Favorite?"),
        content: const Text("This outfit will be removed from your favorites list."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Keep it")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Remove", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (del == true) {
      await FirebaseFirestore.instance.collection('favorites').doc(docId).delete();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border_rounded, size: 100, color: Colors.white.withOpacity(0.6)),
          const SizedBox(height: 20),
          Text(
            "No favorites saved yet!",
            style: GoogleFonts.rubik(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}