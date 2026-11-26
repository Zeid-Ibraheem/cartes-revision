package io.github.zeid_ibraheem.cartes_revision

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Reçoit les fichiers de cartes envoyés par une autre appli :
 * « Partager › Cartes » (ACTION_SEND) ou « Ouvrir avec › Cartes » (ACTION_VIEW).
 *
 * Le contenu est lu ici puis transmis à la partie Dart par le canal
 * [CHANNEL] (voir lib/data/android_shared_files.dart) :
 * - « initial » : ce qui a lancé l'appli ;
 * - « received » : ce qui arrive pendant qu'elle est ouverte.
 * Chaque élément : { name, bytes } ou { name, error }.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: List<Map<String, Any>> = emptyList()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pending = takeShared(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "initial") {
                    result.success(pending)
                    pending = emptyList()
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val items = takeShared(intent)
        if (items.isNotEmpty()) channel?.invokeMethod("received", items)
    }

    /** Lit ce que [intent] apporte, puis le marque comme traité. */
    private fun takeShared(intent: Intent?): List<Map<String, Any>> {
        if (intent == null) return emptyList()
        // Rouverte depuis les applis récentes : l'ancien partage est déjà importé.
        if ((intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) return emptyList()
        val items = when (intent.action) {
            Intent.ACTION_VIEW -> listOfNotNull(intent.data?.let(::readUri))
            Intent.ACTION_SEND -> {
                val uri = streamExtra(intent)
                when {
                    uri != null -> listOf(readUri(uri))
                    else -> textExtra(intent)
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> streamListExtra(intent).map(::readUri)
            else -> emptyList()
        }
        if (items.isNotEmpty()) {
            // Pour ne pas réimporter si l'écran est recréé.
            intent.action = Intent.ACTION_MAIN
            intent.data = null
            intent.removeExtra(Intent.EXTRA_STREAM)
            intent.removeExtra(Intent.EXTRA_TEXT)
        }
        return items
    }

    private fun readUri(uri: Uri): Map<String, Any> {
        val name = displayName(uri)
        if (uri.scheme != "content") return mapOf("name" to name, "error" to "source non prise en charge")
        return try {
            val bytes = contentResolver.openInputStream(uri)?.use { input ->
                val out = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(64 * 1024)
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    out.write(buffer, 0, read)
                    if (out.size() > MAX_BYTES) {
                        return mapOf("name" to name, "error" to "fichier trop gros (plus de 5 Mo)")
                    }
                }
                out.toByteArray()
            } ?: return mapOf("name" to name, "error" to "fichier illisible")
            mapOf("name" to name, "bytes" to bytes)
        } catch (error: Exception) {
            mapOf("name" to name, "error" to "lecture impossible (${error.javaClass.simpleName})")
        }
    }

    private fun textExtra(intent: Intent): List<Map<String, Any>> {
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString() ?: return emptyList()
        if (text.isBlank()) return emptyList()
        val name = intent.getStringExtra(Intent.EXTRA_SUBJECT)?.takeIf { it.isNotBlank() } ?: "Partage"
        val bytes = text.toByteArray(Charsets.UTF_8)
        if (bytes.size > MAX_BYTES) return listOf(mapOf("name" to name, "error" to "texte trop long (plus de 5 Mo)"))
        return listOf(mapOf("name" to name, "bytes" to bytes))
    }

    private fun displayName(uri: Uri): String {
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst() && !cursor.isNull(0)) return cursor.getString(0)
            }
        } catch (_: Exception) {
            // Pas de nom fourni : on prend la fin de l'adresse.
        }
        return uri.lastPathSegment?.substringAfterLast('/') ?: "fichier.txt"
    }

    private fun streamExtra(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }

    private fun streamListExtra(intent: Intent): List<Uri> =
        (if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
        }).orEmpty().take(MAX_FILES)

    companion object {
        const val CHANNEL = "cartes/fichiers_recus"
        const val MAX_BYTES = 5 * 1024 * 1024
        const val MAX_FILES = 20
    }
}
