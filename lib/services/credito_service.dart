// lib/services/credito_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/credito.dart';

class CreditoService {
  final CollectionReference _creditosCollection =
      FirebaseFirestore.instance.collection('creditos');

  // Obtener todos los créditos (Stream en tiempo real)
  Stream<List<Credito>> getCreditosStream() {
    return _creditosCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Asegurar que el ID sea el de Firestore
        return Credito.fromJson(data);
      }).toList();
    });
  }

  // Obtener todos los créditos (una sola vez)
  Future<List<Credito>> getCreditos() async {
    try {
      final snapshot = await _creditosCollection.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Credito.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Error obteniendo créditos: $e');
      return [];
    }
  }

  // Guardar o actualizar un crédito
  Future<void> guardarCredito(Credito credito) async {
    try {
      final jsonCredito = credito.toJson();

      // Eliminar el campo id del mapa para que Firestore use su propio ID
      jsonCredito.remove('id');

      // Asegurar que las fechas sean Timestamp de Firestore
      jsonCredito['fechaInicio'] = Timestamp.fromDate(credito.fechaInicio);

      // Convertir las fechas de las etapas a Timestamp solo si son String
      jsonCredito['etapas'].forEach((key, value) {
        if (value['fechaInicio'] != null && value['fechaInicio'] is String) {
          value['fechaInicio'] =
              Timestamp.fromDate(DateTime.parse(value['fechaInicio']));
        }
        if (value['fechaFin'] != null && value['fechaFin'] is String) {
          value['fechaFin'] =
              Timestamp.fromDate(DateTime.parse(value['fechaFin']));
        }
      });

      if (credito.id.isEmpty || credito.id == 'temp_${credito.nombreCliente}') {
        // Crear nuevo crédito con ID generado por Firestore
        final docRef = await _creditosCollection.add(jsonCredito);
        debugPrint('Crédito creado con ID: ${docRef.id}');
      } else {
        // Actualizar crédito existente
        await _creditosCollection.doc(credito.id).set(jsonCredito);
        debugPrint('Crédito actualizado con ID: ${credito.id}');
      }
    } catch (e) {
      debugPrint('Error guardando crédito: $e');
      rethrow;
    }
  }

  // Guardar lista completa de créditos (útil para migración)
  Future<void> guardarCreditos(List<Credito> creditos) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      for (var credito in creditos) {
        final jsonCredito = credito.toJson();
        jsonCredito.remove('id');
        jsonCredito['fechaInicio'] = Timestamp.fromDate(credito.fechaInicio);

        final docRef = _creditosCollection.doc(credito.id);
        batch.set(docRef, jsonCredito);
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error guardando créditos: $e');
      rethrow;
    }
  }

  // Crear un nuevo crédito
  Future<Credito> crearCredito(String nombreCliente) async {
    final Map<String, Map<String, dynamic>> etapasMap = {};

    for (var etapa in Credito.etapasProceso) {
      etapasMap[etapa] = {
        'completada': false,
        'fechaInicio': null,
        'fechaFin': null,
        'notas': '',
      };
    }

    final nuevoCredito = Credito(
      id: 'temp_$nombreCliente', // ID temporal
      nombreCliente: nombreCliente,
      fechaInicio: DateTime.now(),
      etapas: etapasMap.map((key, value) => MapEntry(
            key,
            EtapaCredito(
              completada: value['completada'],
              fechaInicio: value['fechaInicio'],
              fechaFin: value['fechaFin'],
              notas: value['notas'],
            ),
          )),
      etapaActual: Credito.etapasProceso.first,
    );

    return nuevoCredito;
  }

  // Actualizar etapa específica
  Future<void> actualizarEtapa(
      String creditoId, String etapa, bool completada) async {
    try {
      final docRef = _creditosCollection.doc(creditoId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final etapas = Map<String, dynamic>.from(data['etapas'] ?? {});
          final etapaData = Map<String, dynamic>.from(etapas[etapa] ?? {});

          if (completada && !(etapaData['completada'] ?? false)) {
            // Marcar como completada
            etapaData['completada'] = true;
            final currentIndex = Credito.etapasProceso.indexOf(etapa);
            // Asignar fechaInicio correctamente
            if (etapaData['fechaInicio'] == null) {
              if (currentIndex == 0) {
                // Primera fase: usar fechaInicio del crédito
                etapaData['fechaInicio'] = data['fechaInicio'];
              } else {
                // Otras fases: usar fechaFin de la fase anterior
                final anterior = Credito.etapasProceso[currentIndex - 1];
                final anteriorData =
                    Map<String, dynamic>.from(etapas[anterior] ?? {});
                etapaData['fechaInicio'] =
                    anteriorData['fechaFin'] ?? Timestamp.now();
              }
            }
            etapaData['fechaFin'] =
                Timestamp.now(); // Guardar fecha de finalización

            // Determinar siguiente etapa
            String nuevaEtapaActual = etapa;
            if (currentIndex < Credito.etapasProceso.length - 1) {
              nuevaEtapaActual = Credito.etapasProceso[currentIndex + 1];
            } else {
              nuevaEtapaActual = 'COMPLETADO';
            }

            etapas[etapa] = etapaData;

            transaction.update(docRef, {
              'etapas': etapas,
              'etapaActual': nuevaEtapaActual,
            });
          } else if (!completada && (etapaData['completada'] ?? false)) {
            // Si se desmarca como completada, limpiar fechaFin
            etapaData['fechaFin'] = null;
            etapaData['completada'] = false;
            etapas[etapa] = etapaData;

            transaction.update(docRef, {
              'etapas': etapas,
            });
          }
        }
      });

      debugPrint('Etapa $etapa actualizada correctamente');
    } catch (e) {
      debugPrint('Error actualizando etapa: $e');
      rethrow;
    }
  }

  // Eliminar un crédito
  Future<void> eliminarCredito(String creditoId) async {
    try {
      await _creditosCollection.doc(creditoId).delete();
      debugPrint('Crédito $creditoId eliminado');
    } catch (e) {
      debugPrint('Error eliminando crédito: $e');
      rethrow;
    }
  }

  // Obtener un crédito específico
  Future<Credito?> getCreditoById(String creditoId) async {
    try {
      final doc = await _creditosCollection.doc(creditoId).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Credito.fromJson(data);
      }

      return null;
    } catch (e) {
      debugPrint('Error obteniendo crédito: $e');
      return null;
    }
  }

  // Buscar créditos por nombre de cliente
  Future<List<Credito>> buscarCreditos(String query) async {
    try {
      final snapshot = await _creditosCollection
          .where('nombreCliente', isGreaterThanOrEqualTo: query)
          .where('nombreCliente', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Credito.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Error buscando créditos: $e');
      return [];
    }
  }

  // Obtener estadísticas
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final snapshot = await _creditosCollection.get();
      final creditos = snapshot.docs;

      int total = creditos.length;
      int completados = 0;
      int enProgreso = 0;

      for (var doc in creditos) {
        final data = doc.data() as Map<String, dynamic>;
        final etapas = data['etapas'] as Map<String, dynamic>;
        final completadas =
            etapas.values.where((e) => e['completada'] == true).length;

        if (completadas == Credito.etapasProceso.length) {
          completados++;
        } else if (completadas > 0) {
          enProgreso++;
        }
      }

      return {
        'total': total,
        'completados': completados,
        'enProgreso': enProgreso,
        'pendientes': total - (completados + enProgreso),
      };
    } catch (e) {
      debugPrint('Error obteniendo estadísticas: $e');
      return {
        'total': 0,
        'completados': 0,
        'enProgreso': 0,
        'pendientes': 0,
      };
    }
  }
}
