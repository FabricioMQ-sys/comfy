````markdown
# Comfy Wallet

Comfy Wallet es un MVP de billetera digital personal orientada a educación financiera. Permite enviar y recibir dinero, crear metas de ahorro y analizar gastos desde una interfaz simple.

## Contexto académico

Este proyecto se desarrolla como parte de cursos universitarios de desarrollo de software y arquitectura de sistemas.  
Los objetivos académicos principales son:

- Aplicar buenas prácticas de arquitectura en Flutter.
- Integrar un frontend móvil/web con un backend serverless en Firebase.
- Experimentar con patrones de gamificación y hábitos financieros (metas, candados, gastos hormiga).
- Preparar un MVP que pueda ser usado en sustentaciones y demostraciones en clase.

## Funcionalidades principales

- Login por celular y PIN (simulado con Firebase Auth vía Firestore).
- Home con:
  - Saldo sincronizado con Firestore.
  - Resumen mensual de gastos, ingresos y ahorro en metas.
- Enviar dinero a otro usuario por número de celular.
- Recibir dinero mediante QR y copia de número.
- Bóveda de metas:
  - Crear metas con monto objetivo, plazo y nivel de candado.
  - Aportar y retirar dinero (con cuenta regresiva y PIN).
- Historial de movimientos:
  - Filtros por día, semana, mes y gastos hormiga.
  - Resumen de cuánto representan los gastos hormiga.
- Cuenta demo:
  - Usuario de prueba con transacciones pre-cargadas para demostraciones.

## Stack tecnológico

- Flutter 3 (Dart)
- Firebase:
  - `cloud_firestore`
  - `firebase_core`
- Almacenamiento local: `shared_preferences`
- QR y escáner: `qr_flutter`, `mobile_scanner`
- Web: Flutter Web + Firebase Hosting

## Configuración rápida

1. Clonar el repositorio:

   ```bash
   git clone https://github.com/FabricioMQ-sys/comfy.git
   cd comfy
````

2. Instalar dependencias:

   ```bash
   flutter pub get
   ```

3. Crear tu propio proyecto en Firebase y configurar:

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

   Esto generará/actualizará `lib/firebase_options.dart`.

4. Ajustar reglas de Firestore según tu contexto (desarrollo/demo).

## Ejecución en desarrollo

* Web (Chrome):

  ```bash
  flutter run -d chrome
  ```

* Android (emulador o dispositivo):

  ```bash
  flutter run
  ```

## Build

* APK:

  ```bash
  flutter build apk
  # salida: build/app/outputs/flutter-apk/app-release.apk
  ```

* Web:

  ```bash
  flutter build web
  # salida: build/web
  ```

## Deploy web con Firebase Hosting

1. Inicializar (solo la primera vez):

   ```bash
   firebase init hosting
   # public directory: build/web
   # single page app: Yes
   ```

2. Hacer build:

   ```bash
   flutter build web
   ```

3. Desplegar:

   ```bash
   firebase deploy --only hosting
   ```

## Seguridad y claves

* El archivo `firebase_options.dart` contiene claves públicas necesarias para que el cliente se conecte a Firebase.
* Se recomienda:

  * Crear tu propio proyecto de Firebase si vas a reutilizar este código.
  * Restringir las API keys en Google Cloud a los dominios de tu hosting y a localhost.


