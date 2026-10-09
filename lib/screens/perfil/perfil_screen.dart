import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../widgets/watermark_background.dart';
import '../../services/supabase_service.dart';
import '../../models/models.dart';

enum UserRole { adm, gerente, operador }

class PerfilScreen extends StatefulWidget {
  final UserRole role;

  const PerfilScreen({super.key, required this.role});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final SupabaseService _supabase = SupabaseService();
  UsuarioModel? _perfil;
  bool _isLoading = true;
  String _errorMessage = '';
  List<FrotaModel> _minhasFrotas = [];
  bool _isLoadingFrotas = true;
  String _frotasErrorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final user = _supabase.currentUser;
      if (user != null) {
        final perfil = await _supabase.getUsuarioPerfil(user.id);
        setState(() { _perfil = perfil; });
        if (perfil != null) {
          _loadFrotas(perfil);
        }
      } else {
        setState(() { _errorMessage = 'Usuário não autenticado'; });
      }
    } catch (e) {
      setState(() { _errorMessage = 'Erro ao carregar perfil: $e'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _loadFrotas(UsuarioModel perfil) async {
    setState(() { _isLoadingFrotas = true; _frotasErrorMessage = ''; });
    try {
      List<FrotaModel> frotas = [];
      if (perfil.role == 'admin' || perfil.role == 'gerente') {
        frotas = await _supabase.getFrotasByGerente(perfil.id);
      } else if (perfil.role == 'operador') {
        frotas = await _supabase.getFrotasByOperador(perfil.id);
      }
      if (mounted) setState(() { _minhasFrotas = frotas; });
    } catch (e) {
      if (mounted) setState(() { _frotasErrorMessage = 'Erro ao carregar frotas: $e'; });
    } finally {
      if (mounted) setState(() { _isLoadingFrotas = false; });
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar foto: $e')));
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
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
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
      extendBody: true,
      backgroundColor: const Color(0xFFFFF2E0),
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: -1),
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
    if (widget.role == UserRole.adm) roleText = 'ADM';
    if (widget.role == UserRole.gerente) roleText = 'Gerente';

    return Row(
      children: [
        const Text(
          'Perfil',
          style: TextStyle(
            fontSize: 28,
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFC23147),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickAndUploadImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  backgroundImage: _perfil?.fotoUrl != null ? NetworkImage(_perfil!.fotoUrl!) : null,
                  child: _perfil?.fotoUrl == null ? const Icon(Icons.person_outline, size: 50, color: Colors.grey) : null,
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, size: 16, color: Color(0xFFC23147)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sobre',
                    style: TextStyle(
                      color: Color(0xFFC23147),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildProfileInfoRow(Icons.person, _perfil?.nome ?? 'Sem nome'),
                  _buildProfileInfoRow(Icons.mail, _perfil?.email ?? 'Sem email'),
                  _buildProfileInfoRow(Icons.phone, _perfil?.telefone ?? 'Sem telefone'),
                  if (_perfil?.cargo != null) _buildProfileInfoRow(Icons.work, _perfil!.cargo!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFFE56B7A)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFFE56B7A), fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (widget.role == UserRole.operador) {
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
              onPressed: () {},
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFC8E569),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Minhas frotas >',
            style: TextStyle(color: Color(0xFFC23147), fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_isLoadingFrotas)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Color(0xFFC23147))))
          else if (_frotasErrorMessage.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(_frotasErrorMessage, style: const TextStyle(color: Colors.red)),
                    TextButton(onPressed: () => _loadFrotas(_perfil!), child: const Text('Tentar novamente')),
                  ],
                ),
              ),
            )
          else if (_minhasFrotas.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Nenhuma frota atribuída a este usuário.', style: TextStyle(color: Colors.black54)),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 100,
                  margin: const EdgeInsets.only(right: 12, top: 4),
                  decoration: BoxDecoration(
                    color: Colors.white54,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC23147),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
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
                ),
              ],
            ),
        ],
      ),
    );
  }
}
