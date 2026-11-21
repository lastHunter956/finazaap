package com.example.finazaap

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Base64
import androidx.core.app.NotificationManagerCompat
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.lang.ref.WeakReference
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Servicio nativo Android para captura selectiva y offline de notificaciones bancarias.
 *
 * Reglas de privacidad y ciclo de vida:
 * - Solo procesa notificaciones cuando la captura está habilitada explícitamente por el usuario
 *   y el paquete origen pertenece a la lista de apps seleccionadas.
 * - Descarta de inmediato cualquier otra notificación sin persistir su contenido.
 * - No ejecuta IA ni abre/resuelve URLs dentro del callback nativo.
 * - No registra texto sensible de notificaciones en logcat.
 */
class MoneoNotificationListenerService : NotificationListenerService() {

    companion object {
        const val PREFS_NAME = "moneo_notif_prefs"
        const val KEY_CAPTURE_ENABLED = "capture_enabled"
        const val KEY_ALLOWED_PACKAGES = "allowed_packages"
        private const val QUEUE_FILE_NAME = "moneo_notif_queue.json"
        private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        private const val QUEUE_KEY_ALIAS = "moneo_notif_queue_aes_key_v1"
        private const val AES_GCM_TRANSFORMATION = "AES/GCM/NoPadding"
        private const val ENCRYPTED_QUEUE_PREFIX = "ENCv1:"
        private const val GCM_IV_LENGTH_BYTES = 12
        private const val GCM_TAG_LENGTH_BITS = 128
        private const val MAX_QUEUE_SIZE = 200
        private const val MAX_ITEM_AGE_MS = 7L * 24 * 60 * 60 * 1000

        private val queueLock = Any()

        @Volatile
        private var activeInstance: WeakReference<MoneoNotificationListenerService>? = null

        @Volatile
        private var eventListener: ((Map<String, Any?>) -> Unit)? = null

        fun isListenerConnected(): Boolean = activeInstance?.get() != null

        fun ensureServiceBound(context: Context): Boolean {
            val appCtx = context.applicationContext
            val granted = NotificationManagerCompat
                .getEnabledListenerPackages(appCtx)
                .contains(appCtx.packageName)
            if (granted && activeInstance?.get() == null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                try {
                    NotificationListenerService.requestRebind(
                        ComponentName(appCtx, MoneoNotificationListenerService::class.java)
                    )
                } catch (_: Exception) {
                }
            }
            return isListenerConnected()
        }

        fun setEventListener(listener: ((Map<String, Any?>) -> Unit)?) {
            eventListener = listener
        }

        fun syncConfig(context: Context, enabled: Boolean, allowedPackages: Set<String>) {
            val prefs = context.applicationContext.getSharedPreferences(
                PREFS_NAME,
                Context.MODE_PRIVATE
            )
            prefs.edit()
                .putBoolean(KEY_CAPTURE_ENABLED, enabled)
                .putStringSet(KEY_ALLOWED_PACKAGES, allowedPackages)
                .apply()
            if (enabled) {
                ensureServiceBound(context)
            }
        }

        fun isCaptureEnabled(context: Context): Boolean {
            val prefs = context.applicationContext.getSharedPreferences(
                PREFS_NAME,
                Context.MODE_PRIVATE
            )
            return prefs.getBoolean(KEY_CAPTURE_ENABLED, false)
        }

        fun getAllowedPackages(context: Context): Set<String> {
            val prefs = context.applicationContext.getSharedPreferences(
                PREFS_NAME,
                Context.MODE_PRIVATE
            )
            return prefs.getStringSet(KEY_ALLOWED_PACKAGES, emptySet()) ?: emptySet()
        }

        private fun isExpiredLocked(obj: JSONObject, nowMs: Long): Boolean {
            val ts = obj.optLong("timestampMs", 0L)
            return ts > 0L && (nowMs - ts) > MAX_ITEM_AGE_MS
        }

        fun peekQueue(context: Context): List<Map<String, Any?>> {
            synchronized(queueLock) {
                val appCtx = context.applicationContext
                val array = readQueueArrayLocked(appCtx)
                val nowMs = System.currentTimeMillis()
                val validArray = JSONArray()
                val result = ArrayList<Map<String, Any?>>(array.length())
                var droppedExpired = false
                for (i in 0 until array.length()) {
                    val obj = array.optJSONObject(i) ?: continue
                    if (isExpiredLocked(obj, nowMs)) {
                        droppedExpired = true
                        continue
                    }
                    validArray.put(obj)
                    result.add(jsonObjectToMap(obj))
                }
                if (droppedExpired) {
                    writeQueueArrayLocked(appCtx, validArray)
                }
                return result
            }
        }

        fun ackQueueIds(context: Context, ids: Set<String>): Int {
            if (ids.isEmpty()) return 0
            synchronized(queueLock) {
                val appCtx = context.applicationContext
                val array = readQueueArrayLocked(appCtx)
                val remaining = JSONArray()
                var removed = 0
                for (i in 0 until array.length()) {
                    val obj = array.optJSONObject(i) ?: continue
                    val id = obj.optString("id", "")
                    if (ids.contains(id)) {
                        removed++
                    } else {
                        remaining.put(obj)
                    }
                }
                writeQueueArrayLocked(appCtx, remaining)
                return removed
            }
        }

        fun clearQueue(context: Context) {
            synchronized(queueLock) {
                val file = File(context.applicationContext.filesDir, QUEUE_FILE_NAME)
                if (file.exists()) {
                    file.delete()
                }
            }
        }

        fun collectActiveNotifications(context: Context): List<Map<String, Any?>> {
            val service = activeInstance?.get() ?: return emptyList()
            if (!isCaptureEnabled(context)) return emptyList()
            val allowed = getAllowedPackages(context)
            if (allowed.isEmpty()) return emptyList()

            return try {
                val active = service.activeNotifications ?: return emptyList()
                val collected = ArrayList<Map<String, Any?>>()
                for (sbn in active) {
                    val map = extractAllowedNotification(sbn, allowed) ?: continue
                    enqueueLocked(context.applicationContext, map)
                    collected.add(map)
                }
                collected
            } catch (_: SecurityException) {
                emptyList()
            } catch (_: Exception) {
                emptyList()
            }
        }

        private fun isPackageAllowed(pkg: String, allowedPackages: Set<String>): Boolean {
            if (allowedPackages.contains(pkg)) return true
            val pkgLower = pkg.lowercase()
            return allowedPackages.any { it.trim().lowercase() == pkgLower }
        }

        private fun isGenericSummaryPlaceholder(title: String, body: String): Boolean {
            val combined = "$title $body".trim().lowercase()
            if (combined.isEmpty()) return true
            val hasDigits = combined.any { it.isDigit() }
            val hasCurrency = combined.contains("$") ||
                combined.contains("cop") ||
                combined.contains("usd") ||
                combined.contains("eur")
            if (hasCurrency) return false
            val genericRegex = Regex(
                """^(\d+\s+(nuev[oa]s?\s+)?(mensajes?|notificaciones?|avisos?|correos?|alertas?)\b.*|resumen\s+de\s+notificaciones)$"""
            )
            return genericRegex.matches(combined) || (!hasDigits && combined.length < 18)
        }

        private fun extractAllowedNotification(
            sbn: StatusBarNotification?,
            allowedPackages: Set<String>
        ): Map<String, Any?>? {
            if (sbn == null) return null
            val pkg = sbn.packageName ?: return null
            if (!isPackageAllowed(pkg, allowedPackages)) return null

            val notification = sbn.notification ?: return null
            val isOngoing = (notification.flags and Notification.FLAG_ONGOING_EVENT) != 0
            val isGroupSummary = (notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0

            val extras = notification.extras ?: return null
            val rawTitle = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""
            val bigTitle = extras.getCharSequence(Notification.EXTRA_TITLE_BIG)?.toString()?.trim() ?: ""
            val title = when {
                bigTitle.isNotEmpty() && bigTitle.length >= rawTitle.length -> bigTitle
                rawTitle.isNotEmpty() -> rawTitle
                else -> bigTitle
            }

            val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim() ?: ""
            val plainText = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim() ?: ""
            val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()?.trim() ?: ""
            val summaryText = extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT)?.toString()?.trim() ?: ""
            val infoText = extras.getCharSequence(Notification.EXTRA_INFO_TEXT)?.toString()?.trim() ?: ""
            val tickerText = notification.tickerText?.toString()?.trim() ?: ""

            val textLinesList = ArrayList<String>()
            val rawLines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            if (rawLines != null) {
                for (line in rawLines) {
                    val clean = line?.toString()?.trim() ?: ""
                    if (clean.isNotEmpty()) textLinesList.add(clean)
                }
            }

            // Extraer texto de MessagingStyle (EXTRA_MESSAGES) si existe
            val rawMessages = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                @Suppress("DEPRECATION")
                extras.getParcelableArray(Notification.EXTRA_MESSAGES)
            } else {
                null
            }
            if (rawMessages != null) {
                for (msg in rawMessages) {
                    val bundle = msg as? android.os.Bundle ?: continue
                    val msgText = bundle.getCharSequence("text")?.toString()?.trim() ?: ""
                    val sender = bundle.getCharSequence("sender")?.toString()?.trim() ?: ""
                    val combinedMsg = if (sender.isNotEmpty() && msgText.isNotEmpty()) {
                        "$sender: $msgText"
                    } else {
                        msgText
                    }
                    if (combinedMsg.isNotEmpty() && !textLinesList.contains(combinedMsg)) {
                        textLinesList.add(combinedMsg)
                    }
                }
            }

            val bodyParts = ArrayList<String>()
            fun appendUnique(candidate: String) {
                val clean = candidate.trim()
                if (clean.isEmpty()) return
                val cleanLower = clean.lowercase()
                if (cleanLower == title.lowercase()) return
                if (bodyParts.any {
                        val existingLower = it.lowercase()
                        existingLower == cleanLower || existingLower.contains(cleanLower)
                    }) {
                    return
                }
                bodyParts.add(clean)
            }

            if (bigText.isNotEmpty()) {
                appendUnique(bigText)
            } else if (plainText.isNotEmpty()) {
                appendUnique(plainText)
            }
            for (line in textLinesList) {
                appendUnique(line)
            }
            if (bodyParts.isEmpty()) {
                appendUnique(subText)
                appendUnique(summaryText)
                appendUnique(infoText)
                appendUnique(tickerText)
            } else {
                if (subText.isNotEmpty() && subText.length >= 3) {
                    appendUnique(subText)
                }
            }

            val body = bodyParts.joinToString(" | ")
            if (title.isEmpty() && body.isEmpty()) return null

            // Solo descartar FLAG_GROUP_SUMMARY si es un contenedor genérico sin contenido real.
            if (isGroupSummary && isGenericSummaryPlaceholder(title, body)) {
                return null
            }

            val channelId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                notification.channelId ?: ""
            } else {
                ""
            }
            val category = notification.category ?: ""

