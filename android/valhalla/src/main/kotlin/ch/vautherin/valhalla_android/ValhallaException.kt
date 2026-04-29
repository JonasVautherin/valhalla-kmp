package ch.vautherin.valhalla_android

import org.json.JSONObject

/**
 * Exception thrown when the Valhalla engine returns an error response.
 *
 * The C++ JNI layer returns errors as JSON: `{"code": N, "message": "..."}`.
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
         * (has "code" and "message" fields), throw a [ValhallaException].
         * Otherwise return normally.
         */
        fun throwIfError(json: String) {
            // Fast path: valid route responses start with '{"trip"' or similar,
            // never with '{"code"'. Only attempt to parse if it looks like an error.
            if (!json.contains("\"code\"")) return

            try {
                val obj = JSONObject(json)
                if (obj.has("code") && obj.has("message") && !obj.has("trip")) {
                    throw ValhallaException(
                        code = obj.getInt("code"),
                        message = obj.getString("message"),
                    )
                }
            } catch (e: ValhallaException) {
                throw e
            } catch (ignored: Exception) {
                // Not valid JSON or doesn't match error shape — not an error
            }
        }
    }
}
