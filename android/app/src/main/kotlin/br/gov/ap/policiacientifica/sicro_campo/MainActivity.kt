package br.gov.ap.policiacientifica.sicro_campo

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale

class MainActivity : FlutterActivity() {
    companion object {
        private const val PICK_PDF_REQUEST_CODE = 7301
        private const val PICK_BACKUP_REQUEST_CODE = 7302
    }

    private var importChannel: MethodChannel? = null
    private var documentPickerChannel: MethodChannel? = null
    private var pendingDocumentPickResult: MethodChannel.Result? = null
    private var lastConsumedIntentKey: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        importChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "br.gov.ap.policiacientifica.sicro_operacional/package_import"
        )
        importChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialPackage" -> result.success(copyPackageFromIntent(intent))
                else -> result.notImplemented()
            }
        }
        documentPickerChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "br.gov.ap.policiacientifica.sicro_operacional/document_picker"
        )
        documentPickerChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "pickPdf" -> pickPdf(result)
                "pickBackup" -> pickBackup(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val importedPackage = copyPackageFromIntent(intent)
        if (importedPackage != null) {
            importChannel?.invokeMethod("packageReceived", importedPackage)
        }
    }

    @Deprecated("Deprecated in Android API, still supported by FlutterActivity.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_PDF_REQUEST_CODE && requestCode != PICK_BACKUP_REQUEST_CODE) {
            return
        }
        val pending = pendingDocumentPickResult ?: return
        pendingDocumentPickResult = null
        if (resultCode != Activity.RESULT_OK) {
            pending.success(null)
            return
        }
        val uri = data?.data
        if (uri == null) {
            pending.success(null)
            return
        }
        pending.success(
            try {
                if (requestCode == PICK_PDF_REQUEST_CODE) {
                    copyDocumentToInternalStorage(
                        uri,
                        "application/pdf",
                        "escala.pdf",
                        "sicro_operacional/selected_documents",
                        ::safePdfFileName
                    )
                } else {
                    copyDocumentToInternalStorage(
                        uri,
                        contentResolver.getType(uri),
                        "backup.sicrobackup",
                        "sicro_operacional/selected_backups",
                        ::safeBackupFileName
                    )
                }
            } catch (error: Exception) {
                mapOf(
                    "ok" to false,
                    "sourceUri" to uri.toString(),
                    "mimeType" to contentResolver.getType(uri),
                    "error" to (error.message ?: "Falha ao copiar documento selecionado.")
                )
            }
        )
    }

    private fun pickPdf(result: MethodChannel.Result) {
        if (pendingDocumentPickResult != null) {
            result.error(
                "document_picker_busy",
                "Ja existe uma selecao de documento em andamento.",
                null
            )
            return
        }
        pendingDocumentPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/pdf"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            startActivityForResult(intent, PICK_PDF_REQUEST_CODE)
        } catch (error: Exception) {
            pendingDocumentPickResult = null
            result.error(
                "document_picker_error",
                error.message ?: "Nao foi possivel abrir o seletor de arquivos.",
                null
            )
        }
    }

    private fun pickBackup(result: MethodChannel.Result) {
        if (pendingDocumentPickResult != null) {
            result.error(
                "document_picker_busy",
                "Ja existe uma selecao de documento em andamento.",
                null
            )
            return
        }
        pendingDocumentPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "application/zip",
                    "application/octet-stream",
                    "application/x-zip-compressed",
                    "application/vnd.sicrobackup"
                )
            )
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            startActivityForResult(intent, PICK_BACKUP_REQUEST_CODE)
        } catch (error: Exception) {
            pendingDocumentPickResult = null
            result.error(
                "document_picker_error",
                error.message ?: "Nao foi possivel abrir o seletor de arquivos.",
                null
            )
        }
    }

    private fun copyPackageFromIntent(intent: Intent?): Map<String, Any?>? {
        if (intent == null) {
            return null
        }

        val uri = importUriFrom(intent) ?: return null
        val intentKey = "${intent.action}|$uri"
        if (intentKey == lastConsumedIntentKey) {
            return null
        }
        lastConsumedIntentKey = intentKey

        return try {
            copyUriToInternalStorage(uri, intent.type)
        } catch (error: Exception) {
            mapOf(
                "ok" to false,
                "sourceUri" to uri.toString(),
                "mimeType" to intent.type,
                "error" to (error.message ?: "Falha ao copiar pacote recebido.")
            )
        }
    }

    private fun importUriFrom(intent: Intent): Uri? {
        return when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> intent.getParcelableExtra(Intent.EXTRA_STREAM)
            else -> null
        }
    }

    private fun copyUriToInternalStorage(uri: Uri, mimeType: String?): Map<String, Any?> {
        val resolver = contentResolver
        val sourceInfo = sourceInfoFor(uri)
        val originalName = sourceInfo.first
        val timestamp = System.currentTimeMillis()
        val safeName = safeFileName(originalName)
        val destinationName = "${timestamp}_$safeName"
        val destinationDir = File(filesDir, "sicro_operacional/imports")
        if (!destinationDir.exists()) {
            destinationDir.mkdirs()
        }
        val destination = File(destinationDir, destinationName)

        resolver.openInputStream(uri).use { input ->
            if (input == null) {
                throw IllegalStateException("Nao foi possivel abrir o arquivo recebido.")
            }
            destination.outputStream().use { output ->
                input.copyTo(output)
            }
        }

        return mapOf(
            "ok" to true,
            "filePath" to destination.absolutePath,
            "fileName" to destination.name,
            "originalName" to originalName,
            "sourceUri" to uri.toString(),
            "mimeType" to mimeType,
            "sizeBytes" to destination.length(),
            "sourceSizeBytes" to sourceInfo.second,
            "receivedAtMillis" to timestamp
        )
    }

    private fun copyDocumentToInternalStorage(
        uri: Uri,
        mimeType: String?,
        fallbackName: String,
        destinationSubdir: String,
        safeNameProvider: (String) -> String
    ): Map<String, Any?> {
        val resolver = contentResolver
        val sourceInfo = sourceInfoFor(uri)
        val originalName = sourceInfo.first
        val timestamp = System.currentTimeMillis()
        val safeName = safeNameProvider(originalName.ifBlank { fallbackName })
        val destinationName = "${timestamp}_$safeName"
        val destinationDir = File(filesDir, destinationSubdir)
        if (!destinationDir.exists()) {
            destinationDir.mkdirs()
        }
        val destination = File(destinationDir, destinationName)

        resolver.openInputStream(uri).use { input ->
            if (input == null) {
                throw IllegalStateException("Nao foi possivel abrir o documento selecionado.")
            }
            destination.outputStream().use { output ->
                input.copyTo(output)
            }
        }

        return mapOf(
            "ok" to true,
            "filePath" to destination.absolutePath,
            "fileName" to destination.name,
            "originalName" to originalName,
            "sourceUri" to uri.toString(),
            "mimeType" to mimeType,
            "sizeBytes" to destination.length(),
            "sourceSizeBytes" to sourceInfo.second,
            "receivedAtMillis" to timestamp
        )
    }

    private fun sourceInfoFor(uri: Uri): Pair<String, Long?> {
        var displayName: String? = null
        var size: Long? = null
        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
                null,
                null,
                null
            )
            if (cursor != null && cursor.moveToFirst()) {
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (nameIndex >= 0) {
                    displayName = cursor.getString(nameIndex)
                }
                if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) {
                    size = cursor.getLong(sizeIndex)
                }
            }
        } finally {
            cursor?.close()
        }

        val fallbackName = uri.lastPathSegment
            ?.substringAfterLast('/')
            ?.takeIf { it.isNotBlank() }
            ?: "pacote_recebido.sicroapp"
        return Pair(displayName?.takeIf { it.isNotBlank() } ?: fallbackName, size)
    }

    private fun safeFileName(name: String): String {
        val clean = name
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
            .trim('_', '.', '-')
            .ifBlank { "pacote_recebido.sicroapp" }
        val lower = clean.lowercase(Locale.ROOT)
        val hasKnownExtension = lower.endsWith(".sicroapp") ||
            lower.endsWith(".sicrobackup") ||
            lower.endsWith(".sicrocampo") ||
            lower.endsWith(".zip") ||
            lower.endsWith(".bin")
        return if (hasKnownExtension) clean else "$clean.sicroapp"
    }

    private fun safePdfFileName(name: String): String {
        val clean = name
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
            .trim('_', '.', '-')
            .ifBlank { "escala.pdf" }
        return if (clean.lowercase(Locale.ROOT).endsWith(".pdf")) clean else "$clean.pdf"
    }

    private fun safeBackupFileName(name: String): String {
        val clean = name
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
            .trim('_', '.', '-')
            .ifBlank { "backup.sicrobackup" }
        val lower = clean.lowercase(Locale.ROOT)
        val hasKnownExtension = lower.endsWith(".sicrobackup") ||
            lower.endsWith(".zip") ||
            lower.endsWith(".bin")
        return if (hasKnownExtension) clean else "$clean.sicrobackup"
    }
}
