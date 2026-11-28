import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Algo mudou no banco: nova medição do ESP32, alerta novo/resolvido ou
/// viagem iniciada/finalizada.
class EventoTempoReal {
  final String tabela;
  final String? idDispositivo;
  final DateTime quando;

  const EventoTempoReal(this.tabela, this.idDispositivo, this.quando);

  bool doDispositivo(Iterable<String> ids) => idDispositivo == null || ids.contains(idDispositivo);
}

/// Atualização em tempo real pelo Supabase Realtime (websocket), como no
/// AeroCar. O RLS vale também aqui: cada usuário só recebe eventos dos
/// veículos que pode ver. As telas mantêm uma consulta periódica de reserva,
/// caso a rede bloqueie o websocket.
class TempoRealService {
  TempoRealService._();
  static final TempoRealService instancia = TempoRealService._();

  /// Último evento recebido (as telas escutam e recarregam em silêncio).
  final ValueNotifier<EventoTempoReal?> eventos = ValueNotifier(null);

  /// Canal conectado ao Supabase Realtime.
  final ValueNotifier<bool> conectado = ValueNotifier(false);

  RealtimeChannel? _canal;
  String? _usuarioDoCanal;
  // ignore: cancel_subscriptions -- vive o app inteiro (singleton)
  StreamSubscription<AuthState>? _auth;

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null; // Supabase não inicializado (testes)
    }
  }

  /// Abre o canal (uma vez por usuário logado). Seguro chamar em todo initState.
  void iniciar() {
    final client = _client;
    final uid = client?.auth.currentUser?.id;
    if (client == null || uid == null) return;
    _auth ??= client.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedOut) _fechar();
    });
    if (_canal != null && _usuarioDoCanal == uid) return;
    _fechar();
    _usuarioDoCanal = uid;

    void emitir(PostgresChangePayload p) {
      final reg = p.newRecord.isNotEmpty ? p.newRecord : p.oldRecord;
      eventos.value = EventoTempoReal(p.table, reg['id_dispositivo']?.toString(), DateTime.now());
    }

    _canal = client
        .channel('nutriguard-tempo-real-$uid')
        .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'medicoes', callback: emitir)
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'ocorrencias', callback: emitir)
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'viagens', callback: emitir)
        .subscribe((status, erro) {
      conectado.value = status == RealtimeSubscribeStatus.subscribed;
      if (erro != null) debugPrint('Tempo real indisponível ($status): $erro');
    });
  }

  void _fechar() {
    final canal = _canal;
    _canal = null;
    _usuarioDoCanal = null;
    conectado.value = false;
    if (canal != null) _client?.removeChannel(canal);
  }
}

/// Mistura para telas: chama [aoMudarNoBanco] quando o Realtime avisa de
/// mudança (juntando eventos seguidos) e, se o websocket estiver fora do ar,
/// a cada [intervaloReserva] (consulta periódica de reserva).
mixin OuveTempoReal<T extends StatefulWidget> on State<T> {
  Timer? _atrasoTempoReal;
  Timer? _reserva;
  DateTime? _ultimaExecucao;

  /// Ids dos veículos exibidos; `null` = qualquer veículo.
  Iterable<String>? get idsEmTela => null;

  /// Intervalo mínimo entre duas recargas (telas pesadas usam mais).
  Duration get intervaloMinimo => const Duration(milliseconds: 600);

  /// Consulta de reserva quando o Realtime está desconectado; `null` = sem reserva
  /// (a tela já tem a sua própria consulta periódica).
  Duration? get intervaloReserva => null;

  void aoMudarNoBanco();

  void _executar() {
    if (!mounted) return;
    _ultimaExecucao = DateTime.now();
    aoMudarNoBanco();
  }

  void _agendar() {
    if (_atrasoTempoReal?.isActive ?? false) return;
    final desde = _ultimaExecucao == null ? intervaloMinimo : DateTime.now().difference(_ultimaExecucao!);
    final espera = desde >= intervaloMinimo ? const Duration(milliseconds: 600) : intervaloMinimo - desde;
    _atrasoTempoReal = Timer(espera, _executar);
  }

  void _aoEvento() {
    final e = TempoRealService.instancia.eventos.value;
    if (e == null || !mounted) return;
    final ids = idsEmTela;
    if (ids != null && !e.doDispositivo(ids)) return;
    _agendar();
  }

  @override
  void initState() {
    super.initState();
    TempoRealService.instancia.iniciar();
    TempoRealService.instancia.eventos.addListener(_aoEvento);
    final reserva = intervaloReserva;
    if (reserva != null) {
      _reserva = Timer.periodic(reserva, (_) {
        if (!TempoRealService.instancia.conectado.value) _executar();
      });
    }
  }

  @override
  void dispose() {
    _atrasoTempoReal?.cancel();
    _reserva?.cancel();
    TempoRealService.instancia.eventos.removeListener(_aoEvento);
    super.dispose();
  }
}
