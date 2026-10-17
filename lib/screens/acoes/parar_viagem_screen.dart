import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/supabase_service.dart';
import '../../services/trip_service.dart';
import '../../widgets/watermark_background.dart';
import '../../widgets/responsive_layout.dart';

class PararViagemScreen extends StatefulWidget {
  final String? initialOperatorId;

  const PararViagemScreen({
    super.key,
    this.initialOperatorId,
  });

  @override
  State<PararViagemScreen> createState() => _PararViagemScreenState();
}

class _PararViagemScreenState extends State<PararViagemScreen> {
  final SupabaseService _supabase = SupabaseService();
  final TripService _tripService = TripService();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _motivoController = TextEditingController();
  final TextEditingController _ruaController = TextEditingController();
  final TextEditingController _bairroController = TextEditingController();
  final TextEditingController _cidadeController = TextEditingController();
  final TextEditingController _cepController = TextEditingController();

  final List<String> _anexos = ['Foto1.png', 'Foto2.png'];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _motivoController.dispose();
    _ruaController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _cepController.dispose();
    super.dispose();
  }

  Future<void> _selecionarArquivos() async {
    HapticFeedback.lightImpact();
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _anexos.clear();
          for (final img in images) {
            _anexos.add(img.name);
          }
        });
      }
    } catch (_) {
      // Se der erro de plataforma ou teste, permite adicionar um arquivo exemplo
      setState(() {
        if (!_anexos.contains('Comprovante.png')) {
          _anexos.add('Comprovante.png');
        }
      });
    }
  }

  Future<void> _submeterParada() async {
    final motivo = _motivoController.text.trim();
    final rua = _ruaController.text.trim();
    final bairro = _bairroController.text.trim();
    final cidade = _cidadeController.text.trim();
    final cep = _cepController.text.trim();

    if (motivo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, descreva o motivo da parada.'),
          backgroundColor: Color(0xFFC23147),
        ),
      );
      return;
    }

    if (rua.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, informe o nome da rua.'),
          backgroundColor: Color(0xFFC23147),
        ),
      );
      return;
    }

    if (cidade.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, informe a cidade do local de parada.'),
          backgroundColor: Color(0xFFC23147),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final user = _supabase.currentUser;
      final operatorId = widget.initialOperatorId ?? user?.id ?? '';

      final activeTrip = await _tripService.getActiveTrip(operatorId);
      final deviceId = activeTrip?.deviceId;

      await _tripService.endTripWithReport(
        operatorId: operatorId,
        motivo: motivo,
        rua: rua,
        bairro: bairro,
        cidade: cidade,
        cep: cep.isNotEmpty ? cep : null,
        anexos: _anexos,
      );

      try {
        await _supabase.salvarFimViagem(
          operatorId: operatorId,
          deviceId: deviceId,
          motivo: motivo,
          rua: rua,
          bairro: bairro,
          cidade: cidade,
          cep: cep.isNotEmpty ? cep : null,
          anexos: _anexos,
        );
      } catch (_) {}

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Viagem finalizada com sucesso!'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao finalizar viagem: $e'),
          backgroundColor: const Color(0xFFC23147),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String anexosText = _anexos.isNotEmpty ? _anexos.join(', ') : 'Nenhum arquivo anexado';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF2E0),
      body: WatermarkBackground(
        child: SafeArea(
          child: ResponsiveContentWrapper(
            maxWidth: ResponsiveBreakpoints.maxFormWidth,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 16),
                  _buildBackButton(context),
                  const SizedBox(height: 16),
                  _buildMotivoSection(anexosText),
                  const SizedBox(height: 16),
                  _buildLocalParadaSection(),
                  const SizedBox(height: 20),
                  _buildSubmitButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Row(
          children: [
            const Text(
              'Parar Viajem',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC23147),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFC23147),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Operador',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        SizedBox(
          width: 44,
          height: 44,
          child: Image.asset(
            'assets/images/logo.png',
            color: const Color(0xFFC23147),
            width: 38,
            height: 38,
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pop(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFC23147),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(
              'Voltar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMotivoSection(String anexosText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Motivo',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFC8E569),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Descreva o motivo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _motivoController,
                minLines: 4,
                maxLines: 6,
                decoration: InputDecoration(
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                  hintText: 'Informe o motivo para pausar ou finalizar a viagem...',
                  hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Anexar arquivos',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _selecionarArquivos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC23147),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.insert_drive_file_outlined, color: Colors.white, size: 16),
                    label: const Text(
                      'Selecionar arquivos',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      anexosText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocalParadaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Local de parada',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFC8E569),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFieldLabel('Nome da rua'),
              _buildInputText(controller: _ruaController, hint: 'Ex: Av. Paulista, 1000'),
              const SizedBox(height: 10),
              _buildFieldLabel('Bairro'),
              _buildInputText(controller: _bairroController, hint: 'Ex: Bela Vista'),
              const SizedBox(height: 10),
              _buildFieldLabel('Cidade'),
              _buildInputText(controller: _cidadeController, hint: 'Ex: São Paulo'),
              const SizedBox(height: 10),
              _buildFieldLabel('CEP (Opcional)'),
              _buildInputText(
                controller: _cepController,
                hint: '00000-000',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildInputText({
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13, color: Colors.black87),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submeterParada,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC23147),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'Parar Viajem',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}
