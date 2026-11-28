import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutriguard1/services/supabase_service.dart';
import 'package:nutriguard1/utils/validacao_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('ValidacaoAuth.login', () {
    test('vazio pede e-mail e senha (não vai ao servidor)', () {
      expect(ValidacaoAuth.login(email: '', senha: ''), 'Informe seu e-mail e sua senha.');
    });
    test('sem senha', () {
      expect(ValidacaoAuth.login(email: 'a@b.com', senha: ''), 'Informe sua senha.');
    });
    test('e-mail inválido', () {
      expect(ValidacaoAuth.login(email: 'abc', senha: 'x'), 'Informe um e-mail válido.');
    });
    test('ok', () {
      expect(ValidacaoAuth.login(email: ' a@b.com ', senha: '123456'), isNull);
    });
  });

  group('ValidacaoAuth.cadastroAdmin', () {
    String? v({
      String empresa = 'QA Transportes',
      String nome = 'Fulano',
      String email = 'f@x.com',
      String senha = '123456',
      String? confirma,
      String telefone = '(11) 91234-0001',
      String cpf = '453.331.478-33',
    }) =>
        ValidacaoAuth.cadastroAdmin(
          empresa: empresa,
          nome: nome,
          email: email,
          senha: senha,
          confirmaSenha: confirma ?? senha,
          telefone: telefone,
          cpf: cpf,
        );

    test('formulário vazio não envia', () {
      expect(v(empresa: '', nome: '', email: '', senha: '', telefone: '', cpf: ''), 'Informe o nome da empresa.');
    });
    test('campos obrigatórios em ordem', () {
      expect(v(nome: ''), 'Informe seu nome.');
      expect(v(email: 'x'), 'Informe um e-mail válido.');
      expect(v(senha: '123'), 'A senha deve conter no mínimo 6 caracteres.');
      expect(v(confirma: '654321'), 'As senhas não coincidem.');
      expect(v(telefone: '(11) 9'), 'O telefone deve conter DDD e pelo menos 10 dígitos.');
      expect(v(cpf: '123'), 'O CPF deve conter exatamente 11 dígitos.');
    });
    test('ok', () => expect(v(), isNull));
  });

  group('SupabaseService.criarContaAuth (sem trocar a sessão do admin)', () {
    test('usa a API de signup direto e devolve o usuário da sessão retornada', () async {
      late http.Request enviado;
      final client = MockClient((req) async {
        enviado = req;
        return http.Response(
          jsonEncode({
            'access_token': 'x',
            'user': {
              'id': 'u1',
              'aud': 'authenticated',
              'email': 'g@x.com',
              'created_at': '2026-11-26T00:00:00Z',
              'app_metadata': {},
              'user_metadata': {'nome': 'G'},
            },
          }),
          200,
        );
      });

      final user = await SupabaseService.criarContaAuth(
        email: 'g@x.com',
        password: '123456',
        dados: {'nome': 'G', 'cpf': '1'},
        httpClient: client,
      );

      expect(user.id, 'u1');
      expect(enviado.url.path, '/auth/v1/signup');
      expect(enviado.headers['apikey'], SupabaseService.supabaseAnonKey);
      final corpo = jsonDecode(enviado.body);
      expect(corpo['data'], {'nome': 'G', 'cpf': '1'});
    });

    test('aceita resposta só com o usuário (confirmação de e-mail ligada)', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'id': 'u2',
              'aud': 'authenticated',
              'email': 'o@x.com',
              'created_at': '2026-11-26T00:00:00Z',
              'app_metadata': {},
              'user_metadata': {},
            }),
            200,
          ));
      final user = await SupabaseService.criarContaAuth(
          email: 'o@x.com', password: '123456', dados: const {}, httpClient: client);
      expect(user.id, 'u2');
    });

    test('erro da API vira AuthException traduzível', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'code': 422, 'error_code': 'user_already_exists', 'msg': 'User already registered'}),
            422,
          ));
      try {
        await SupabaseService.criarContaAuth(
            email: 'o@x.com', password: '123456', dados: const {}, httpClient: client);
        fail('deveria lançar');
      } on AuthException catch (e) {
        expect(SupabaseService.formatarErro(e), 'Este e-mail já está cadastrado no sistema.');
      }
    });
  });
}
