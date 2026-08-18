import 'package:flutter/foundation.dart';

/// Bumped when the user taps the bottom-nav tab they are ALREADY on, so that
/// tab's page can reload itself (go_router treats navigating to the current
/// location as a no-op, so tapping an active tab otherwise does nothing).
class TabRefresh {
  TabRefresh._();
  static final ValueNotifier<int> requirements = ValueNotifier<int>(0);
  static final ValueNotifier<int> vehicles = ValueNotifier<int>(0);
}
