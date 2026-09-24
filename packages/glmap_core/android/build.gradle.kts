import groovy.json.JsonSlurper

plugins { id("com.android.library") }
group = "software.globus.glmap_core"
version = "0.1.0-beta.1"
val sdkDirectory = System.getenv("GLMAP_SDK_DIR")?.let(::file)
val sdkVersion = sdkDirectory?.let {
    (JsonSlurper().parse(it.resolve("sdk.json")) as Map<*, *>)["version"] as String
} ?: "2.2.0"
repositories {
    sdkDirectory?.let { maven { url = uri(it.resolve("maven")) } }
    google(); mavenCentral()
    maven { url = uri("https://maven.globus.software/artifactory/libs") }
}
android {
    namespace = "software.globus.flutter.core"
    compileSdk = 36
    defaultConfig { minSdk = 24 }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    sourceSets.getByName("main").java.srcDir("src/main/kotlin")
}
kotlin { compilerOptions { jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17 } }
dependencies {
    implementation("globus:glmapcore:$sdkVersion")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
}
