# 📋 Contas de Acesso — NutriGuard (dados de demonstração)

Todos os dados são **fictícios** (nomes, CPFs, telefones, placas). Criados por `supabase/seed_demo_completo.sql`.
Todas as contas usam a mesma senha, definida por quem executou o script — **a senha não é versionada**.

Empresa: **NutriGuard Logística** (1 admin · 5 gerentes · 50 operadores · 50 veículos)

## 🔌 Veículo ligado ao ESP32 do Wokwi

| Veículo | Placa | Frota | Operador (login) | Gerente (login) |
| :--- | :--- | :--- | :--- | :--- |
| Veículo 01 — Grande São Paulo — Ford Cargo 816 (Carnes) | **RLD7R83** | Frota Grande São Paulo | Luana Lima — `operador.luana.lima@nutriguard.com` | Mariana Silveira — `gerente.mariana.silveira@nutriguard.com` |

Faixa de temperatura configurada: -2 °C a 4 °C. O token do ESP32 não fica no repositório: gere um novo no app (Listar dispositivos → ícone da chave) se precisar.

## Administrador

| Nome | E-mail | CPF | Telefone |
| :--- | :--- | :--- | :--- |
| Carlos Henrique | `admin@nutriguard.com` | 317.784.864-52 | (11) 99980-9223 |

## Gerentes (um por frota)

| Nome | E-mail | Frota | Base |
| :--- | :--- | :--- | :--- |
| Mariana Silveira | `gerente.mariana.silveira@nutriguard.com` | Frota Grande São Paulo | CD São Paulo (Vila Leopoldina) |
| Roberto Costa | `gerente.roberto.costa@nutriguard.com` | Frota Campinas | CD Campinas (Viracopos) |
| Fernanda Ribeiro | `gerente.fernanda.ribeiro@nutriguard.com` | Frota Curitiba | CD Curitiba (CIC) |
| Paulo Henrique Alves | `gerente.paulo.alves@nutriguard.com` | Frota Belo Horizonte | CD Contagem |
| Camila Duarte | `gerente.camila.duarte@nutriguard.com` | Frota Rio de Janeiro | CD Duque de Caxias |

## Operadores — Frota Grande São Paulo

| Operador | E-mail | Veículo | Placa | Carga (faixa °C) |
| :--- | :--- | :--- | :--- | :--- |
| Luana Lima 🔌 | `operador.luana.lima@nutriguard.com` | Veículo 01 — Grande São Paulo | RLD7R83 | Carnes (-2 a 4) |
| Renata Teixeira | `operador.renata.teixeira@nutriguard.com` | Veículo 02 — Grande São Paulo | NJP8P20 | Congelados (-18 a -12) |
| Simone Carvalho | `operador.simone.carvalho@nutriguard.com` | Veículo 03 — Grande São Paulo | FMU9U37 | Congelados (-18 a -12) |
| Vinícius Souza | `operador.vinicius.souza@nutriguard.com` | Veículo 04 — Grande São Paulo | CAP4P11 | Congelados (-18 a -12) |
| Gustavo Araújo | `operador.gustavo.araujo@nutriguard.com` | Veículo 05 — Grande São Paulo | ZLK1K63 | Congelados (-20 a -15) |
| Amanda Silva | `operador.amanda.silva@nutriguard.com` | Veículo 06 — Grande São Paulo | UAY8Y81 | Laticínios (0 a 4) |
| Bruno Cardoso | `operador.bruno.cardoso@nutriguard.com` | Veículo 07 — Grande São Paulo | ENZ5H81 | Laticínios (0 a 4) |
| Fábio Pinto | `operador.fabio.pinto@nutriguard.com` | Veículo 08 — Grande São Paulo | GZV4V15 | Resfriados (2 a 8) |
| Henrique Moura | `operador.henrique.moura@nutriguard.com` | Veículo 09 — Grande São Paulo | UFT0F50 | Carnes (-2 a 4) |
| Diego Reis | `operador.diego.reis@nutriguard.com` | Veículo 10 — Grande São Paulo | UTH5Y68 | Carnes (-2 a 4) |

