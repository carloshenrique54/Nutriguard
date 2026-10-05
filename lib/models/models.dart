class User {
  String id;
  String nome;
  String email;
  String senha;
  String cpf;
  String telefone;
  String role; // 'adm', 'gerente', 'operador'

  User({
    required this.id,
    required this.nome,
    required this.email,
    required this.senha,
    required this.cpf,
    required this.telefone,
    required this.role,
  });
}

class Device {
  String id;
  String nome;
  String numeroSerie;
  String modelo;
  String? operadorId;
  String tempMin;
  String tempMax;
  String humidadeMax;
  String? carga;

  Device({
    required this.id,
    required this.nome,
    required this.numeroSerie,
    required this.modelo,
    this.operadorId,
    required this.tempMin,
    required this.tempMax,
    required this.humidadeMax,
    this.carga,
  });
}

class Fleet {
  String id;
  String nome;
  String? gerenteId;
  List<String> deviceIds;

  Fleet({
    required this.id,
    required this.nome,
    this.gerenteId,
    required this.deviceIds,
  });
}

class Alert {
  String id;
  String titulo;
  String subtitulo;
  String hora;
  String gravidade; // 'alta', 'media', 'baixa'

  Alert({
    required this.id,
    required this.titulo,
    required this.subtitulo,
    required this.hora,
    required this.gravidade,
  });
}
