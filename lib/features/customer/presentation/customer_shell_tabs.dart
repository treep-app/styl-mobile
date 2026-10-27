import 'package:flutter/foundation.dart';

/// Shared tab index for [CustomerShell].
/// Order matches the attached home: Home, Explore, Bookings, Saved, Profile.
class CustomerShellTabs {
  CustomerShellTabs._();

  static const home = 0;
  static const explore = 1;
  static const appointments = 2;
  static const saved = 3;
  static const profile = 4;

  static final ValueNotifier<int> index = ValueNotifier<int>(home);

  static void goTo(int tab) => index.value = tab;
}
