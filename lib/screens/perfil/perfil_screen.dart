import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../widgets/watermark_background.dart';
import '../../services/supabase_service.dart';
import '../../services/admin_context_service.dart';
import '../../models/models.dart';
import '../../widgets/confirmation_dialog.dart';

enum UserRole { adm, gerente, operador }

class PerfilScreen extends StatefulWidget {
  final UserRole? role;
  final UsuarioModel? usuario;

  const PerfilScreen({super.key, this.role, this.usuario});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final SupabaseService _supabase = SupabaseService();
  UsuarioModel? _perfil;
  bool _isLoading = true;
  String _errorMessage = '';
  List<FrotaModel> _minhasFrotas = [];
  List<DispositivoModel> _meusDispositivos = [];
  int _totalFrotas = 0;
  int _totalDispositivos = 0;
  int _totalGerentes = 0;
  int _totalOperadores = 0;
  bool _isLoadingAssociated = true;
  String _associatedErrorMessage = '';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.usuario != null) {
      _perfil = widget.usuario;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final arg = ModalRoute.of(context)?.settings.arguments;
      if (arg is UsuarioModel) {
        _perfil = arg;
        _loadProfile(initialUser: arg);
      } else if (arg is String) {
        _loadProfile(initialUserId: arg);
      } else if (widget.usuario != null) {
        _loadProfile(initialUser: widget.usuario);
      } else {
        _loadProfile();
      }
    }
  }

  Future<void> _loadProfile({UsuarioModel? initialUser, String? initialUserId}) async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      if (initialUser != null) {
        setState(() { _perfil = initialUser; });
        await _loadAssociatedData(initialUser);
        if (mounted) setState(() { _isLoading = false; });
        return;
      }
      final targetId = initialUserId ?? _supabase.currentUser?.id;
      if (targetId != null) {
        final perfil = await _supabase.getUsuarioPerfil(targetId);
        if (mounted) setState(() { _perfil = perfil; });
        if (perfil != null) {
          await _loadAssociatedData(perfil);
        }
      } else {
        if (mounted) setState(() { _errorMessage = 'Usuário não autenticado'; });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = 'Erro ao carregar perfil: $e'; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _loadAssociatedData(UsuarioModel perfil) async {
    setState(() { _isLoadingAssociated = true; _associatedErrorMessage = ''; });
    try {
      final isAdmin = perfil.role == 'admin' || (perfil.cargo?.toLowerCase() == 'admin');
      final isOperador = perfil.role == 'operador' || (perfil.cargo?.toLowerCase() == 'operador');

      if (isAdmin) {
        try {
          final frotas = await _supabase.getFrotas();
          final dispositivos = await _supabase.getDispositivos();
          final usuarios = await _supabase.getUsuarios();
          if (mounted) {
            setState(() {
              _totalFrotas = frotas.length;
              _totalDispositivos = dispositivos.length;
              _totalGerentes = usuarios.where((u) => u.cargo?.toLowerCase() == 'gerente' || u.role == 'gerente').length;
              _totalOperadores = usuarios.where((u) => u.cargo?.toLowerCase() == 'operador' || u.role == 'operador').length;
            });
          }
        } catch (e) {
          debugPrint('Aviso: dados estatísticos do admin não puderam ser carregados: $e');
        }
      } else if (isOperador) {
        final dispositivos = await _supabase.getDispositivosByOperador(perfil.id);
        if (mounted) setState(() { _meusDispositivos = dispositivos; });
      } else {
        final frotas = await _supabase.getFrotasByGerente(perfil.id);
        if (mounted) setState(() { _minhasFrotas = frotas; });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (perfil.role == 'operador' || perfil.cargo?.toLowerCase() == 'operador') {
            _associatedErrorMessage = 'Erro ao carregar dispositivo responsável: $e';
          } else {
            _associatedErrorMessage = 'Erro ao carregar frotas: $e';
          }
        });
      }
    } finally {
      if (mounted) setState(() { _isLoadingAssociated = false; });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() { _isLoading = true; });
      try {
        final bytes = await pickedFile.readAsBytes();
        final ext = pickedFile.name.split('.').last.toLowerCase() == 'png' ? 'png' : 'jpg';
        await _supabase.uploadProfilePicture(_perfil!.id, bytes, ext);
        await _loadProfile(); 
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto atualizada!')));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(SupabaseService.formatarErro(e), style: const TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFFC23147),
            ),
          );
        }
      } finally {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _editProfile() async {
    if (_perfil == null) return;
    final nameController = TextEditingController(text: _perfil!.nome);
    final phoneController = TextEditingController(text: _perfil!.telefone);
    
    await showDialog(context: context, barrierDismissible: false, builder: (context) {
      bool isSaving = false;
      return StatefulBuilder(builder: (context, setDialogState) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFFFFF2E0),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: isSaving 
                ? const SizedBox(height: 150, child: Center(child: CircularProgressIndicator(color: Color(0xFFC23147))))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Editar Perfil',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Nome completo',
                          labelStyle: const TextStyle(color: Color(0xFFC23147)),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFC23147), width: 2)),
                          prefixIcon: const Icon(Icons.person, color: Color(0xFFC23147)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: phoneController,
                        decoration: InputDecoration(
                          labelText: 'Telefone',
                          labelStyle: const TextStyle(color: Color(0xFFC23147)),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFC23147), width: 2)),
                          prefixIcon: const Icon(Icons.phone, color: Color(0xFFC23147)),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFC23147),
                                side: const BorderSide(color: Color(0xFFC23147)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (nameController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nome não pode ser vazio')));
                                  return;
                                }
                                setDialogState(() { isSaving = true; });
                                try {
                                  await _supabase.updateUsuario(_perfil!.id, {
                                    'nome': nameController.text.trim(),
                                    'telefone': phoneController.text.trim(),
                                  });
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    _loadProfile();
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil atualizado!')));
                                  }
                                } catch (e) {
                                  setDialogState(() { isSaving = false; });
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(SupabaseService.formatarErro(e), style: const TextStyle(color: Colors.white)),
                                        backgroundColor: const Color(0xFFC23147),
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC23147),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Salvar', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF2E0),
      body: WatermarkBackground(
        child: SafeArea(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                      ElevatedButton(onPressed: _loadProfile, child: const Text('Tentar Novamente'))
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildProfileCard(),
                      const SizedBox(height: 24),
                      _buildActionButtons(),
                      const SizedBox(height: 24),
                      _buildListSection(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String roleText = 'Operador';
    final viewerRole = SupabaseService.currentCachedPerfil?.role.toLowerCase()
        ?? _supabase.currentUser?.userMetadata?['cargo']?.toString().toLowerCase()
        ?? (widget.role == UserRole.adm ? 'admin' : (widget.role == UserRole.gerente ? 'gerente' : null));

    final effectiveRole = viewerRole ?? _perfil?.role.toLowerCase() ?? '';
    if (effectiveRole == 'admin' || effectiveRole == 'adm') {
      roleText = 'ADM';
    } else if (effectiveRole == 'gerente') {
      roleText = 'Gerente';
    } else {
      roleText = 'Operador';
    }

    final bool canPop = Navigator.canPop(context);
    final bool isOwner = _perfil != null && _perfil!.id == _supabase.currentUser?.id;

    return Row(
      children: [
        if (canPop) ...[
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFFC23147)),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          !isOwner ? 'Perfil do Funcionário' : 'Perfil',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFC23147),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFC23147),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            roleText,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const Spacer(),
        Builder(
          builder: (context) => GestureDetector(
            onTap: () => CustomEndDrawer.showMenu(context),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Image.asset(
                'assets/images/logo.png',
                errorBuilder: (ctx, error, stackTrace) =>
                    const Icon(Icons.local_shipping_outlined, color: Color(0xFFC23147), size: 32),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    final bool isOwner = _perfil != null && _perfil!.id == _supabase.currentUser?.id;
    final bool isOperador = _perfil?.role == 'operador' || (_perfil?.cargo?.toLowerCase() == 'operador');

    final String cargoNome = (_perfil?.cargo != null && _perfil!.cargo!.isNotEmpty)
        ? _perfil!.cargo!
        : (_perfil?.role == 'admin' ? 'Administrador' : (_perfil?.role == 'gerente' ? 'Gerente' : 'Operador'));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFC23147),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Seção Superior: Avatar + Nome + Cargo + Contato
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: isOwner ? _pickAndUploadImage : null,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white,
                      backgroundImage: _perfil?.fotoUrl != null ? NetworkImage(_perfil!.fotoUrl!) : null,
                      child: _perfil?.fotoUrl == null
                          ? const Icon(Icons.person_outline, size: 44, color: Colors.grey)
                          : null,
                    ),
                    if (isOwner)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, size: 14, color: Color(0xFFC23147)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _perfil?.nome ?? 'Sem nome',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8E569),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        cargoNome.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFC23147),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.mail_outline, size: 13, color: Colors.white70),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _perfil?.email ?? 'Sem email',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (_perfil?.telefone != null && _perfil!.telefone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 13, color: Colors.white70),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _perfil!.telefone!,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Seção Inferior: Cartão Branco de Dados e Documentos
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildDocItem(
                        icon: Icons.badge_outlined,
                        label: 'Documento',
                        value: 'CPF: ${_perfil?.cpf ?? 'Não informado'}',
                      ),
                    ),
                    if (isOperador) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDocItem(
                          icon: Icons.cake_outlined,
                          label: 'Nascimento',
                          value: _perfil?.dataNascimento != null
                              ? 'Aniversário: ${_formatDate(_perfil!.dataNascimento!)}'
                              : 'Aniversário: Não informado',
                        ),
                      ),
                    ],
                  ],
                ),
                if (isOperador) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: Color(0xFFF0F0F0), thickness: 1),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildDocItem(
                          icon: Icons.drive_eta_outlined,
                          label: 'Habilitação',
                          value: (_perfil?.numeroCnh != null && _perfil!.numeroCnh!.isNotEmpty)
                              ? 'CNH: ${_perfil!.numeroCnh!}'
                              : 'CNH: Não informada',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDocItem(
                          icon: Icons.event_available_outlined,
                          label: 'Vencimento',
                          value: _perfil?.validadeCnh != null
                              ? 'Validade CNH: ${_formatDate(_perfil!.validadeCnh!)}'
                              : 'Validade CNH: Não informada',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFFC23147)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC23147),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Future<void> _confirmDeleteUser() async {
    if (_perfil == null) return;
    final confirmed = await showDeleteConfirmationModal(
      context: context,
      title: 'Excluir Funcionário',
      itemName: _perfil!.nome ?? 'Funcionário',
      itemDetail: 'CPF: ${_perfil!.cpf ?? "Não informado"} • Cargo: ${_perfil!.cargo ?? _perfil!.role}',
      itemIcon: Icons.person_outline,
    );

    if (confirmed == true && mounted) {
      try {
        await _supabase.deleteUsuario(_perfil!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Funcionário "${_perfil!.nome ?? "Funcionário"}" removido com sucesso!', style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          );
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacementNamed(context, '/dashboard-frota');
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir funcionário: $e', style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          );
        }
      }
    }
  }

  Widget _buildActionButtons() {
    final bool isOwner = _perfil != null && _perfil!.id == _supabase.currentUser?.id;

    if (!isOwner) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacementNamed(context, '/dashboard-frota');
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC23147),
                side: const BorderSide(color: Color(0xFFC23147), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.arrow_back, color: Color(0xFFC23147)),
              label: const Text('Voltar para a listagem', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirmDeleteUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC23147),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
              label: const Text('Excluir funcionário', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    if (widget.role == UserRole.operador || _perfil?.role == 'operador' || _perfil?.cargo?.toLowerCase() == 'operador') {
      if (_meusDispositivos.isNotEmpty) {
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _editProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC23147),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Editar perfil', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  final dev = _meusDispositivos.first;
                  AdminContextService().setDevice(dev);
                  Navigator.pushNamed(context, '/dashboard-veiculo', arguments: dev);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC23147),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.directions_car, color: Colors.white, size: 18),
                label: const Text('Meu veículo', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        );
      }
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _editProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC23147),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Editar perfil', style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _editProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC23147),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Editar perfil', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/listar-frotas');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC23147),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Ver frotas', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildListSection() {
    final isAdmin = _perfil?.role == 'admin' || (_perfil?.cargo?.toLowerCase() == 'admin');
    final isOperador = _perfil?.role == 'operador' || (_perfil?.cargo?.toLowerCase() == 'operador');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFC8E569),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isOperador)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dispositivo responsável >',
                  style: TextStyle(color: Color(0xFFC23147), fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (_meusDispositivos.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      final dev = _meusDispositivos.first;
                      AdminContextService().setDevice(dev);
                      Navigator.pushNamed(context, '/historico-veiculo', arguments: dev);
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.history, size: 16, color: Color(0xFFC23147)),
                        SizedBox(width: 4),
                        Text(
                          'Histórico de viagens',
                          style: TextStyle(
                            color: Color(0xFFC23147),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            )
          else if (isAdmin)
            const Text(
              'Gestão da Operação >',
              style: TextStyle(color: Color(0xFFC23147), fontSize: 16, fontWeight: FontWeight.bold),
            )
          else
            const Text(
              'Frota responsável >',
              style: TextStyle(color: Color(0xFFC23147), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 16),
          if (_isLoadingAssociated)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Color(0xFFC23147))))
          else if (_associatedErrorMessage.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(_associatedErrorMessage, style: const TextStyle(color: Colors.red)),
                    TextButton(onPressed: () => _loadAssociatedData(_perfil!), child: const Text('Tentar novamente')),
                  ],
                ),
              ),
            )
          else if (isAdmin)
            _buildAdminDashboard()
          else if (isOperador)
            if (_meusDispositivos.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Nenhum dispositivo ou veículo associado a este operador.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _meusDispositivos.length,
                itemBuilder: (context, index) {
                  final device = _meusDispositivos[index];
                  return _buildDeviceCard(device);
                },
              )
          else
            if (_minhasFrotas.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Nenhuma frota atribuída a este usuário.', style: TextStyle(color: Colors.black54)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _minhasFrotas.length,
                itemBuilder: (context, index) {
                  final frota = _minhasFrotas[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.directions_car, color: Colors.black54, size: 30),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                frota.nome ?? 'Frota sem nome',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                'ID: ${frota.id.length > 8 ? '${frota.id.substring(0, 8)}...' : frota.id}',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }

  Widget _buildAdminDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAdminStatCard(
          icon: Icons.fire_truck_outlined,
          iconBgColor: const Color(0xFFE8F5E9),
          iconColor: const Color(0xFF2E7D32),
          title: 'FROTAS ATIVAS',
          value: '$_totalFrotas ${_totalFrotas == 1 ? 'frota cadastrada' : 'frotas cadastradas'}',
          subtitle: 'Gerencie regiões e distribuição de frotas',
          onTap: () => Navigator.pushNamed(context, '/listar-frotas'),
        ),
        _buildAdminStatCard(
          icon: Icons.sensors_outlined,
          iconBgColor: const Color(0xFFE3F2FD),
          iconColor: const Color(0xFF1565C0),
          title: 'VEÍCULOS & SENSORES IoT',
          value: '$_totalDispositivos ${_totalDispositivos == 1 ? 'dispositivo conectado' : 'dispositivos conectados'}',
          subtitle: 'Monitoramento térmico, umidade e impacto',
          onTap: () => Navigator.pushNamed(context, '/listar-dispositivos'),
        ),
        _buildAdminStatCard(
          icon: Icons.people_outline,
          iconBgColor: const Color(0xFFFFF3E0),
          iconColor: const Color(0xFFE65100),
          title: 'EQUIPE DA OPERAÇÃO',
          value: '$_totalGerentes ${_totalGerentes == 1 ? 'gerente' : 'gerentes'} • $_totalOperadores ${_totalOperadores == 1 ? 'operador' : 'operadores'}',
          subtitle: 'Controle de acessos, motoristas e gestores',
          onTap: () => Navigator.pushNamed(context, '/listar-operadores'),
        ),
        _buildAdminQuickActions(),
      ],
    );
  }

  Widget _buildAdminStatCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFFC23147)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Text(
          'ATALHOS DE CADASTRO',
          style: TextStyle(
            color: const Color(0xFFC23147).withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                label: '+ Frota',
                icon: Icons.add_business_outlined,
                onTap: () => Navigator.pushNamed(context, '/criar-frota'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickActionButton(
                label: '+ Veículo',
                icon: Icons.add_box_outlined,
                onTap: () => Navigator.pushNamed(context, '/cadastrar-dispositivo'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickActionButton(
                label: '+ Equipe',
                icon: Icons.person_add_alt_outlined,
                onTap: () => Navigator.pushNamed(context, '/cadastrar-funcionario'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: const Color(0xFFC23147)),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceCard(DispositivoModel device) {
    final vehicleTitle = (device.modeloVeiculo != null && device.modeloVeiculo!.isNotEmpty)
        ? device.modeloVeiculo!
        : (device.nomeDispositivo ?? 'Veículo IoT');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            AdminContextService().setDevice(device);
            Navigator.pushNamed(context, '/dashboard-veiculo', arguments: device);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_shipping, color: Colors.black54, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicleTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (device.nomeDispositivo != null && device.nomeDispositivo != vehicleTitle)
                        Text(
                          device.nomeDispositivo!,
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      if (device.placaVeiculo != null && device.placaVeiculo!.isNotEmpty)
                        Text(
                          'Placa: ${device.placaVeiculo}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      if (device.numeroSerie != null && device.numeroSerie!.isNotEmpty)
                        Text(
                          'Série: ${device.numeroSerie}',
                          style: const TextStyle(fontSize: 11, color: Colors.black45),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.history, color: Color(0xFFC23147)),
                  tooltip: 'Histórico de viagens',
                  onPressed: () {
                    AdminContextService().setDevice(device);
                    Navigator.pushNamed(context, '/historico-veiculo', arguments: device);
                  },
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFC23147)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
