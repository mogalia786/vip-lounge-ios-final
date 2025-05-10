import 'package:flutter/material.dart';
import '../constants/colors.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    primaryColor: AppColors.gold,
    scaffoldBackgroundColor: AppColors.black,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.black,
      foregroundColor: AppColors.gold,
      elevation: 0,
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: AppColors.blue),
      bodyMedium: TextStyle(color: AppColors.blue),
      titleLarge: TextStyle(color: AppColors.gold),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.black,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        side: BorderSide(color: AppColors.gold),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.gold),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.gold),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.gold),
      ),
      labelStyle: TextStyle(color: AppColors.gold),
      hintStyle: TextStyle(color: AppColors.gold.withOpacity(0.5)),
    ),
  );
}
