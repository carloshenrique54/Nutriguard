import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uma viagem (em andamento ou encerrada) da tabela `public.viagens`.
class ViagemRegistro {
  final String id;
  final String idDispositivo;
  final String? idOperador;
  final String destino;
  final double? destinoLatitude;
  final double? destinoLongitude;
  final String status;
  final DateTime iniciadoEm;
  final DateTime? finalizadoEm;
  final int? duracaoMinutos;
  final String? observacoes;
  final String? placaVeiculo;
  final String? modeloVeiculo;

  const ViagemRegistro({
    required this.id,
    required this.idDispositivo,
    this.idOperador,
    required this.destino,
    this.destinoLatitude,
    this.destinoLongitude,
    required this.status,
    required this.iniciadoEm,
    this.finalizadoEm,
    this.duracaoMinutos,
    this.observacoes,
    this.placaVeiculo,
    this.modeloVeiculo,
  });

  bool get emAndamento => status == ViagemRepositorio.emAndamento;

  /// Duração em minutos: a gravada no encerramento ou, se ainda em andamento,
  /// o tempo decorrido até [agora].
  int duracaoAte(DateTime agora) => duracaoMinutos ?? (finalizadoEm ?? agora).difference(iniciadoEm).inMinutes;

  static double? _dbl(dynamic v) => v == null ? null : (v as num).toDouble();

  factory ViagemRegistro.fromJson(Map<String, dynamic> j) {
    final disp = j['Dispositivos'];
    return ViagemRegistro(
      id: j['id'].toString(),
      idDispositivo: j['id_dispositivo'].toString(),
      idOperador: j['id_operador']?.toString(),
      destino: (j['destino'] ?? '').toString(),
      destinoLatitude: _dbl(j['destino_latitude']),
      destinoLongitude: _dbl(j['destino_longitude']),
      status: (j['status'] ?? ViagemRepositorio.emAndamento).toString(),
      iniciadoEm: DateTime.parse(j['iniciado_em'].toString()).toLocal(),
      finalizadoEm: j['finalizado_em'] != null ? DateTime.parse(j['finalizado_em'].toString()).toLocal() : null,
      duracaoMinutos: (j['duracao_minutos'] as num?)?.toInt(),
      observacoes: j['observacoes']?.toString(),
      placaVeiculo: disp is Map ? disp['placa_veiculo']?.toString() : j['placa_veiculo']?.toString(),
      modeloVeiculo: disp is Map ? disp['modelo_veiculo']?.toString() : j['modelo_veiculo']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'id_dispositivo': idDispositivo,
    'id_operador': idOperador,
    'destino': destino,
    'destino_latitude': destinoLatitude,
    'destino_longitude': destinoLongitude,
    'status': status,
    'iniciado_em': iniciadoEm.toUtc().toIso8601String(),
    'finalizado_em': finalizadoEm?.toUtc().toIso8601String(),
    'duracao_minutos': duracaoMinutos,
    'observacoes': observacoes,
    'placa_veiculo': placaVeiculo,
    'modelo_veiculo': modeloVeiculo,
  };

  ViagemRegistro encerrada(DateTime quando, {String? observacoes}) => ViagemRegistro(
    id: id,
    idDispositivo: idDispositivo,
    idOperador: idOperador,
    destino: destino,
    destinoLatitude: destinoLatitude,
    destinoLongitude: destinoLongitude,
    status: ViagemRepositorio.finalizada,
    iniciadoEm: iniciadoEm,
    finalizadoEm: quando,
    duracaoMinutos: quando.difference(iniciadoEm).inMinutes,
    observacoes: observacoes ?? this.observacoes,
    placaVeiculo: placaVeiculo,
    modeloVeiculo: modeloVeiculo,
  );
}

/// Erro de regra de negócio ao iniciar uma viagem (mensagem pronta para o usuário).
class ViagemException implements Exception {
  final String mensagem;
  const ViagemException(this.mensagem);
  @override
  String toString() => mensagem;
}

/// Onde as viagens ficam guardadas. No app é o Supabase (visível para admin,
/// gerente e para o ESP32); nos testes, o armazenamento local.
abstract class ViagemRepositorio {
  static const emAndamento = 'em_andamento';
  static const finalizada = 'finalizada';

  Future<ViagemRegistro?> ativaDoOperador(String operadorId);
  Future<ViagemRegistro?> ativaDoDispositivo(String dispositivoId);
  Future<Set<String>> dispositivosEmViagem(List<String> dispositivoIds);

