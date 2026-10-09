class UsuarioModel {
  final String id;
  final String? fotoUrl;
  final String? nome;
  final String? email;
  final String? cpf;
  final String? telefone;
  final String? cargo;
  final DateTime? dataNascimento;
  final String? numeroCnh;
  final DateTime? validadeCnh;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UsuarioModel({
    required this.id,
    this.fotoUrl,
    this.nome,
    this.email,
    this.cpf,
    this.telefone,
    this.cargo,
    this.dataNascimento,
    this.numeroCnh,
    this.validadeCnh,
    this.createdAt,
    this.updatedAt,
  });

  factory UsuarioModel.fromJson(Map<String, dynamic> json) {
    return UsuarioModel(
      id: json['id'],
      fotoUrl: json['foto_url'] ?? json['avatar_url'],
      nome: json['nome'],
      email: json['email'],
      cpf: json['cpf'],
      telefone: json['telefone'],
      cargo: json['cargo'],
      dataNascimento: json['data_nascimento'] != null ? DateTime.tryParse(json['data_nascimento']) : null,
      numeroCnh: json['numero_cnh'],
      validadeCnh: json['validade_cnh'] != null ? DateTime.tryParse(json['validade_cnh']) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (fotoUrl != null) 'foto_url': fotoUrl,
      if (nome != null) 'nome': nome,
      if (email != null) 'email': email,
      if (cpf != null) 'cpf': cpf,
      if (telefone != null) 'telefone': telefone,
      if (cargo != null) 'cargo': cargo,
      if (dataNascimento != null) 'data_nascimento': dataNascimento!.toIso8601String().split('T').first,
      if (numeroCnh != null) 'numero_cnh': numeroCnh,
      if (validadeCnh != null) 'validade_cnh': validadeCnh!.toIso8601String().split('T').first,
    };
  }

  /// Cargo normalizado do usuario: 'admin', 'gerente', 'operador' ou '' (desconhecido).
  String get role {
    final c = (cargo ?? '').trim().toLowerCase();
    if (c == 'admin' || c == 'adm' || c == 'administrador') return 'admin';
    if (c == 'gerente') return 'gerente';
    if (c == 'operador') return 'operador';
    return '';
  }
}

class FrotaModel {
  final String id;
  final String? fotoUrl;
  final String? idGerente;
  final String? nome;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FrotaModel({
    required this.id,
    this.fotoUrl,
    this.idGerente,
    this.nome,
    this.createdAt,
    this.updatedAt,
  });

  factory FrotaModel.fromJson(Map<String, dynamic> json) {
    return FrotaModel(
      id: json['id'],
      fotoUrl: json['foto_url'] ?? json['avatar_url'],
      idGerente: json['id_gerente'],
      nome: json['nome'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (fotoUrl != null) 'foto_url': fotoUrl,
      if (idGerente != null) 'id_gerente': idGerente,
      if (nome != null) 'nome': nome,
    };
  }
}

class DispositivoModel {
  final String id;
  final String? fotoUrl;
  final String? idOperador;
  final String? idFrota;
  final String? nomeDispositivo;
  final String? numeroSerie;
  final String? modeloDispositivo;
  final String? modeloVeiculo;
  final String? placaVeiculo;
  final num? temperaturaMinima;
  final num? temperaturaMaxima;
  final num? umidadeMinima;
  final num? umidadeMaxima;
  final int? sensibilidadeVibracao;
  final int? limiteVibracao;
  final num? intervaloDados;
  final num? bateriaMinima;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DispositivoModel({
    required this.id,
    this.fotoUrl,
    this.idOperador,
    this.idFrota,
    this.nomeDispositivo,
    this.numeroSerie,
    this.modeloDispositivo,
    this.modeloVeiculo,
    this.placaVeiculo,
    this.temperaturaMinima,
    this.temperaturaMaxima,
    this.umidadeMinima,
    this.umidadeMaxima,
    this.sensibilidadeVibracao,
    this.limiteVibracao,
    this.intervaloDados,
    this.bateriaMinima,
    this.createdAt,
    this.updatedAt,
  });