## Operadores — Frota Campinas

| Operador | E-mail | Veículo | Placa | Carga (faixa °C) |
| :--- | :--- | :--- | :--- | :--- |
| Daniela Ferreira | `operador.daniela.ferreira@nutriguard.com` | Veículo 01 — Campinas | YEP4L25 | Carnes (-2 a 4) |
| Priscila Carvalho | `operador.priscila.carvalho@nutriguard.com` | Veículo 02 — Campinas | BNF0J81 | Vacinas (2 a 8) |
| Juliana Nascimento | `operador.juliana.nascimento@nutriguard.com` | Veículo 03 — Campinas | RGW2Z49 | Congelados (-18 a -12) |
| Renan Nunes | `operador.renan.nunes@nutriguard.com` | Veículo 04 — Campinas | SMJ7G57 | Carnes (-2 a 4) |
| Tatiane Monteiro | `operador.tatiane.monteiro@nutriguard.com` | Veículo 05 — Campinas | WGA7H36 | Congelados (-20 a -15) |
| Rafael Reis | `operador.rafael.reis@nutriguard.com` | Veículo 06 — Campinas | ZME7F33 | Congelados (-18 a -12) |
| Wesley Correia | `operador.wesley.correia@nutriguard.com` | Veículo 07 — Campinas | FTG1P94 | Hortifrúti (8 a 15) |
| Leonardo Silva | `operador.leonardo.silva@nutriguard.com` | Veículo 08 — Campinas | GPA8E92 | Laticínios (0 a 4) |
| Letícia Moura | `operador.leticia.moura@nutriguard.com` | Veículo 09 — Campinas | TTD4K14 | Carnes (-2 a 4) |
| Marcos Araújo | `operador.marcos.araujo@nutriguard.com` | Veículo 10 — Campinas | KSH5Z69 | Vacinas (2 a 8) |

## Operadores — Frota Curitiba

| Operador | E-mail | Veículo | Placa | Carga (faixa °C) |
| :--- | :--- | :--- | :--- | :--- |
| Felipe Vieira | `operador.felipe.vieira@nutriguard.com` | Veículo 01 — Curitiba | JPV0M87 | Laticínios (0 a 4) |
| Otávio Nascimento | `operador.otavio.nascimento@nutriguard.com` | Veículo 02 — Curitiba | DRU0M98 | Resfriados (2 a 8) |
| Gabriel Cruz | `operador.gabriel.cruz@nutriguard.com` | Veículo 03 — Curitiba | HUN7C41 | Resfriados (2 a 8) |
| Carolina Reis | `operador.carolina.reis@nutriguard.com` | Veículo 04 — Curitiba | FSU1E10 | Congelados (-18 a -12) |
| Igor Carvalho | `operador.igor.carvalho@nutriguard.com` | Veículo 05 — Curitiba | VDH7F87 | Congelados (-18 a -12) |
| Natália Cardoso | `operador.natalia.cardoso@nutriguard.com` | Veículo 06 — Curitiba | KJR9P70 | Hortifrúti (8 a 15) |
| Elaine Vieira | `operador.elaine.vieira@nutriguard.com` | Veículo 07 — Curitiba | MRH2T48 | Congelados (-20 a -15) |
| Kelly Moura | `operador.kelly.moura@nutriguard.com` | Veículo 08 — Curitiba | APT6N89 | Congelados (-20 a -15) |
| Bruna Nascimento | `operador.bruna.nascimento@nutriguard.com` | Veículo 09 — Curitiba | XDP3L49 | Vacinas (2 a 8) |
| Michele Nascimento | `operador.michele.nascimento@nutriguard.com` | Veículo 10 — Curitiba | RSB7S54 | Carnes (-2 a 4) |

