import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../petals/petals_page.dart';
import '../profile/profile_page.dart';
import '../record_home/record_home_page.dart';
import '../timeline/timeline_page.dart';
import 'shell_tab_controller.dart';

/// 应用主壳 —— 四个一级 Tab 的容器。
///
/// 信息架构按原型 v5 调整：
/// - Tab1 **记录**（进入 App 的第一屏，全屏极简）
/// - Tab2 时光
/// - Tab3 花园（花瓣进度 + 花之图鉴）
/// - Tab4 我的
///
/// 与原 PRD 第 6 章相比有两处结构性变化，都是原型定下的：
///
/// 1. **记录升为一级 Tab**。它原本只是花园首页上的一张入口卡片，
///    但用户打开这个 App 是为了把一件事记下来，不是为了看数据——
///    把记录埋进二级页面，等于让最高频的动作多走一步。
/// 2. **图鉴并入花园**。「还差多少」和「已经有什么」是同一个问题的两面，
///    分成两个 Tab 反而要来回切（见 [PetalsPage] 的说明）。
///
/// 使用 [IndexedStack] 而非按需构建，让四个 Tab 的滚动位置与内部状态
/// 在切换时保持不变——用户从时光翻到花园再翻回来，不该丢失浏览位置。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// Tab 索引由 [ShellTabController] 持有，而不是本地的 state。
  ///
  /// 因为记录页右上角有个直达「我的」的入口，它需要从页面内部改索引；
  /// 用回调透传会把 MainShell 变成消息中转站。
  final ShellTabController _tabs = ShellTabController();

  static const List<Widget> _pages = <Widget>[
    RecordHomePage(),
    TimelinePage(),
    PetalsPage(),
    ProfilePage(),
  ];

  static const List<NavigationDestination> _destinations =
      <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.edit_note_outlined),
      selectedIcon: Icon(Icons.edit_note),
      label: '记录',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_today_outlined),
      selectedIcon: Icon(Icons.calendar_today),
      label: '时光',
    ),
    NavigationDestination(
      icon: Icon(Icons.local_florist_outlined),
      selectedIcon: Icon(Icons.local_florist),
      label: '花园',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: '我的',
    ),
  ];

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 用 ChangeNotifierProvider 而不是 Provider：ShellTabController 是
    // ValueNotifier（一个 Listenable），Provider 会拒绝这种类型——
    // 它会以为你期待自动重建，而 ValueNotifier 并不通知 Provider 的依赖者。
    // 这里真正负责重建的是下面的 ValueListenableBuilder。
    // 用 `.value` 形式，避免 provider 再次 dispose 这个 notifier。
    return ChangeNotifierProvider<ShellTabController>.value(
      value: _tabs,
      child: ValueListenableBuilder<int>(
        valueListenable: _tabs,
        builder: (context, currentIndex, _) {
          return Scaffold(
            body: IndexedStack(
              index: currentIndex,
              children: _pages,
            ),
            bottomNavigationBar: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.divider),
                ),
              ),
              child: NavigationBar(
                selectedIndex: currentIndex,
                onDestinationSelected: (index) {
                  if (index == currentIndex) {
                    return;
                  }
                  _tabs.value = index;
                },
                destinations: _destinations,
              ),
            ),
          );
        },
      ),
    );
  }
}
