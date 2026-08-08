import org.jetbrains.kotlin.gradle.plugin.mpp.apple.XCFramework

plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.android.kotlin.multiplatform.library)
    alias(libs.plugins.maven.publish)
}

group = "ch.vautherin"

// Pushes to main publish this; a release tag overrides it with -PVERSION=x.y.z. Bump it after a release.
val fallbackVersion = "0.1.0-SNAPSHOT"
version = project.findProperty("VERSION")?.toString() ?: fallbackVersion

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

val repositoryRoot = layout.projectDirectory.dir("../..")
val thirdPartySbom = repositoryRoot.file("dist/third-party.cdx.json").asFile
val thirdPartyNotices = repositoryRoot.file("dist/THIRD-PARTY-NOTICES.txt").asFile

mavenPublishing {
    publishToMavenCentral()
    signAllPublications()
    coordinates(group.toString(), "valhalla", version.toString())

    pom {
        name = "Valhalla KMP"
        description = "Offline routing for Kotlin Multiplatform, wrapping Valhalla built for Android and iOS."
        url = "https://github.com/JonasVautherin/valhalla-kmp"
        // The wrapper only; the statically linked native licences are in the attribution artifacts below.
        licenses {
            license {
                name = "Mozilla Public License 2.0"
                url = "https://www.mozilla.org/en-US/MPL/2.0/"
                distribution = "repo"
            }
        }
        developers {
            developer {
                id = "JonasVautherin"
                name = "Jonas Vautherin"
                url = "https://github.com/JonasVautherin"
            }
        }
        scm {
            url = "https://github.com/JonasVautherin/valhalla-kmp"
            connection = "scm:git:https://github.com/JonasVautherin/valhalla-kmp.git"
            developerConnection = "scm:git:ssh://git@github.com/JonasVautherin/valhalla-kmp.git"
        }
    }
}

publishing {
    publications.withType<MavenPublication>().configureEach {
        // Root publication only: attaching to each target would publish the same 40 KB four more times.
        if (name != "kotlinMultiplatform") {
            return@configureEach
        }
        artifact(thirdPartySbom) {
            classifier = "cyclonedx"
            extension = "json"
        }
        artifact(thirdPartyNotices) {
            classifier = "third-party-notices"
            extension = "txt"
        }
    }
}
