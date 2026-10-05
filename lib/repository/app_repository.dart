import 'package:flutter/foundation.dart';
import '../models/models.dart';

class AppRepository extends ChangeNotifier {
  // Singleton
  static final AppRepository instance = AppRepository._internal();

  AppRepository._internal() {
    _initMocks();
  }

  // State
  User? currentUser;

  final List<User> users = [];
  final List<Device> devices = [];
  final List<Fleet> fleets = [];
  final List<Alert> alerts = [];

  void _initMocks() {
    // Current user default (ADM)
    currentUser = User(id: 'adm1', nome: 'Admin', email: 'adm@nutri.com', senha: '123', cpf: '000', telefone: '000', role: 'adm');

    // Mocks - Users (Gerentes)
    users.add(User(id: 'ger1', nome: 'Vinícius Silva', email: 'vinicius@nutri.com', senha: '123', cpf: '111', telefone: '999', role: 'gerente'));
    users.add(User(id: 'ger2', nome: 'Ricardo Gomes', email: 'ricardo@nutri.com', senha: '123', cpf: '222', telefone: '888', role: 'gerente'));
    users.add(User(id: 'ger3', nome: 'Mariana Luz', email: 'mariana@nutri.com', senha: '123', cpf: '333', telefone: '777', role: 'gerente'));

    // Mocks - Users (Operadores)
    users.add(User(id: 'op1', nome: 'José Almeida', email: 'jose@nutri.com', senha: '123', cpf: '444', telefone: '666', role: 'operador'));
    users.add(User(id: 'op2', nome: 'Rafael Costa', email: 'rafael@nutri.com', senha: '123', cpf: '555', telefone: '555', role: 'operador'));
    users.add(User(id: 'op3', nome: 'Ana Ferreira', email: 'ana@nutri.com', senha: '123', cpf: '555', telefone: '555', role: 'operador'));

    // Mocks - Devices
    devices.add(Device(id: 'dev1', nome: 'Volvo FH 540', numeroSerie: '12345', modelo: 'Volvo', operadorId: 'op1', tempMin: '-2', tempMax: '4', humidadeMax: '80', carga: 'Legumes'));
    devices.add(Device(id: 'dev2', nome: 'Scania R 450', numeroSerie: '12346', modelo: 'Scania', operadorId: 'op2', tempMin: '-5', tempMax: '2', humidadeMax: '70', carga: 'Frutas'));
    devices.add(Device(id: 'dev3', nome: 'Mercedes Actros', numeroSerie: '12347', modelo: 'Mercedes', operadorId: 'op3', tempMin: '0', tempMax: '5', humidadeMax: '65', carga: 'Frutas'));

    // Mocks - Fleets
    fleets.add(Fleet(id: 'flt1', nome: 'Frota Sul', gerenteId: 'ger1', deviceIds: ['dev1', 'dev2']));
    fleets.add(Fleet(id: 'flt2', nome: 'Frota Norte', gerenteId: 'ger2', deviceIds: ['dev3']));
    
    // Alerts
    alerts.add(Alert(id: 'al1', titulo: 'Alerta Temperatura', subtitulo: 'O camião 1 (Volvo FH 540) excedeu a temperatura mínima estabelecida.', hora: 'Agora', gravidade: 'alta'));
  }

  // --- Login ---
  void login(String email, String senha) {
    if (email == 'adm@nutri.com') {
      currentUser = User(id: 'adm1', nome: 'Admin', email: 'adm@nutri.com', senha: '123', cpf: '000', telefone: '000', role: 'adm');
    } else {
      try {
        currentUser = users.firstWhere((u) => u.email == email && u.senha == senha);
      } catch (e) {
        throw Exception("Invalid credentials");
      }
    }
    notifyListeners();
  }
  
  void logout() {
    currentUser = null;
    notifyListeners();
  }

  // --- CRUD Devices ---
  void addDevice(Device d) {
    devices.add(d);
    notifyListeners();
  }

  void updateDevice(Device d) {
    int index = devices.indexWhere((e) => e.id == d.id);
    if (index != -1) {
      devices[index] = d;
      notifyListeners();
    }
  }

  void removeDevice(String id) {
    devices.removeWhere((e) => e.id == id);
    // Also remove from fleets
    for (var f in fleets) {
      f.deviceIds.remove(id);
    }
    notifyListeners();
  }

  // --- CRUD Fleets ---
  void addFleet(Fleet f) {
    fleets.add(f);
    notifyListeners();
  }

  void updateFleet(Fleet f) {
    int index = fleets.indexWhere((e) => e.id == f.id);
    if (index != -1) {
      fleets[index] = f;
      notifyListeners();
    }
  }

  void removeFleet(String id) {
    fleets.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  // --- CRUD Users ---
  void addUser(User u) {
    users.add(u);
    notifyListeners();
  }

  void updateUser(User u) {
    int index = users.indexWhere((e) => e.id == u.id);
    if (index != -1) {
      users[index] = u;
      notifyListeners();
    }
  }

  void removeUser(String id) {
    users.removeWhere((e) => e.id == id);
    // Remove references
    for (var f in fleets) {
      if (f.gerenteId == id) f.gerenteId = null;
    }
    for (var d in devices) {
      if (d.operadorId == id) d.operadorId = null;
    }
    notifyListeners();
  }

  // Helpers
  User? getUserById(String? id) {
    if (id == null) return null;
    try {
      return users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }
  
  Device? getDeviceById(String? id) {
    if (id == null) return null;
    try {
      return devices.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }
}
