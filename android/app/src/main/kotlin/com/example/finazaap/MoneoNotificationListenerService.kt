package com.example.finazaap

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Servicio mínimo declarativo para que Android muestre a Moneo en
 * Ajustes -> Acceso a notificaciones y permita consultar el estado real del permiso.
 *
 * En esta etapa no captura ni persiste notificaciones reales del usuario.
 */
class MoneoNotificationListenerService : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        // Sin procesamiento en esta etapa (solo demo / configuración de permisos)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // No-op
    }
}
