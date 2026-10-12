import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../services/admin_context_service.dart';

class CustomBottomNavBar extends StatefulWidget {
  final int? selectedIndex;
  final bool? isVehicleContext;
  final Object? currentDevice;
  final String? userRoleOverride;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    this.isVehicleContext,
    this.currentDevice,
    this.userRoleOverride,
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

  @override
  void initState() {
    super.initState();
    _userRole = widget.userRoleOverride ?? SupabaseService.currentCachedPerfil?.role ?? '';
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
  void dispose() {
    _adminContext.removeListener(_onContextChanged);
    super.dispose();
  }

  void _onContextChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _resolveContext() async {
    if (widget.userRoleOverride != null) {
      if (mounted) setState(() => _userRole = widget.userRoleOverride!);
      return;
    }
    final client = _supabase;
    if (client == null) return;
    final user = client.currentUser;
    if (user != null) {
      final perfil = await client.getUsuarioPerfil(user.id);
      if (mounted) {
        setState(() {
          _userRole = perfil?.role ?? '';
          if (_userRole != 'admin') {
            if (widget.isVehicleContext != null) {
              _isVehicle = widget.isVehicleContext!;
            } else {
              _isVehicle = perfil?.role == 'operador';
            }
          }
        });
      }
    }
  }

  /// Verifica se o item da barra inferior está habilitado.
  /// 
  /// Regras para ADM:
  /// - Índice 4 (GPS): SEMPRE indisponível (Regra 5).
  /// - Índices 0..3 (Alertas, Relatórios, Dashboard, Histórico):
  ///   Indisponíveis enquanto nenhuma frota estiver selecionada.
  ///   Habilitados assim que uma frota for selecionada.
  bool _isItemEnabled(int index) {
    if (_userRole != 'admin') {
      // Para outros papéis (gerente, operador), mantém comportamento padrão
      return true;
    }

    // Regra 5: GPS é SEMPRE indisponível para o ADM
    if (index == 4) {
      return false;
    }

    // Enquanto nenhuma frota estiver selecionada para o ADM,
    // todas as opções secundárias permanecem indisponíveis
    if (!_adminContext.hasFrota) {
      return false;
    }

    return true;
  }

  Object? _resolveRouteArgs(String routeName) {
    if (_userRole == 'admin') {
      if (_adminContext.hasDevice) {
        return _adminContext.selectedDevice;
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
    final bool isAdmVehicle = _userRole == 'admin' && _adminContext.hasDevice;
    final bool effectiveIsVehicle = (_userRole == 'admin') ? isAdmVehicle : _isVehicle;

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
      child: Stack(
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
                icon: Icons.notifications_none,
                label: 'Alertas',
                routeName: alertasRoute,
                isEnabled: _isItemEnabled(0),
                isActive: showBubble && widget.selectedIndex == 0,
              ),
              _buildNavItem(
                context: context,
                index: 1,
                icon: Icons.description_outlined,
                label: 'Relatórios',
                routeName: relatoriosRoute,
                isEnabled: _isItemEnabled(1),
                isActive: showBubble && widget.selectedIndex == 1,
              ),
              _buildNavItem(
                context: context,
                index: 2,
                icon: Icons.dashboard_rounded,
                label: 'Dashboard',
                routeName: dashboardRoute,
                isEnabled: _isItemEnabled(2),
                isActive: showBubble && widget.selectedIndex == 2,
              ),
              _buildNavItem(
                context: context,
                index: 3,
                icon: Icons.access_time,
                label: 'Histórico',
                routeName: historicoRoute,
                isEnabled: _isItemEnabled(3),
                isActive: showBubble && widget.selectedIndex == 3,
              ),
              _buildNavItem(
                context: context,
                index: 4,
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
              left: _calculateLeftPosition(context, widget.selectedIndex!),
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
      ),
    );
  }

  double _calculateLeftPosition(BuildContext context, int index) {
    final width = MediaQuery.of(context).size.width;
    final itemWidth = width / 5;
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
        width: MediaQuery.of(context).size.width / 5,
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
