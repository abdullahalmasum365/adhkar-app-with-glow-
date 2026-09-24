# Flutter Local Notifications
-keep class com.dexterous.** { *; }
-keepclassmembers class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.models.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# WorkManager
-keep class androidx.work.** { *; }
-keepclassmembers class androidx.work.** { *; }

# GSON specific rules for serialization
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers class * { @com.google.gson.annotations.SerializedName <fields>; }
-keep class com.google.gson.** { *; }
-keepclassmembers class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# Keep app resources and R classes
-keep class com.adhkaar365.app.R$* { *; }
-keepclassmembers class com.adhkaar365.app.R$* { *; }

# Google Play Billing (In-App Purchases)
-keep class com.android.billingclient.** { *; }
-keepclassmembers class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# Firebase & Google Play Services
-keepattributes EnclosingMethod
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**

# Audio (just_audio / audio_session)
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.audio_session.** { *; }
-dontwarn com.ryanheise.**

# Wakelock Plus
-keep class dev.fluttercommunity.plus.wakelock.** { *; }

# Geolocator & Geocoding
-keep class com.baseflow.geolocator.** { *; }
-keep class com.baseflow.geocoding.** { *; }
