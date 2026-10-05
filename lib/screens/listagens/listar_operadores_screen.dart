import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';
import '../../widgets/animated_components.dart';
import '../../widgets/watermark_background.dart';

class ListarOperadoresScreen extends StatefulWidget {
  final String title;
  
  const ListarOperadoresScreen({
    super.key, 
    this.title = 'Operadores',
  });

  @override
  State<ListarOperadoresScreen> createState() => _ListarOperadoresScreenState();
}

class _ListarOperadoresScreenState extends State<ListarOperadoresScreen> {
  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = true;
  List<UsuarioModel> _usuarios = [];
  Map<String, String> _infoMap = {};
  String _userRole = 'ADM';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final currentUserId = _supabase.currentUser?.id;
      if (currentUserId != null) {
        final perfil = await _supabase.getUsuarioPerfil(currentUserId);
        if (perfil != null) _userRole = perfil.cargo ?? 'ADM';
      }

      // Fetch all users manually from 'Usuarios' table
      // Supabase Auth users can't be fetched entirely by client unless using an RPC or service key. 
      // We will just query the public 'Usuarios' table.
      final response = await Supabase.instance.client.from('Usuarios').select();
      final allUsers = (response as List).map((e) => UsuarioModel.fromJson(e)).toList();

      final isGerente = widget.title == 'Gerentes';
      final filteredUsers = allUsers.where((u) => u.cargo?.toLowerCase() == (isGerente ? 'gerente' : 'operador')).toList();

      final frotas = await _supabase.getFrotas();
      final dispositivos = await _supabase.getDispositivos();

      Map<String, String> info = {};
      for (var u in filteredUsers) {
        if (isGerente) {
          final f = frotas.where((f) => f.idGerente == u.id).toList();
          info[u.id] = f.isNotEmpty ? f.map((x) => x.nome).join(', ') : 'Nenhuma';
        } else {
          final d = dispositivos.where((d) => d.idOperador == u.id).toList();
          info[u.id] = d.isNotEmpty ? d.map((x) => x.nomeDispositivo).join(', ') : 'Nenhum';
        }
      }

      if (mounted) {
        setState(() {
          _usuarios = filteredUsers;
          _infoMap = info;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar usuarios: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isGerente = widget.title == 'Gerentes';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF2E0),
      body: WatermarkBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 16.0, right: 16.0),
            child: Column(
              children: [
                // 1. CABEÇALHO
                Row(
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFC23147),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC23147),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _userRole.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Builder(
                      builder: (ctx) => GestureDetector(
                        onTap: () => CustomEndDrawer.showMenu(context),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 32,
                            height: 32,
                            color: const Color(0xFFC23147),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 2. LISTA DE COLABORADORES
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFFC23147),
                    onRefresh: () async {
                      HapticFeedback.lightImpact();
                      await _fetchData();
                    },
                    child: _isLoading
                        ? ListView.builder(
                            itemCount: 4,
                            itemBuilder: (context, index) => const Padding(
                              padding: EdgeInsets.only(bottom: 16.0, right: 12),
                              child: ShimmerEffect(
                                width: double.infinity,
                                height: 92,
                                borderRadius: 12,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 100),
                            itemCount: _usuarios.length,
                            itemBuilder: (context, index) {
                              final user = _usuarios[index];
                              final infoValue = _infoMap[user.id] ?? 'N/A';

                              return AnimatedListItem(
                                index: index,
                                child: Dismissible(
                                  key: Key(user.id),
                                  direction: DismissDirection.horizontal,
                                  confirmDismiss: (direction) async {
                                    HapticFeedback.mediumImpact();
                                    if (direction == DismissDirection.endToStart) {
                                      return await _showDeleteDialog(context, user);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Redirecionando para edição...'),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                        ),
                                      );
                                      return false;
                                    }
                                  },
                                  background: Container(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    margin: const EdgeInsets.only(bottom: 16, right: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8DB600),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.edit, color: Colors.white),
                                  ),
                                  secondaryBackground: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    margin: const EdgeInsets.only(bottom: 16, right: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFC23147),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.delete, color: Colors.white),
                                  ),
                                  child: ColabCard(
                                    user: user,
                                    infoLabel: isGerente ? 'Frota Responsável' : 'Veículo Associado',
                                    infoValue: infoValue,
                                    onDelete: () {
                                      HapticFeedback.mediumImpact();
                                      _showDeleteDialog(context, user);
                                    },
                                    onTap: () {},
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteDialog(BuildContext context, UsuarioModel user) {
    return showGeneralDialog<bool>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: 'Delete',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return Stack(
          children: [
            FadeTransition(
              opacity: animation,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                child: Container(color: const Color(0x33000000)),
              ),
            ),
            ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              child: AlertDialog(
                title: const Text('Excluir Funcionário'),
                content: Text('Tem certeza que deseja remover ${user.nome}?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, true);
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Removido com sucesso (simulado)', style: TextStyle(color: Colors.white)),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      );
                      _fetchData();
                    },
                    child: const Text('Excluir', style: TextStyle(color: Color(0xFFC23147))),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// 3. COMPONENTE REUTILIZÁVEL (ColabCard)
class ColabCard extends StatelessWidget {
  final UsuarioModel user;
  final String infoLabel;
  final String infoValue;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const ColabCard({
    super.key,
    required this.user,
    required this.infoLabel,
    required this.infoValue,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // Sombra difusa colorida
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Esquerda (Ícone Perfil)
          Hero(
            tag: 'user_icon_${user.id}',
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFC8E569),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.person_outline,
                color: Color(0xFF333333),
                size: 32,
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Centro (Expanded)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: 'user_title_${user.id}',
                  child: Material(
                    color: Colors.transparent,
                    child: Text(
                      user.nome ?? 'Sem Nome',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'CPF: ${user.cpf ?? 'N/A'}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Direita
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFC23147)),
                    onPressed: onDelete,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                infoLabel,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 10,
                ),
                textAlign: TextAlign.right,
              ),
              Text(
                infoValue.isEmpty ? 'Nenhum' : infoValue,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Material(
                color: const Color(0xFFC23147),
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      'Ver perfil',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
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
}