## Operadores — Frota Belo Horizonte

| Operador | E-mail | Veículo | Placa | Carga (faixa °C) |
| :--- | :--- | :--- | :--- | :--- |
| Patrícia Nunes | `operador.patricia.nunes@nutriguard.com` | Veículo 01 — Belo Horizonte | KHW8F77 | Congelados (-20 a -15) |
| Yasmin Mendes | `operador.yasmin.mendes@nutriguard.com` | Veículo 02 — Belo Horizonte | NXP9R87 | Resfriados (2 a 8) |
| Larissa Cardoso | `operador.larissa.cardoso@nutriguard.com` | Veículo 03 — Belo Horizonte | NKZ4A36 | Vacinas (2 a 8) |
| Lucas Barbosa | `operador.lucas.barbosa@nutriguard.com` | Veículo 04 — Belo Horizonte | KPM8Y66 | Carnes (-2 a 4) |
| Vanessa Monteiro | `operador.vanessa.monteiro@nutriguard.com` | Veículo 05 — Belo Horizonte | ADG7N19 | Vacinas (2 a 8) |
| Pedro Santos | `operador.pedro.santos@nutriguard.com` | Veículo 06 — Belo Horizonte | NJV7M34 | Hortifrúti (8 a 15) |
| Jéssica Ramos | `operador.jessica.ramos@nutriguard.com` | Veículo 07 — Belo Horizonte | LKK2Z16 | Congelados (-20 a -15) |
| André Oliveira | `operador.andre.oliveira@nutriguard.com` | Veículo 08 — Belo Horizonte | UJU8M61 | Vacinas (2 a 8) |
| João Lopes | `operador.joao.lopes@nutriguard.com` | Veículo 09 — Belo Horizonte | NXE3Z87 | Carnes (-2 a 4) |
| Matheus Nascimento | `operador.matheus.nascimento@nutriguard.com` | Veículo 10 — Belo Horizonte | HHK9P69 | Resfriados (2 a 8) |

## Operadores — Frota Rio de Janeiro

| Operador | E-mail | Veículo | Placa | Carga (faixa °C) |
| :--- | :--- | :--- | :--- | :--- |
| Débora Silva | `operador.debora.silva@nutriguard.com` | Veículo 01 — Rio de Janeiro | AYK2V45 | Hortifrúti (8 a 15) |
| Raquel Freitas | `operador.raquel.freitas@nutriguard.com` | Veículo 02 — Rio de Janeiro | AVD7B35 | Resfriados (2 a 8) |
| Murilo Ferreira | `operador.murilo.ferreira@nutriguard.com` | Veículo 03 — Rio de Janeiro | HBB4A90 | Resfriados (2 a 8) |
| Rodrigo Lopes | `operador.rodrigo.lopes@nutriguard.com` | Veículo 04 — Rio de Janeiro | FVZ9F36 | Vacinas (2 a 8) |
| Thiago Correia | `operador.thiago.correia@nutriguard.com` | Veículo 05 — Rio de Janeiro | BPN3L22 | Hortifrúti (8 a 15) |
| Sabrina Carvalho | `operador.sabrina.carvalho@nutriguard.com` | Veículo 06 — Rio de Janeiro | EXE0K27 | Congelados (-18 a -12) |
| Viviane Moura | `operador.viviane.moura@nutriguard.com` | Veículo 07 — Rio de Janeiro | NVM6G92 | Congelados (-18 a -12) |
| Caio Santos | `operador.caio.santos@nutriguard.com` | Veículo 08 — Rio de Janeiro | HES4N50 | Vacinas (2 a 8) |
| Eduardo Moura | `operador.eduardo.moura@nutriguard.com` | Veículo 09 — Rio de Janeiro | GDN1B34 | Resfriados (2 a 8) |
| Aline Silva | `operador.aline.silva@nutriguard.com` | Veículo 10 — Rio de Janeiro | HME1E33 | Congelados (-20 a -15) |
