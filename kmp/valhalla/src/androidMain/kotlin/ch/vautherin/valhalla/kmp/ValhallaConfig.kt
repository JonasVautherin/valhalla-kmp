package ch.vautherin.valhalla.kmp

import java.io.File

/**
 * Writes a Valhalla config JSON file from the bundled defaults,
 * overriding the tile/admin/timezone paths for the local device.
 */
object ValhallaConfig {

    /**
     * Write a config JSON file to [filesDir]/valhalla.json, pointing
     * at the tile extract and optional admin/timezone databases.
     *
     * @param filesDir       the app's internal files directory.
     * @param tileExtract    path to valhalla_tiles.tar (default: filesDir/valhalla_tiles.tar).
     * @param admin          path to admins.sqlite (default: filesDir/admins.sqlite).
     * @param timezone       path to timezones.sqlite (default: filesDir/timezones.sqlite).
     * @param configFileName name of the output file (default: "valhalla.json").
     * @return absolute path to the written config file.
     */
    fun writeConfig(
        filesDir: File,
        tileExtract: String = "${filesDir}/valhalla_tiles.tar",
        admin: String = "${filesDir}/admins.sqlite",
        timezone: String = "${filesDir}/timezones.sqlite",
        configFileName: String = "valhalla.json",
    ): String {
        val configFile = File(filesDir, configFileName)
        configFile.writeText(defaultValhallaConfig(tileExtract, admin, timezone))
        return configFile.absolutePath
    }
}
