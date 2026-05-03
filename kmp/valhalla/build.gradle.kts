import java.io.FileInputStream
import java.io.IOException
import java.util.Properties
import org.jetbrains.kotlin.gradle.plugin.mpp.apple.XCFramework

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
    compilerOptions {
        freeCompilerArgs.add("-Xexpect-actual-classes")
    }

    android {
        namespace = "ch.vautherin.valhalla.kmp"
        compileSdk = 36
        minSdk = 25

        withHostTestBuilder {
        }

        withDeviceTestBuilder {
            sourceSetTreeName = "test"
        }
    }

    val nativeInterop = projectDir.resolve("src/nativeInterop/cinterop")
    val xcf = XCFramework("Valhalla")

    listOf(
        iosArm64() to "ios-device",
        iosSimulatorArm64() to "ios-simulator-arm64",
    ).forEach { (target, dir) ->
        target.compilations.getByName("main") {
            cinterops.create("ValhallaCAPI") {
                defFile(nativeInterop.resolve("ValhallaCAPI.def"))
                includeDirs(nativeInterop.resolve("$dir/include"))
                extraOpts("-libraryPath", nativeInterop.resolve("$dir/lib").absolutePath)
            }
        }
        target.binaries.framework {
            baseName = "Valhalla"
            xcf.add(this)
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