  Future<ViagemRegistro> iniciar({
    required String operadorId,
    required String dispositivoId,
    required String destino,
    double? destinoLatitude,
    double? destinoLongitude,
    double? origemLatitude,
    double? origemLongitude,
    String? placaVeiculo,
    String? modeloVeiculo,
  });

  /// Encerra a viagem em andamento do operador (se houver).
  Future<void> encerrar(String operadorId, {String? observacoes});

  /// Viagens dos dispositivos que estiveram ativas em algum momento do período.
  Future<List<ViagemRegistro>> doPeriodo(List<String> dispositivoIds, DateTime inicio, DateTime fim);

  /// Regras comuns: um operador e um veículo têm no máximo uma viagem aberta.
  static Future<ViagemRegistro?> validarInicio(ViagemRepositorio repo, String operadorId, String dispositivoId) async {
    final doOperador = await repo.ativaDoOperador(operadorId);
    if (doOperador != null) {
      if (doOperador.idDispositivo == dispositivoId) return doOperador;
      throw const ViagemException('Você já tem uma viagem em andamento em outro veículo. Finalize-a primeiro.');
    }
    final doVeiculo = await repo.ativaDoDispositivo(dispositivoId);
    if (doVeiculo != null) {
      throw const ViagemException('Este veículo já está em viagem com outro operador.');
    }
    return null;
  }
}

class ViagemRepositorioSupabase implements ViagemRepositorio {
  SupabaseClient get _db => Supabase.instance.client;

  static const _colunas =
      'id,id_dispositivo,id_operador,destino,destino_latitude,destino_longitude,status,'
      'iniciado_em,finalizado_em,duracao_minutos,observacoes,Dispositivos(placa_veiculo,modelo_veiculo)';

  Future<ViagemRegistro?> _uma(String coluna, String valor) async {
    if (valor.trim().isEmpty) return null;
    try {
      final row = await _db
          .from('viagens')
          .select(_colunas)
          .eq(coluna, valor.trim())
          .eq('status', ViagemRepositorio.emAndamento)
          .order('iniciado_em', ascending: false)
          .limit(1)
          .maybeSingle();
      return row == null ? null : ViagemRegistro.fromJson(row);
    } catch (e) {
      debugPrint('viagens: falha ao consultar viagem ativa ($coluna): $e');
      return null;
    }
  }

  @override
  Future<ViagemRegistro?> ativaDoOperador(String operadorId) => _uma('id_operador', operadorId);

  @override
  Future<ViagemRegistro?> ativaDoDispositivo(String dispositivoId) => _uma('id_dispositivo', dispositivoId);

  @override
  Future<Set<String>> dispositivosEmViagem(List<String> dispositivoIds) async {
    final ids = dispositivoIds.where((i) => i.trim().isNotEmpty).toList();
    if (ids.isEmpty) return {};
    try {
      final rows = await _db
          .from('viagens')
          .select('id_dispositivo')
          .inFilter('id_dispositivo', ids)
          .eq('status', ViagemRepositorio.emAndamento);
      return {for (final r in rows) r['id_dispositivo'].toString()};
    } catch (e) {
      debugPrint('viagens: falha ao listar veículos em viagem: $e');
      return {};
    }
  }

  @override
  Future<ViagemRegistro> iniciar({
    required String operadorId,
    required String dispositivoId,
    required String destino,
    double? destinoLatitude,
    double? destinoLongitude,
    double? origemLatitude,
    double? origemLongitude,
    String? placaVeiculo,
    String? modeloVeiculo,
  }) async {
    final existente = await ViagemRepositorio.validarInicio(this, operadorId, dispositivoId);
    if (existente != null) return existente;

    String? idFrota;
    try {
      final d = await _db.from('Dispositivos').select('id_frota').eq('id', dispositivoId).maybeSingle();
      idFrota = d?['id_frota']?.toString();
    } catch (_) {}

    final Map<String, dynamic> row;
    try {
      row = await _db
          .from('viagens')
          .insert({
            'id_dispositivo': dispositivoId,
            'id_operador': operadorId,
            'id_frota': ?idFrota,
            'destino': destino.trim(),
            'destino_latitude': ?destinoLatitude,
            'destino_longitude': ?destinoLongitude,
            'origem_latitude': ?origemLatitude,
            'origem_longitude': ?origemLongitude,
            'status': ViagemRepositorio.emAndamento,
          })
          .select(_colunas)
          .single();
    } on PostgrestException catch (e) {
      // Índice único: outra viagem foi aberta ao mesmo tempo.
      if (e.code == '23505') {
        throw const ViagemException('Já existe uma viagem em andamento para este veículo ou operador.');
      }
      rethrow;
    }
    return ViagemRegistro.fromJson(row);
  }

