plugins {
    id("com.android.application")
}

android {
    namespace = "cn.codex.fpga_music"
    compileSdk = 37

    defaultConfig {
        applicationId = "cn.codex.fpga_music"
        minSdk = 23
        targetSdk = 35
        versionCode = 8
        versionName = "1.7-audio-effects-octaves"
    }
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.activity:activity-ktx:1.9.3")
}
