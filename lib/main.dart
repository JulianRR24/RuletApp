import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await windowManager.ensureInitialized();
    // Iniciar en pantalla completa por defecto en Windows
    await windowManager.waitUntilReadyToShow();
    await windowManager.setFullScreen(true);
  } catch (_) {
    // Si no está disponible (p. ej. en web), continuar sin pantalla completa
  }
  runApp(const RuletaApp());
}

class PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final radio = size.width / 2;
    final centro = Offset(radio, radio);

    // Aguja fina y precisa apuntando hacia adentro, en la parte superior
    final tip = Offset(centro.dx, centro.dy - radio + 3);
    final length = max(24.0, radio * 0.22);
    final baseY = tip.dy + length;
    final halfBase = max(2.0, radio * 0.012);

    final needle = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - halfBase, baseY)
      ..lineTo(tip.dx + halfBase, baseY)
      ..close();

    // Base circular pequeña para soporte visual
    final baseCircleCenter = Offset(centro.dx, baseY + halfBase + 2);
    final baseCircleR = max(2.5, radio * 0.015);

    final fill = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Sombra sutil
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.save();
    canvas.translate(0, 1);
    canvas.drawPath(needle, shadow);
    canvas.restore();

    canvas.drawPath(needle, fill);
    canvas.drawPath(needle, stroke);
    canvas.drawCircle(baseCircleCenter, baseCircleR, fill);
    canvas.drawCircle(baseCircleCenter, baseCircleR, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RuletaApp extends StatelessWidget {
  const RuletaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ruleta de Juegos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const RuletaHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RuletaHome extends StatefulWidget {
  const RuletaHome({super.key});

  @override
  State<RuletaHome> createState() => _RuletaHomeState();
}

class _RuletaHomeState extends State<RuletaHome>
    with SingleTickerProviderStateMixin {
  final List<String> _opciones = [
    "Minecraft",
    "Fortnite",
    "Among Us",
    "FIFA",
    "Call of Duty",
  ];

  late ValueNotifier<List<String>> _opcionesVN;

  late AnimationController _controller;
  late Animation<double> _animation;
  double _giroActual = 0.0;
  String? _opcionSeleccionada;
  double _fuerza = 0.0; // 0.0 a 1.0, inicia en 0 y se carga al mantener
  Timer? _chargeTimer;

  @override
  void initState() {
    super.initState();
    _opcionesVN = ValueNotifier<List<String>>(List.unmodifiable(_opciones));
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    _animation = CurvedAnimation(parent: _controller, curve: Curves.decelerate);

    _controller.addListener(() {
      setState(() {
        _giroActual =
            _animation.value * 2 * pi; // Rotación entre 0 y 2π varias veces
      });
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _determinarOpcion();
      }
    });

    // Cargar opciones persistidas desde disco
    _loadOptions();
  }

  // Obtiene el archivo de datos en una carpeta segura para la app
  Future<File> _getDataFile() async {
    final dir = await getApplicationSupportDirectory();
    final appDirPath = '${dir.path}${Platform.pathSeparator}ruleta_juegos';
    final appDir = Directory(appDirPath);
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    final filePath = '${appDir.path}${Platform.pathSeparator}juegos.json';
    return File(filePath);
  }

  Future<void> _loadOptions() async {
    try {
      final file = await _getDataFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        final data = jsonDecode(contents);
        if (data is List) {
          final list = data.whereType<String>().toList();
          setState(() {
            _opciones
              ..clear()
              ..addAll(list);
            _opcionesVN.value = List.unmodifiable(_opciones);
          });
        }
      }
    } catch (e) {
      debugPrint('Error al cargar opciones: $e');
    }
  }

  Future<void> _saveOptions() async {
    try {
      final file = await _getDataFile();
      await file.writeAsString(jsonEncode(_opciones), flush: true);
    } catch (e) {
      debugPrint('Error al guardar opciones: $e');
    }
  }

  void _girarRuleta() => _girarConFuerza(_fuerza);

  void _girarConFuerza(double fuerza) {
    setState(() {
      _opcionSeleccionada = null;
    });

    final random = Random();
    // spins: de 3 a 12 vueltas + una fracción aleatoria para evitar determinismo
    final spins = 3 + (fuerza.clamp(0.0, 1.0) * 9) + random.nextDouble();
    // duración: de 2s a 7s
    final duracion = Duration(milliseconds: (2000 + (fuerza * 5000)).round());

    _controller.duration = duracion;

    _animation = Tween<double>(
      begin: 0,
      end: spins,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.decelerate));

    _controller.reset();
    _controller.forward();
  }

  void _determinarOpcion() {
    // Alinear con puntero en la parte superior (12 en punto).
    // En coordenadas del canvas, 0 rad apunta a la derecha. La parte superior es -pi/2.
    final angulo = _giroActual % (2 * pi);
    final sweep = (2 * pi) / _opciones.length;
    double topAngle = (-pi / 2 - angulo) % (2 * pi);
    if (topAngle < 0) topAngle += 2 * pi;
    // Pequeño sesgo para evitar empates exactos en el borde entre sectores
    topAngle = (topAngle - 1e-6) % (2 * pi);
    // Elegir el sector cuyo CENTRO está más cercano al puntero superior.
    // i corresponde al centro en (i + 0.5) * sweep => i = round(topAngle/sweep - 0.5)
    int indice = ((topAngle / sweep) - 0.5).round();
    indice = (indice % _opciones.length + _opciones.length) % _opciones.length;

    setState(() {
      _opcionSeleccionada = _opciones[indice];
      // Ya no se reordena automáticamente; el usuario decide con un botón.
    });
  }

  void _reordenarRuleta() {
    setState(() {
      _opciones.shuffle(Random());
      _opcionesVN.value = List.unmodifiable(_opciones);
      // Opcional: reiniciar ángulo para ver el nuevo orden desde arriba
      _giroActual = 0.0;
    });
  }

  void _agregarOpcion() {
    final controlador = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Agregar juego"),
        content: TextField(
          controller: controlador,
          decoration: const InputDecoration(hintText: "Nombre del juego"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              if (controlador.text.trim().isNotEmpty) {
                setState(() {
                  _opciones.add(controlador.text.trim());
                  _opcionesVN.value = List.unmodifiable(_opciones);
                });
                _saveOptions();
              }
              Navigator.pop(context);
            },
            child: const Text("Agregar"),
          ),
        ],
      ),
    );
  }

  void _editarOpcion(int index) {
    final controlador = TextEditingController(text: _opciones[index]);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Editar juego"),
        content: TextField(
          controller: controlador,
          decoration: const InputDecoration(hintText: "Nuevo nombre"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              if (controlador.text.trim().isNotEmpty) {
                setState(() {
                  _opciones[index] = controlador.text.trim();
                  _opcionesVN.value = List.unmodifiable(_opciones);
                });
                _saveOptions();
              }
              Navigator.pop(context);
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  void _eliminarOpcion(int index) {
    setState(() {
      _opciones.removeAt(index);
      _opcionesVN.value = List.unmodifiable(_opciones);
    });
    _saveOptions();
  }

  void _abrirJuegos() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: SafeArea(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: _opcionesVN,
              builder: (context, opciones, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Juegos',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _agregarOpcion,
                            icon: const Icon(Icons.add),
                            label: const Text('Agregar'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: opciones.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(opciones[index]),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editarOpcion(index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _eliminarOpcion(index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _chargeTimer?.cancel();
    _opcionesVN.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ruleta de Juegos")),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dim = min(constraints.maxWidth, constraints.maxHeight);
                  return ValueListenableBuilder<List<String>>(
                    valueListenable: _opcionesVN,
                    builder: (context, opciones, _) {
                      return GestureDetector(
                        onPanEnd: (details) {
                          final v = details.velocity.pixelsPerSecond.distance;
                          // mapa de velocidad a fuerza: 0.1 a 1.0
                          final nuevaFuerza = (v / 3000).clamp(0.1, 1.0);
                          setState(() => _fuerza = nuevaFuerza);
                          _girarConFuerza(nuevaFuerza);
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.rotate(
                              angle: _giroActual,
                              child: CustomPaint(
                                size: Size(dim, dim),
                                painter: RuletaPainter(opciones),
                              ),
                            ),
                            // Puntero personalizado
                            CustomPaint(
                              size: Size(dim, dim),
                              painter: PointerPainter(),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ValueListenableBuilder<List<String>>( 
              valueListenable: _opcionesVN,
              builder: (context, opciones, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: opciones.isNotEmpty ? _girarRuleta : null,
                      icon: const Icon(Icons.casino),
                      label: const Text("Girar Ruleta"),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: opciones.isNotEmpty ? _reordenarRuleta : null,
                      icon: const Icon(Icons.shuffle),
                      label: const Text("Reordenar ruleta"),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTapDown: (_) {
                        // Inicia carga desde 0 cada vez
                        _chargeTimer?.cancel();
                        setState(() => _fuerza = 0.0);
                        _chargeTimer = Timer.periodic(
                          const Duration(milliseconds: 40),
                          (t) {
                            // Incremento con una ligera aleatoriedad para que nunca sea exacto
                            final jitter = (Random().nextDouble() * 0.02);
                            final next = (_fuerza + 0.03 + jitter).clamp(0.0, 1.0);
                            setState(() => _fuerza = next);
                            if (_fuerza >= 1.0) {
                              // Si llegó al máximo, mantenemos al 100% pero seguimos esperando a que suelte
                              setState(() => _fuerza = 1.0);
                            }
                          },
                        );
                      },
                      onTapUp: (_) {
                        _chargeTimer?.cancel();
                        _girarConFuerza(_fuerza);
                        setState(() => _fuerza = 0.0);
                      },
                      onTapCancel: () {
                        _chargeTimer?.cancel();
                        _girarConFuerza(_fuerza);
                        setState(() => _fuerza = 0.0);
                      },
                      child: OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.flash_on),
                        label: const Text("Mantén para cargar"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _abrirJuegos,
                      icon: const Icon(Icons.list),
                      label: const Text("Juegos"),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: LinearProgressIndicator(value: _fuerza),
          ),
          if (_opcionSeleccionada != null) ...[
            const SizedBox(height: 8),
            Text(
              "Juego seleccionado: $_opcionSeleccionada",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  // Cerrar la app completamente
                  exit(0);
                },
                icon: const Icon(Icons.exit_to_app, size: 26),
                label: const Text("Ir a jugar"),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class RuletaPainter extends CustomPainter {
  final List<String> opciones;
  RuletaPainter(this.opciones);

  @override
  void paint(Canvas canvas, Size size) {
    if (opciones.isEmpty) {
      // Nada que dibujar si no hay opciones
      return;
    }
    final paint = Paint()..style = PaintingStyle.fill;
    final radio = size.width / 2;
    final centro = Offset(radio, radio);
    final sweep = (2 * pi) / opciones.length;
    final random = Random(42);

    for (int i = 0; i < opciones.length; i++) {
      paint.color = Colors.primaries[i % Colors.primaries.length].withValues(
        alpha: 0.7 + random.nextDouble() * 0.3,
      );

      final start = i * sweep;
      canvas.drawArc(
        Rect.fromCircle(center: centro, radius: radio),
        start,
        sweep,
        true,
        paint,
      );

      // Dibujar el texto
      final textPainter = TextPainter(
        text: TextSpan(
          text: opciones[i],
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final angle = start + sweep / 2;
      final offset = Offset(
        centro.dx + (radio / 2) * cos(angle) - textPainter.width / 2,
        centro.dy + (radio / 2) * sin(angle) - textPainter.height / 2,
      );

      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
