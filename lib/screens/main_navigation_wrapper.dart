// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Needed for SystemNavigator
import 'outfit_suggestion_screen.dart'; 
import 'weather_overview_screen.dart'; 

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  // Start at page 0 (Outfit Screen)
  final PageController _controller = PageController(initialPage: 0);

  @override
  Widget build(BuildContext context) {
    // 🔒 PopScope prevents the "Swipe Back" gesture from closing the app
    // canPop: false -> Disables system back button/gesture
    return PopScope(
      canPop: false, 
      onPopInvoked: (didPop) {
        if (didPop) return;
        // Optional: You could show a "Do you want to exit?" dialog here
        // For now, we just do nothing so the user stays on the screen.
      },
      child: Scaffold(
        body: PageView(
          controller: _controller,
          physics: const ClampingScrollPhysics(), // Gives that solid "snap" feel
          children: const [
            // 1. First Screen (Home / Default)
            OutfitSuggestionScreen(),   
            
            // 2. Second Screen (Swipe LEFT to see this)
            WeatherOverviewScreen(),    
          ],
        ),
      ),
    );
  }
}