# Reglas de R8/ProGuard para release.
#
# ML Kit (usado por mobile_scanner para el escáner QR) descubre e instancia sus
# `ComponentRegistrar` por reflexión durante el arranque (MlKitInitProvider →
# ComponentDiscovery). R8 no ve esas instanciaciones y, sin estas reglas, elimina
# los constructores sin argumentos de los registrars:
#   NoSuchMethodException: com.google.mlkit...Registrar.<init> []
# con lo que ML Kit nunca inicializa y `BarcodeScanning.getClient()` lanza un NPE
# al abrir el escáner. Mantener las clases de ML Kit y sus miembros lo evita.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.mlkit.**

# Los ComponentRegistrar (firebase-components) deben conservar su constructor
# sin argumentos para poder instanciarse por reflexión.
-keep class * implements com.google.firebase.components.ComponentRegistrar {
    <init>();
}
-keepclassmembers class * implements com.google.firebase.components.ComponentRegistrar {
    <init>();
}

# Plugin mobile_scanner (defensivo; ya trae reglas de consumidor).
-keep class dev.steenbakker.mobile_scanner.** { *; }
