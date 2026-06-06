package com.upi.payment.upi_payment_alert

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PaymentWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.payment_widget).apply {
                val received = widgetData.getString("total_received", "₹0")
                val sent = widgetData.getString("total_sent", "₹0")
                setTextViewText(R.id.tv_received, received)
                setTextViewText(R.id.tv_sent, sent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
