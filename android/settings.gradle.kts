pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        // 只用国内镜像：本网络环境下 maven.google.com 连接超时不可达，
        // 而 Android Gradle Plugin 与 Kotlin 插件都托管在 Google Maven 上，
        // 走官方源会让每次坐标解析都先等一轮超时。
        // 需要换回官方源时，把 google() / mavenCentral() / gradlePluginPortal()
        // 加回本列表即可——阿里云镜像收录了这三者的全部坐标。
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")
