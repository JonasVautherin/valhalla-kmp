package ch.vautherin.valhalla.kmp

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/** Valhalla costing models. */
enum class Costing(val value: String) {
    AUTO("auto"),
    PEDESTRIAN("pedestrian"),
    BICYCLE("bicycle"),
    TRUCK("truck"),
    MOTORCYCLE("motorcycle"),
    MOTOR_SCOOTER("motor_scooter"),
    BUS("bus"),
    TAXI("taxi"),
}

/**
 * Idiomatic Kotlin API for the Valhalla routing engine.
 *
 * Wraps [ValhallaEngine] with proper lifecycle management, coroutine support,
 * and structured error handling.
 *
 * Usage:
 * ```
 * val valhalla = Valhalla.create(configPath)
 * try {
 *     val response = valhalla.route(requestJson)
 * } finally {
 *     valhalla.close()
 * }
 * ```
 */
class Valhalla private constructor(private val engine: ValhallaEngine) : AutoCloseable {

    private val mutex = Mutex()
    private var closed = false

    companion object {
        /**
         * Initialise the Valhalla engine with a config JSON file and return
         * a ready-to-use [Valhalla] instance.
         *
         * This is expensive (parses the config and loads the graph reader),
         * so call it once and reuse the instance.
         *
         * @param configPath absolute path to a Valhalla config JSON file.
         */
        suspend fun create(configPath: String): Valhalla = withContext(ioDispatcher) {
            val engine = ValhallaEngine()
            engine.nativeInit(configPath)
            Valhalla(engine)
        }
    }

    /**
     * Compute a turn-by-turn route.
     *
     * @param requestJson raw Valhalla JSON request string.
     * @return raw Valhalla JSON response string.
     * @throws ValhallaException if the engine returns an error.
     * @throws IllegalStateException if [close] has already been called.
     */
    suspend fun route(requestJson: String): String = call { engine.nativeRoute(requestJson) }

    /**
     * Compute a route between two points.
     *
     * @param fromLat origin latitude.
     * @param fromLon origin longitude.
     * @param toLat   destination latitude.
     * @param toLon   destination longitude.
     * @param costing transport mode (default: [Costing.AUTO]).
     * @param language directions language (default: "en-US").
     * @return raw Valhalla JSON response string.
     * @throws ValhallaException if the engine returns an error.
     * @throws IllegalStateException if [close] has already been called.
     */
    suspend fun route(
        fromLat: Double, fromLon: Double,
        toLat: Double, toLon: Double,
        costing: Costing = Costing.AUTO,
        language: String = "en-US",
    ): String {
        val requestJson = """
            {
              "locations": [
                {"lat": $fromLat, "lon": $fromLon},
                {"lat": $toLat, "lon": $toLon}
              ],
              "costing": "${costing.value}",
              "directions_options": {"language": "$language"}
            }
        """.trimIndent()
        return route(requestJson)
    }

    /**
     * Map-match a GPS trace to the road network and return a route.
     *
     * @param requestJson raw Valhalla JSON request string containing a `shape` array.
     * @return raw Valhalla JSON response string.
     * @throws ValhallaException if the engine returns an error.
     * @throws IllegalStateException if [close] has already been called.
     */
    suspend fun traceRoute(requestJson: String): String = call { engine.nativeTraceRoute(requestJson) }

    /**
     * Map-match a GPS trace and return edge/node attributes.
     *
     * @param requestJson raw Valhalla JSON request string containing a `shape` array.
     * @return raw Valhalla JSON response string.
     * @throws ValhallaException if the engine returns an error.
     * @throws IllegalStateException if [close] has already been called.
     */
    suspend fun traceAttributes(requestJson: String): String = call { engine.nativeTraceAttributes(requestJson) }

    /**
     * Destroy the native actor and release resources.
     * Safe to call multiple times.
     */
    override fun close() {
        if (!closed) {
            closed = true
            engine.nativeDestroy()
        }
    }

    private suspend fun call(block: () -> String): String {
        mutex.withLock {
            check(!closed) { "Valhalla instance has been closed" }
            return withContext(ioDispatcher) {
                val result = block()
                ValhallaException.throwIfError(result)
                result
            }
        }
    }
}
