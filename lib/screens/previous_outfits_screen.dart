// ignore_for_file: deprecated_member_use
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; 
import '../widgets/avatar_builder.dart';

class PreviousOutfitsScreen extends StatefulWidget {
  const PreviousOutfitsScreen({super.key});

  @override
  State<PreviousOutfitsScreen> createState() => _PreviousOutfitsScreenState();
}

class _PreviousOutfitsScreenState extends State<PreviousOutfitsScreen> {
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), // ✨ Changed to white for better contrast
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Outfit History",
          style: GoogleFonts.rubik(
            fontWeight: FontWeight.w700,
            color: Colors.white, // ✨ Changed to white for better contrast
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // ✨ UPDATED: Gradient Background with deeper top shade
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF4FC3F7), // ✨ Darker Sky Blue top
                  Color(0xFFB3E5FC), // ✨ Original light blue bottom
                ],
              ),
            ),
          ),

          // ✨ DENSE BACKGROUND DECORATIONS (Stars & Clouds)
          Positioned(top: 60, left: -30, child: Opacity(opacity: 0.3, child: Image.asset("assets/images/smallcloud1.png", width: 200))),
          Positioned(top: 150, right: -20, child: Opacity(opacity: 0.4, child: Image.asset("assets/images/smallcloud1.png", width: 150))),
          Positioned(top: 100, right: 30, child: Opacity(opacity: 0.9, child: Image.asset("assets/images/Suggestion_bg/night_bg/star1.png", width: 40))),
          Positioned(top: 250, left: 40, child: Opacity(opacity: 0.5, child: Image.asset("assets/images/Suggestion_bg/night_bg/star1.png", width: 25))),
          Positioned(top: 400, right: 20, child: Opacity(opacity: 0.7, child: Image.asset("assets/images/Suggestion_bg/night_bg/star1.png", width: 35))),
          Positioned(bottom: 200, left: -40, child: Opacity(opacity: 0.3, child: Image.asset("assets/images/smallcloud1.png", width: 250))),
          Positioned(bottom: 120, right: 40, child: Opacity(opacity: 0.5, child: Image.asset("assets/images/Suggestion_bg/night_bg/star1.png", width: 30))),
          Positioned(bottom: 50, left: 20, child: Opacity(opacity: 0.4, child: Image.asset("assets/images/Suggestion_bg/night_bg/star1.png", width: 30))),

          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('outfit_history')
                  .where('userId', isEqualTo: _uid)
                  .orderBy('timestamp', descending: true)
                  .limit(7)
                  .snapshots(includeMetadataChanges: true), 
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      color: Colors.red.withOpacity(0.8),
                      child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final docs = snapshot.data!.docs;

                return PageView.builder(
                  controller: PageController(viewportFraction: 0.85),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _buildOutfitCard(data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutfitCard(Map<String, dynamic> data) {
    DateTime date = DateTime.now();
    if (data['timestamp'] != null) {
      date = (data['timestamp'] as Timestamp).toDate();
    }
    
    String formattedDate = DateFormat('EEEE, MMM d').format(date);
    String gender = data['gender'] ?? 'female';
    Map<String, String> outfit = Map<String, String>.from(data['outfit'] ?? {});

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.65), // ✨ Slightly more opaque for better readability
              borderRadius: BorderRadius.circular(35),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  formattedDate,
                  style: GoogleFonts.rubik(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A4D9E),
                  ),
                ),
                Text(
                  data['activity'] ?? "Daily Look",
                  style: GoogleFonts.rubik(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const Spacer(),
                
                AvatarBuilder.build(
                  gender: gender,
                  outfit: outfit,
                  height: MediaQuery.of(context).size.height * 0.45,
                ),
                
                const Spacer(),
                
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "You wore a ${outfit['top']?.replaceAll('_', ' ')} and ${outfit['bottom']?.replaceAll('_', ' ')} with ${outfit['shoes']?.replaceAll('_', ' ')}.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.rubik(fontSize: 13, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Icon(Icons.history, size: 80, color: Colors.white.withOpacity(0.5)),
          const SizedBox(height: 20),
          Text(
            "No history yet!",
            style: GoogleFonts.rubik(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }
}