package ch.vautherin.valhalla.kmp

/**
 * Thin 1-to-1 Kotlin wrapper around the native Valhalla JNI functions.
 * The class must be named ValhallaEngine to match the JNI symbols in valhalla_jni.cpp.
 */
internal actual class ValhallaEngine actual constructor() {

    companion object {
        init {
            System.loadLibrary("valhalla_jni")
        }
    }

    /** Parse config JSON at [configPath] and construct the singleton actor. */
    actual external fun nativeInit(configPath: String)

    /** Destroy the singleton actor. */
    actual external fun nativeDestroy()

    /** Turn-by-turn route. Returns raw Valhalla JSON. */
    actual external fun nativeRoute(requestJson: String): String

    /** Map-match a GPS trace to the road network and return a route. */
    actual external fun nativeTraceRoute(requestJson: String): String

    /** Map-match a GPS trace and return edge/node attributes. */
    actual external fun nativeTraceAttributes(requestJson: String): String
}
