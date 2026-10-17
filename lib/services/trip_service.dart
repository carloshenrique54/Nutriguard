import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TripInfo {
  final String operatorId;
  final String deviceId;
  final String destination;
  final DateTime startedAt;
  final String? vehiclePlate;
  final String? vehicleModel;
  final double? destinationLatitude;
  final double? destinationLongitude;

  const TripInfo({
    required this.operatorId,
    required this.deviceId,
    required this.destination,
    required this.startedAt,
    this.vehiclePlate,
    this.vehicleModel,
    this.destinationLatitude,
    this.destinationLongitude,
  });

  Duration get duration => DateTime.now().difference(startedAt);

  String get formattedDuration {
    final d = duration;
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }
}

class TripStopReport {
  final String operatorId;
  final String motivo;
  final String rua;
  final String bairro;
  final String cidade;
  final String? cep;
  final List<String> anexos;
  final DateTime stoppedAt;

  const TripStopReport({
    required this.operatorId,
    required this.motivo,
    required this.rua,
    required this.bairro,
    required this.cidade,
    this.cep,
    this.anexos = const [],
    required this.stoppedAt,
  });
}

class TripService {
  static final TripService _instance = TripService._internal();
  factory TripService() => _instance;
  TripService._internal();

  /// Notifier reativo para avisar ouvintes (como Drawer ou Dashboards) sobre mudanças de estado
  final ValueNotifier<bool> tripStateNotifier = ValueNotifier<bool>(false);

  Future<bool> isTripActive(String operatorId) async {
    final cleanId = operatorId.trim();
    if (cleanId.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getBool('trip_active_$cleanId') ?? false;
    tripStateNotifier.value = active;
    return active;
  }

  Future<TripInfo?> getActiveTrip(String operatorId) async {
    final cleanId = operatorId.trim();
    if (cleanId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getBool('trip_active_$cleanId') ?? false;
    if (!active) return null;

    final deviceId = prefs.getString('trip_device_id_$cleanId') ?? '';
    final destination = prefs.getString('trip_destination_$cleanId') ?? '';
    final startedAtStr = prefs.getString('trip_started_at_$cleanId');
    final vehiclePlate = prefs.getString('trip_vehicle_plate_$cleanId');
    final vehicleModel = prefs.getString('trip_vehicle_model_$cleanId');
    final destinationLat = prefs.getDouble('trip_destination_lat_$cleanId');
    final destinationLng = prefs.getDouble('trip_destination_lng_$cleanId');

    final startedAt = startedAtStr != null ? DateTime.tryParse(startedAtStr) ?? DateTime.now() : DateTime.now();

    return TripInfo(
      operatorId: cleanId,
      deviceId: deviceId,
      destination: destination,
      startedAt: startedAt,
      vehiclePlate: vehiclePlate,
      vehicleModel: vehicleModel,
      destinationLatitude: destinationLat,
      destinationLongitude: destinationLng,
    );
  }

  Future<void> startTrip({
    required String operatorId,
    required String deviceId,
    required String destination,
    String? vehiclePlate,
    String? vehicleModel,
    double? destinationLatitude,
    double? destinationLongitude,
  }) async {
    final cleanId = operatorId.trim();
    if (cleanId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('trip_active_$cleanId', true);
    await prefs.setString('trip_device_id_$cleanId', deviceId.trim());
    await prefs.setString('trip_destination_$cleanId', destination.trim());
    await prefs.setString('trip_started_at_$cleanId', DateTime.now().toIso8601String());
    if (vehiclePlate != null) {
      await prefs.setString('trip_vehicle_plate_$cleanId', vehiclePlate.trim());
    }
    if (vehicleModel != null) {
      await prefs.setString('trip_vehicle_model_$cleanId', vehicleModel.trim());
    }
    if (destinationLatitude != null) {
      await prefs.setDouble('trip_destination_lat_$cleanId', destinationLatitude);
    }
    if (destinationLongitude != null) {
      await prefs.setDouble('trip_destination_lng_$cleanId', destinationLongitude);
    }
    tripStateNotifier.value = true;
  }

  Future<void> endTrip(String operatorId) async {
    final cleanId = operatorId.trim();
    if (cleanId.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('trip_active_$cleanId', false);
    }
    tripStateNotifier.value = false;
  }

  Future<void> endTripWithReport({
    required String operatorId,
    required String motivo,
    required String rua,
    required String bairro,
    required String cidade,
    String? cep,
    List<String> anexos = const [],
  }) async {
    final cleanId = operatorId.trim();
    if (cleanId.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('trip_active_$cleanId', false);
      await prefs.setString('trip_stop_motivo_$cleanId', motivo.trim());
      await prefs.setString('trip_stop_rua_$cleanId', rua.trim());
      await prefs.setString('trip_stop_bairro_$cleanId', bairro.trim());
      await prefs.setString('trip_stop_cidade_$cleanId', cidade.trim());
      if (cep != null && cep.trim().isNotEmpty) {
        await prefs.setString('trip_stop_cep_$cleanId', cep.trim());
      }
      if (anexos.isNotEmpty) {
        await prefs.setStringList('trip_stop_anexos_$cleanId', anexos);
      }
      await prefs.setString('trip_stopped_at_$cleanId', DateTime.now().toIso8601String());
    }
    tripStateNotifier.value = false;
  }

  Future<TripStopReport?> getLastStopReport(String operatorId) async {
    final cleanId = operatorId.trim();
    if (cleanId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final motivo = prefs.getString('trip_stop_motivo_$cleanId');
    final rua = prefs.getString('trip_stop_rua_$cleanId');
    final bairro = prefs.getString('trip_stop_bairro_$cleanId');
    final cidade = prefs.getString('trip_stop_cidade_$cleanId');
    if (motivo == null || rua == null || cidade == null) return null;
    final cep = prefs.getString('trip_stop_cep_$cleanId');
    final anexos = prefs.getStringList('trip_stop_anexos_$cleanId') ?? [];
    final stoppedAtStr = prefs.getString('trip_stopped_at_$cleanId');
    final stoppedAt = stoppedAtStr != null ? DateTime.tryParse(stoppedAtStr) ?? DateTime.now() : DateTime.now();

    return TripStopReport(
      operatorId: cleanId,
      motivo: motivo,
      rua: rua,
      bairro: bairro ?? '',
      cidade: cidade,
      cep: cep,
      anexos: anexos,
      stoppedAt: stoppedAt,
    );
  }

  Future<void> resetTrip(String operatorId) async {
    final cleanId = operatorId.trim();
    if (cleanId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('trip_active_$cleanId');
    await prefs.remove('trip_device_id_$cleanId');
    await prefs.remove('trip_destination_$cleanId');
    await prefs.remove('trip_started_at_$cleanId');
    await prefs.remove('trip_vehicle_plate_$cleanId');
    await prefs.remove('trip_vehicle_model_$cleanId');
    await prefs.remove('trip_destination_lat_$cleanId');
    await prefs.remove('trip_destination_lng_$cleanId');
    await prefs.remove('trip_stop_motivo_$cleanId');
    await prefs.remove('trip_stop_rua_$cleanId');
    await prefs.remove('trip_stop_bairro_$cleanId');
    await prefs.remove('trip_stop_cidade_$cleanId');
    await prefs.remove('trip_stop_cep_$cleanId');
    await prefs.remove('trip_stop_anexos_$cleanId');
    await prefs.remove('trip_stopped_at_$cleanId');
    tripStateNotifier.value = false;
  }
}
