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
