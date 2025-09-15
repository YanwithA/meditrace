// Top-level build.gradle.kts
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.3.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.22") // Use compatible version
        classpath("com.google.gms:google-services:4.4.0") // Add this here
    }
}

plugins {
    id("com.google.gms.google-services") version "4.4.0" apply false
}

// Optional: set namespace as an extra value
val appNamespace by extra("com.example.meditrace")

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// NDK version configuration
val ndkVersion by extra("27.0.12077973")

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Apply NDK version to all subprojects
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.application") ||
            project.plugins.hasPlugin("com.android.library")) {
            extensions.configure<com.android.build.gradle.BaseExtension> {
                ndkVersion = rootProject.extra["ndkVersion"] as String
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}