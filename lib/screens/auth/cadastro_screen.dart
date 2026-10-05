import 'package:flutter/material.dart';
import '../../widgets/auth_components.dart';

class CadastroScreen extends StatelessWidget {
  const CadastroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      
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
