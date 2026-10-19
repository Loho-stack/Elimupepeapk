plugins {
    id("com.google.gms.google-services") version "4.4.4" apply false
    id("com.google.firebase.crashlytics") version "3.0.6" apply false
    id("com.google.firebase.firebase-perf") version "2.0.2" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    val forceCompileSdk: Project.() -> Unit = {
        if (name != "app") {
            extensions.findByName("android")?.let { ext ->
                try {
                    ext.javaClass
                        .getMethod("setCompileSdk", Integer::class.javaObjectType)
                        .invoke(ext, 36)
                } catch (e: Exception) {
                    logger.warn("compileSdk override skipped for $name: ${e.message}")
                }
            }
        }
    }
    if (state.executed) forceCompileSdk() else afterEvaluate { forceCompileSdk() }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
