# Ruleta de Juegos (ruleta_aleatoria)

Ruleta de Juegos es una app Flutter multiplataforma (Windows, Web, Android, iOS, Linux y macOS) que te ayuda a elegir al azar qué juego jugar. Puedes añadir, editar y eliminar juegos; reordenar la ruleta; girarla con gesto tipo “flick”, con un botón, o cargar fuerza manteniendo pulsado.

La app persiste la lista de juegos localmente en una carpeta segura de la aplicación utilizando `path_provider`. En Windows, la app intenta iniciarse a pantalla completa utilizando `window_manager` (si el paquete está disponible en la plataforma actual).

---

## Tabla de contenidos

- [Características](#características)
- [Tecnologías y dependencias](#tecnologías-y-dependencias)
- [Requisitos](#requisitos)
- [Instalación y ejecución](#instalación-y-ejecución)
- [Compilación por plataforma](#compilación-por-plataforma)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Configuración y permisos](#configuración-y-permisos)
- [Pruebas](#pruebas)
- [Uso](#uso)
- [Capturas de pantalla](#capturas-de-pantalla)
- [Despliegue Web](#despliegue-web)
- [Solución de problemas](#solución-de-problemas)
- [Roadmap](#roadmap)
- [Contribuir](#contribuir)
- [Licencia](#licencia)

---

## Características

- Girar la ruleta mediante:
  - Botón “Girar Ruleta”.
  - Gesto de arrastre tipo “flick”; la velocidad se traduce en fuerza.
  - Modo “cargar fuerza” manteniendo pulsado y soltando para girar.
- Puntero fijo en la parte superior con aguja personalizada (`PointerPainter`).
- Sectores de colores y nombres centrados en cada sector de la ruleta.
- Gestión de lista de juegos:
  - Agregar, editar y eliminar desde una hoja inferior modal.
  - Reordenar aleatoriamente la ruleta con un botón dedicado.
- Persistencia local de opciones en `juegos.json` usando `path_provider`.
- Intento de pantalla completa en Windows usando `window_manager`.
- UI adaptativa con `LayoutBuilder` para un lienzo cuadrado responsivo.

---

## Tecnologías y dependencias

- Flutter (Material 3)
- Dart SDK `^3.8.1` (ver `pubspec.yaml`)
- Dependencias:
  - `path_provider: ^2.1.4` (persistencia en carpeta segura)
  - `window_manager: ^0.4.2` (gestión de ventana en desktop; se usa si está disponible)
  - `cupertino_icons: ^1.0.8`

---

## Requisitos

- Flutter instalado y configurado.
- Dart SDK compatible (gestionado por Flutter).
- Para ejecución en desktop: configurar los toolchains de cada SO (Windows/macOS/Linux) según la documentación oficial de Flutter.

---

## Instalación y ejecución

1. Clona el repositorio:
   ```bash
   git clone https://github.com/USUARIO/ruleta_aleatoria.git
   cd ruleta_aleatoria
   ```
2. Obtén dependencias:
   ```bash
   flutter pub get
   ```
3. Ejecuta en el dispositivo/simulador deseado:
   ```bash
   flutter run
   ```

> Nota: asegúrate de tener un dispositivo o emulador seleccionado (`flutter devices`).

---

## Compilación por plataforma

- Android:
  ```bash
  flutter build apk --release
  ```
- iOS:
  ```bash
  flutter build ios --release
  ```
  Luego archiva desde Xcode si lo requieres.
- Web:
  ```bash
  flutter build web --release
  ```
- Windows:
  ```bash
  flutter build windows --release
  ```
- Linux:
  ```bash
  flutter build linux --release
  ```
- macOS:
  ```bash
  flutter build macos --release
  ```

---

## Estructura del proyecto

```
ruleta_aleatoria/
├─ lib/
│  └─ main.dart            # UI principal, animaciones y lógica de ruleta
├─ test/
│  └─ widget_test.dart     # Prueba base generada por Flutter
├─ web/
│  ├─ index.html           # Entrada para compilación Web
│  └─ icons/ ...           # Íconos PWA
├─ android/, ios/, linux/, macos/, windows/  # Soporte multiplataforma
├─ pubspec.yaml            # Dependencias y configuración Flutter
└─ analysis_options.yaml   # Reglas de linter
```

Puntos clave del código (`lib/main.dart`):

- `RuletaPainter`: dibuja sectores, colores y textos de cada opción.
- `PointerPainter`: dibuja la aguja fija arriba (12 en punto).
- Animación de giro con `AnimationController` y `Curves.decelerate`.
- Métodos de estado:
  - `_girarConFuerza(double fuerza)`: inicia giro ajustando vueltas y duración.
  - `_determinarOpcion()`: calcula la opción ganadora según el ángulo final.
  - `_loadOptions()` y `_saveOptions()`: persistencia de lista de juegos en JSON.
  - `_abrirJuegos()`, `_agregarOpcion()`, `_editarOpcion()`, `_eliminarOpcion()`: gestión de lista.

---

## Configuración y permisos

- `path_provider` no requiere permisos extra en la mayoría de plataformas, pero la ubicación de almacenamiento puede variar. En Windows se usa `getApplicationSupportDirectory()` y se crea `ruleta_juegos/juegos.json`.
- `window_manager` requiere configuración para desktop (ya incluida por Flutter al añadir la dependencia). El código maneja errores si no está disponible (por ejemplo en Web) con un `try/catch` alrededor de `windowManager.ensureInitialized()` y `setFullScreen(true)`.

---

## Pruebas

Ejecuta el analizador y pruebas:

```bash
flutter analyze
flutter test
```

---

## Uso

1. Abre la app.
2. Pulsa “Juegos” para gestionar la lista (agregar/editar/eliminar).
3. Gira la ruleta:
   - Botón “Girar Ruleta”, o
   - Arrastra y suelta con gesto rápido, o
   - Mantén pulsado “Mantén para cargar” y suelta para girar con más fuerza.
4. La opción seleccionada se mostrará bajo la barra de carga.
5. Botón “Ir a jugar” cierra la app (en desktop/móvil). Nota: en Web no aplica `exit(0)`.

---

## Capturas de pantalla

Inserta aquí imágenes del funcionamiento (añádelas en `docs/` o `assets/` y referencia sus rutas):

```
docs/
├─ screenshot_1.png
├─ screenshot_2.png
└─ screenshot_3.png
```

> Si prefieres, puedes alojarlas en issues o en el apartado “Releases” y enlazarlas con URLs absolutas.

---

## Despliegue Web

1. Construye el sitio:
   ```bash
   flutter build web --release
   ```
2. Sube el contenido de `build/web/` a tu hosting estático (GitHub Pages, Netlify, Vercel, etc.).
3. Si usas GitHub Pages:
   - Coloca el contenido de `build/web/` en la rama `gh-pages` o configura Pages para servir desde `/docs` y copia ahí el build.
   - Asegúrate de configurar correctamente el `base href` si publicas bajo un subpath.

---

## Solución de problemas

- Ventana no entra en pantalla completa en Web: `window_manager` no está disponible en Web, la app lo ignora de forma segura.
- Lista no se guarda: revisa permisos de escritura/localización en plataformas restringidas. Verifica que se haya creado la carpeta `ruleta_juegos` en el directorio de soporte de la app.
- Texto superpuesto en sectores con nombres muy largos: considera abreviaciones o ajustar `fontSize` en `RuletaPainter`.

---

## Roadmap

- Ajuste automático de tamaño de fuente por longitud del texto.
- Sonidos y animaciones extra al detenerse la ruleta.
- Temas de color configurables.
- Exportar/importar lista de juegos.
- Evitar que se repita la última opción ganadora de forma consecutiva (opcional).

---

## Contribuir

¡Las contribuciones son bienvenidas! Para cambios mayores, por favor abre primero un issue para discutir lo que te gustaría cambiar.

Pasos sugeridos:

1. Haz un fork del proyecto.
2. Crea una rama de feature: `git checkout -b feature/mi-mejora`.
3. Commit de cambios: `git commit -m "feat: descripción de la mejora"`.
4. Push a tu rama: `git push origin feature/mi-mejora`.
5. Abre un Pull Request.

---

## Licencia

Indica aquí la licencia del proyecto (por ejemplo MIT, Apache-2.0, GPL-3.0). Si eliges MIT, añade un archivo `LICENSE` con el texto correspondiente y referencia aquí:

```
Este proyecto está licenciado bajo los términos de la licencia MIT. Consulta el archivo LICENSE para más información.
```