import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://tlcsqlemhpxftatpivac.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_RkyrNG8clRlnHWJFvmOEPQ_DIRp4SKV';

  final SupabaseClient _client = Supabase.instance.client;

  // --- Auth & Users ---
  Future<AuthResponse> signIn(String email, String password) async {
    try {
      return await _client.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      throw Exception(formatarErro(e));
    }
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String nome,
    required String cpf,
    required String telefone,
    required String cargo,
    DateTime? dataNascimento,
    String? numeroCnh,
    DateTime? validadeCnh,
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
          if (dataNascimento != null)
            'data_nascimento': dataNascimento.toIso8601String().split('T').first,
          if (numeroCnh != null && numeroCnh.isNotEmpty)
            'numero_cnh': numeroCnh,
          if (validadeCnh != null)
            'validade_cnh': validadeCnh.toIso8601String().split('T').first,
        },
      );
    } catch (e) {
      throw Exception(formatarErro(e));
    }

    final user = response.user;
    // Se houver sessão (confirmação de e-mail desativada), garante o perfil
    // via upsert direto — idempotente caso a trigger já tenha inserido.
    if (user != null && response.session != null) {
      try {
        final profileData = <String, dynamic>{
          'id': user.id,
          'nome': nome,
          'email': email,
          'cpf': cpf,
          'telefone': telefone,
          'cargo': cargo,
        };
        if (dataNascimento != null) {
          profileData['data_nascimento'] = dataNascimento.toIso8601String().split('T').first;
        }
        if (numeroCnh != null && numeroCnh.isNotEmpty) {
          profileData['numero_cnh'] = numeroCnh;
        }
        if (validadeCnh != null) {
          profileData['validade_cnh'] = validadeCnh.toIso8601String().split('T').first;
        }
        await _client.from('Usuarios').upsert(profileData, onConflict: 'id');
      } on PostgrestException catch (e) {
        // A conta já foi criada; a trigger é a fonte principal do perfil.
        // ignore: avoid_print
        print('Aviso ao salvar perfil: ${e.message}');
      }
    }
    return response;
  }

  /// Cadastra um novo funcionário (gerente, operador ou admin) criando a conta
  /// em auth.users e garantindo a inserção na tabela public."Usuarios",
  /// sem sobrescrever ou encerrar a sessão do Administrador atualmente logado.
  Future<AuthResponse> cadastrarFuncionario({
    required String email,
    required String password,
    required String nome,
    required String cpf,
    required String telefone,
    required String cargo,
    DateTime? dataNascimento,
    String? numeroCnh,
    DateTime? validadeCnh,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCpf = cpf.trim();
    final cpfDigits = cleanCpf.replaceAll(RegExp(r'\D'), '');

    // 1) Pré-validação com a sessão ativa do Administrador:
    // Evita erros 500 do banco ao verificar se e-mail ou CPF já existem na tabela Usuarios
    try {
      final existingUsers = await _client.from('Usuarios').select('id, nome, email, cpf');
      for (var u in (existingUsers as List)) {
        final existingEmail = (u['email'] ?? '').toString().trim().toLowerCase();
        if (existingEmail.isNotEmpty && existingEmail == cleanEmail) {
          throw Exception('Este e-mail já está cadastrado para outro funcionário.');
        }
        final existingCpf = (u['cpf'] ?? '').toString().trim();
        final existingCpfDigits = existingCpf.replaceAll(RegExp(r'\D'), '');
        if (existingCpf == cleanCpf || (cpfDigits.isNotEmpty && existingCpfDigits == cpfDigits)) {
          final nomeCadastrado = (u['nome'] ?? '').toString().trim();
          final info = nomeCadastrado.isNotEmpty ? ' ($nomeCadastrado)' : '';
          throw Exception('Já existe um funcionário cadastrado com este CPF$info.');
        }
      }
    } catch (e) {
      if (e.toString().contains('Já existe') || e.toString().contains('já está cadastrado')) {
        rethrow;
      }
    }

    // 2) Criação da conta no Supabase Auth usando cliente temporário com fluxo implícito
    final tempClient = SupabaseClient(
      supabaseUrl,
      supabaseAnonKey,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: false,
      ),
    );

    try {
      final response = await tempClient.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'nome': nome,
          'cpf': cleanCpf,
          'telefone': telefone,
          'cargo': cargo,
          if (dataNascimento != null)
            'data_nascimento': dataNascimento.toIso8601String().split('T').first,
          if (numeroCnh != null && numeroCnh.isNotEmpty)
            'numero_cnh': numeroCnh,
          if (validadeCnh != null)
            'validade_cnh': validadeCnh.toIso8601String().split('T').first,
        },
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Falha ao registrar usuário no sistema.');
      }

      // 3) Garantir persistência na tabela public."Usuarios"
      // A trigger handle_new_user() insere os dados via security definer.
      // Caso a trigger tenha atraso ou não tenha sido acionada, realizamos a verificação
      // e inserção direta para garantir que o funcionário exista na tabela Usuarios.
      await Future.delayed(const Duration(milliseconds: 300));
      try {
        final profile = await _client.from('Usuarios').select('id').eq('id', user.id).maybeSingle();
        if (profile == null) {
          final profileData = <String, dynamic>{
            'id': user.id,
            'nome': nome,
            'email': cleanEmail,
            'cpf': cleanCpf,
            'telefone': telefone,
            'cargo': cargo,
          };
          if (dataNascimento != null) {
            profileData['data_nascimento'] = dataNascimento.toIso8601String().split('T').first;
          }
          if (numeroCnh != null && numeroCnh.isNotEmpty) {
            profileData['numero_cnh'] = numeroCnh;
          }
          if (validadeCnh != null) {
            profileData['validade_cnh'] = validadeCnh.toIso8601String().split('T').first;
          }

          // Tenta salvar via admin ou via tempClient
          try {
            await _client.from('Usuarios').upsert(profileData, onConflict: 'id');
          } catch (_) {
            if (response.session != null) {
              await tempClient.from('Usuarios').upsert(profileData, onConflict: 'id');
            }
          }
        }
      } catch (e) {
        // ignore: avoid_print
        print('Aviso ao sincronizar perfil de funcionário: $e');
      }

      return response;
    } catch (e) {
      throw Exception(formatarErro(e));
    } finally {
      tempClient.dispose();
    }
  }

  /// Formata e traduz qualquer exceção ou erro técnico (Auth, Postgrest, rede, etc.)
  /// para uma mensagem amigável, clara e pronta para exibição em português.
  static String formatarErro(dynamic error) {
    if (error == null) return 'Ocorreu um erro desconhecido.';

    if (error is AuthException) {
      final msg = error.message.toLowerCase();

      if (msg.contains('usuarios_cpf_unique') ||
          (msg.contains('unique') && msg.contains('cpf')) ||
          (msg.contains('23505') && msg.contains('cpf'))) {
        return 'Já existe um funcionário cadastrado com este CPF.';
      }
      if (msg.contains('duplicate key') || msg.contains('unique constraint') || msg.contains('23505')) {
        if (msg.contains('email')) return 'Este e-mail já está cadastrado no sistema.';
        return 'Já existe um registro com estas informações no sistema.';
      }
      if (msg.contains('23502') || msg.contains('not-null') || msg.contains('violates not-null')) {
        return 'Preencha todos os campos obrigatórios (nome, CPF, telefone).';
      }
      if (msg.contains('database error saving new user')) {
        return 'Não foi possível salvar o funcionário no banco de dados. O CPF ou e-mail informado já está em uso por outro cadastro. Verifique os dados.';
      }
      if (msg.contains('database error querying schema')) {
        return 'Erro no serviço de autenticação do Supabase (colunas de token nulas em auth.users). Execute a correção no SQL Editor.';
      }
      if (msg.contains('database error')) {
        return 'Erro de comunicação com o banco de dados. Verifique os dados e tente novamente.';
      }
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid credentials') ||
          msg.contains('invalid_credentials')) {
        return 'E-mail ou senha incorretos.';
      }
      if (msg.contains('already registered') ||
          msg.contains('already exists') ||
          msg.contains('user already exists') ||
          msg.contains('user_already_exists')) {
        return 'Este e-mail já está cadastrado no sistema.';
      }
      if (msg.contains('password') && (msg.contains('least') || msg.contains('characters') || msg.contains('short') || msg.contains('weak'))) {
        return 'A senha deve conter no mínimo 6 caracteres.';
      }
      if (msg.contains('email') && (msg.contains('invalid') || msg.contains('format'))) {
        return 'O endereço de e-mail informado é inválido.';
      }
      if (msg.contains('email not confirmed') || msg.contains('unconfirmed')) {
        return 'E-mail não confirmado. Verifique sua caixa de entrada.';
      }
      if (msg.contains('rate limit') ||
          msg.contains('too many requests') ||
          msg.contains('over_request_rate_limit')) {
        return 'Muitas tentativas em pouco tempo. Aguarde alguns minutos e tente novamente.';
      }
      if (msg.contains('signups not allowed') || msg.contains('signup is disabled')) {
        return 'Novos cadastros estão temporariamente indisponíveis.';
      }
      if (msg.contains('user not found')) {
        return 'Usuário não encontrado no sistema.';
      }
      if (error.message.isNotEmpty && !error.message.contains('package:') && !error.message.contains('assert')) {
        return error.message;
      }
      return 'Erro na autenticação. Verifique os dados e tente novamente.';
    }

    if (error is PostgrestException) {
      final msg = error.message.toLowerCase();
      final details = (error.details ?? '').toString().toLowerCase();

      if (error.code == '23505' || msg.contains('duplicate key') || msg.contains('unique constraint')) {
        if (msg.contains('cpf') || details.contains('cpf')) {
          return 'Já existe um cadastro registrado com este CPF.';
        }
        if (msg.contains('email') || details.contains('email')) {
          return 'Este e-mail já está registrado no sistema.';
        }
        if (msg.contains('placa') || details.contains('placa')) {
          return 'Já existe um veículo cadastrado com esta placa.';
        }
        return 'Já existe um registro com essas informações no sistema.';
      }
      if (error.code == '23502' ||
          msg.contains('not-null') ||
          msg.contains('violates not-null') ||
          msg.contains('null value in column') ||
          details.contains('null value')) {
        if (msg.contains('id_frota') || details.contains('id_frota')) {
          return 'O banco de dados ainda possui restrição NOT NULL na coluna id_frota da tabela Dispositivos. Execute o script no Supabase para permitir dispositivos sem frota.';
        }
        if (msg.contains('id_operador') || details.contains('id_operador')) {
          return 'Selecione o operador responsável pelo dispositivo.';
        }
        if (msg.contains('nome_dispositivo') || details.contains('nome_dispositivo')) {
          return 'O nome do dispositivo é obrigatório.';
        }
        return 'Preencha todos os campos obrigatórios antes de prosseguir.';
      }
      if (error.code == '42501' || msg.contains('permission denied') || msg.contains('row-level security')) {
        return 'Você não tem permissão para realizar esta operação.';
      }
      if (error.code == '23503' || msg.contains('foreign key')) {
        return 'O registro informado está vinculado a outros dados e não pôde ser processado.';
      }
      if (error.message.isNotEmpty && !error.message.contains('package:')) {
        return error.message;
      }
      return 'Erro ao acessar o banco de dados. Tente novamente.';
    }

    final str = error.toString();
    final lower = str.toLowerCase();

    // Erros internos de asserção de SDKs ou bibliotecas
    if (lower.contains('failed assertion') || lower.contains('package:gotrue') || lower.contains('asyncstorage')) {
      return 'Falha no processo de autenticação. Tente novamente.';
    }

    // Erros de conexão e rede
    if (lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable') ||
        lower.contains('timeout')) {
      return 'Sem conexão com a internet ou servidor indisponível. Verifique sua rede.';
    }

    // Limpa prefixos de exceção comuns
    String cleaned = str.replaceFirst('Exception: ', '').replaceFirst('Error: ', '').trim();
    if (cleaned.startsWith('AuthException: ')) {
      cleaned = cleaned.replaceFirst('AuthException: ', '').trim();
    }
    if (cleaned.startsWith('PostgrestException: ')) {
      cleaned = cleaned.replaceFirst('PostgrestException: ', '').trim();
    }

    if (lower.contains('null value in column "id_frota"') || (lower.contains('id_frota') && lower.contains('not-null'))) {
      return 'O banco de dados ainda possui restrição NOT NULL na coluna id_frota da tabela Dispositivos. Execute o script no Supabase para permitir dispositivos sem frota.';
    }
    if (lower.contains('violates not-null constraint') || lower.contains('null value in column')) {
      return 'Preencha todos os campos obrigatórios antes de prosseguir.';
    }

    // Se ainda for um erro técnico longo ou stack trace, simplifica
    if (cleaned.contains('package:') || cleaned.contains('dart:') || cleaned.contains('line ') || cleaned.length > 200) {
      return 'Ocorreu um erro ao processar a operação. Verifique os dados e tente novamente.';
    }

    return cleaned.isNotEmpty ? cleaned : 'Ocorreu um erro inesperado.';
  }

  static UsuarioModel? _cachedPerfil;
  static UsuarioModel? get currentCachedPerfil => _cachedPerfil;

  Future<void> signOut() async {
    _cachedPerfil = null;
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;

  Future<UsuarioModel?> getUsuarioPerfil(String userId) async {
    try {
      var data = await _client.from('Usuarios').select().eq('id', userId).maybeSingle();
      if (data == null && userId == currentUser?.id && currentUser?.email != null) {
        // Fallback: se o id na tabela Usuarios difere do auth id, busca pelo email do usuário logado
        try {
          data = await _client
              .from('Usuarios')
              .select()
              .eq('email', currentUser!.email!.trim().toLowerCase())
              .maybeSingle();
          if (data != null) {
            // Tenta sincronizar o id na tabela Usuarios com o auth.uid()
            try {
              await _client.from('Usuarios').update({'id': userId}).eq('id', data['id']);
              data['id'] = userId;
            } catch (_) {}
          }
        } catch (_) {}
      }

      if (data == null) {
        // Fallback para os metadados da autenticacao caso a trigger tenha falhado ou a tabela esteja vazia
        if (userId == currentUser?.id) {
          final meta = currentUser?.userMetadata;
          if (meta != null && meta['cargo'] != null) {
            final fallback = UsuarioModel(
              id: userId,
              nome: meta['nome'],
              email: currentUser?.email,
              cpf: meta['cpf'],
              telefone: meta['telefone'],
              cargo: meta['cargo'],
            );
            _cachedPerfil = fallback;
            return fallback;
          }
        }
        return null;
      }
      final perfil = UsuarioModel.fromJson(data);
      if (userId == currentUser?.id) {
        _cachedPerfil = perfil;
      }
      return perfil;
    } catch (e) {
      // Se RLS ou schema estiver bloqueando, tenta buscar por email ou faz fallback
      if (userId == currentUser?.id) {
        if (currentUser?.email != null) {
          try {
            final data = await _client
                .from('Usuarios')
                .select()
                .eq('email', currentUser!.email!.trim().toLowerCase())
                .maybeSingle();
            if (data != null) {
              final perfil = UsuarioModel.fromJson(data);
              _cachedPerfil = perfil;
              return perfil;
            }
          } catch (_) {}
        }

        final meta = currentUser?.userMetadata;
        if (meta != null && meta['cargo'] != null) {
          final fallback = UsuarioModel(
            id: userId,
            nome: meta['nome'],
            email: currentUser?.email,
            cpf: meta['cpf'],
            telefone: meta['telefone'],
            cargo: meta['cargo'],
          );
          _cachedPerfil = fallback;
          return fallback;
        }
      }
      return null;
    }
  }

  Future<List<UsuarioModel>> getUsuarios() async {
    try {
      final data = await _client.from('Usuarios').select();
      return (data as List).map((e) => UsuarioModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Erro ao buscar todos usuarios: $e');
      return [];
    }
  }

  Future<void> updateUsuario(String userId, Map<String, dynamic> data) async {
    await _client.from('Usuarios').update(data).eq('id', userId);
  }

  Future<String?> uploadProfilePicture(String userId, Uint8List fileBytes, String fileName) async {
    final path = 'avatars/$userId-${DateTime.now().millisecondsSinceEpoch}-$fileName';
    await _client.storage.from('profiles').uploadBinary(path, fileBytes);
    final url = _client.storage.from('profiles').getPublicUrl(path);
    await updateUsuario(userId, {'foto_url': url});
    return url;
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

  Future<List<FrotaModel>> getFrotasByOperador(String operadorId) async {
    final dispositivos = await getDispositivosByOperador(operadorId);
    final frotaIds = dispositivos.map((d) => d.idFrota).whereType<String>().toSet().toList();
    if (frotaIds.isEmpty) return [];
    
    List<FrotaModel> frotas = [];
    for (var id in frotaIds) {
      final data = await _client.from('Frotas').select().eq('id', id).maybeSingle();
      if (data != null) {
        frotas.add(FrotaModel.fromJson(data));
      }
    }
    return frotas;
  }

  Future<FrotaModel?> getFrotaById(String id) async {
    final data = await _client.from('Frotas').select().eq('id', id).maybeSingle();
    return data != null ? FrotaModel.fromJson(data) : null;
  }

  Future<void> deleteFrota(String id) async {
    // Desvincular dispositivos da frota antes de deletar
    await _client.from('Dispositivos').update({'id_frota': null}).eq('id_frota', id);
    await _client.from('Frotas').delete().eq('id', id);
  }

  Future<FrotaModel> updateFrota({
    required String id,
    required String nome,
    String? idGerente,
    List<String>? selectedDeviceIds,
  }) async {
    try {
      final payload = <String, dynamic>{
        'nome': nome,
        'id_gerente': idGerente,
      };
      final res = await _client.from('Frotas').update(payload).eq('id', id).select().single();
      final updatedFrota = FrotaModel.fromJson(res);

      if (selectedDeviceIds != null) {
        // Desvincular dispositivos que pertenciam à frota e agora não foram selecionados
        await _client.from('Dispositivos').update({'id_frota': null}).eq('id_frota', id);
        // Vincular os dispositivos selecionados para esta frota
        for (var devId in selectedDeviceIds) {
          await _client.from('Dispositivos').update({'id_frota': id}).eq('id', devId);
        }
      }

      return updatedFrota;
    } catch (e) {
      throw Exception(formatarErro(e));
    }
  }

  // --- Dispositivos ---
  Future<List<DispositivoModel>> getDispositivos() async {
    final data = await _client.from('Dispositivos').select();
    return (data as List).map((e) => DispositivoModel.fromJson(e)).toList();
  }

  Future<DispositivoModel?> getDispositivoById(String id) async {
    final data = await _client.from('Dispositivos').select().eq('id', id).maybeSingle();
    return data != null ? DispositivoModel.fromJson(data) : null;
  }

  Future<void> deleteDispositivo(String id) async {
    await _client.from('Dispositivos').delete().eq('id', id);
  }

  Future<void> deleteUsuario(String id) async {
    // Desvincular dispositivos associados ao operador
    await _client.from('Dispositivos').update({'id_operador': null}).eq('id_operador', id);
    // Desvincular frotas associadas ao gerente
    await _client.from('Frotas').update({'id_gerente': null}).eq('id_gerente', id);
    // Deletar da tabela Usuarios
    await _client.from('Usuarios').delete().eq('id', id);
  }

  Future<List<DispositivoModel>> getDispositivosByFrota(String frotaId) async {
    final data = await _client.from('Dispositivos').select().eq('id_frota', frotaId);
    return (data as List).map((e) => DispositivoModel.fromJson(e)).toList();
  }

  Future<List<DispositivoModel>> getDispositivosByOperador(String operadorId) async {
    final cleanId = operadorId.trim();
    List<DispositivoModel> list = [];

    // 1. Busca direta por id_operador = cleanId
    try {
      final data = await _client.from('Dispositivos').select().eq('id_operador', cleanId);
      list = (data as List).map((e) => DispositivoModel.fromJson(e)).toList();
      if (list.isNotEmpty) return list;
    } catch (e) {
      debugPrint('Erro na busca direta por id_operador: $e');
    }

    // 2. Fallback inteligente: se a lista veio vazia, coleta todos os identificadores possíveis
    // do operador (auth UID, id na tabela Usuarios, email, CPF, nome)
    try {
      final candidateIds = <String>{cleanId};
      final user = currentUser;

      if (user != null) {
        if (user.id.isNotEmpty) candidateIds.add(user.id.trim());
        if (user.email != null && user.email!.trim().isNotEmpty) {
          candidateIds.add(user.email!.trim().toLowerCase());
        }
        if (user.userMetadata?['nome'] != null) {
          final mNome = user.userMetadata!['nome'].toString().trim().toLowerCase();
          if (mNome.isNotEmpty) candidateIds.add(mNome);
        }
      }

      if (_cachedPerfil != null) {
        if (_cachedPerfil!.id.isNotEmpty) candidateIds.add(_cachedPerfil!.id.trim());
        if (_cachedPerfil!.email != null && _cachedPerfil!.email!.trim().isNotEmpty) {
          candidateIds.add(_cachedPerfil!.email!.trim().toLowerCase());
        }
        if (_cachedPerfil!.nome != null && _cachedPerfil!.nome!.trim().isNotEmpty) {
          candidateIds.add(_cachedPerfil!.nome!.trim().toLowerCase());
        }
        if (_cachedPerfil!.cpf != null && _cachedPerfil!.cpf!.trim().isNotEmpty) {
          candidateIds.add(_cachedPerfil!.cpf!.replaceAll(RegExp(r'\D'), ''));
        }
      }

      // Tenta consultar na tabela Usuarios pelo cleanId ou pelo email do usuário atual
      try {
        final emailToSearch = user?.email?.trim().toLowerCase();
        if (emailToSearch != null && emailToSearch.isNotEmpty) {
          final res = await _client
              .from('Usuarios')
              .select('id, email, cpf, nome')
              .or('id.eq.$cleanId,email.eq.$emailToSearch');
          for (var u in (res as List)) {
            if (u['id'] != null) candidateIds.add(u['id'].toString().trim());
            if (u['email'] != null) candidateIds.add(u['email'].toString().trim().toLowerCase());
            if (u['nome'] != null) candidateIds.add(u['nome'].toString().trim().toLowerCase());
            if (u['cpf'] != null) {
              candidateIds.add(u['cpf'].toString().trim());
              candidateIds.add(u['cpf'].toString().replaceAll(RegExp(r'\D'), ''));
            }
          }
        }
      } catch (_) {}

      // Busca todos os dispositivos acessíveis para verificar se algum tem id_operador compatível
      final allData = await _client.from('Dispositivos').select();
      final allDevs = (allData as List).map((e) => DispositivoModel.fromJson(e)).toList();

      final matched = allDevs.where((d) {
        if (d.idOperador == null) return false;
        final op = d.idOperador!.trim();
        final opClean = op.replaceAll(RegExp(r'\D'), '');
        return candidateIds.any((cid) {
          if (cid.isEmpty) return false;
          if (cid == op || cid.toLowerCase() == op.toLowerCase()) return true;
          if (opClean.isNotEmpty && cid == opClean) return true;
          return false;
        });
      }).toList();

      // Se nenhum veículo bateu com o operador, mas há veículo com ID mock dummy
      // ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') ou 'Operador Teste', adota para o operador logado
      if (matched.isEmpty && allDevs.isNotEmpty) {
        final dummyDevs = allDevs.where((d) {
          final op = d.idOperador?.trim().toLowerCase() ?? '';
          return op == 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' ||
                 op == 'operador teste' ||
                 op.isEmpty;
        }).toList();

        if (dummyDevs.isNotEmpty) {
          final adopted = dummyDevs.first;
          matched.add(adopted);
        }
      }

      if (matched.isNotEmpty) {
        // Se encontramos o dispositivo e o id_operador difere do auth id atual,
        // sincroniza de forma segura
        if (user != null && user.id.isNotEmpty) {
          for (var dev in matched) {
            if (dev.idOperador != user.id) {
              try {
                await _client.from('Dispositivos').update({'id_operador': user.id}).eq('id', dev.id);
              } catch (_) {}
            }
          }
        }
        return matched;
      }
    } catch (e) {
      debugPrint('Erro no fallback inteligente de getDispositivosByOperador: $e');
    }

    return list;
  }

  Future<DispositivoModel> cadastrarDispositivo({
    required String nomeDispositivo,
    String? idFrota,
    required String idOperador,
    required String numeroSerie,
    required String modeloDispositivo,
    required String modeloVeiculo,
    required String placaVeiculo,
    required num temperaturaMinima,
    required num temperaturaMaxima,
    required num umidadeMaxima,
    required num sensibilidadeVibracao,
    required num limiteVibracao,
    required num intervaloDados,
  }) async {
    try {
      final payload = <String, dynamic>{
        'nome_dispositivo': nomeDispositivo.trim(),
        'id_operador': idOperador.trim(),
        'numero_serie': numeroSerie.trim(),
        'modelo_dispositivo': modeloDispositivo.trim(),
        'modelo_veiculo': modeloVeiculo.trim(),
        'placa_veiculo': placaVeiculo.trim(),
        'temperatura_minima': temperaturaMinima,
        'temperatura_maxima': temperaturaMaxima,
        'umidade_maxima': umidadeMaxima,
        'sensibilidade_vibracao': sensibilidadeVibracao,
        'limite_vibracao': limiteVibracao,
        'intervalo_dados': intervaloDados,
      };
      if (idFrota != null && idFrota.trim().isNotEmpty) {
        payload['id_frota'] = idFrota.trim();
      }

      final res = await _client.from('Dispositivos').insert(payload).select().single();
      return DispositivoModel.fromJson(res);
    } catch (e) {
      throw Exception(formatarErro(e));
    }
  }

  Future<DispositivoModel> updateDispositivo({
    required String id,
    required String nomeDispositivo,
    String? idFrota,
    required String idOperador,
    required String numeroSerie,
    required String modeloDispositivo,
    required String modeloVeiculo,
    required String placaVeiculo,
    required num temperaturaMinima,
    required num temperaturaMaxima,
    required num umidadeMaxima,
    required num sensibilidadeVibracao,
    required num limiteVibracao,
    required num intervaloDados,
  }) async {
    try {
      final payload = <String, dynamic>{
        'nome_dispositivo': nomeDispositivo.trim(),
        'id_frota': (idFrota != null && idFrota.trim().isNotEmpty) ? idFrota.trim() : null,
        'id_operador': idOperador.trim(),
        'numero_serie': numeroSerie.trim(),
        'modelo_dispositivo': modeloDispositivo.trim(),
        'modelo_veiculo': modeloVeiculo.trim(),
        'placa_veiculo': placaVeiculo.trim(),
        'temperatura_minima': temperaturaMinima,
        'temperatura_maxima': temperaturaMaxima,
        'umidade_maxima': umidadeMaxima,
        'sensibilidade_vibracao': sensibilidadeVibracao,
        'limite_vibracao': limiteVibracao,
        'intervalo_dados': intervaloDados,
      };

      final res = await _client.from('Dispositivos').update(payload).eq('id', id).select().single();
      return DispositivoModel.fromJson(res);
    } catch (e) {
      throw Exception(formatarErro(e));
    }
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

  Future<List<MedicaoModel>> getMedicoesFiltro(List<String> dispositivoIds, DateTime inicio, DateTime fim) async {
    if (dispositivoIds.isEmpty) return [];
    final data = await _client
        .from('medicoes')
        .select()
        .inFilter('id_dispositivo', dispositivoIds)
        .gte('registrado_em', inicio.toUtc().toIso8601String())
        .lte('registrado_em', fim.toUtc().toIso8601String())
        .order('registrado_em', ascending: true);
    return (data as List).map((e) => MedicaoModel.fromJson(e)).toList();
  }

  Future<MedicaoModel?> getLatestMedicao(String dispositivoId) async {
    try {
      final cleanId = dispositivoId.trim();
      if (cleanId.isEmpty) return null;
      final data = await _client
          .from('medicoes')
          .select()
          .eq('id_dispositivo', cleanId)
          .order('registrado_em', ascending: false)
          .limit(1);
      if ((data as List).isNotEmpty) {
        return MedicaoModel.fromJson(data.first);
      }
    } catch (e) {
      debugPrint('Erro ao buscar medicao mais recente para $dispositivoId: $e');
    }
    return null;
  }

  Future<List<OcorrenciaModel>> getOcorrenciasFiltro(List<String> dispositivoIds, DateTime inicio, DateTime fim) async {
    if (dispositivoIds.isEmpty) return [];
    final data = await _client
        .from('ocorrencias')
        .select()
        .inFilter('id_dispositivo', dispositivoIds)
        .gte('criado_em', inicio.toUtc().toIso8601String())
        .lte('criado_em', fim.toUtc().toIso8601String())
        .order('criado_em', ascending: true);
    return (data as List).map((e) => OcorrenciaModel.fromJson(e)).toList();
  }

  // --- Fins de Viagem / Paradas ---
  Future<String?> uploadAnexoViagem(String operatorId, Uint8List fileBytes, String fileName) async {
    try {
      final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = 'viagens/$operatorId-${DateTime.now().millisecondsSinceEpoch}-$safeName';
      await _client.storage.from('anexos-viagem').uploadBinary(path, fileBytes);
      return _client.storage.from('anexos-viagem').getPublicUrl(path);
    } catch (e) {
      debugPrint('Aviso: upload de anexo de viagem não concluído: $e');
      return null;
    }
  }

  Future<bool> salvarFimViagem({
    required String operatorId,
    String? deviceId,
    required String motivo,
    required String rua,
    required String bairro,
    required String cidade,
    String? cep,
    List<String> anexos = const [],
  }) async {
    try {
      final cleanOpId = operatorId.trim();
      final payload = {
        if (cleanOpId.isNotEmpty) 'id_operador': cleanOpId,
        if (deviceId != null && deviceId.trim().isNotEmpty) 'id_dispositivo': deviceId.trim(),
        'motivo': motivo.trim(),
        'rua': rua.trim(),
        'bairro': bairro.trim(),
        'cidade': cidade.trim(),
        if (cep != null && cep.trim().isNotEmpty) 'cep': cep.trim(),
        'anexos': anexos,
      };
      await _client.from('fins_viagem').insert(payload);
      return true;
    } catch (e) {
      debugPrint('Aviso: fins_viagem não inserido no Supabase (tabela pode ainda não ter sido executada): $e');
      return false;
    }
  }
}
