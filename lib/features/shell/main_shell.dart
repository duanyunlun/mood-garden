import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../codex/codex_page.dart';
import '../garden/garden_home_page.dart';
import '../profile/profile_page.dart';
import '../timeline/timeline_page.dart';

/// 应用主壳 —— 四个一级 Tab 的容器。
///
/// 严格对应 PRD 第 6 章「产品信息架构图」：
/// - Tab1 花园首页（核心视觉入口）
/// - Tab2 时光轴（日历 / 多视图回顾）
/// - Tab3 花之图鉴
/// - Tab4 我的
///
/// 使用 [IndexedStack] 而非按需构建，让四个 Tab 的滚动位置与内部状态
/// 在切换时保持不变——用户从时光轴翻到花园再翻回来，不该丢失浏览位置。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const List<Widget> _pages = <Widget>[
    GardenHomePage(),
    TimelinePage(),
    CodexPage(),
    ProfilePage(),
  ];

  static const List<NavigationDestination> _destinations =
      <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.local_florist_outlined),
      selectedIcon: Icon(Icons.local_florist),
      label: '花园',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_today_outlined),
      selectedIcon: Icon(Icons.calendar_today),
      label: '时光轴',
    ),
    NavigationDestination(
      icon: Icon(Icons.menu_book_outlined),
      selectedIcon: Icon(Icons.menu_book),
      label: '图鉴',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: '我的',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.divider),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            if (index == _currentIndex) {
              return;
            }
            setState(() => _currentIndex = index);
          },
          destinations: _destinations,
        ),
      ),
    );
  }
}
