import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // --- Auth & Users ---
  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String nome,
    required String cpf,
    required String telefone,
    required String cargo,
  }) async {
    final AuthResponse response;
    try {
      // O perfil em "Usuarios" é criado pela trigger on_auth_user_created
      // (supabase/fix_signup_trigger.sql) a partir deste metadata.
      response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'nome': nome,
          'cpf': cpf,
          'telefone': telefone,
          'cargo': cargo,
        },
      );
    } on AuthException catch (e) {
      throw Exception(_traduzirErroAuth(e));
    }

    final user = response.user;
    // Se houver sessão (confirmação de e-mail desativada), garante o perfil
    // via upsert direto — idempotente caso a trigger já tenha inserido.
    if (user != null && response.session != null) {
      try {
        await _client.from('Usuarios').upsert({
          'id': user.id,
          'nome': nome,
          'email': email,
          'cpf': cpf,
          'telefone': telefone,
          'cargo': cargo,
        }, onConflict: 'id');
      } on PostgrestException catch (e) {
        // A conta já foi criada; a trigger é a fonte principal do perfil.
        // ignore: avoid_print
        print('Aviso ao salvar perfil: ${e.message}');
      }
    }
    return response;
  }

  String _traduzirErroAuth(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('database error saving new user')) {
      return 'Erro no banco ao criar o usuário. Execute o script '
          'supabase/fix_signup_trigger.sql no SQL Editor do Supabase.';
    }
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'Este e-mail já está cadastrado.';
    }
    if (msg.contains('password')) {
      return 'Senha inválida: use no mínimo 6 caracteres.';
    }
    if (msg.contains('email') && msg.contains('invalid')) {
      return 'E-mail inválido.';
    }
    if (msg.contains('rate limit') || msg.contains('too many requests') || msg.contains('signups not allowed')) {
      return 'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
    }
    return e.message;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;

  Future<UsuarioModel?> getUsuarioPerfil(String userId) async {
    final data = await _client.from('Usuarios').select().eq('id', userId).maybeSingle();
    if (data == null) return null;
    return UsuarioModel.fromJson(data);
  }

  // --- Frotas ---
  Future<List<FrotaModel>> getFrotas() async {
    final data = await _client.from('Frotas').select();
    return (data as List).map((e) => FrotaModel.fromJson(e)).toList();
  }

  Future<List<FrotaModel>> getFrotasByGerente(String gerenteId) async {
    final data = await _client.from('Frotas').select().eq('id_gerente', gerenteId);
    return (data as List).map((e) => FrotaModel.fromJson(e)).toList();
  }

  // --- Dispositivos ---
  Future<List<DispositivoModel>> getDispositivos() async {
    final data = await _client.from('Dispositivos').select();
    return (data as List).map((e) => DispositivoModel.fromJson(e)).toList();
  }

  Future<List<DispositivoModel>> getDispositivosByFrota(String frotaId) async {
    final data = await _client.from('Dispositivos').select().eq('id_frota', frotaId);
    return (data as List).map((e) => DispositivoModel.fromJson(e)).toList();
  }

  Future<List<DispositivoModel>> getDispositivosByOperador(String operadorId) async {
    final data = await _client.from('Dispositivos').select().eq('id_operador', operadorId);
    return (data as List).map((e) => DispositivoModel.fromJson(e)).toList();
  }

  // --- Medicoes (Streams) ---
  Stream<List<MedicaoModel>> streamMedicoes() {
    return _client.from('medicoes').stream(primaryKey: ['id']).map(
      (data) => data.map((e) => MedicaoModel.fromJson(e)).toList(),
    );
  }

  // --- Ocorrencias (Streams) ---
  Stream<List<OcorrenciaModel>> streamOcorrencias() {
    return _client.from('ocorrencias').stream(primaryKey: ['id']).map(
      (data) => data.map((e) => OcorrenciaModel.fromJson(e)).toList(),
    );
  }

  Future<List<OcorrenciaModel>> getOcorrencias() async {
    final data = await _client.from('ocorrencias').select().order('criado_em', ascending: false);
    return (data as List).map((e) => OcorrenciaModel.fromJson(e)).toList();
  }
}
