<div align="center">

![NutriGuard](https://capsule-render.vercel.app/api?type=waving&color=0:FF0000,100:7A0000&height=160&section=header&text=NutriGuard&fontSize=65&fontColor=ffffff&animation=fadeIn&fontAlignY=38&desc=Telemetria%20e%20Gest%C3%A3o%20de%20Frotas%20para%20Cargas%20Sens%C3%ADveis&descSize=20&descAlignY=58&descColor=90caf9)

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![IoT](https://img.shields.io/badge/IoT-Telemetria-0d47a1?style=for-the-badge)](#-visão-geral)

</div>

---

## ◈ Visão Geral

O **NutriGuard** é uma plataforma de **telemetria e gestão de frotas** focada no monitoramento em tempo real de **cargas sensíveis**.

O sistema coleta dados de sensores IoT — como **temperatura, umidade e vibração** —, emite **alertas** sobre ocorrências críticas e organiza o acesso à informação por meio de uma **hierarquia de papéis** (Administradores, Gerentes e Operadores), garantindo que cada pessoa veja apenas o que lhe cabe.

Desenvolvido em **Flutter** no front-end e **Supabase** como _Backend as a Service_ (BaaS).

---

## ✦ Funcionalidades

| ◆ Módulo                        | › Descrição                                                                    |
| ------------------------------- | ------------------------------------------------------------------------------ |
| `[ Monitoramento em Tempo Real ]` | Recebimento contínuo de medições dos sensores IoT instalados nos veículos      |
| `[ Alertas e Ocorrências ]`       | Geração automática de ocorrências quando uma medição ultrapassa os limites     |
| `[ Gestão de Frotas ]`            | Agrupamento de veículos e dispositivos sob a responsabilidade de um gerente    |
| `[ Controle de Dispositivos ]`    | Cadastro de rastreadores/sensores com limites configuráveis por dispositivo    |
| `[ Controle de Acesso (RBAC) ]`   | Navegação dinâmica e permissões estritas conforme o cargo do usuário           |
| `[ Perfil de Usuário ]`           | Edição de nome, telefone e foto de perfil com upload seguro para o Storage     |
| `[ Multiplataforma ]`             | Compatível com Web (Chrome) e Mobile a partir da mesma base de código          |

---

## ⚙ Stack Tecnológica

```
◆ Front-end      →  Flutter (Dart) — Web e Mobile
◆ Back-end       →  Supabase (BaaS)
◆ Banco de Dados →  PostgreSQL + Row Level Security (RLS)
◆ Autenticação   →  Supabase Auth (Email e Senha)
◆ Storage        →  Supabase Storage (fotos de perfil)
◆ Pacotes        →  supabase_flutter, image_picker
```

---

## ◉ Perfis e Permissões (RBAC)

A navegação é dinâmica e o controle de acesso é estrito, com base na coluna `cargo` do usuário.

| ◆ Perfil                | › Cargo (`cargo`) | › Permissões                                                                                                                                  |
| ----------------------- | ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `[ Administrador ]`     | `admin`           | Acesso irrestrito. Cadastra funcionários (gerentes e operadores), registra dispositivos IoT, cria frotas e visualiza todos os relatórios e frotas |
| `[ Gerente ]`           | `gerente`         | Acesso limitado à **própria frota**. Visualiza veículos associados, histórico de viagens e alertas de sensores dos dispositivos sob sua gestão  |
| `[ Operador ]`          | `operador`        | Motorista responsável pela viagem. Acessa o próprio perfil e as opções operacionais (iniciar e parar viagem)                                  |

---

## ◆ Banco de Dados

O banco é **PostgreSQL** (Supabase), com políticas de **RLS (Row Level Security)** protegendo as tabelas.

### Tabelas Principais

| ◆ Tabela        | › Descrição                                                              | › Colunas principais                                                                                                                                   |
| --------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Usuarios`      | Perfis dos usuários                                                      | `id` (FK de `auth.users`), `nome`, `email`, `cpf`, `telefone`, `cargo`, `foto_url`                                                                     |
| `Frotas`        | Agrupamento de veículos                                                  | `id`, `nome`, `id_gerente` (referência ao usuário que gerencia a frota)                                                                                |
| `Dispositivos`  | Aparelhos IoT rastreadores/sensores                                      | `id`, `id_frota`, `id_operador`, `nome_dispositivo`, `temperatura_maxima`, `temperatura_minima`, `limite_vibracao`, ...                                |
| `medicoes`      | Dados recebidos constantemente dos sensores                              | `id`, `id_dispositivo`, `temperatura`, `umidade`, `vibracao`, `porta_aberta`, `latitude`, `longitude`, `bateria`                                       |
| `ocorrencias`   | Alertas gerados quando uma medição ultrapassa os limites do dispositivo  | —                                                                                                                                                      |

> **Trigger `on_auth_user_created`:** copia automaticamente os dados de `auth.users` para a tabela `Usuarios` no momento do cadastro.

### Storage

```
◆ Bucket   →  profiles
◆ Uso      →  Fotos de perfil dos usuários
◆ Leitura  →  Pública
◆ Escrita  →  Insert / Update / Delete protegidos por RLS,
              restritos ao dono da foto (auth.uid())
```

---

## ▸ Como Executar Localmente

**Pré-requisitos:** [Flutter](https://docs.flutter.dev/get-started/install) instalado e um projeto [Supabase](https://supabase.com/) configurado com as tabelas e políticas descritas acima.

```bash
# › Clone o repositório
git clone https://github.com/SEU-USUARIO/NutriGuard.git

# › Acesse o diretório
cd NutriGuard

# › Baixe as dependências
flutter pub get

# › Execute o projeto (emulador, dispositivo físico ou Chrome)
flutter run -d chrome
```

> ⚠ Certifique-se de que a **URL** e a **anon key** do seu projeto Supabase estão configuradas na inicialização do app.

---

## ◉ Estrutura do Projeto

A arquitetura do front-end é dividida por funcionalidades e telas contextuais.

```
NutriGuard/
└── lib/
    ├── models/       ◆ Modelos de dados (UsuarioModel, DispositivoModel, MedicaoModel...)
    │                   com os métodos .fromJson e .toJson
    ├── services/     ◆ Regras de negócio e comunicação externa
    │   └── supabase_service.dart   → Auth, CRUD do banco e upload de Storage
    ├── screens/      ◆ Telas organizadas por domínio
    │   ├── auth/         → Login e Cadastro
    │   ├── dashboard/    → Dashboards de frotas, veículos e estado vazio
    │   ├── perfil/       → Visualização e edição de perfil (image_picker)
    │   ├── cadastros/    → Formulários de usuários, frotas e dispositivos
    │   └── listagens/    → Listas para gerenciar frotas, dispositivos, etc.
    └── widgets/      ◆ Componentes reaproveitáveis
        ├── custom_end_drawer.dart      → Drawer lateral dinâmico (adapta-se ao role)
        └── custom_bottom_nav_bar.dart  → Rodapé customizado
```

---

## ✦ Para Quem Está Assumindo o Projeto

| ◆ Tema                    | › O que saber                                                                                                                                                                                                         |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `[ Fallback de Sessão ]`  | Se a trigger do Supabase falhar e a tabela `Usuarios` não for preenchida, o `SupabaseService` e a tela de perfil extraem nome, telefone, CPF e cargo de `currentUser.userMetadata`                                    |
| `[ Edição de Perfil ]`    | `perfil_screen.dart` atualiza em tempo real nome, telefone e foto (enviada ao Storage com segurança). **Cargo e ID não são editáveis** pelo usuário                                                                    |
| `[ Drawer Dinâmico ]`     | Ao criar telas novas e ligá-las ao menu, atualize o `_buildActionButtons` ou os `if (_userRole == '...')` em `lib/widgets/custom_end_drawer.dart`                                                                     |

---

## ◆ Equipe

| `[ Dev ]` Carlos Henrique | `[ Dev ]` João Lucas  | `[ Dev ]` Gustavo Leite 
| ------------------ | ------------------------ | ------------------------ |

---

## → Links

[![Repositório](https://img.shields.io/badge/GitHub-Reposit%C3%B3rio-181717?style=for-the-badge&logo=github)](https://github.com/SEU-USUARIO/NutriGuard)

---

## ◈ Licença

Distribuído sob a licença **MIT**. Consulte o arquivo [`LICENSE`](./LICENSE) para mais detalhes.

<div align="center">

![Footer](https://capsule-render.vercel.app/api?type=waving&color=0:FF0000,100:7A0000&height=100&section=footer)

</div>
