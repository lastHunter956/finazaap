package com.example.finazaap

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class FinazaapWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                    // Get data from SharedPreferences (synced via home_widget)
                    // Use fallback values if data is not yet available
                    val income = widgetData.getString("income", null) ?: "$ 0"
                    val expense = widgetData.getString("expense", null) ?: "$ 0"
                    
                    setTextViewText(R.id.widget_income, income)
                    setTextViewText(R.id.widget_expense, expense)

                    // Add Button Action: Deep link to add operation
                    val addIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("finazaap://add_operation")
                    )
                    setOnClickPendingIntent(R.id.widget_add_btn, addIntent)
                    
                    // Main Container Action: Open App normally
                    val mainIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java
                    )
                    setOnClickPendingIntent(R.id.widget_container, mainIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                // Log error but don't crash
                android.util.Log.e("FinazaapWidget", "Error updating widget: ${e.message}")
            }
        }
    }
}
