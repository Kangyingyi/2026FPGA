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
        versionCode = 12
        versionName = "2.1-score-row-order"
    }
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.activity:activity-ktx:1.9.3")
    implementation("com.google.mlkit:text-recognition:16.0.1")
    testImplementation("junit:junit:4.13.2")
}
