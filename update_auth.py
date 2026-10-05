import os

base_dir = r"c:\Users\46612581859\Desktop\nutriguard sem banco\nutriguard1\lib"

files = {
    "widgets/auth_components.dart": """import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final IconData prefixIcon;
  final String hintText;
  final bool obscureText;

  const CustomTextField({
    super.key,
    required this.prefixIcon,
    required this.hintText,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        obscureText: obscureText,
        decoration: InputDecoration(
          prefixIcon: Icon(prefixIcon, color: Colors.grey),
          hintText: hintText,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class PrimaryGradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const PrimaryGradientButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 50,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC23147), Color(0xFFAD2C3F)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class GoogleButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const GoogleButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 50,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.g_mobiledata, color: Colors.red, size: 32),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class TopSection extends StatelessWidget {
  const TopSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 60),
        SizedBox(
          width: 120,
          height: 120,
          child: Image.asset(
            'nutriguard1/web/icons/1.png',
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.apple, // Fallback visual se a imagem não for encontrada
              size: 80,
              color: Color(0xFFAD2C3F),
            ),
          ),
        ),
        const SizedBox(height: 16),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            children: [
              TextSpan(
                text: 'Nutri',
                style: TextStyle(color: Color(0xFF8DB600)),
              ),
              TextSpan(
                text: 'Guard',
                style: TextStyle(color: Color(0xFFAD2C3F)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}
""",
    "screens/auth/login_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/auth_components.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF2E0),
      body: SafeArea(
        child: Column(
          children: [
            const TopSection(),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: const BoxDecoration(
                  color: Color(0xFFC8E569),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const CustomTextField(
                        prefixIcon: Icons.person_outline,
                        hintText: "Nome de Usuário",
                      ),
                      const CustomTextField(
                        prefixIcon: Icons.mail_outline,
                        hintText: "E-mail",
                      ),
                      const CustomTextField(
                        prefixIcon: Icons.lock_outline,
                        hintText: "Senha",
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      PrimaryGradientButton(
                        text: "Login",
                        onPressed: () => Navigator.pushNamed(context, '/dashboard-adm-frota'),
                      ),
                      GoogleButton(
                        text: "Entrar com Google",
                        onPressed: () {},
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/cadastro'),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            children: [
                              TextSpan(
                                text: 'Não possue conta? Faça ',
                                style: TextStyle(color: Colors.black54),
                              ),
                              TextSpan(
                                text: 'Cadastro!',
                                style: TextStyle(color: Color(0xFFAD2C3F), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
""",
    "screens/auth/cadastro_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/auth_components.dart';

class CadastroScreen extends StatelessWidget {
  const CadastroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF2E0),
      body: SafeArea(
        child: Column(
          children: [
            const TopSection(),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: const BoxDecoration(
                  color: Color(0xFFC8E569),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const CustomTextField(
                        prefixIcon: Icons.person_outline,
                        hintText: "Nome de Usuário",
                      ),
                      const CustomTextField(
                        prefixIcon: Icons.mail_outline,
                        hintText: "E-mail",
                      ),
                      const CustomTextField(
                        prefixIcon: Icons.lock_outline,
                        hintText: "Senha",
                        obscureText: true,
                      ),
                      const CustomTextField(
                        prefixIcon: Icons.lock_outline,
                        hintText: "Confirmar senha",
                        obscureText: true,
                      ),
                      const CustomTextField(
                        prefixIcon: Icons.phone_outlined,
                        hintText: "Telefone",
                      ),
                      const CustomTextField(
                        prefixIcon: Icons.description_outlined,
                        hintText: "CPF",
                      ),
                      const SizedBox(height: 16),
                      PrimaryGradientButton(
                        text: "Cadastrar",
                        onPressed: () => Navigator.pop(context),
                      ),
                      GoogleButton(
                        text: "crie uma conta com google",
                        onPressed: () {},
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/'),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            children: [
                              TextSpan(
                                text: 'Ja tem conta? Faça ',
                                style: TextStyle(color: Colors.black54),
                              ),
                              TextSpan(
                                text: 'Login!',
                                style: TextStyle(color: Color(0xFFAD2C3F), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
"""
}

for path, content in files.items():
    full_path = os.path.join(base_dir, path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, "w", encoding="utf-8") as f:
        f.write(content)

print(f"Updated {len(files)} files successfully in {base_dir}")
