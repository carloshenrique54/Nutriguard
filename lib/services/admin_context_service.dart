import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'supabase_service.dart';

/// Serviço singleton para gerenciar o contexto ativo de navegação do Administrador (ADM).
/// 
/// Contextos possíveis:
/// 1. Sem frota selecionada (ex: Tela de Seleção de Frotas)
/// 2. Frota selecionada (Dashboard da Frota, Lista de Veículos da Frota, Histórico/Relatórios da Frota)
/// 3. Veículo selecionado (Dashboard do Veículo, Histórico/Relatórios do Veículo, preservando a frota de origem)
class AdminContextService extends ChangeNotifier {
  static final AdminContextService _instance = AdminContextService._internal();
  factory AdminContextService() => _instance;
  AdminContextService._internal();

  SupabaseService? get _supabase {
    try {
      return SupabaseService();
    } catch (_) {
      return null;
    }
  }

  FrotaModel? _selectedFrota;
  DispositivoModel? _selectedDevice;

  FrotaModel? get selectedFrota => _selectedFrota;
  DispositivoModel? get selectedDevice => _selectedDevice;

  bool get hasFrota => _selectedFrota != null;
  bool get hasDevice => _selectedDevice != null;

  String? get currentFrotaId => _selectedFrota?.id;
  String? get currentFrotaName => _selectedFrota?.nome;
  String? get currentDeviceId => _selectedDevice?.id;
  String? get currentDeviceName => _selectedDevice?.placaVeiculo ?? _selectedDevice?.nomeDispositivo;

  /// Define a frota ativa no contexto do ADM.
  /// Se um veículo selecionado não pertencer a esta frota, o veículo é desmarcado.
  void setFrota(FrotaModel? frota) {
    _selectedFrota = frota;
    if (frota == null || (_selectedDevice != null && _selectedDevice!.idFrota != frota.id)) {
      _selectedDevice = null;
    }
    notifyListeners();
  }

  /// Define o veículo ativo no contexto do ADM, preservando ou associando sua frota de origem.
  void setDevice(DispositivoModel? device, {FrotaModel? frota}) async {
    _selectedDevice = device;
    if (frota != null) {
      _selectedFrota = frota;
    } else if (device != null && device.idFrota != null) {
      // Se não temos a frota em memória ou é diferente, carrega a frota de origem
      if (_selectedFrota == null || _selectedFrota!.id != device.idFrota) {
        try {
          final client = _supabase;
          if (client != null) {
            final frotas = await client.getFrotas();
            final matching = frotas.where((f) => f.id == device.idFrota).firstOrNull;
            if (matching != null) {
              _selectedFrota = matching;
            }
          }
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  /// Limpa apenas o contexto do veículo, mantendo a frota ativa.
  void clearVehicle() {
    _selectedDevice = null;
    notifyListeners();
  }

  /// Limpa todo o contexto de frota e veículo (ex: ao retornar à tela de seleção de frotas).
  void clearAll() {
    _selectedFrota = null;
    _selectedDevice = null;
    notifyListeners();
  }
}
