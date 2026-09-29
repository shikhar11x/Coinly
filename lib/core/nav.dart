import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which bottom-nav tab is selected (0 Home, 1 Transactions, 2 Assistant, 3 Profile).
class TabIndex extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) => state = index;
}

final tabIndexProvider = NotifierProvider<TabIndex, int>(TabIndex.new);