# Flutter/plugin rules được các plugin tự khai báo (consumer rules).
# Google Play Billing (in_app_purchase_android):
-keep class com.android.vending.billing.** { *; }
-dontwarn com.google.android.play.core.**
