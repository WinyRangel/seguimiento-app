import 'package:cloud_firestore/cloud_firestore.dart';

class Credito {
  final String id;
  final String nombreCliente;
  DateTime fechaInicio;
  Map<String, EtapaCredito> etapas;
  String etapaActual;

  Credito({
    required this.id,
    required this.nombreCliente,
    required this.fechaInicio,
    required this.etapas,
    required this.etapaActual,
  });

  // Lista estática de etapas del proceso
  static List<String> etapasProceso = [
    'COORDINADOR (REVISIÓN)',
    'EJECUTIVA',
    'MESA DE CONTROL',
    'GERENTE DE OPERACION',
    'TESORERIA (1)',
    'MINISTRACION',
    'CONTROL INTERNO',
    'TESORERIA (2)',
    'COORDINADOR (CIERRE)',
    'PAQUETE',
    'HOJA DE CONTROL'
  ];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombreCliente': nombreCliente,
      'fechaInicio': fechaInicio.toIso8601String(),
      'etapas': etapas.map((key, value) => MapEntry(key, value.toJson())),
      'etapaActual': etapaActual,
    };
  }

  factory Credito.fromJson(Map<String, dynamic> json) {
    // Helper to handle both String (ISO8601) and Timestamp
    DateTime parseDate(dynamic date) {
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.parse(date);
      return DateTime.now(); // Fallback
    }

    return Credito(
      id: json['id'],
      nombreCliente: json['nombreCliente'],
      fechaInicio: parseDate(json['fechaInicio']),
      etapas: (json['etapas'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, EtapaCredito.fromJson(value)),
      ),
      etapaActual: json['etapaActual'],
    );
  }
}

// En tu archivo credito.dart
class EtapaCredito {
  bool completada;
  DateTime? fechaInicio;
  DateTime? fechaFin;
  String? notas;

  // Nueva propiedad para calcular duración
  Duration? get duracion {
    if (fechaInicio != null && fechaFin != null) {
      return fechaFin!.difference(fechaInicio!);
    }
    return null;
  }

  // Método para obtener duración formateada
  String get duracionFormateada {
    final dur = duracion;
    if (dur == null) return 'En progreso';

    if (dur.inDays > 0) {
      return '${dur.inDays}d ${dur.inHours % 24}h';
    } else if (dur.inHours > 0) {
      return '${dur.inHours}h ${dur.inMinutes % 60}m';
    } else if (dur.inMinutes > 0) {
      return '${dur.inMinutes}m ${dur.inSeconds % 60}s';
    } else {
      return '${dur.inSeconds}s';
    }
  }

  EtapaCredito(
      {required this.completada, this.fechaInicio, this.fechaFin, this.notas});

  Map<String, dynamic> toJson() {
    return {
      'completada': completada,
      'fechaInicio': fechaInicio?.toIso8601String(),
      'fechaFin': fechaFin?.toIso8601String(),
      'notas': notas,
    };
  }

  factory EtapaCredito.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic date) {
      if (date == null) return null;
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.parse(date);
      return null;
    }

    return EtapaCredito(
      completada: json['completada'],
      fechaInicio: parseDate(json['fechaInicio']),
      fechaFin: parseDate(json['fechaFin']),
      notas: json['notas'] as String?,
    );
  }
}
