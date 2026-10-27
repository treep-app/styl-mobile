import 'package:flutter/foundation.dart';

/// Shared tab index for [ProviderShell].
/// Order matches Looksy: Home, Calendar, Clients, More.
class ProviderShellTabs {
  ProviderShellTabs._();

  static const home = 0;
  static const calendar = 1;
  static const clients = 2;
  static const more = 3;

  static final ValueNotifier<int> index = ValueNotifier<int>(home);

  static void goTo(int tab) => index.value = tab;
}
