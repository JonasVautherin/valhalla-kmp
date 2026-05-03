package ch.vautherin.valhalla.kmp

import ValhallaCAPI.*
import cnames.structs.ValhallActor
import kotlinx.cinterop.*

/**
 * iOS implementation of [ValhallaEngine] using the C API via cinterop.
 */
@OptIn(ExperimentalForeignApi::class)
internal actual class ValhallaEngine actual constructor() {

    private var actor: CPointer<ValhallActor>? = null

    /** Parse config JSON at [configPath] and construct the actor. */
    actual fun nativeInit(configPath: String) {
        memScoped {
            val errorPtr = allocPointerTo<ByteVar>()
            actor = valhalla_create(configPath, errorPtr.ptr)
            if (actor == null) {
                val error = errorPtr.value?.toKString() ?: "unknown error"
                valhalla_free_string(errorPtr.value)
                throw RuntimeException("Failed to init Valhalla: $error")
            }
        }
    }

    /** Destroy the actor. */
    actual fun nativeDestroy() {
        valhalla_destroy(actor)
        actor = null
    }

    /** Turn-by-turn route. Returns raw Valhalla JSON. */
    actual fun nativeRoute(requestJson: String): String {
        return callAndFree(valhalla_route(actor, requestJson))
    }

    /** Map-match a GPS trace to the road network and return a route. */
    actual fun nativeTraceRoute(requestJson: String): String {
        return callAndFree(valhalla_trace_route(actor, requestJson))
    }

    /** Map-match a GPS trace and return edge/node attributes. */
    actual fun nativeTraceAttributes(requestJson: String): String {
        return callAndFree(valhalla_trace_attributes(actor, requestJson))
    }

    private fun callAndFree(result: CPointer<ByteVar>?): String {
        if (result == null) return "{\"code\":-1,\"message\":\"null result from native\"}"
        val str = result.toKString()
        valhalla_free_string(result)
        return str
    }
}
