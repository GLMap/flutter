allprojects {
    repositories {
        System.getenv("GLMAP_SDK_DIR")?.let { maven { url = uri(file(it).resolve("maven")) } }
        google()
        mavenCentral()
        maven { url = uri("https://maven.globus.software/artifactory/libs") }
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
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
