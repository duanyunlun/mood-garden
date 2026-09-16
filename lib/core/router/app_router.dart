import 'package:flutter/material.dart';

import '../../features/codex/codex_page.dart';
import '../../features/record_happy/record_happy_page.dart';
import '../../features/record_unhappy/record_unhappy_page.dart';
import '../../features/timeline/date_detail_page.dart';

/// 页面路由。
///
/// 采用集中式静态方法而非命名路由表：类型安全（参数在编译期校验）、
/// 无需维护字符串常量与 `arguments` 的动态转换。
abstract final class AppRouter {
  /// 记录开心事页（PRD 7.1.1）。
  static Future<T?> pushRecordHappy<T>(BuildContext context) {
    return Navigator.of(context).push<T>(
      _softRoute<T>(const RecordHappyPage()),
    );
  }

  /// 记录不开心事（情绪纸卷）页（PRD 7.2.1）。
  static Future<T?> pushRecordUnhappy<T>(BuildContext context) {
    return Navigator.of(context).push<T>(
      _softRoute<T>(const RecordUnhappyPage()),
    );
  }

  /// 时光轴日期详情页（PRD Tab2）。
  static Future<T?> pushDateDetail<T>(BuildContext context, DateTime day) {
    return Navigator.of(context).push<T>(
      _softRoute<T>(DateDetailPage(day: day)),
    );
  }

  /// 花之图鉴详情页。骨架期复用图鉴页（详情页待设计细化后补充）。
  static Future<T?> pushCodex<T>(BuildContext context) {
    return Navigator.of(context).push<T>(
      _softRoute<T>(const CodexPage()),
    );
  }

  /// 统一使用柔和的淡入 + 轻微上移过渡，替代平台默认的横向推入，
  /// 呼应 PRD 11.3「整体交互节奏偏慢、偏柔和」的要求。
  static PageRoute<T> _softRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
