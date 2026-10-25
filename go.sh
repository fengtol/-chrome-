#!/bin/sh
set -e

mkdir -p app/src/main/res/values
mkdir -p app/src/main/java/com/example/dnsclear
mkdir -p .github/workflows

cat > settings.gradle <<'EOF'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        maven { url 'https://maven.rosan.dev/releases' }
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven { url 'https://maven.rosan.dev/releases' }
    }
}
rootProject.name = "DnsClear"
include ':app'
EOF

cat > build.gradle <<'EOF'
plugins {
    id 'com.android.application' version '8.2.2' apply false
}
EOF

cat > gradle.properties <<'EOF'
org.gradle.jvmargs=-Xmx2048m
android.useAndroidX=true
EOF

cat > app/build.gradle <<'EOF'
plugins {
    id 'com.android.application'
}

android {
    namespace 'com.example.dnsclear'
    compileSdk 34

    defaultConfig {
        applicationId "com.example.dnsclear"
        minSdk 24
        targetSdk 34
        versionCode 1
        versionName "1.0"
    }

    buildTypes {
        release {
            minifyEnabled false
        }
    }
}

dependencies {
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.rosan.dhizuku:dhizuku-api:2.6.0'
}
EOF

cat > app/src/main/AndroidManifest.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="com.rosan.dhizuku.permission.API_V1" />
    <application
        android:allowBackup="true"
        android:label="DnsClear"
        android:supportsRtl="true"
        android:theme="@style/Theme.AppCompat.DayNight.NoActionBar">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

cat > app/src/main/res/values/strings.xml <<'EOF'
<resources>
    <string name="app_name">DnsClear</string>
</resources>
EOF

cat > app/src/main/java/com/example/dnsclear/MainActivity.kt <<'EOF'
package com.example.dnsclear

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.ServiceConnection
import android.os.Bundle
import android.os.IBinder
import android.widget.Button
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.rosan.dhizuku.Dhizuku
import com.rosan.dhizuku.DhizukuRequestPermissionListener
import com.rosan.dhizuku.IDhizuku

class MainActivity : AppCompatActivity() {
    private val CHROME = "com.android.chrome"

    private val conn = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            try {
                val dhizuku = IDhizuku.Stub.asInterface(service)
                val dpm = dhizuku.devicePolicyManager
                val admin = ComponentName(dhizuku.ownerPackageName, dhizuku.ownerComponentName)
                dpm.setApplicationRestrictions(admin, CHROME, Bundle())
                Toast.makeText(this@MainActivity,
                    "已清除 Chrome 策略，去 chrome://policy 重新加载确认", Toast.LENGTH_LONG).show()
            } catch (e: Exception) {
                Toast.makeText(this@MainActivity, "执行失败: ${e.message}", Toast.LENGTH_LONG).show()
            }
        }
        override fun onServiceDisconnected(name: ComponentName?) {}
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Dhizuku.init(this)
        val btn = Button(this).apply {
            text = "清除 Chrome DoH 策略"
            setOnClickListener {
                if (Dhizuku.isPermissionGranted) {
                    Dhizuku.bindService(conn)
                } else {
                    Dhizuku.requestPermission(object : DhizukuRequestPermissionListener() {
                        override fun onRequestPermission(grantResult: Int) {
                            if (grantResult == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                                Dhizuku.bindService(conn)
                            } else {
                                Toast.makeText(this@MainActivity, "未获得 Dhizuku 授权", Toast.LENGTH_SHORT).show()
                            }
                        }
                    })
                }
            }
        }
        setContentView(btn)
    }
}
EOF

cat > .github/workflows/build.yml <<'EOF'
name: Build Debug APK

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - name: Setup Android SDK
        uses: android-actions/setup-android@v3

      - name: Accept licenses and install SDK
        run: |
          yes | sdkmanager --licenses || true
          sdkmanager "platforms;android-34" "build-tools;34.0.0"

      - name: Build APK
        uses: gradle/gradle-build-action@v3
        with:
          gradle-version: 8.4
          arguments: :app:assembleDebug

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: app-debug
          path: app/build/outputs/apk/debug/*.apk
EOF

echo "已生成全部文件:"
find . -type f -not -path './.git/*' | sort