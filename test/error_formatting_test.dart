import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nutriguard1/services/supabase_service.dart';

void main() {
  group('SupabaseService.formatarErro Tests', () {
    test('1. Formats AuthException invalid credentials correctly', () {
      const err = AuthException('Invalid login credentials', statusCode: '400');
      expect(SupabaseService.formatarErro(err), 'E-mail ou senha incorretos.');
    });

    test('2. Formats AuthException user already registered', () {
      const err = AuthException('User already registered', statusCode: '422');
      expect(SupabaseService.formatarErro(err), 'Este e-mail já está cadastrado no sistema.');
    });

    test('3. Formats AuthException weak password', () {
      const err = AuthException('Password should be at least 6 characters', statusCode: '422');
      expect(SupabaseService.formatarErro(err), 'A senha deve conter no mínimo 6 caracteres.');
    });

    test('4. Formats AuthException unconfirmed email', () {
      const err = AuthException('Email not confirmed', statusCode: '400');
      expect(SupabaseService.formatarErro(err), 'E-mail não confirmado. Verifique sua caixa de entrada.');
    });

    test('5. Formats AuthException rate limit', () {
      const err = AuthException('Over request rate limit', statusCode: '429');
      expect(SupabaseService.formatarErro(err), 'Muitas tentativas em pouco tempo. Aguarde alguns minutos e tente novamente.');
    });

    test('6. Formats PostgrestException duplicate CPF', () {
      const err = PostgrestException(
        message: 'duplicate key value violates unique constraint',
        code: '23505',
        details: 'Key (cpf)=(12345678901) already exists.',
      );
      expect(SupabaseService.formatarErro(err), 'Já existe um cadastro registrado com este CPF.');
    });

    test('7. Formats PostgrestException duplicate email', () {
      const err = PostgrestException(
        message: 'duplicate key value violates unique constraint',
        code: '23505',
        details: 'Key (email)=(test@example.com) already exists.',
      );
      expect(SupabaseService.formatarErro(err), 'Este e-mail já está registrado no sistema.');
    });

    test('8. Formats internal gotrue / asyncStorage assertion errors gracefully', () {
      final err = AssertionError(
        "'package:gotrue/src/gotrue_client.dart': Failed assertion: line 478 pos 7: '_asyncStorage != null': You need to provide asyncStorage to perform pkce flow.",
      );
      final formatted = SupabaseService.formatarErro(err);
      expect(formatted, 'Falha no processo de autenticação. Tente novamente.');
      expect(formatted.contains('package:'), isFalse);
      expect(formatted.contains('gotrue'), isFalse);
    });

    test('10. Formats database error saving new user', () {
      const err = AuthException('Database error saving new user', statusCode: '500');
      expect(
        SupabaseService.formatarErro(err),
        'Não foi possível salvar o funcionário no banco de dados. O CPF ou e-mail informado já está em uso por outro cadastro. Verifique os dados.',
      );
    });

    test('11. Formats AuthException with usuarios_cpf_unique', () {
      const err = AuthException('duplicate key value violates unique constraint "usuarios_cpf_unique"', statusCode: '500');
      expect(
        SupabaseService.formatarErro(err),
        'Já existe um funcionário cadastrado com este CPF.',
      );
    });

    test('12. Formats AuthException with not-null constraint violation', () {
      const err = AuthException('null value in column "cpf" of relation "Usuarios" violates not-null constraint', statusCode: '500');
      expect(
        SupabaseService.formatarErro(err),
        'Preencha todos os campos obrigatórios (nome, CPF, telefone).',
      );
    });
  });
}
