import 'package:flutter/foundation.dart';

/// Simple global notifier to trigger UI rebuilds for follow counts
class FollowEvents {
  FollowEvents._();
  static final FollowEvents instance = FollowEvents._();

  /// Increment this to notify listeners that follow state changed
  final ValueNotifier<int> tick = ValueNotifier<int>(0);

  void notify() => tick.value++;
}

