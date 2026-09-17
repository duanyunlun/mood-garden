#!/usr/bin/env bash
#
# 构建 Android release APK。
#
# 保留这个脚本的原因只有一个：本机的 JDK 与 Android SDK 装在
# ~/development/toolchain 下，不在系统路径里，每次手工 export 太啰嗦。
#
# 用法：
#   tool/build_android.sh            # 通用 APK（含 arm64-v8a / armeabi-v7a / x86_64）
#   tool/build_android.sh --split    # 按 ABI 拆分，单个体积小得多，便于传输
#
# 可用环境变量覆盖默认路径：
#   MOOD_GARDEN_TOOLCHAIN   工具链根目录（默认 ~/development/toolchain）
#   FLUTTER_ROOT            Flutter SDK 根目录（默认 ~/development/flutter）
#
# 历史备注：Xcode 许可未接受时 `git` 会被拦死，导致 bin/flutter 内部的
# update_engine_version.sh 以 69 退出（Flutter Gradle 插件再调它时报
# "non-zero exit value 69"），当时这里用 FLUTTER_PREBUILT_ENGINE_VERSION 绕过。
# 开发机执行 `sudo xcodebuild -license accept` 之后，该绕过已移除。
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLCHAIN="${MOOD_GARDEN_TOOLCHAIN:-$HOME/development/toolchain}"
FLUTTER_ROOT="${FLUTTER_ROOT:-$HOME/development/flutter}"

export JAVA_HOME="$TOOLCHAIN/jdk/Contents/Home"
export ANDROID_HOME="$TOOLCHAIN/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"

cd "$PROJECT_ROOT"

if [ "${1:-}" = "--split" ]; then
  "$FLUTTER_ROOT/bin/flutter" build apk --release --split-per-abi
else
  "$FLUTTER_ROOT/bin/flutter" build apk --release
fi

echo
echo "=== 产物 ==="
ls -lh "$PROJECT_ROOT/build/app/outputs/flutter-apk/"*.apk
