plugins {
  id("com.android.application")
  id("org.jetbrains.kotlin.android")
}

android {
  namespace = "co.displaydeck.player"
  compileSdk = 34

  buildFeatures {
    buildConfig = true
  }

  signingConfigs {
    create("release") {
      storeFile = file("release-keystore.jks")
      storePassword = "displaydeck123"
      keyAlias = "displaydeck"
      keyPassword = "displaydeck123"
    }
  }

  defaultConfig {
    applicationId = "co.displaydeck.player"
    minSdk = 24
    targetSdk = 33
    versionCode = 8
    versionName = "0.2.6"

    // If you self-host on http:// LAN later, this avoids surprises.
    manifestPlaceholders["usesCleartextTraffic"] = "true"
  }

  buildTypes {
    release {
      isMinifyEnabled = false
      signingConfig = signingConfigs.getByName("release")
      proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
    }
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }

  kotlinOptions {
    jvmTarget = "17"
  }
}

dependencies {
  implementation("androidx.core:core-ktx:1.12.0")
  implementation("androidx.appcompat:appcompat:1.6.1")
  implementation("com.google.android.material:material:1.11.0")

  // Native campaign video playback (more reliable than WebView HTML video).
  implementation("androidx.media3:media3-exoplayer:1.2.1")
  implementation("androidx.media3:media3-ui:1.2.1")
}
