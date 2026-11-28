import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'viagem_repositorio.dart';

class TripInfo {
  /// Id da linha em `public.viagens` (null em dados antigos).
  final String? id;
  final String operatorId;
  final String deviceId;
  final String destination;
  final DateTime startedAt;
  final String? vehiclePlate;
  final String? vehicleModel;
  final double? destinationLatitude;
  final double? destinationLongitude;

  const TripInfo({
    this.id,
    required this.operatorId,
    required this.deviceId,
    required this.destination,
    required this.startedAt,
    this.vehiclePlate,
    this.vehicleModel,
    this.destinationLatitude,
    this.destinationLongitude,
  });

  factory TripInfo.deRegistro(ViagemRegistro v) => TripInfo(
        id: v.id,
        operatorId: v.idOperador ?? '',
        deviceId: v.idDispositivo,
        destination: v.destino,
        startedAt: v.iniciadoEm,
        vehiclePlate: v.placaVeiculo,
        vehicleModel: v.modeloVeiculo,
        destinationLatitude: v.destinoLatitude,
        destinationLongitude: v.destinoLongitude,
      );

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

  static ViagemRepositorio? _repositorio;

  /// Onde as viagens ficam: Supabase (tabela `viagens`) no app, para que admin,
  /// gerente e o ESP32 vejam o mesmo estado; armazenamento local quando o
  /// Supabase não foi inicializado (testes).
  static ViagemRepositorio get repositorio => _repositorio ??= _padrao();
  static set repositorio(ViagemRepositorio r) => _repositorio = r;

  static ViagemRepositorio _padrao() {
    try {
      if (Supabase.instance.isInitialized) return ViagemRepositorioSupabase();
    } catch (_) {}
    return ViagemRepositorioLocal();
  }

  /// Notifier reativo para avisar ouvintes (como Drawer ou Dashboards) sobre mudanças de estado
  final ValueNotifier<bool> tripStateNotifier = ValueNotifier<bool>(false);

  Future<bool> isTripActive(String operatorId) async {
    final active = await getActiveTrip(operatorId) != null;
    tripStateNotifier.value = active;
    return active;
  }

  Future<TripInfo?> getActiveTrip(String operatorId) async {
    final cleanId = operatorId.trim();
    if (cleanId.isEmpty) return null;
    final v = await repositorio.ativaDoOperador(cleanId);
    return v == null ? null : TripInfo.deRegistro(v);
  }

  /// Viagem em andamento do operador informado ou, se não houver, do veículo.
  Future<TripInfo?> getActiveTripByDevice(String deviceId, {String? operatorId}) async {
    if (operatorId != null && operatorId.trim().isNotEmpty) {
      final trip = await getActiveTrip(operatorId.trim());
      if (trip != null) return trip;
    }
    if (deviceId.trim().isEmpty) return null;
    final v = await repositorio.ativaDoDispositivo(deviceId.trim());
    return v == null ? null : TripInfo.deRegistro(v);
  }

  /// O veículo tem viagem em andamento (de qualquer operador)?
  Future<bool> isDeviceInTrip(String deviceId, {String? operatorId}) async {
    if (deviceId.trim().isEmpty) return false;
    return await repositorio.ativaDoDispositivo(deviceId.trim()) != null;
  }

  /// Ids dos veículos em viagem, numa única consulta.
  Future<Set<String>> devicesInTrip(List<String> deviceIds) => repositorio.dispositivosEmViagem(deviceIds);

  /// Viagens (em andamento ou encerradas) dos veículos no período.
  Future<List<ViagemRegistro>> tripsInPeriod(List<String> deviceIds, DateTime inicio, DateTime fim) =>
      repositorio.doPeriodo(deviceIds, inicio, fim);

  Future<TripInfo> startTrip({
    required String operatorId,
    required String deviceId,
    required String destination,
    String? vehiclePlate,
    String? vehicleModel,
    double? destinationLatitude,
    double? destinationLongitude,
    double? originLatitude,
    double? originLongitude,
  }) async {
    final v = await repositorio.iniciar(
      operadorId: operatorId.trim(),
      dispositivoId: deviceId.trim(),
      destino: destination,
      destinoLatitude: destinationLatitude,
      destinoLongitude: destinationLongitude,
      origemLatitude: originLatitude,
      origemLongitude: originLongitude,
      placaVeiculo: vehiclePlate,
      modeloVeiculo: vehicleModel,
    );
    tripStateNotifier.value = true;
    return TripInfo.deRegistro(v);
  }

  /// Encerra a viagem sem relatório de parada (ex.: logout). O banco gera o
  /// alerta "viagem encerrada sem relatório" para gerente e ADM.
  Future<void> endTrip(String operatorId) async {
    final cleanId = operatorId.trim();
    if (cleanId.isNotEmpty) await repositorio.encerrar(cleanId);
    tripStateNotifier.value = false;
  }

  /// Encerra a viagem depois do formulário "Parar viagem" (o relatório em
  /// `fins_viagem` deve ser gravado ANTES, para o alerta sair como "com relatório").
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
      await repositorio.encerrar(cleanId, observacoes: motivo);
      final prefs = await SharedPreferences.getInstance();
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
    final devId = prefs.getString('trip_device_id_$cleanId');
    if (devId != null && devId.isNotEmpty) {
      await prefs.remove('trip_device_active_$devId');
    }
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
