import 'package:flutter/material.dart';
import '../models/credito.dart';
import '../services/credito_service.dart';

class ProgresoCreditoWidget extends StatefulWidget {
  final Credito credito;
  final Function() onActualizado;

  const ProgresoCreditoWidget(
      {super.key, required this.credito, required this.onActualizado});

  @override
  State<ProgresoCreditoWidget> createState() => _ProgresoCreditoWidgetState();
}

class _ProgresoCreditoWidgetState extends State<ProgresoCreditoWidget> {
  final _creditoService = CreditoService();
  // Mapa para rastrear qué etapa se está actualizando actualmente
  final Map<String, bool> _updatingEtapas = {};

  Color _getColorForEtapa(String etapa, String etapaActual) {
    if (etapa == etapaActual) {
      return Colors.orange;
    }

    final etapaIndex = Credito.etapasProceso.indexOf(etapa);
    final actualIndex = Credito.etapasProceso.indexOf(etapaActual);

    if (etapaIndex < actualIndex) {
      return Colors.green;
    }

    return Colors.grey[300]!;
  }

  IconData _getIconForEtapa(String etapa, String etapaActual) {
    final etapaIndex = Credito.etapasProceso.indexOf(etapa);
    final actualIndex = Credito.etapasProceso.indexOf(etapaActual);

    if (etapaIndex < actualIndex) {
      return Icons.check_circle;
    } else if (etapa == etapaActual) {
      return Icons.play_circle_filled;
    } else {
      return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.credito.nombreCliente,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Etapa Actual: ${widget.credito.etapaActual}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.blue[800],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(Credito.etapasProceso.length, (index) {
              final etapa = Credito.etapasProceso[index];
              final etapaData = widget.credito.etapas[etapa];
              final isUpdating = _updatingEtapas[etapa] ?? false;
              if (etapaData == null) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: _getColorForEtapa(etapa, widget.credito.etapaActual),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: Icon(
                    _getIconForEtapa(etapa, widget.credito.etapaActual),
                    color: Colors.white,
                  ),
                  title: Text(
                    etapa,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: etapa == widget.credito.etapaActual
                      ? SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: isUpdating
                                ? null
                                : () async {
                                    setState(() {
                                      _updatingEtapas[etapa] = true;
                                    });
                                    await _creditoService.actualizarEtapa(
                                      widget.credito.id,
                                      etapa,
                                      true,
                                    );
                                    widget.onActualizado();
                                    // No necesitamos poner false aquí porque el widget se reconstruirá
                                    // con los nuevos datos del padre, o si falla, el padre manejará el error.
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.orange,
                            ),
                            child: isUpdating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Text('Completar'),
                          ),
                        )
                      : (etapaData.completada
                          ? const Icon(Icons.check, color: Colors.white)
                          : null),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
