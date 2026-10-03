import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'login_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                // Top official logos header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/sviet_logo.png', height: 48, fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Text('SVIET', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                    ),
                    Container(height: 32, width: 1, color: AppColors.textGray.withOpacity(0.3), margin: const EdgeInsets.symmetric(horizontal: 16)),
                    Image.asset('assets/s60_logo.png', height: 48, fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Text('SUPER60', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // Headline matching the design mockup exactly
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "S60",
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryOrange,
                          height: 1.1,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const Text(
                        "Inventory &",
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryNavy,
                          height: 1.1,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const Text(
                        "Rewards Portal",
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryOrange,
                          height: 1.1,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Manage event inventory and student rewards, all in one place.",
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textGray,
                          height: 1.4,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(width: 48, height: 3, decoration: BoxDecoration(color: AppColors.primaryOrange, borderRadius: BorderRadius.circular(2))),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // SVIET Campus Hero Visual with rounded card
                Container(
                  width: double.infinity,
                  height: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/sviet_campus.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.secondaryLightOrange,
                        child: const Center(
                          child: Icon(Icons.school, size: 64, color: AppColors.primaryOrange),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Primary CTA: Admin Login ->
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 2,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Admin Login",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Footer branding
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "S60   |   SVIET",
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryNavy,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(width: 32, height: 2, color: AppColors.primaryOrange),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
