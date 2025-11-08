// 🔹 Top-level Gradle build file for Android (Kotlin DSL)

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // 🔹 Google Services (Firebase)
        classpath("com.google.gms:google-services:4.4.2")

        // 🔹 Android Gradle Plugin (Flutter kendi versiyonunu da ekler)
        classpath("com.android.tools.build:gradle:8.4.2")

        // 🔹 Kotlin Gradle Plugin
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.23")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 🔹 Flutter build klasör yönlendirmesi
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

// 🔹 "clean" komutu
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
