import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../services/admin_context_service.dart';

class CustomBottomNavBar extends StatefulWidget {
  final int? selectedIndex;
  final bool? isVehicleContext;
  final Object? currentDevice;
  final String? userRoleOverride;
  final bool isDisabled;
  final bool? hasFleetsOverride;
  final bool? hasDevicesOverride;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    this.isVehicleContext,
    this.currentDevice,
    this.userRoleOverride,
    this.isDisabled = false,
    this.hasFleetsOverride,
    this.hasDevicesOverride,
  });

  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  SupabaseService? get _supabase {
    try {
      return SupabaseService();
    } catch (_) {
      return null;
    }
  }

  final AdminContextService _adminContext = AdminContextService();
  bool _isInit = false;
  bool _isVehicle = false;
  String _userRole = '';
  bool _hasFleets = true;
  bool _hasDevices = true;

  @override
  void initState() {
    super.initState();
    _userRole = widget.userRoleOverride ?? SupabaseService.currentCachedPerfil?.role ?? '';
    if (widget.hasFleetsOverride != null) {
      _hasFleets = widget.hasFleetsOverride!;
    }
    if (widget.hasDevicesOverride != null) {
      _hasDevices = widget.hasDevicesOverride!;
    }
    _adminContext.addListener(_onContextChanged);
    _resolveContext();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isInit = true;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant CustomBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userRoleOverride != null) {
      _userRole = widget.userRoleOverride!;
    }
    if (widget.hasFleetsOverride != null) {
      _hasFleets = widget.hasFleetsOverride!;
    }
    if (widget.hasDevicesOverride != null) {
      _hasDevices = widget.hasDevicesOverride!;
    }
  }

  @override
  void dispose() {
    _adminContext.removeListener(_onContextChanged);
    super.dispose();
  }

  void _onContextChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _resolveContext() async {
    final client = _supabase;
    if (client == null) return;
    final user = client.currentUser;
    if (user != null) {
      if (widget.userRoleOverride == null) {
        final perfil = await client.getUsuarioPerfil(user.id);
        if (mounted && perfil != null) {
          setState(() {
            _userRole = perfil.role;
          });
        }
      }

      final role = widget.userRoleOverride ?? _userRole;
      if (role == 'gerente') {
        if (widget.hasFleetsOverride == null || widget.hasDevicesOverride == null) {
          try {
            final frotas = await client.getFrotasByGerente(user.id);
            bool hasDevs = false;
            if (frotas.isNotEmpty) {
              final allDevices = await client.getDispositivos();
              final frotaIds = frotas.map((f) => f.id).toSet();
              hasDevs = allDevices.any((d) => frotaIds.contains(d.idFrota));
            }
            if (mounted) {
              setState(() {
                if (widget.hasFleetsOverride == null) _hasFleets = frotas.isNotEmpty;
                if (widget.hasDevicesOverride == null) _hasDevices = hasDevs;
              });
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          if (_userRole != 'admin') {
            if (widget.isVehicleContext != null) {
              _isVehicle = widget.isVehicleContext!;
            } else {
              _isVehicle = _userRole == 'operador';
            }
          }
        });
      }
    }
  }

  /// Verifica se o item da barra inferior está habilitado.
  /// 
  /// Regras:
  /// - Se isDisabled for true: tudo indisponível (cinza).
  /// - Para Gerente: se não tiver frota ou não tiver dispositivo cadastrado,
  ///   tudo fica indisponível (cinza).
  /// - Para ADM:
  ///   - Índice 4 (GPS): SEMPRE indisponível em contexto de frota.
  ///   - Índices 0..3: Indisponíveis enquanto nenhuma frota estiver selecionada.
  bool _isItemEnabled(int index) {
    if (widget.isDisabled) {
      return false;
    }

    final effectiveRole = widget.userRoleOverride ?? _userRole;
    final effectiveHasFleets = widget.hasFleetsOverride ?? _hasFleets;
    final effectiveHasDevices = widget.hasDevicesOverride ?? _hasDevices;

    if (effectiveRole == 'gerente') {
      if (!effectiveHasFleets || !effectiveHasDevices) {
        return false;
      }
    }

    // Índice 4 (GPS): Estritamente vinculado ao contexto de veículo.
    // Em contexto de frota (isVehicleContext == false), o GPS SEMPRE deve estar indisponível
    // tanto para ADM quanto para Gerente (o dashboard da frota não pode levar pro GPS).
    if (index == 4) {
      if (widget.isVehicleContext == false) {
        return false;
      }
      if (effectiveRole == 'admin') {
        return widget.isVehicleContext == true || _adminContext.hasDevice;
      }
      return widget.isVehicleContext == true;
    }

    if (effectiveRole != 'admin') {
      // Para outros papéis (gerente com dispositivos, operador), mantém comportamento padrão
      return true;
    }

    // Enquanto nenhuma frota estiver selecionada para o ADM,
    // todas as opções secundárias permanecem indisponíveis
    if (!_adminContext.hasFrota && widget.isVehicleContext != true) {
      return false;
    }

    return true;
  }

  Object? _resolveRouteArgs(String routeName) {
    final effectiveRole = widget.userRoleOverride ?? _userRole;
    final bool isAdmVehicle = effectiveRole == 'admin' && (_adminContext.hasDevice || widget.isVehicleContext == true);
    final bool effectiveIsVehicle = widget.isVehicleContext ?? ((effectiveRole == 'admin') ? isAdmVehicle : _isVehicle);

    if (effectiveRole == 'admin') {
      if (effectiveIsVehicle) {
        return widget.currentDevice ?? _adminContext.selectedDevice;
      } else if (_adminContext.hasFrota) {
        return _adminContext.selectedFrota;
      }
    }
    return widget.currentDevice;
  }

  void _onTapNav(BuildContext context, int index, String routeName, bool isActive, bool isEnabled) {
    if (!isEnabled || isActive) return;

    HapticFeedback.lightImpact();
    final args = _resolveRouteArgs(routeName);
    if (args != null) {
      Navigator.pushReplacementNamed(context, routeName, arguments: args);
    } else {
      Navigator.pushReplacementNamed(context, routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmVehicle = _userRole == 'admin' && (_adminContext.hasDevice || widget.isVehicleContext == true);
    final bool effectiveIsVehicle = widget.isVehicleContext ?? ((_userRole == 'admin') ? isAdmVehicle : _isVehicle);

    final String alertasRoute = effectiveIsVehicle ? '/alertas-veiculo' : '/alertas-frota';
    final String relatoriosRoute = effectiveIsVehicle ? '/relatorios-veiculo' : '/relatorios-frota';
    final String dashboardRoute = effectiveIsVehicle ? '/dashboard-veiculo' : '/dashboard-frota';
    final String historicoRoute = effectiveIsVehicle ? '/historico-veiculo' : '/historico-frota';
    const String gpsRoute = '/gps';

    final bool showBubble = widget.selectedIndex != null &&
        widget.selectedIndex! >= 0 &&
        widget.selectedIndex! < 5 &&
        _isItemEnabled(widget.selectedIndex!);

    return Container(
      height: 75,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFC8E569),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double barWidth = constraints.maxWidth;
              final double itemWidth = barWidth / 5;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Background layout for spacing
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildNavItem(
                        context: context,
                        index: 0,
                        itemWidth: itemWidth,
                        icon: Icons.notifications_none,
                        label: 'Alertas',
                        routeName: alertasRoute,
                        isEnabled: _isItemEnabled(0),
                        isActive: showBubble && widget.selectedIndex == 0,
                      ),
                      _buildNavItem(
                        context: context,
                        index: 1,
                        itemWidth: itemWidth,
                        icon: Icons.description_outlined,
                        label: 'Relatórios',
                        routeName: relatoriosRoute,
                        isEnabled: _isItemEnabled(1),
                        isActive: showBubble && widget.selectedIndex == 1,
                      ),
                      _buildNavItem(
                        context: context,
                        index: 2,
                        itemWidth: itemWidth,
                        icon: Icons.dashboard_rounded,
                        label: 'Dashboard',
                        routeName: dashboardRoute,
                        isEnabled: _isItemEnabled(2),
                        isActive: showBubble && widget.selectedIndex == 2,
                      ),
                      _buildNavItem(
                        context: context,
                        index: 3,
                        itemWidth: itemWidth,
                        icon: Icons.access_time,
                        label: 'Histórico',
                        routeName: historicoRoute,
                        isEnabled: _isItemEnabled(3),
                        isActive: showBubble && widget.selectedIndex == 3,
                      ),
                      _buildNavItem(
                        context: context,
                        index: 4,
                        itemWidth: itemWidth,
                        icon: Icons.location_on_outlined,
                        label: 'GPS',
                        routeName: gpsRoute,
                        isEnabled: _isItemEnabled(4),
                        isActive: showBubble && widget.selectedIndex == 4,
                      ),
                    ],
                  ),

                  // Animated Bubble
                  if (showBubble)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutBack,
                      bottom: _isInit ? 20 : 0,
                      left: _calculateLeftPosition(barWidth, widget.selectedIndex!),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: Color(0xFFC23147),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x4DC23147),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            _getIconForIndex(widget.selectedIndex!),
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  double _calculateLeftPosition(double barWidth, int index) {
    final itemWidth = barWidth / 5;
    return (itemWidth * index) + (itemWidth / 2) - 28;
  }

  IconData _getIconForIndex(int index) {
    switch (index) {
      case 0: return Icons.notifications_none;
      case 1: return Icons.description_outlined;
      case 2: return Icons.dashboard_rounded;
      case 3: return Icons.access_time;
      case 4: return Icons.location_on_outlined;
      default: return Icons.dashboard_rounded;
    }
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required double itemWidth,
    required IconData icon,
    required String label,
    required String routeName,
    required bool isEnabled,
    required bool isActive,
  }) {
    // Símbolos e textos desabilitados ficam cinzas nítidos; habilitados ficam pretos
    final Color itemColor = isEnabled ? Colors.black87 : const Color(0xFF757575);

    return GestureDetector(
      onTap: isEnabled
          ? () => _onTapNav(context, index, routeName, isActive, isEnabled)
          : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: itemWidth,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isActive ? 0.0 : 1.0,
                child: Icon(
                  icon,
                  color: itemColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isActive ? 0.0 : 1.0,
                child: Text(
                  label,
                  style: TextStyle(
                    color: itemColor,
                    fontSize: 10,
                    fontWeight: isEnabled ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
