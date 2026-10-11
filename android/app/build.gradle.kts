import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// android/key.properties는 git에 커밋되지 않음(android/.gitignore 참고) —
// release 서명 키스토어 정보(경로/비밀번호)를 여기서 읽어온다
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
} else if (gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }) {
    // release 빌드인데 서명 정보가 없으면 서명 단계의 알아보기 힘든 NPE 대신 원인을 바로 알려줌
    throw GradleException("android/key.properties가 없어 release 빌드를 서명할 수 없습니다. 업로드 키스토어 정보를 먼저 준비하세요.")
}

android {
    namespace = "com.woogyocheong.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.woogyocheong.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // 스토어 업로드용 빌드가 실수로 디버그 키로 서명되지 않도록 폴백을 두지 않음 —
            // key.properties가 없으면 release 빌드는 서명 단계에서 실패한다(debug 빌드는 영향 없음)
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
