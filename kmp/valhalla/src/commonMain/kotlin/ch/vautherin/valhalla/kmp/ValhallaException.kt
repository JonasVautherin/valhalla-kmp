package ch.vautherin.valhalla.kmp

/**
 * Exception thrown when the Valhalla engine returns an error response.
 *
 * The native layer returns errors as JSON: `{"code": N, "message": "..."}`.
 * This exception captures both the Valhalla error code and human-readable message.
 *
 * @property code Valhalla error code, or -1 for generic/unknown errors.
 * @property message human-readable error description from the engine.
 */
class ValhallaException(
    val code: Int,
    override val message: String,
) : RuntimeException("Valhalla error $code: $message") {

    internal companion object {
        /**
         * Inspect a JSON response string. If it looks like an error object
         * (has "code" and "message" fields but no "trip"), throw a [ValhallaException].
         * Otherwise return normally.
         */
        fun throwIfError(json: String) {
            if (!json.contains("\"code\"")) return
            if (json.contains("\"trip\"")) return

            try {
                val code = Regex("\"code\"\\s*:\\s*(-?\\d+)").find(json)?.groupValues?.get(1)?.toInt()
                    ?: return
                val message = Regex("\"message\"\\s*:\\s*\"([^\"]*?)\"").find(json)?.groupValues?.get(1)
                    ?: return
                throw ValhallaException(code = code, message = message)
            } catch (e: ValhallaException) {
                throw e
            } catch (_: Exception) {
                // Not valid or doesn't match error shape — not an error
            }
        }
    }
}