            val postTime = sbn.postTime
            val sbnKey = sbn.key ?: "${pkg}_${sbn.id}_$postTime"
            val eventId = "${sbnKey}_$postTime"

            return mapOf(
                "id" to eventId,
                "sbnKey" to sbnKey,
                "packageName" to pkg,
                "title" to title,
                "body" to body,
                "timestampMs" to postTime,
                "channelId" to channelId,
                "category" to category,
                "subText" to subText,
                "summaryText" to summaryText,
                "tickerText" to tickerText,
                "textLines" to textLinesList,
                "isOngoing" to isOngoing,
                "isGroupSummary" to isGroupSummary
            )
        }

        private fun enqueueLocked(context: Context, item: Map<String, Any?>) {
            synchronized(queueLock) {
                val array = readQueueArrayLocked(context)
                val targetId = item["id"]?.toString() ?: return
                val nowMs = System.currentTimeMillis()

                val filtered = JSONArray()
                for (i in 0 until array.length()) {
                    val existing = array.optJSONObject(i) ?: continue
                    if (isExpiredLocked(existing, nowMs)) continue
                    if (existing.optString("id") == targetId) {
                        writeQueueArrayLocked(context, filtered.also {
                            for (j in i until array.length()) {
                                val rest = array.optJSONObject(j) ?: continue
                                if (!isExpiredLocked(rest, nowMs)) {
                                    it.put(rest)
                                }
                            }
                        })
                        return
                    }
                    filtered.put(existing)
                }

                val jsonObj = JSONObject()
                jsonObj.put("id", targetId)
                jsonObj.put("sbnKey", item["sbnKey"]?.toString() ?: "")
                jsonObj.put("packageName", item["packageName"]?.toString() ?: "")
                jsonObj.put("title", item["title"]?.toString() ?: "")
                jsonObj.put("body", item["body"]?.toString() ?: "")
                jsonObj.put("timestampMs", (item["timestampMs"] as? Number)?.toLong() ?: nowMs)
                jsonObj.put("channelId", item["channelId"]?.toString() ?: "")
                jsonObj.put("category", item["category"]?.toString() ?: "")
                jsonObj.put("subText", item["subText"]?.toString() ?: "")
                jsonObj.put("summaryText", item["summaryText"]?.toString() ?: "")
                jsonObj.put("tickerText", item["tickerText"]?.toString() ?: "")
                jsonObj.put("isOngoing", item["isOngoing"] as? Boolean ?: false)
                jsonObj.put("isGroupSummary", item["isGroupSummary"] as? Boolean ?: false)
                val lines = item["textLines"] as? List<*>
                if (lines != null && lines.isNotEmpty()) {
                    val linesArr = JSONArray()
                    for (line in lines) {
                        val str = line?.toString() ?: continue
                        if (str.isNotEmpty()) linesArr.put(str)
                    }
                    jsonObj.put("textLines", linesArr)
                }

                filtered.put(jsonObj)

                val trimmed = if (filtered.length() > MAX_QUEUE_SIZE) {
                    val next = JSONArray()
                    val start = filtered.length() - MAX_QUEUE_SIZE
                    for (i in start until filtered.length()) {
                        next.put(filtered.get(i))
                    }
                    next
                } else {
                    filtered
                }

                writeQueueArrayLocked(context, trimmed)
            }
        }

        private fun getOrCreateQueueSecretKey(): SecretKey? {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
            val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }
            val existing = keyStore.getKey(QUEUE_KEY_ALIAS, null) as? SecretKey
            if (existing != null) return existing

            val keyGenerator = KeyGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_AES,
                KEYSTORE_PROVIDER
            )
            val spec = KeyGenParameterSpec.Builder(
                QUEUE_KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setRandomizedEncryptionRequired(true)
                .build()
            keyGenerator.init(spec)
            return keyGenerator.generateKey()
        }

        private fun encryptQueuePayload(plainJson: String): String {
            val secretKey = getOrCreateQueueSecretKey() ?: return plainJson
            val cipher = Cipher.getInstance(AES_GCM_TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, secretKey)
            val iv = cipher.iv
            val cipherBytes = cipher.doFinal(plainJson.toByteArray(Charsets.UTF_8))
            val combined = ByteArray(iv.size + cipherBytes.size)
            System.arraycopy(iv, 0, combined, 0, iv.size)
            System.arraycopy(cipherBytes, 0, combined, iv.size, cipherBytes.size)
            return ENCRYPTED_QUEUE_PREFIX + Base64.encodeToString(combined, Base64.NO_WRAP)
        }

        private fun decryptQueuePayload(rawContent: String): String? {
            if (!rawContent.startsWith(ENCRYPTED_QUEUE_PREFIX)) {
                // Compatibilidad de lectura para cola legada en claro previa a la migración.
                return rawContent
            }
            val secretKey = getOrCreateQueueSecretKey() ?: return null
            val encoded = rawContent.substring(ENCRYPTED_QUEUE_PREFIX.length)
            val combined = Base64.decode(encoded, Base64.NO_WRAP)
            if (combined.size <= GCM_IV_LENGTH_BYTES) return null

            val iv = combined.copyOfRange(0, GCM_IV_LENGTH_BYTES)
            val cipherBytes = combined.copyOfRange(GCM_IV_LENGTH_BYTES, combined.size)
            val cipher = Cipher.getInstance(AES_GCM_TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, secretKey, GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv))
            return String(cipher.doFinal(cipherBytes), Charsets.UTF_8)
        }

        private fun readQueueArrayLocked(context: Context): JSONArray {
            val file = File(context.filesDir, QUEUE_FILE_NAME)
            if (!file.exists()) return JSONArray()
            return try {
                val rawContent = file.readText(Charsets.UTF_8)
                if (rawContent.isBlank()) return JSONArray()
                val jsonText = decryptQueuePayload(rawContent) ?: return JSONArray()
                if (jsonText.isBlank()) JSONArray() else JSONArray(jsonText)
            } catch (_: Exception) {
                JSONArray()
            }
        }

        private fun writeQueueArrayLocked(context: Context, array: JSONArray) {
            val file = File(context.filesDir, QUEUE_FILE_NAME)
            val tmpFile = File(context.filesDir, "$QUEUE_FILE_NAME.tmp")
            val payload = encryptQueuePayload(array.toString())
            tmpFile.writeText(payload, Charsets.UTF_8)
            if (!tmpFile.renameTo(file)) {
                file.writeText(payload, Charsets.UTF_8)
                tmpFile.delete()
            }
        }

        private fun jsonObjectToMap(obj: JSONObject): Map<String, Any?> {
            val lines = ArrayList<String>()
            val arr = obj.optJSONArray("textLines")
            if (arr != null) {
                for (i in 0 until arr.length()) {
                    val str = arr.optString(i, "")
                    if (str.isNotEmpty()) lines.add(str)
                }
            }
            return mapOf(
                "id" to obj.optString("id", ""),
                "sbnKey" to obj.optString("sbnKey", ""),
                "packageName" to obj.optString("packageName", ""),
                "title" to obj.optString("title", ""),
                "body" to obj.optString("body", ""),
                "timestampMs" to obj.optLong("timestampMs", 0L),
                "channelId" to obj.optString("channelId", ""),
                "category" to obj.optString("category", ""),
                "subText" to obj.optString("subText", ""),
                "summaryText" to obj.optString("summaryText", ""),
                "tickerText" to obj.optString("tickerText", ""),
                "textLines" to lines,
                "isOngoing" to obj.optBoolean("isOngoing", false),
                "isGroupSummary" to obj.optBoolean("isGroupSummary", false)
            )
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        activeInstance = WeakReference(this)
        collectActiveNotifications(applicationContext)
    }

    override fun onListenerDisconnected() {
        activeInstance = null
        super.onListenerDisconnected()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        if (!isCaptureEnabled(applicationContext)) return

        val allowed = getAllowedPackages(applicationContext)
        if (allowed.isEmpty()) return

        val eventMap = extractAllowedNotification(sbn, allowed) ?: return
        enqueueLocked(applicationContext, eventMap)
        eventListener?.invoke(eventMap)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // No-op: los eventos ya capturados permanecen en cola hasta ser procesados.
    }
}