  factory DispositivoModel.fromJson(Map<String, dynamic> json) {
    return DispositivoModel(
      id: json['id'],
      fotoUrl: json['foto_url'] ?? json['avatar_url'],
      idOperador: json['id_operador'],
      idFrota: json['id_frota'],
      nomeDispositivo: json['nome_dispositivo'],
      numeroSerie: json['numero_serie'],
      modeloDispositivo: json['modelo_dispositivo'],
      modeloVeiculo: json['modelo_veiculo'],
      placaVeiculo: json['placa_veiculo'],
      temperaturaMinima: json['temperatura_minima'],
      temperaturaMaxima: json['temperatura_maxima'],
      umidadeMinima: json['umidade_minima'],
      umidadeMaxima: json['umidade_maxima'],
      sensibilidadeVibracao: json['sensibilidade_vibracao'],
      limiteVibracao: json['limite_vibracao'],
      intervaloDados: json['intervalo_dados'],
      bateriaMinima: json['bateria_minima'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (fotoUrl != null) 'foto_url': fotoUrl,
      if (idOperador != null) 'id_operador': idOperador,
      if (idFrota != null) 'id_frota': idFrota,
      if (nomeDispositivo != null) 'nome_dispositivo': nomeDispositivo,
      if (numeroSerie != null) 'numero_serie': numeroSerie,
      if (modeloDispositivo != null) 'modelo_dispositivo': modeloDispositivo,
      if (modeloVeiculo != null) 'modelo_veiculo': modeloVeiculo,
      if (placaVeiculo != null) 'placa_veiculo': placaVeiculo,
      if (temperaturaMinima != null) 'temperatura_minima': temperaturaMinima,
      if (temperaturaMaxima != null) 'temperatura_maxima': temperaturaMaxima,
      if (umidadeMinima != null) 'umidade_minima': umidadeMinima,
      if (umidadeMaxima != null) 'umidade_maxima': umidadeMaxima,
      if (sensibilidadeVibracao != null) 'sensibilidade_vibracao': sensibilidadeVibracao,
      if (limiteVibracao != null) 'limite_vibracao': limiteVibracao,
      if (intervaloDados != null) 'intervalo_dados': intervaloDados,
      if (bateriaMinima != null) 'bateria_minima': bateriaMinima,
    };
  }
}

class MedicaoModel {
  final String id;
  final String? fotoUrl;
  final String? idDispositivo;
  final num? temperatura;
  final num? umidade;
  final num? vibracao;
  final bool? portaAberta;
  final num? latitude;
  final num? longitude;
  final num? bateria;
  final DateTime? registradoEm;

  MedicaoModel({
    required this.id,
    this.fotoUrl,
    this.idDispositivo,
    this.temperatura,
    this.umidade,
    this.vibracao,
    this.portaAberta,
    this.latitude,
    this.longitude,
    this.bateria,
    this.registradoEm,
  });

  factory MedicaoModel.fromJson(Map<String, dynamic> json) {
    return MedicaoModel(
      id: json['id'],
      fotoUrl: json['foto_url'] ?? json['avatar_url'],
      idDispositivo: json['id_dispositivo'],
      temperatura: json['temperatura'],
      umidade: json['umidade'],
      vibracao: json['vibracao'],
      portaAberta: json['porta_aberta'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      bateria: json['bateria'],
      registradoEm: json['registrado_em'] != null ? DateTime.tryParse(json['registrado_em']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (fotoUrl != null) 'foto_url': fotoUrl,
      if (idDispositivo != null) 'id_dispositivo': idDispositivo,
      if (temperatura != null) 'temperatura': temperatura,
      if (umidade != null) 'umidade': umidade,
      if (vibracao != null) 'vibracao': vibracao,
      if (portaAberta != null) 'porta_aberta': portaAberta,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (bateria != null) 'bateria': bateria,
    };
  }
}

class OcorrenciaModel {
  final String id;
  final String? fotoUrl;
  final String? idDispositivo;
  final String? idMedicao;
  final String? tipo;
  final num? valorRegistrado;
  final num? limiteConfigurado;
  final String? status;
  final DateTime? criadoEm;

  OcorrenciaModel({
    required this.id,
    this.fotoUrl,
    this.idDispositivo,
    this.idMedicao,
    this.tipo,
    this.valorRegistrado,
    this.limiteConfigurado,
    this.status,
    this.criadoEm,
  });

  factory OcorrenciaModel.fromJson(Map<String, dynamic> json) {
    return OcorrenciaModel(
      id: json['id'],
      fotoUrl: json['foto_url'] ?? json['avatar_url'],
      idDispositivo: json['id_dispositivo'],
      idMedicao: json['id_medicao'],
      tipo: json['tipo'],
      valorRegistrado: json['valor_registrado'],
      limiteConfigurado: json['limite_configurado'],
      status: json['status'],
      criadoEm: json['criado_em'] != null ? DateTime.tryParse(json['criado_em']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (fotoUrl != null) 'foto_url': fotoUrl,
      if (idDispositivo != null) 'id_dispositivo': idDispositivo,
      if (idMedicao != null) 'id_medicao': idMedicao,
      if (tipo != null) 'tipo': tipo,
      if (valorRegistrado != null) 'valor_registrado': valorRegistrado,
      if (limiteConfigurado != null) 'limite_configurado': limiteConfigurado,
      if (status != null) 'status': status,
    };
  }
}
