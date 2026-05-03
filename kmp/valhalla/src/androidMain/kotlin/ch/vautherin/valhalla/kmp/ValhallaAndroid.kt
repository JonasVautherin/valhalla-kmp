package ch.vautherin.valhalla.kmp

import kotlinx.coroutines.withContext
import java.io.File

/**
 * Convenience: write the default config for [filesDir] and initialise.
 */
suspend fun Valhalla.Companion.create(filesDir: File): Valhalla {
    val configPath = withContext(ioDispatcher) {
        ValhallaConfig.writeConfig(filesDir)
    }
    return create(configPath)
}
