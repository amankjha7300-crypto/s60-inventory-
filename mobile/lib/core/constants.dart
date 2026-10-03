import 'package:flutter/material.dart';

class AppColors {
  // Brand Primary Visual Palette (as specified in Master Prompt & Styleboard)
  static const Color primaryOrange = Color(0xFFF47B20);
  static const Color primaryNavy = Color(0xFF0F2B5B);
  static const Color background = Color(0xFFFFF8E8);
  static const Color secondaryLightOrange = Color(0xFFFFD7B3);
  static const Color lightSurface = Color(0xFFEEF2F7);
  static const Color textGray = Color(0xFF4B5563);
  static const Color white = Color(0xFFFFFFFF);
  
  // Status Colors
  static const Color statusDistributed = Color(0xFF10B981); // Green
  static const Color statusPending = Color(0xFFF59E0B);     // Orange / Amber
  static const Color statusPartial = Color(0xFF3B82F6);     // Blue
  static const Color statusOutOfStock = Color(0xFFEF4444);  // Red
  static const Color statusCancelled = Color(0xFF9CA3AF);   // Gray
  static const Color borderSubtle = Color(0xFFE5E7EB);
}

class AppConstants {
  static const String appName = "S60 Inventory & Rewards";
  static const String appSubtitle = "Management Portal";
  static const String institutionName = "Swami Vivekanand Group of Institutes (SVIET)";
  static const String departmentName = "Super60 / Department of Computer Science & Engineering";

  // Centralized API Base URL configuration
  // For physical Android device over Wi-Fi (Current Host IP):
  static const String defaultApiBaseUrl = "http://192.168.31.19:8000/api/v1";
}
