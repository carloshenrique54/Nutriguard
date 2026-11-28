/// Tela para onde um usuário já logado volta quando abre uma rota que o seu
/// perfil não pode acessar (em vez de cair na tela de login ainda logado).
class RotaInicial {
  static String paraPapel(String? role) {
    switch (role) {
      case 'admin':
      case 'gerente':
        return '/dashboard-frota';
      case 'operador':
        return '/dashboard-veiculo';
      default:
        return '/login';
    }
  }
}
