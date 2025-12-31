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

  defaultConfig {
    applicationId = "co.displaydeck.player"
    minSdk = 24
    targetSdk = 33
    versionCode = 1
    versionName = "0.1.0"

    // If you self-host on http:// LAN later, this avoids surprises.
    manifestPlaceholders["usesCleartextTraffic"] = "true"
  }

  buildTypes {
    release {
      isMinifyEnabled = false
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
}
