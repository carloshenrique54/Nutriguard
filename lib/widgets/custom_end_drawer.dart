import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../services/admin_context_service.dart';

class CustomEndDrawer {
  static void showMenu(BuildContext context, {String? userRoleOverride, bool? hasFleetsOverride, bool? hasDevicesOverride}) {
    HapticFeedback.lightImpact();
    showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: 'Menu',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink(); // Built in transitionBuilder
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final slideTween = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );

        return Stack(
          children: [
            // Background Blur
            FadeTransition(
              opacity: animation,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                  child: Container(
                    color: const Color(0x33000000),
                  ),
                ),
              ),
            ),
            // Slide Menu Content
            Align(
              alignment: Alignment.centerRight,
              child: SlideTransition(
                position: slideTween,
                child: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.height,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF2E0),
                        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
                      ),
                      child: _MenuContent(
                        userRoleOverride: userRoleOverride,
                        hasFleetsOverride: hasFleetsOverride,
                        hasDevicesOverride: hasDevicesOverride,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MenuContent extends StatefulWidget {
  final String? userRoleOverride;
  final bool? hasFleetsOverride;
  final bool? hasDevicesOverride;
  const _MenuContent({this.userRoleOverride, this.hasFleetsOverride, this.hasDevicesOverride});

  @override
  State<_MenuContent> createState() => _MenuContentState();
}

class _MenuContentState extends State<_MenuContent> {
  SupabaseService? get _supabase {
    try {
      return SupabaseService();
    } catch (_) {
      return null;
    }
  }
  final AdminContextService _adminContext = AdminContextService();
  String _userRole = '';
  bool _hasFleets = true;
  bool _hasDevices = true;

  @override
  void initState() {
    super.initState();
    if (widget.userRoleOverride != null) {
      _userRole = widget.userRoleOverride!;
    }
    if (widget.hasFleetsOverride != null) {
      _hasFleets = widget.hasFleetsOverride!;
    }
    if (widget.hasDevicesOverride != null) {
      _hasDevices = widget.hasDevicesOverride!;
    }
    _fetchUserRole();
    _adminContext.addListener(_onContextChanged);
  }

  @override
  void dispose() {
    _adminContext.removeListener(_onContextChanged);
    super.dispose();
  }

  void _onContextChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchUserRole() async {
    final client = _supabase;
    if (client == null) return;
    final currentUserId = client.currentUser?.id;
    if (currentUserId != null) {
      if (widget.userRoleOverride == null) {
        final perfil = await client.getUsuarioPerfil(currentUserId);
        if (perfil != null && mounted) {
          setState(() {
            _userRole = perfil.role;
          });
        }
      }

      final role = widget.userRoleOverride ?? _userRole;
      if (role == 'gerente') {
        if (widget.hasFleetsOverride == null) {
          try {
            final frotas = await client.getFrotasByGerente(currentUserId);
            bool hasDevs = false;
            if (frotas.isNotEmpty) {
              final allDevices = await client.getDispositivos();
              final frotaIds = frotas.map((f) => f.id).toSet();
              hasDevs = allDevices.any((d) => frotaIds.contains(d.idFrota));
            }
            if (mounted) {
              setState(() {
                _hasFleets = frotas.isNotEmpty;
                _hasDevices = hasDevs;
              });
            }
          } catch (_) {}
        } else if (widget.hasDevicesOverride != null) {
          if (mounted) {
            setState(() {
              _hasDevices = widget.hasDevicesOverride!;
            });
          }
        }
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFC23147),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // Close Button
          Positioned(
            top: 16,
            left: 0,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFC23147),
                  borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
                ),
                child: const Icon(Icons.chevron_right, color: Colors.white),
              ),
            ),
          ),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Right Logo
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, right: 16),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 40,
                    width: 40,
                    color: const Color(0xFFC23147),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Menu Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: _userRole == 'admin' 
                      ? _buildAdminMenuItems(context)
                      : _buildDefaultMenuItems(context),
                ),
              ),
              
              // Footer Logout
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    onPressed: () async {
                      _adminContext.clearAll();
                      await _supabase?.signOut();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC23147),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.logout, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Sair', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Constrói o menu dinâmico contextual para o perfil Administrador (ADM).
  List<Widget> _buildAdminMenuItems(BuildContext context) {
    final hasFrota = _adminContext.hasFrota;
    final hasDevice = _adminContext.hasDevice;
    final frota = _adminContext.selectedFrota;
    final device = _adminContext.selectedDevice;

    return [
      // Banner de Contexto Atual
      if (!hasFrota) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC8E569), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFFC23147)),
                  SizedBox(width: 6),
                  Text(
                    'Nenhuma frota selecionada',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC23147),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Selecione uma frota para habilitar as opções contextuais.',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ] else if (hasDevice) ...[
        // Contexto de Veículo
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC8E569), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_car, size: 16, color: Color(0xFFC23147)),
                  const SizedBox(width: 6),
                  const Text(
                    'VEÍCULO SELECIONADO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFC23147),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _adminContext.clearVehicle();
                      Navigator.pushNamed(context, '/dashboard-frota', arguments: frota);
                    },
                    child: const Text(
                      'Frota >',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _adminContext.currentDeviceName ?? 'Veículo',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              if (_adminContext.currentFrotaName != null)
                Text(
                  'Frota: ${_adminContext.currentFrotaName}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ] else ...[
        // Contexto de Frota
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC8E569), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.local_shipping, size: 20, color: Color(0xFFC23147)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FROTA SELECIONADA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFC23147),
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      _adminContext.currentFrotaName ?? 'Frota',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/listar-frotas');
                },
                child: const Text(
                  'Trocar',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],

      // --- NAVEGAÇÃO CONTEXTUAL ---
      if (hasDevice) ...[
        _buildSectionHeader('VEÍCULO ATUAL'),
        MenuListItem(
          icon: Icons.notification_important_outlined,
          title: 'Alertas do veículo',
          routeName: '/alertas-veiculo',
          routeArguments: device,
          isEnabled: true,
        ),
        MenuListItem(
          icon: Icons.manage_history_outlined,
          title: 'Histórico do veículo',
          routeName: '/historico-veiculo',
          routeArguments: device,
          isEnabled: true,
        ),
        MenuListItem(
          icon: Icons.assessment_outlined,
          title: 'Relatório do veículo',
          routeName: '/relatorios-veiculo',
          routeArguments: device,
          isEnabled: true,
        ),
        MenuListItem(
          icon: Icons.location_on_outlined,
          title: 'GPS — Veículo',
          routeName: '/gps',
          routeArguments: device,
          isEnabled: true,
        ),

        const SizedBox(height: 8),
        _buildSectionHeader('FROTA DE ORIGEM'),
        MenuListItem(
          icon: Icons.directions_car_outlined,
          title: 'Veículos da frota',
          onTapAction: () {
            _adminContext.clearVehicle();
            Navigator.pushNamed(context, '/listar-dispositivos', arguments: frota);
          },
          isEnabled: true,
        ),
      ] else if (hasFrota) ...[
        _buildSectionHeader('FROTA ATUAL'),
        MenuListItem(
          icon: Icons.directions_car_outlined,
          title: 'Veículos da frota',
          routeName: '/listar-dispositivos',
          routeArguments: frota,
          isEnabled: true,
        ),
        MenuListItem(
          icon: Icons.notifications_none,
          title: 'Alertas da frota',
          routeName: '/alertas-frota',
          routeArguments: frota,
          isEnabled: true,
        ),
        MenuListItem(
          icon: Icons.history,
          title: 'Histórico da frota',
          routeName: '/historico-frota',
          routeArguments: frota,
          isEnabled: true,
        ),
        MenuListItem(
          icon: Icons.description_outlined,
          title: 'Relatório da frota',
          routeName: '/relatorios-frota',
          routeArguments: frota,
          isEnabled: true,
        ),
        const MenuListItem(
          icon: Icons.location_on_outlined,
          title: 'GPS — Frota',
          isEnabled: false,
          disabledReason: 'Indisponível',
        ),
      ] else ...[
        // Sem frota selecionada: opções contextuais desabilitadas
        _buildSectionHeader('NAVEGAÇÃO CONTEXTUAL'),
        const MenuListItem(
          icon: Icons.directions_car_outlined,
          title: 'Veículos da frota',
          isEnabled: false,
          disabledReason: 'Requer frota',
        ),
        const MenuListItem(
          icon: Icons.notifications_none,
          title: 'Alertas',
          isEnabled: false,
          disabledReason: 'Requer frota',
        ),
        const MenuListItem(
          icon: Icons.history,
          title: 'Histórico',
          isEnabled: false,
          disabledReason: 'Requer frota',
        ),
        const MenuListItem(
          icon: Icons.description_outlined,
          title: 'Relatórios',
          isEnabled: false,
          disabledReason: 'Requer frota',
        ),
        const MenuListItem(
          icon: Icons.location_on_outlined,
          title: 'GPS',
          isEnabled: false,
          disabledReason: 'Indisponível',
        ),
      ],

      // --- GERENCIAMENTO GERAL ---
      const SizedBox(height: 12),
      _buildSectionHeader('GERENCIAMENTO'),
      const MenuListItem(
        icon: Icons.fire_truck_outlined,
        title: 'Frotas (Seleção)',
        routeName: '/listar-frotas',
        isEnabled: true,
      ),
      const MenuListItem(
        icon: Icons.add_business_outlined,
        title: 'Criar frota',
        routeName: '/criar-frota',
        isEnabled: true,
      ),
      const MenuListItem(
        icon: Icons.devices_other_outlined,
        title: 'Listar dispositivos',
        routeName: '/listar-dispositivos',
        isEnabled: true,
      ),
      const MenuListItem(
        icon: Icons.add_box_outlined,
        title: 'Cadastrar dispositivo',
        routeName: '/cadastrar-dispositivo',
        isEnabled: true,
      ),
      const MenuListItem(
        icon: Icons.people_alt_outlined,
        title: 'Listar operadores',
        routeName: '/listar-operadores',
        isEnabled: true,
      ),
      const MenuListItem(
        icon: Icons.badge_outlined,
        title: 'Listar gerentes',
        routeName: '/listar-gerentes',
        isEnabled: true,
      ),
      const MenuListItem(
        icon: Icons.person_add_alt_1_outlined,
        title: 'Cadastrar funcionário',
        routeName: '/cadastrar-funcionario',
        isEnabled: true,
      ),

      // --- CONTA ---
      const SizedBox(height: 12),
      _buildSectionHeader('CONTA'),
      const MenuListItem(
        icon: Icons.person_outline,
        title: 'Perfil',
        routeName: '/perfil',
        isEnabled: true,
      ),
      const SizedBox(height: 16),
    ];
  }

  /// Menu padrão para perfis não-admin (gerente, operador). Mantido inalterado conforme escopo.
  List<Widget> _buildDefaultMenuItems(BuildContext context) {
    return [
      if (_userRole == 'gerente') ...[
        if (!_hasFleets) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC8E569), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.info_outline, size: 16, color: Color(0xFFC23147)),
                    SizedBox(width: 6),
                    Text(
                      'Nenhuma frota atribuída',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC23147),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'As opções que dependem de frota estão indisponíveis.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ] else if (!_hasDevices) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC8E569), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.info_outline, size: 16, color: Color(0xFFC23147)),
                    SizedBox(width: 6),
                    Text(
                      'Nenhum dispositivo cadastrado',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC23147),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'As opções que dependem de dispositivo estão indisponíveis.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        _buildSectionHeader('GERENCIAMENTO'),
        MenuListItem(
          icon: Icons.devices_other_outlined,
          title: 'Listar dispositivos',
          routeName: '/listar-dispositivos',
          isEnabled: _hasFleets && _hasDevices,
          disabledReason: !_hasFleets ? 'Requer frota' : 'Requer dispositivo',
          disabledMessage: !_hasFleets
              ? 'Você não possui nenhuma frota atribuída para acessar esta opção.'
              : 'Sua frota não possui nenhum dispositivo cadastrado para acessar esta opção.',
        ),
        MenuListItem(
          icon: Icons.people_alt_outlined,
          title: 'Listar operadores',
          routeName: '/listar-operadores',
          isEnabled: _hasFleets && _hasDevices,
          disabledReason: !_hasFleets ? 'Requer frota' : 'Requer dispositivo',
          disabledMessage: !_hasFleets
              ? 'Você não possui nenhuma frota atribuída para acessar esta opção.'
              : 'Sua frota não possui nenhum dispositivo cadastrado para acessar esta opção.',
        ),

        const SizedBox(height: 12),
        _buildSectionHeader('ALERTAS'),
        MenuListItem(
          icon: Icons.notifications_none,
          title: 'Alertas — Frota',
          routeName: '/alertas-frota',
          isEnabled: _hasFleets && _hasDevices,
          disabledReason: !_hasFleets ? 'Requer frota' : 'Requer dispositivo',
          disabledMessage: !_hasFleets
              ? 'Você não possui nenhuma frota atribuída para acessar esta opção.'
              : 'Sua frota não possui nenhum dispositivo cadastrado para acessar esta opção.',
        ),
        MenuListItem(
          icon: Icons.notification_important_outlined,
          title: 'Alertas — Veículo',
          routeName: '/alertas-veiculo',
          isEnabled: _hasFleets && _hasDevices,
          disabledReason: !_hasFleets ? 'Requer frota' : 'Requer dispositivo',
          disabledMessage: !_hasFleets
              ? 'Você não possui nenhuma frota atribuída para acessar esta opção.'
              : 'Sua frota não possui nenhum dispositivo cadastrado para acessar esta opção.',
        ),

        const SizedBox(height: 12),
        _buildSectionHeader('LOCALIZAÇÃO'),
        MenuListItem(
          icon: Icons.location_on_outlined,
          title: 'GPS — Veículo',
          routeName: '/gps',
          isEnabled: _hasFleets && _hasDevices,
          disabledReason: !_hasFleets ? 'Requer frota' : 'Requer dispositivo',
          disabledMessage: !_hasFleets
              ? 'Você não possui nenhuma frota atribuída para acessar esta opção.'
              : 'Sua frota não possui nenhum dispositivo cadastrado para acessar esta opção.',
        ),

        const SizedBox(height: 12),
        _buildSectionHeader('HISTÓRICO'),
        MenuListItem(
          icon: Icons.history,
          title: 'Histórico — Frota',
          routeName: '/historico-frota',
          isEnabled: _hasFleets && _hasDevices,
          disabledReason: !_hasFleets ? 'Requer frota' : 'Requer dispositivo',
          disabledMessage: !_hasFleets
              ? 'Você não possui nenhuma frota atribuída para acessar esta opção.'
              : 'Sua frota não possui nenhum dispositivo cadastrado para acessar esta opção.',
        ),
        MenuListItem(
          icon: Icons.manage_history_outlined,
          title: 'Histórico — Veículo',
          routeName: '/historico-veiculo',
          isEnabled: _hasFleets && _hasDevices,
          disabledReason: !_hasFleets ? 'Requer frota' : 'Requer dispositivo',
          disabledMessage: !_hasFleets
              ? 'Você não possui nenhuma frota atribuída para acessar esta opção.'
              : 'Sua frota não possui nenhum dispositivo cadastrado para acessar esta opção.',
        ),

        const SizedBox(height: 12),
        _buildSectionHeader('RELATÓRIOS'),
        MenuListItem(
          icon: Icons.description_outlined,
          title: 'Relatório — Frota',
          routeName: '/relatorios-frota',
          isEnabled: _hasFleets && _hasDevices,
          disabledReason: !_hasFleets ? 'Requer frota' : 'Requer dispositivo',
          disabledMessage: !_hasFleets
              ? 'Você não possui nenhuma frota atribuída para acessar esta opção.'
              : 'Sua frota não possui nenhum dispositivo cadastrado para acessar esta opção.',
        ),
        MenuListItem(
          icon: Icons.assessment_outlined,
          title: 'Relatório — Veículo',
          routeName: '/relatorios-veiculo',
          isEnabled: _hasFleets && _hasDevices,
          disabledReason: !_hasFleets ? 'Requer frota' : 'Requer dispositivo',
          disabledMessage: !_hasFleets
              ? 'Você não possui nenhuma frota atribuída para acessar esta opção.'
              : 'Sua frota não possui nenhum dispositivo cadastrado para acessar esta opção.',
        ),
      ] else if (_userRole == 'operador') ...[
        _buildSectionHeader('ALERTAS'),
        const MenuListItem(
          icon: Icons.notification_important_outlined,
          title: 'Alertas — Veículo',
          routeName: '/alertas-veiculo',
        ),

        const SizedBox(height: 12),
        _buildSectionHeader('LOCALIZAÇÃO'),
        const MenuListItem(
          icon: Icons.location_on_outlined,
          title: 'GPS — Veículo',
          routeName: '/gps',
        ),

        const SizedBox(height: 12),
        _buildSectionHeader('HISTÓRICO'),
        const MenuListItem(
          icon: Icons.manage_history_outlined,
          title: 'Histórico — Veículo',
          routeName: '/historico-veiculo',
        ),

        const SizedBox(height: 12),
        _buildSectionHeader('RELATÓRIOS'),
        const MenuListItem(
          icon: Icons.assessment_outlined,
          title: 'Relatório — Veículo',
          routeName: '/relatorios-veiculo',
        ),
      ],

      const SizedBox(height: 12),
      _buildSectionHeader('CONTA'),
      const MenuListItem(
        icon: Icons.person_outline,
        title: 'Perfil',
        routeName: '/perfil',
      ),
      if (_userRole == 'operador')
        MenuListItem(
          icon: Icons.stop_circle_outlined,
          title: 'Parar viagem',
          onTapAction: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Viagem parada com sucesso!')),
            );
          },
        ),
      const SizedBox(height: 16),
    ];
  }
}

class MenuListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? routeName;
  final Object? routeArguments;
  final VoidCallback? onTapAction;
  final bool isEnabled;
  final String? disabledReason;
  final String? disabledMessage;

  const MenuListItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.routeName,
    this.routeArguments,
    this.onTapAction,
    this.isEnabled = true,
    this.disabledReason,
    this.disabledMessage,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor = isEnabled ? Colors.black87 : Colors.black38;
    final Color iconColor = isEnabled ? const Color(0xFFC23147) : Colors.black26;

    return InkWell(
      onTap: isEnabled
          ? () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
              if (onTapAction != null) {
                onTapAction!();
              } else if (routeName != null) {
                Navigator.pushNamed(context, routeName!, arguments: routeArguments);
              }
            }
          : () {
              if (disabledReason != null || disabledMessage != null) {
                HapticFeedback.lightImpact();
                final String msg = disabledMessage ??
                    (disabledReason == 'Indisponível'
                        ? 'A funcionalidade de GPS está indisponível na sidebar no momento.'
                        : 'Selecione uma frota primeiro para acessar esta opção.');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      msg,
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: const Color(0xFFC23147),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                );
              }
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11.0),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: isEnabled ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: isEnabled ? Colors.black54 : Colors.black26,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            if (!isEnabled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 12, color: Colors.black38),
                    if (disabledReason != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        disabledReason!,
                        style: const TextStyle(fontSize: 10, color: Colors.black38),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
