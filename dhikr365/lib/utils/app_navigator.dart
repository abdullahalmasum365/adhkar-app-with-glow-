// ============================================================================
// lib/utils/app_navigator.dart
//
// A single GlobalKey<NavigatorState> shared across the app.
// Used by NotificationService to navigate from static tap handlers
// and by SplashScreen to handle cold-start notification launches —
// both of which run outside the normal widget-tree context.
// ============================================================================

import 'package:flutter/material.dart';

/// Pass this key to [MaterialApp.navigatorKey].
/// Anywhere else, call [appNavigatorKey.currentState?.push(...)].
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
