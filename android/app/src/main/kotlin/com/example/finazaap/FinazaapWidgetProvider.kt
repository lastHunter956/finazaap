package com.example.finazaap

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class FinazaapWidgetProvider : HomeWidgetProvider() {
    
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_layout)
                
                // Get main data from SharedPreferences
                val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val isPrivacyActive = widgetData.getBoolean("privacy_mode", false) ||
                    widgetData.getBoolean("hide_balance", false) ||
                    flutterPrefs.getBoolean("flutter.privacy_mode_enabled", false) ||
                    flutterPrefs.getBoolean("flutter.hide_balance", false)

                val income = if (isPrivacyActive) "••••••" else (widgetData.getString("income", null) ?: "$ 0")
                val expense = if (isPrivacyActive) "••••••" else (widgetData.getString("expense", null) ?: "$ 0")
                val balance = if (isPrivacyActive) "••••••" else (widgetData.getString("balance", null) ?: "$ 0")
                val isPositive = widgetData.getBoolean("is_positive", true)
                
                // Set main values
                views.setTextViewText(R.id.widget_income, income)
                views.setTextViewText(R.id.widget_expense, expense)
                views.setTextViewText(R.id.widget_balance, balance)
                
                // Set balance color based on privacy mode or positive/negative
                val balanceColor = when {
                    isPrivacyActive -> Color.parseColor("#94A3B8")
                    isPositive -> Color.parseColor("#4ADE80")
                    else -> Color.parseColor("#F87171")
                }
                views.setTextColor(R.id.widget_balance, balanceColor)

                // Add Button Action: Deep link to add operation
                val addIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("finazaap://add_operation")
                )
                views.setOnClickPendingIntent(R.id.widget_add_btn, addIntent)
                
                // Main Container Action: Open App normally
                val mainIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                views.setOnClickPendingIntent(R.id.widget_container, mainIntent)
                
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                android.util.Log.e("FinazaapWidget", "Error updating widget: ${e.message}", e)
            }
        }
    }
}
