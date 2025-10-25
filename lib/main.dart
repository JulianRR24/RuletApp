import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Importado para los campos de números
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow();
    await windowManager.setFullScreen(true);
  } catch (_) {
    // Si no está disponible (p. ej. en web), continuar sin pantalla completa
  }
  runApp(const RuletaApp());
}

// NUEVO: Modelo de datos para las opciones de la ruleta
class RuletaOpcion {
  String nombre;
  double porcentaje;

  RuletaOpcion({required this.nombre, required this.porcentaje});

  // Métodos para guardar y cargar desde JSON
  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'porcentaje': porcentaje,
      };

  factory RuletaOpcion.fromJson(Map<String, dynamic> json) => RuletaOpcion(
        nombre: json['nombre'] as String,
        porcentaje: (json['porcentaje'] as num).toDouble(),
      );
}

class PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final radio = size.width / 2;
    final centro = Offset(radio, radio);
    final tip = Offset(centro.dx, centro.dy - radio + 3);
    final length = max(24.0, radio * 0.22);
    final baseY = tip.dy + length;
    final halfBase = max(2.0, radio * 0.012);
    final needle = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - halfBase, baseY)
      ..lineTo(tip.dx + halfBase, baseY)
      ..close();
    final baseCircleCenter = Offset(centro.dx, baseY + halfBase + 2);
    final baseCircleR = max(2.5, radio * 0.015);
    final fill = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
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
  // ACTUALIZADO: Ahora es una lista de RuletaOpcion
  final List<RuletaOpcion> _opciones = [];

  // ACTUALIZADO: El ValueNotifier ahora maneja RuletaOpcion
  late ValueNotifier<List<RuletaOpcion>> _opcionesVN;

  late AnimationController _controller;
  late Animation<double> _animation;
  double _giroActual = 0.0;
  String? _opcionSeleccionada;
  double _fuerza = 0.0;
  Timer? _chargeTimer;

  @override
  void initState() {
    super.initState();
    // ACTUALIZADO: Inicializa con la nueva lista y notificador
    _opciones.addAll(_getDefaultOptions());
    _opcionesVN =
        ValueNotifier<List<RuletaOpcion>>(List.unmodifiable(_opciones));

    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.decelerate);
    _controller.addListener(() {
      setState(() {
        _giroActual = _animation.value * 2 * pi;
      });
    });
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _determinarOpcion();
      }
    });
    _loadOptions();
  }

  // NUEVO: Opciones por defecto si no hay nada guardado
  List<RuletaOpcion> _getDefaultOptions() {
    return [
      RuletaOpcion(nombre: "Minecraft", porcentaje: 20.0),
      RuletaOpcion(nombre: "Fortnite", porcentaje: 20.0),
      RuletaOpcion(nombre: "Among Us", porcentaje: 20.0),
      RuletaOpcion(nombre: "FIFA", porcentaje: 20.0),
      RuletaOpcion(nombre: "Call of Duty", porcentaje: 20.0),
    ];
  }

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

  // ACTUALIZADO: Carga la nueva estructura de datos (List<RuletaOpcion>)
  Future<void> _loadOptions() async {
    try {
      final file = await _getDataFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        final data = jsonDecode(contents);
        if (data is List) {
          List<RuletaOpcion> loadedOpciones = [];

          if (data.isEmpty) {
            // Archivo vacío, usar defaults
            loadedOpciones = _getDefaultOptions();
          } else if (data.first is String) {
            // Formato ANTIGUO: List<String>
            // Migrar a nuevo formato con porcentajes iguales
            final double equalPct =
                data.isNotEmpty ? (100.0 / data.length) : 100.0;
            loadedOpciones = data
                .whereType<String>()
                .map((nombre) =>
                    RuletaOpcion(nombre: nombre, porcentaje: equalPct))
                .toList();
            // Guardar el formato nuevo inmediatamente
            await _saveOptions(loadedOpciones);
          } else if (data.first is Map) {
            // Formato NUEVO: List<Map>
            loadedOpciones = data
                .map((item) {
                  try {
                    return RuletaOpcion.fromJson(item as Map<String, dynamic>);
                  } catch (e) {
                    return null;
                  }
                })
                .whereType<RuletaOpcion>()
                .toList();
          }

          // Validar que los porcentajes sumen 100
          final double total =
              loadedOpciones.fold(0.0, (sum, op) => sum + op.porcentaje);
          // Usar un epsilon (margen de error) para comparar doubles
          if (loadedOpciones.isNotEmpty && (total - 100.0).abs() > 0.01) {
            // Los porcentajes están corruptos, re-balancear
            final double equalPct = 100.0 / loadedOpciones.length;
            loadedOpciones = loadedOpciones
                .map((op) =>
                    RuletaOpcion(nombre: op.nombre, porcentaje: equalPct))
                .toList();
            // Guardar el formato corregido
            await _saveOptions(loadedOpciones);
          }

          setState(() {
            _opciones.clear();
            _opciones.addAll(
                loadedOpciones.isNotEmpty ? loadedOpciones : _getDefaultOptions());
            _opcionesVN.value = List.unmodifiable(_opciones);
          });
        }
      }
    } catch (e) {
      debugPrint('Error al cargar opciones: $e');
      // Si falla la carga, usar valores por defecto
      setState(() {
        _opciones.clear();
        _opciones.addAll(_getDefaultOptions());
        _opcionesVN.value = List.unmodifiable(_opciones);
      });
    }
  }

  // ACTUALIZADO: Guarda la nueva estructura de datos
  // Acepta una lista opcional para usar durante la migración
  Future<void> _saveOptions([List<RuletaOpcion>? opcionesAGuardar]) async {
    try {
      final file = await _getDataFile();
      // Usar la lista provista (para migración) o la lista de estado actual
      final lista = opcionesAGuardar ?? _opciones;
      final dataToSave = lista.map((op) => op.toJson()).toList();
      await file.writeAsString(jsonEncode(dataToSave), flush: true);
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
    final spins = 3 + (fuerza.clamp(0.0, 1.0) * 9) + random.nextDouble();
    final duracion = Duration(milliseconds: (2000 + (fuerza * 5000)).round());

    _controller.duration = duracion;
    _animation = Tween<double>(
      begin: 0,
      end: spins,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.decelerate));
    _controller.reset();
    _controller.forward();
  }

  // ACTUALIZADO: Determina la opción basado en los porcentajes
  void _determinarOpcion() {
    if (_opciones.isEmpty) return;

    // Alinear con puntero en la parte superior (12 en punto).
    // 0 rad es derecha. Superior es -pi/2.
    final anguloFinal = _giroActual % (2 * pi);
    // Normalizar el ángulo del puntero (0 a 2pi, donde 0 es la parte superior)
    double anguloPuntero = (-pi / 2 - anguloFinal) % (2 * pi);
    if (anguloPuntero < 0) anguloPuntero += 2 * pi;
    // Pequeño sesgo para evitar empates en el borde
    anguloPuntero = (anguloPuntero - 1e-6) % (2 * pi);

    double anguloAcumulado = 0.0;
    RuletaOpcion? opcionGanadora;

    // Iterar sobre las opciones y sus sectores
    for (final opcion in _opciones) {
      // Calcular el tamaño del sector basado en el porcentaje
      final sweepAngle = (opcion.porcentaje / 100.0) * (2 * pi);
      final anguloFinSector = anguloAcumulado + sweepAngle;

      // Comprobar si el puntero está dentro de este sector
      if (anguloPuntero >= anguloAcumulado && anguloPuntero < anguloFinSector) {
        opcionGanadora = opcion;
        break;
      }
      anguloAcumulado = anguloFinSector;
    }

    // Fallback por si acaso (ej. error de punto flotante en el último sector)
    if (opcionGanadora == null && _opciones.isNotEmpty) {
      opcionGanadora = _opciones.last;
    }

    setState(() {
      _opcionSeleccionada = opcionGanadora?.nombre;
    });
  }

  // Reordenar ahora solo afecta el orden de los colores en la ruleta
  void _reordenarRuleta() {
    setState(() {
      _opciones.shuffle(Random());
      _opcionesVN.value = List.unmodifiable(_opciones);
      _giroActual = 0.0;
    });
    // No es necesario guardar, el orden visual es temporal
  }

  // ELIMINADOS: _agregarOpcion, _editarOpcion, _eliminarOpcion
  // Ahora se manejan en _GestionarOpcionesSheet

  // ACTUALIZADO: Abre el nuevo modal de gestión
  void _abrirJuegos() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Usar constraints para que no ocupe toda la pantalla en web/desktop
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width > 700
            ? 700
            : double.infinity,
      ),
      builder: (ctx) {
        // Pasamos una copia de las opciones para editar de forma segura
        return _GestionarOpcionesSheet(
          opcionesIniciales: List<RuletaOpcion>.from(_opciones.map(
              (op) => RuletaOpcion(nombre: op.nombre, porcentaje: op.porcentaje))),
          onGuardar: (nuevasOpciones) {
            setState(() {
              _opciones
                ..clear()
                ..addAll(nuevasOpciones);
              _opcionesVN.value = List.unmodifiable(_opciones);
            });
            _saveOptions(); // Guardar la nueva lista
            Navigator.pop(context); // Cierra el bottom sheet
          },
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
                  // ACTUALIZADO: Escucha cambios en List<RuletaOpcion>
                  return ValueListenableBuilder<List<RuletaOpcion>>(
                    valueListenable: _opcionesVN,
                    builder: (context, opciones, _) {
                      return GestureDetector(
                        onPanEnd: (details) {
                          final v = details.velocity.pixelsPerSecond.distance;
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
                                // ACTUALIZADO: Pasa la lista de RuletaOpcion
                                painter: RuletaPainter(opciones),
                              ),
                            ),
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
            // ACTUALIZADO: Escucha cambios en List<RuletaOpcion>
            child: ValueListenableBuilder<List<RuletaOpcion>>(
              valueListenable: _opcionesVN,
              builder: (context, opciones, _) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: opciones.isNotEmpty ? _girarRuleta : null,
                      icon: const Icon(Icons.casino),
                      label: const Text("Girar Ruleta"),
                    ),
                    OutlinedButton.icon(
                      onPressed: opciones.isNotEmpty ? _reordenarRuleta : null,
                      icon: const Icon(Icons.shuffle),
                      label: const Text("Reordenar colores"),
                    ),
                    GestureDetector(
                      onTapDown: (_) {
                        _chargeTimer?.cancel();
                        setState(() => _fuerza = 0.0);
                        _chargeTimer = Timer.periodic(
                          const Duration(milliseconds: 40),
                          (t) {
                            final jitter = (Random().nextDouble() * 0.02);
                            final next =
                                (_fuerza + 0.03 + jitter).clamp(0.0, 1.0);
                            setState(() => _fuerza = next);
                            if (_fuerza >= 1.0) {
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
                        onPressed: null, // Deshabilitado para el gesto
                        icon: const Icon(Icons.flash_on),
                        label: const Text("Mantén para cargar"),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _abrirJuegos,
                      icon: const Icon(Icons.list),
                      label: const Text("Juegos y %"),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: LinearProgressIndicator(value: _fuerza),
          ),
          if (_opcionSeleccionada != null) ...[
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
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
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

// ACTUALIZADO: El pintor ahora usa List<RuletaOpcion>
class RuletaPainter extends CustomPainter {
  final List<RuletaOpcion> opciones;
  RuletaPainter(this.opciones);

  @override
  void paint(Canvas canvas, Size size) {
    if (opciones.isEmpty) {
      return;
    }
    final paint = Paint()..style = PaintingStyle.fill;
    final radio = size.width / 2;
    final centro = Offset(radio, radio);
    final random = Random(42); // Random consistente para los colores

    double startAngle = 0.0; // El ángulo de inicio se acumula

    for (int i = 0; i < opciones.length; i++) {
      final opcion = opciones[i];
      // ACTUALIZADO: El sweep (arco) se calcula desde el porcentaje
      final sweepAngle = (opcion.porcentaje / 100.0) * (2 * pi);

      paint.color = Colors.primaries[i % Colors.primaries.length].withValues(
        alpha: 0.7 + random.nextDouble() * 0.3,
      );

      canvas.drawArc(
        Rect.fromCircle(center: centro, radius: radio),
        startAngle,
        sweepAngle, // Usar el arco calculado
        true,
        paint,
      );

      // Dibujar el texto
      final textPainter = TextPainter(
        text: TextSpan(
          // Mostrar nombre y porcentaje
          text: "${opcion.nombre}\n(${opcion.porcentaje.toStringAsFixed(1)}%)",
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.white, blurRadius: 1.0),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center, // Centrar texto de varias líneas
      );
      textPainter.layout();

      // Calcular la posición del texto en el centro del sector
      final angle = startAngle + sweepAngle / 2;
      // Ajustar la distancia del radio para textos más largos
      final textRadius = radio * 0.6;
      final offset = Offset(
        centro.dx + textRadius * cos(angle) - textPainter.width / 2,
        centro.dy + textRadius * sin(angle) - textPainter.height / 2,
      );

      // Rotar el canvas para que el texto quede alineado
      canvas.save();
      canvas.translate(offset.dx + textPainter.width / 2,
          offset.dy + textPainter.height / 2);
      canvas.rotate(angle + pi / 2); // Rotar para que "apunte" hacia afuera
      canvas.translate(-(offset.dx + textPainter.width / 2),
          -(offset.dy + textPainter.height / 2));
      textPainter.paint(canvas, offset);
      canvas.restore();

      // Incrementar el ángulo de inicio para el próximo sector
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// NUEVO: Widget Stateful para el BottomSheet de gestión de opciones
class _GestionarOpcionesSheet extends StatefulWidget {
  final List<RuletaOpcion> opcionesIniciales;
  final Function(List<RuletaOpcion>) onGuardar;

  const _GestionarOpcionesSheet({
    required this.opcionesIniciales,
    required this.onGuardar,
  });

  @override
  State<_GestionarOpcionesSheet> createState() =>
      _GestionarOpcionesSheetState();
}

class _GestionarOpcionesSheetState extends State<_GestionarOpcionesSheet> {
  late List<RuletaOpcion> _opcionesEditables;
  late List<TextEditingController> _nombreControllers;
  late List<TextEditingController> _porcentajeControllers;
  double _totalPorcentaje = 0.0;
  bool _esTotalCien = false;

  @override
  void initState() {
    super.initState();
    // Clonar la lista para editarla
    _opcionesEditables = List<RuletaOpcion>.from(widget.opcionesIniciales
        .map((op) => RuletaOpcion(nombre: op.nombre, porcentaje: op.porcentaje)));

    _nombreControllers = [];
    _porcentajeControllers = [];

    for (final opcion in _opcionesEditables) {
      _nombreControllers.add(TextEditingController(text: opcion.nombre));
      final pController =
          TextEditingController(text: opcion.porcentaje.toStringAsFixed(1));
      pController.addListener(_calcularTotal);
      _porcentajeControllers.add(pController);
    }

    _calcularTotal(); // Calcular el total inicial
  }

  @override
  void dispose() {
    for (final controller in _nombreControllers) {
      controller.dispose();
    }
    for (final controller in _porcentajeControllers) {
      controller.removeListener(_calcularTotal);
      controller.dispose();
    }
    super.dispose();
  }

  void _calcularTotal() {
    double total = 0.0;
    for (final controller in _porcentajeControllers) {
      total += double.tryParse(controller.text) ?? 0.0;
    }
    setState(() {
      _totalPorcentaje = total;
      // Usar un epsilon para la comparación de punto flotante
      _esTotalCien = (total - 100.0).abs() < 0.01;
    });
  }

  void _agregarOpcion() {
    setState(() {
      final nuevaOpcion = RuletaOpcion(nombre: "Nuevo", porcentaje: 0.0);
      _opcionesEditables.add(nuevaOpcion);
      _nombreControllers.add(TextEditingController(text: nuevaOpcion.nombre));
      final pController =
          TextEditingController(text: nuevaOpcion.porcentaje.toStringAsFixed(1));
      pController.addListener(_calcularTotal);
      _porcentajeControllers.add(pController);
    });
    _calcularTotal(); // Recalcular
  }

  void _eliminarOpcion(int index) {
    setState(() {
      // Importante desregistrar el listener antes de desechar
      _porcentajeControllers[index].removeListener(_calcularTotal);
      _nombreControllers[index].dispose();
      _porcentajeControllers[index].dispose();

      _opcionesEditables.removeAt(index);
      _nombreControllers.removeAt(index);
      _porcentajeControllers.removeAt(index);
    });
    _calcularTotal(); // Recalcular
  }

  void _reequilibrar() {
    if (_opcionesEditables.isEmpty) return;
    final double equalPct = 100.0 / _opcionesEditables.length;
    setState(() {
      for (int i = 0; i < _opcionesEditables.length; i++) {
        _opcionesEditables[i].porcentaje = equalPct;
        _porcentajeControllers[i].text =
            equalPct.toStringAsFixed(2); // Formatear a 2 decimales
      }
    });
    _calcularTotal();
  }

  void _guardar() {
    // Actualizar la lista de opciones desde los controllers antes de guardar
    for (int i = 0; i < _opcionesEditables.length; i++) {
      _opcionesEditables[i].nombre = _nombreControllers[i].text.trim();
      _opcionesEditables[i].porcentaje =
          double.tryParse(_porcentajeControllers[i].text) ?? 0.0;
    }
    // Filtrar opciones sin nombre
    final opcionesValidas =
        _opcionesEditables.where((op) => op.nombre.isNotEmpty).toList();

    // Re-validar por si acaso se borró un nombre
    final double totalFinal =
        opcionesValidas.fold(0.0, (sum, op) => sum + op.porcentaje);
    if ((totalFinal - 100.0).abs() < 0.01) {
      widget.onGuardar(opcionesValidas);
    } else {
      // Mostrar un snackbar o algo si el total cambió (ej. al borrar fila)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Error: El total debe ser 100% y todas las opciones deben tener nombre."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Padding para que el teclado no tape el contenido
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Cabecera ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Juegos y Probabilidades',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _reequilibrar,
                        icon: const Icon(Icons.scale),
                        label: const Text('Equilibrar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _agregarOpcion,
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar'),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              // --- Lista de Opciones ---
              Expanded(
                child: ListView.builder(
                  itemCount: _opcionesEditables.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          // Campo de Nombre
                          Expanded(
                            child: TextField(
                              controller: _nombreControllers[index],
                              decoration: const InputDecoration(
                                labelText: "Nombre",
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Campo de Porcentaje
                          SizedBox(
                            width: 90,
                            child: TextField(
                              controller: _porcentajeControllers[index],
                              decoration: const InputDecoration(
                                labelText: "Porc. %",
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              // Teclado numérico con decimales
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                // Permitir solo números y un punto decimal
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*')),
                              ],
                            ),
                          ),
                          // Botón de Eliminar
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => _eliminarOpcion(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // --- Footer de Validación y Guardado ---
              const Divider(height: 24),
              Column(
                children: [
                  Text(
                    "Total: ${_totalPorcentaje.toStringAsFixed(1)}% / 100%",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      // Color verde si es 100, rojo si no
                      color: _esTotalCien
                          ? Colors.green
                          : (_totalPorcentaje > 100 ? Colors.red : Colors.orange),
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _totalPorcentaje / 100.0,
                    // Color verde si es 100, rojo si se pasa, naranja si falta
                    color: _esTotalCien
                        ? Colors.green
                        : (_totalPorcentaje > 100 ? Colors.red : Colors.orange),
                    backgroundColor: Colors.grey[300],
                    minHeight: 6,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.check_circle),
                      label: const Text("Listo", style: TextStyle(fontSize: 18)),
                      // Deshabilitado si el total no es 100%
                      onPressed: _esTotalCien ? _guardar : null,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
