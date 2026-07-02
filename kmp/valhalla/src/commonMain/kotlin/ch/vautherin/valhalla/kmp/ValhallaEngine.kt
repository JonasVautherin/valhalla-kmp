package ch.vautherin.valhalla.kmp

internal expect class ValhallaEngine() {
    fun nativeInit(configPath: String)
    fun nativeDestroy()
    fun nativeRoute(requestJson: String): String
    fun nativeOptimizedRoute(requestJson: String): String
    fun nativeTraceRoute(requestJson: String): String
    fun nativeTraceAttributes(requestJson: String): String
}
