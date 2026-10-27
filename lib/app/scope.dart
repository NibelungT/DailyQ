import 'package:flutter/material.dart';

import '../data/store.dart';

/// 轻量依赖注入：InheritedNotifier 让依赖者在 store 变更时自动重建。
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(scope?.notifier != null, 'StoreScope 不在祖先节点上');
    return scope!.notifier!;
  }
}
