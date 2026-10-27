import 'package:flutter/material.dart';

/// Root navigator key — use for overlays that sit above [MaterialApp]'s route
/// tree (e.g. notification snackbars in [NotificationHost]).
final GlobalKey<NavigatorState> stylNavigatorKey = GlobalKey<NavigatorState>();
