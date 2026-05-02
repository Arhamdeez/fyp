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
    project.evaluationDependsOn(":app")
}

// flutter_bluetooth_serial 0.4.0 has no `namespace` (required by AGP 8+). Set it when the library plugin applies.
subprojects {
    if (name != "flutter_bluetooth_serial") {
        return@subprojects
    }
    pluginManager.withPlugin("com.android.library") {
        val android = extensions.getByName("android")
        val getNs = android.javaClass.methods.firstOrNull { it.name == "getNamespace" && it.parameterCount == 0 }
        val current = runCatching { getNs?.invoke(android) as? String }.getOrNull()
        if (current.isNullOrBlank()) {
            val setNs =
                android.javaClass.methods.firstOrNull {
                    it.name == "setNamespace" && it.parameterCount == 1 && it.parameterTypes[0] == String::class.java
                }
            setNs?.invoke(android, "io.github.edufolly.flutterbluetoothserial")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
