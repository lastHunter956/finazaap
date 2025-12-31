import 'package:flutter/material.dart';

class AppIcons {
  // Prevent instantiation
  AppIcons._();

  // Centralized list of all allowed icons in the app
  static const List<IconData> allIcons = [
    Icons.fastfood, Icons.restaurant, Icons.local_cafe, Icons.local_bar,
    Icons.shopping_bag, Icons.shopping_cart, Icons.credit_card, Icons.receipt,
    Icons.directions_car, Icons.directions_bus, Icons.flight, Icons.hotel,
    Icons.home, Icons.build, Icons.lightbulb, Icons.wifi,
    Icons.health_and_safety, Icons.local_hospital, Icons.fitness_center, Icons.spa,
    Icons.school, Icons.book, Icons.work, Icons.computer,
    Icons.phone_android, Icons.tv, Icons.videogame_asset, Icons.music_note,
    Icons.pets, Icons.child_friendly, Icons.card_giftcard, Icons.savings,
    Icons.account_balance, Icons.attach_money, Icons.trending_up, Icons.category,
    // Add other icons used elsewhere in the app if they are dynamic
    Icons.swap_horiz_rounded, Icons.north_rounded, Icons.south_rounded,
    Icons.sync_alt, Icons.arrow_downward_rounded, Icons.arrow_upward_rounded,
    Icons.account_balance_wallet,
  ];

  // Map for fast lookup by codePoint
  static final Map<int, IconData> _codePointMap = {
    for (var icon in allIcons) icon.codePoint: icon,
  };

  /// Retrieves an IconData from a codePoint assuming it's in the allowed list.
  /// Returns a default icon (Icons.help_outline) if not found, 
  /// ensuring we never return a dynamically created IconData that violates tree shaking.
  static IconData getIcon(int codePoint) {
    return _codePointMap[codePoint] ?? Icons.category;
  }
}
