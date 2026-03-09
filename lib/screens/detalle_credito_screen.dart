import 'dart:async';

import 'package:flutter/material.dart';
import '../models/credito.dart';
import '../widgets/progreso_credito_widget.dart';
import '../services/credito_service.dart';

class DetalleCreditoScreen extends StatefulWidget {
  final Credito credito;

  const DetalleCreditoScreen({super.key, required this.credito});

  @override
  State<DetalleCreditoScreen> createState() => _DetalleCreditoScreenState();
}

// Agrega este widget al inicio de la clase o en un archivo separado
class RelojDuracionEtapa extends StatefulWidget {
  final EtapaCredito? etapa;
  final String nombreEtapa;
  final bool isActive;

  const RelojDuracionEtapa({
    super.key,
    required this.etapa,
    required this.nombreEtapa,
    this.isActive = false,
  });

  @override
  State<RelojDuracionEtapa> createState() => _RelojDuracionEtapaState();
}

class _RelojDuracionEtapaState extends State<RelojDuracionEtapa> {
  late Duration _currentDuration;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateDuration();
    if (widget.isActive && widget.etapa?.fechaFin == null) {
      _startTimer();
    }
  }

  void _updateDuration() {
    if (widget.etapa?.fechaInicio != null) {
      if (widget.etapa?.fechaFin != null) {
        // Si la etapa está completada, la duración es fechaFin - fechaInicio
        _currentDuration =
            widget.etapa!.fechaFin!.difference(widget.etapa!.fechaInicio!);
      } else {
        // Si la etapa no está completada, la duración es ahora - fechaInicio
        _currentDuration =
            DateTime.now().difference(widget.etapa!.fechaInicio!);
      }
    } else {
      _currentDuration = Duration.zero;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _updateDuration();
        });
      }
    });
  }

  @override
  void didUpdateWidget(RelojDuracionEtapa oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si la etapa se acaba de marcar como completada, forzar actualización inmediata
    if (widget.etapa?.fechaFin != oldWidget.etapa?.fechaFin) {
      _updateDuration();
      _timer?.cancel();
      setState(() {}); // Fuerza el rebuild para mostrar el tiempo final
    } else if (widget.isActive != oldWidget.isActive) {
      _updateDuration();
      if (widget.isActive && widget.etapa?.fechaFin == null) {
        _timer?.cancel();
        _startTimer();
      } else {
        _timer?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');

    final totalHours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    // Si la duración es exactamente cero segundos y la etapa está completada, mostrar 00:00:01
    if (duration.inSeconds == 0 && (widget.etapa?.fechaFin != null)) {
      return '00:00:01';
    }

    return '${twoDigits(totalHours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.etapa?.fechaFin != null;
    final color = isCompleted
        ? Colors.green
        : (widget.isActive ? Colors.blue : Colors.grey);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted ? Icons.access_time_filled : Icons.timer,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDuration(_currentDuration),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontFamily: 'monospace',
                ),
              ),
              if (isCompleted && widget.etapa?.fechaFin != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Finalizado: '
                    '${widget.etapa!.fechaFin!.day.toString().padLeft(2, '0')}/'
                    '${widget.etapa!.fechaFin!.month.toString().padLeft(2, '0')}/'
                    '${widget.etapa!.fechaFin!.year}',
                    style: TextStyle(
                      fontSize: 10,
                      color: color.withOpacity(0.7),
                    ),
                  ),
                ),
            ],
          ),
          if (widget.isActive && !isCompleted) ...[
            const SizedBox(width: 4),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 1,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetalleCreditoScreenState extends State<DetalleCreditoScreen> {
  final _creditoService = CreditoService();
  late Credito _credito;
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _credito = widget.credito;
  }

  Future<void> _actualizarCredito() async {
    // No activamos _isLoading para evitar parpadeos, ya que la actualización por ID es rápida
    try {
      // Optimización: Usar getCreditoById en lugar de traer todos los créditos
      final actualizado = await _creditoService.getCreditoById(_credito.id);

      if (actualizado != null) {
        _verificarYNotificarCompletado(_credito, actualizado);
        if (mounted) {
          setState(() {
            _credito = actualizado;
          });
        }
      }
    } catch (e) {
      if (mounted) _mostrarError('Error al actualizar el crédito');
    }
  }

  void _verificarYNotificarCompletado(Credito anterior, Credito nuevo) {
    for (var entry in nuevo.etapas.entries) {
      final nombreEtapa = entry.key;
      final etapaNueva = entry.value;
      final etapaAnterior = anterior.etapas[nombreEtapa];

      if (etapaNueva.completada && !(etapaAnterior?.completada ?? false)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text('Fase "$nombreEtapa" completada')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        break; // Notificar solo la primera diferencia encontrada
      }
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  double _getProgreso() {
    final completadas =
        _credito.etapas.values.where((e) => e.completada).length;
    return completadas / Credito.etapasProceso.length;
  }

  Color _getColorForProgreso() {
    final progreso = _getProgreso();
    if (progreso == 1.0) return Colors.green;
    if (progreso >= 0.6) return Colors.blue;
    if (progreso >= 0.3) return Colors.orange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final colorProgreso = _getColorForProgreso();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorProgreso.withAlpha(13),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    // App Bar personalizada
                    SliverAppBar(
                      expandedHeight: 200,
                      pinned: true,
                      backgroundColor: colorProgreso,
                      flexibleSpace: FlexibleSpaceBar(
                        title: Text(
                          _credito.nombreCliente,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colorProgreso,
                                colorProgreso.withAlpha(178),
                              ],
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                right: -50,
                                top: -50,
                                child: CircleAvatar(
                                  radius: 100,
                                  backgroundColor: Colors.white.withAlpha(26),
                                ),
                              ),
                              Positioned(
                                left: -30,
                                bottom: -30,
                                child: CircleAvatar(
                                  radius: 80,
                                  backgroundColor: Colors.white.withAlpha(26),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Cliente',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      _credito.nombreCliente,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                    // Contenido principal
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          // Widget de progreso del crédito
                          ProgresoCreditoWidget(
                            credito: _credito,
                            onActualizado: _actualizarCredito,
                          ),

                          const SizedBox(height: 20),

                          // Tarjeta de información general
                          _buildInfoCard(colorProgreso),

                          const SizedBox(height: 20),

                          // Línea de tiempo del flujo de entrega
                          _buildTimelineSection(),

                          const SizedBox(height: 20),

                          const SizedBox(height: 20),

                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(Color colorProgreso) {
    final completadas =
        _credito.etapas.values.where((e) => e.completada).length;
    final total = Credito.etapasProceso.length;
    final progreso = completadas / total;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Barra de progreso superior
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: LinearProgressIndicator(
              value: progreso,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(colorProgreso),
              minHeight: 6,
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorProgreso.withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.credit_card,
                        color: colorProgreso,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ID del Crédito',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            _credito.id,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorProgreso.withAlpha(26),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colorProgreso,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${(progreso * 100).toInt()}%',
                            style: TextStyle(
                              color: colorProgreso,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30),

                Row(
                  children: [
                    _buildInfoItem(
                      icon: Icons.calendar_today,
                      label: 'Fecha inicio',
                      value:
                          '${_credito.fechaInicio.day}/${_credito.fechaInicio.month}/${_credito.fechaInicio.year}',
                      color: Colors.blue,
                    ),
                    Container(
                      height: 30,
                      width: 1,
                      color: Colors.grey.shade300,
                    ),
                    _buildInfoItem(
                      icon: Icons.flag,
                      label: 'Etapa actual',
                      value: _credito.etapaActual,
                      color: colorProgreso,
                    ),
                    Container(
                      height: 30,
                      width: 1,
                      color: Colors.grey.shade300,
                    ),
                    _buildInfoItem(
                      icon: Icons.check_circle,
                      label: 'Progreso',
                      value: '$completadas/$total',
                      color: Colors.green,
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                _buildTiempoTotal(), // <-- AÑADE ESTA LÍNEA
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    final etapas = Credito.etapasProceso;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.timeline, color: Colors.blue.shade700),
              ),
              const SizedBox(width: 10),
              const Text(
                'Flujo de Entrega',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Línea de tiempo mejorada
          ...etapas.asMap().entries.map((entry) {
            final index = entry.key;
            final etapa = entry.value;
            final etapaData = _credito.etapas[etapa];
            final isCompleted = etapaData?.completada ?? false;
            final isCurrent = etapa == _credito.etapaActual && !isCompleted;

            return _buildTimelineItem(
              etapa: etapa,
              index: index + 1,
              isCompleted: isCompleted,
              isCurrent: isCurrent,
              fecha: isCompleted ? etapaData?.fechaFin : null,
              notas: etapaData?.notas,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required String etapa,
    required int index,
    required bool isCompleted,
    required bool isCurrent,
    DateTime? fecha,
    String? notas,
  }) {
    Color getColor() {
      if (isCompleted) return Colors.green;
      if (isCurrent) return Colors.blue;
      return Colors.grey;
    }

    final etapaData = _credito.etapas[etapa];

    return Stack(children: [
      if (index < Credito.etapasProceso.length)
        Positioned(
          top: 30,
          bottom: 0,
          left: 19,
          width: 2,
          child: Container(
            color: getColor().withAlpha(77),
          ),
        ),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Columna del indicador
        SizedBox(
          width: 40,
          child: Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: getColor().withAlpha(26),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: getColor(),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check, color: getColor(), size: 16)
                      : Text(
                          index.toString(),
                          style: TextStyle(
                            color: getColor(),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),

        // Contenido
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 20),
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: getColor().withAlpha(13),
                borderRadius: BorderRadius.circular(12),
                border:
                    isCurrent ? Border.all(color: getColor(), width: 2) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          etapa,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: getColor(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Reloj de duración y fecha de finalización
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          RelojDuracionEtapa(
                            etapa: etapaData,
                            nombreEtapa: etapa,
                            isActive: isCurrent && !isCompleted,
                          ),
                          if (isCompleted && etapaData?.fechaFin != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Finalizado: '
                                '${etapaData!.fechaFin!.day.toString().padLeft(2, '0')}/'
                                '${etapaData!.fechaFin!.month.toString().padLeft(2, '0')}/'
                                '${etapaData!.fechaFin!.year}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: getColor().withOpacity(0.7),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (notas != null && notas.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      notas,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  if (isCurrent && !isCompleted) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Etapa actual',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ]),
    ]);
  }

  Widget _buildTiempoTotal() {
    // Obtener todas las fechas de inicio no nulas
    final fechasInicio = _credito.etapas.values
        .map((e) => e.fechaInicio)
        .whereType<DateTime>()
        .toList();

    // Obtener todas las fechas de fin no nulas
    final fechasFin = _credito.etapas.values
        .map((e) => e.fechaFin)
        .whereType<DateTime>()
        .toList();

    if (fechasInicio.isEmpty) return const SizedBox.shrink();

    final primeraFecha = fechasInicio.reduce((a, b) => a.isBefore(b) ? a : b);
    final todasCompletadas = _credito.etapas.values.every((e) => e.completada);

    DateTime? ultimaFecha;
    if (fechasFin.isNotEmpty && todasCompletadas) {
      ultimaFecha = fechasFin.reduce((a, b) => a.isAfter(b) ? a : b);
    }

    final ahora = DateTime.now();
    final fechaDeCalculo = todasCompletadas ? (ultimaFecha ?? ahora) : ahora;
    final duracionTotal = fechaDeCalculo.difference(primeraFecha);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.timer, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tiempo total del crédito',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  _formatDuration(duracionTotal),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: todasCompletadas
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              todasCompletadas ? 'COMPLETADO' : 'EN PROCESO',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: todasCompletadas
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final totalHours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    // Si la duración es exactamente cero segundos, mostrar 00:00:01 si está completado (opcional, igual que en etapas)
    if (duration.inSeconds == 0) {
      return '00:00:01';
    }
    return '${twoDigits(totalHours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}
