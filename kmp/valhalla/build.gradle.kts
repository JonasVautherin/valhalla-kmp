import java.io.FileInputStream
import java.io.IOException
import java.util.Properties

plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.android.kotlin.multiplatform.library)
}

group = "ch.vautherin"
version = "0.1.0"

// Load file "keystore.properties" where we keep our keys
val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties()

try {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} catch (ignored: IOException) {
    if (project.hasProperty("ossrhUsername")) keystoreProperties["ossrhUsername"] =
        property("ossrhUsername")
    if (project.hasProperty("ossrhPassword")) keystoreProperties["ossrhPassword"] =
        property("ossrhPassword")
}

kotlin {
    androidLibrary {
        namespace = "ch.vautherin.valhalla.kmp"
        compileSdk = 36
        minSdk = 25

        withHostTestBuilder {
        }

        withDeviceTestBuilder {
            sourceSetTreeName = "test"
        }
    }

    listOf(
        iosArm64(),
        iosSimulatorArm64(),
    ).forEach { target ->
        target.compilations.getByName("main") {
            // cinterop will be configured here in the next step
        }
    }

    sourceSets {
        commonMain.dependencies {
            implementation(libs.kotlinx.coroutines.core)
        }
        androidMain.dependencies {
            implementation(libs.kotlinx.coroutines.android)
        }
    }
}
