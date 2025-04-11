import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // You might need to add this package
import 'package:pronounce_it_right/screen/home.dart';
import 'package:pronounce_it_right/screen/practice_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  void _navigateToHome() {
    Timer(const Duration(seconds: 3), () {
      // Ensure the widget is still mounted before navigating
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Optional: Add a background color or image
      // backgroundColor: Colors.blueAccent,
      body: Center(
        // Use a Column to stack the texts vertically
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center the column content vertically
          children: [
            Text(
              'Pronounce It Right',
              textAlign: TextAlign.center, // Ensure text is centered if it wraps
              style: GoogleFonts.pacifico( // Example font, choose one you like!
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor, // Use your theme's primary color
              ),
            ),
            const SizedBox(height: 04), // Add some space between the texts
            Text(
              'Prononcez-le bien', // The French translation
              textAlign: TextAlign.center,
              style: GoogleFonts.podkova( // Use a different font or style if desired
                
               
                color: Theme.of(context).colorScheme.secondary, // Use a secondary color
              ),
            ),
          ],
        ),
      ),
    );
  }
}