  @override
  Future<void> encerrar(String operadorId, {String? observacoes}) async {
    final ativa = await ativaDoOperador(operadorId);
    if (ativa == null) return;
    final agora = DateTime.now();
    await _db
        .from('viagens')
        .update({
          'status': ViagemRepositorio.finalizada,
          'finalizado_em': agora.toUtc().toIso8601String(),
          'duracao_minutos': agora.difference(ativa.iniciadoEm).inMinutes,
          if (observacoes != null && observacoes.trim().isNotEmpty) 'observacoes': observacoes.trim(),
          'atualizado_em': agora.toUtc().toIso8601String(),
        })
        .eq('id', ativa.id);
  }

  @override
  Future<List<ViagemRegistro>> doPeriodo(List<String> dispositivoIds, DateTime inicio, DateTime fim) async {
    final ids = dispositivoIds.where((i) => i.trim().isNotEmpty).toList();
    if (ids.isEmpty) return [];
    try {
      final rows = await _db
          .from('viagens')
          .select(_colunas)
          .inFilter('id_dispositivo', ids)
          .lte('iniciado_em', fim.toUtc().toIso8601String())
          .or('finalizado_em.is.null,finalizado_em.gte.${inicio.toUtc().toIso8601String()}')
          .order('iniciado_em', ascending: false);
      return rows.map<ViagemRegistro>(ViagemRegistro.fromJson).toList();
    } catch (e) {
      debugPrint('viagens: falha ao listar viagens do período: $e');
      return [];
    }
  }
}

/// Guarda as viagens no SharedPreferences (usado nos testes, sem banco).
class ViagemRepositorioLocal implements ViagemRepositorio {
  static const _chave = 'viagens_local';

  Future<List<ViagemRegistro>> _todas() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_chave);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => ViagemRegistro.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> _salvar(List<ViagemRegistro> v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chave, jsonEncode(v.map((e) => e.toJson()).toList()));
  }

  @override
  Future<ViagemRegistro?> ativaDoOperador(String operadorId) async {
    for (final v in (await _todas()).reversed) {
      if (v.emAndamento && v.idOperador == operadorId.trim()) return v;
    }
    return null;
  }

  @override
  Future<ViagemRegistro?> ativaDoDispositivo(String dispositivoId) async {
    for (final v in (await _todas()).reversed) {
      if (v.emAndamento && v.idDispositivo == dispositivoId.trim()) return v;
    }
    return null;
  }

  @override
  Future<Set<String>> dispositivosEmViagem(List<String> dispositivoIds) async {
    final ids = dispositivoIds.toSet();
    return {
      for (final v in await _todas())
        if (v.emAndamento && ids.contains(v.idDispositivo)) v.idDispositivo,
    };
  }

  @override
  Future<ViagemRegistro> iniciar({
    required String operadorId,
    required String dispositivoId,
    required String destino,
    double? destinoLatitude,
    double? destinoLongitude,
    double? origemLatitude,
    double? origemLongitude,
    String? placaVeiculo,
    String? modeloVeiculo,
  }) async {
    final existente = await ViagemRepositorio.validarInicio(this, operadorId.trim(), dispositivoId.trim());
    if (existente != null) return existente;
    final todas = await _todas();
    final nova = ViagemRegistro(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      idDispositivo: dispositivoId.trim(),
      idOperador: operadorId.trim(),
      destino: destino.trim(),
      destinoLatitude: destinoLatitude,
      destinoLongitude: destinoLongitude,
      status: ViagemRepositorio.emAndamento,
      iniciadoEm: DateTime.now(),
      placaVeiculo: placaVeiculo,
      modeloVeiculo: modeloVeiculo,
    );
    await _salvar([...todas, nova]);
    return nova;
  }

  @override
  Future<void> encerrar(String operadorId, {String? observacoes}) async {
    final todas = await _todas();
    final agora = DateTime.now();
    await _salvar([
      for (final v in todas)
        (v.emAndamento && v.idOperador == operadorId.trim()) ? v.encerrada(agora, observacoes: observacoes) : v,
    ]);
  }

  @override
  Future<List<ViagemRegistro>> doPeriodo(List<String> dispositivoIds, DateTime inicio, DateTime fim) async {
    final ids = dispositivoIds.toSet();
    return (await _todas())
        .where(
          (v) =>
              ids.contains(v.idDispositivo) &&
              !v.iniciadoEm.isAfter(fim) &&
              (v.finalizadoEm == null || !v.finalizadoEm!.isBefore(inicio)),
        )
        .toList()
      ..sort((a, b) => b.iniciadoEm.compareTo(a.iniciadoEm));
  }
}
