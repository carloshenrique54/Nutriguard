/// Validações locais das telas de login e de cadastro público (admin), feitas
/// antes de chamar o Supabase. Mesmas regras do cadastro de funcionário.
class ValidacaoAuth {
  static final RegExp _email = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');

  static String _digitos(String v) => v.replaceAll(RegExp(r'\D'), '');

  /// Mensagem de erro do login, ou `null` se pode enviar.
  static String? login({required String email, required String senha}) {
    final e = email.trim();
    if (e.isEmpty && senha.isEmpty) return 'Informe seu e-mail e sua senha.';
    if (e.isEmpty) return 'Informe seu e-mail.';
    if (!_email.hasMatch(e)) return 'Informe um e-mail válido.';
    if (senha.isEmpty) return 'Informe sua senha.';
    return null;
  }

  /// Mensagem de erro do cadastro da empresa (admin), ou `null` se pode enviar.
  static String? cadastroAdmin({
    required String empresa,
    required String nome,
    required String email,
    required String senha,
    required String confirmaSenha,
    required String telefone,
    required String cpf,
  }) {
    if (empresa.trim().length < 2) return 'Informe o nome da empresa.';
    final n = nome.trim();
    if (n.isEmpty) return 'Informe seu nome.';
    if (n.length < 3) return 'O nome deve ter no mínimo 3 caracteres.';
    final e = email.trim();
    if (e.isEmpty) return 'Informe seu e-mail.';
    if (!_email.hasMatch(e)) return 'Informe um e-mail válido.';
    if (senha.isEmpty) return 'Defina uma senha de acesso.';
    if (senha.length < 6) return 'A senha deve conter no mínimo 6 caracteres.';
    if (confirmaSenha != senha) return 'As senhas não coincidem.';
    final tel = _digitos(telefone);
    if (tel.isEmpty) return 'Informe seu telefone.';
    if (tel.length < 10) return 'O telefone deve conter DDD e pelo menos 10 dígitos.';
    final c = _digitos(cpf);
    if (c.isEmpty) return 'Informe seu CPF.';
    if (c.length != 11) return 'O CPF deve conter exatamente 11 dígitos.';
    return null;
  }
}
