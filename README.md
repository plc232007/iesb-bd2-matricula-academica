# Sistema de Matrícula Acadêmica

Projeto acadêmico de **Banco de Dados II (CCO072)** do Centro Universitário IESB, semestre **2026/2**, sob orientação do **Prof. Rodrigo Gonçalves**.

Implementação de um banco de dados para matrícula acadêmica, com foco em integridade, consultas avançadas, desempenho, concorrência, segurança e recuperação.

> **Situação:** documentação inicial de planejamento. As listas abaixo representam requisitos a verificar, não funcionalidades concluídas. O modelo relacional e o ambiente Docker oficiais devem ser incorporados a partir dos materiais do professor. Ajuste a seção de execução e valide-a antes da entrega.

## Objetivo

Transformar o modelo relacional fornecido pelo professor em um banco PostgreSQL funcional e reproduzível. O domínio abrange cursos, currículos, disciplinas e pré-requisitos, turmas, horários, salas, alunos, matrículas e histórico acadêmico, com a grade de 2026/2.

## Tecnologias

- PostgreSQL 17 no ambiente Docker oficial da disciplina.
- SQL e recursos nativos de administração do PostgreSQL.
- Git e GitHub para versionamento, revisão e acompanhamento de tarefas.

## Entregas

| Etapa | Prazo no enunciado | Escopo |
| --- | --- | --- |
| Marco 1 | 14/09/2026 | DDL, carga de dados e 10 consultas |
| Marco 2 | 06/11/2026 | Views, índices, concorrência, segurança e operação |
| Seminário | 09/11 ou 16/11/2026 | Demonstração ao vivo e arguição individual cruzada |

A escala do seminário será divulgada em 26/10/2026. O prazo do Marco 1 deve ser conferido com o professor se houver alteração de calendário.

## Requisitos do Marco 1

- [ ] DDL completo conforme o modelo fornecido, com tipos, domínios, colunas geradas e restrições de integridade aplicáveis.
- [ ] Carga com pelo menos 100 alunos, 6 turmas e 300 matrículas.
- [ ] Dez consultas comentadas de complexidade crescente.
- [ ] Junção externa com agregação.
- [ ] Consulta recursiva da árvore de pré-requisitos.
- [ ] Consulta recursiva das disciplinas que um aluno já pode cursar.
- [ ] Função de janela com ranking e percentil.
- [ ] Função de janela com LAG para evolução do rendimento.

## Requisitos do Marco 2

- [ ] Três views: oferta, vagas e histórico.
- [ ] Uma materialized view de indicadores, com política de atualização justificada.
- [ ] Pelo menos quatro índices, incluindo um parcial.
- [ ] Evidências de EXPLAIN (ANALYZE, BUFFERS) antes e depois de cada índice, com ganho medido e análise.
- [ ] Reprodução da anomalia na disputa pela última vaga.
- [ ] Correção com bloqueio explícito.
- [ ] Correção por nível de isolamento.
- [ ] Comparação das correções: custo, contenção e necessidade de retentativa.
- [ ] Papéis aluno, secretaria e coordenacao com GRANT/REVOKE.
- [ ] Row-level security impedindo um aluno de consultar o histórico de outro.
- [ ] Backup e restauração documentados e reproduzíveis do zero.

**Bônus opcional:** particionamento do histórico por ano ou uso de JSONB com índice GIN, conforme o enunciado.

## Organização proposta

Os caminhos abaixo são uma convenção sugerida e devem acompanhar os arquivos efetivamente implementados.

| Caminho | Finalidade |
| --- | --- |
| `README.md` | Visão geral, instalação e execução |
| `AUTORES.md` | Integrantes e responsabilidades formais |
| `compose.yaml` | Ambiente oficial, se fornecido neste formato |
| `.env.example` | Exemplo das variáveis usadas pelo ambiente, sem credenciais pessoais |
| `sql/01_ddl.sql` | Tipos, domínios, tabelas e restrições |
| `sql/02_carga.sql` | Carga inicial e dados sintéticos |
| `sql/03_consultas.sql` | Dez consultas comentadas |
| `sql/04_views.sql` | Views e materialized view |
| `sql/05_indices.sql` | Índices e comentários das decisões |
| `sql/06_seguranca.sql` | Roles, privilégios e RLS |
| `cenarios/concorrencia/` | Preparação, sessão A e sessão B de cada cenário |
| `operacao/` | Scripts e instruções de backup e restauração |
| `testes/` | Verificações de integridade, carga, segurança e recuperação |
| `evidencias/explain/` | Planos completos antes/depois e comparação |
| `evidencias/concorrencia/` | Sequência executada e resultados observados |
| `evidencias/seguranca/` | Verificações dos papéis e isolamento por aluno |
| `evidencias/restauracao/` | Registro da restauração e validação |
| `docs/decisoes.md` | Justificativas técnicas e alternativas avaliadas |
| `docs/apresentacao.md` | Roteiro da demonstração e revisão cruzada |

Os cenários concorrentes devem ter arquivos numerados e instruções explícitas sobre a ordem dos comandos entre duas sessões. Não devem ser executados em lote junto à instalação.

## Como executar — completar com o ambiente oficial

### Pré-requisitos

- Git.
- Docker e o comando Compose compatíveis com o material da disciplina.
- Arquivos oficiais do ambiente e modelo relacional fornecidos pelo professor.

### 1. Obter o projeto

Substitua `SEU_USUARIO` pelo proprietário do repositório:

```bash
git clone https://github.com/SEU_USUARIO/iesb-bd2-matricula-academica.git
cd iesb-bd2-matricula-academica
```

### 2. Preparar e iniciar o ambiente

Incorpore o ambiente oficial. Documente aqui o nome do serviço PostgreSQL, o banco, o usuário, as variáveis necessárias e a porta. Caso ele use um arquivo Compose na raiz, a inicialização será:

```bash
docker compose up -d
docker compose ps
```

Se houver `.env.example`, copie-o para `.env` e preencha os valores exigidos. Não versione o `.env`.

### 3. Executar os scripts

**Exemplo a adaptar:** substitua os três valores abaixo pelos nomes reais definidos no ambiente oficial. Os arquivos SQL também precisam existir antes da execução.

```bash
DB_SERVICE='SUBSTITUIR_PELO_SERVICO'
DB_USER='SUBSTITUIR_PELO_USUARIO'
DB_NAME='SUBSTITUIR_PELO_BANCO'

docker compose exec -T "$DB_SERVICE" psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 < sql/01_ddl.sql
docker compose exec -T "$DB_SERVICE" psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 < sql/02_carga.sql
docker compose exec -T "$DB_SERVICE" psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 < sql/03_consultas.sql
docker compose exec -T "$DB_SERVICE" psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 < sql/04_views.sql
```

Antes de aplicar `sql/05_indices.sql`, capture os planos de referência das consultas escolhidas. Depois, aplique e avalie cada índice conforme o procedimento documentado em `evidencias/explain/`. Conclua aplicando `sql/06_seguranca.sql` com um usuário autorizado a configurar roles e políticas.

Se o ambiente oficial já executar scripts de inicialização automaticamente, documente esse mecanismo e ajuste este roteiro para não executar o DDL duas vezes.

### 4. Validar a instalação

Complete esta seção com comandos reais, resultados esperados e caminhos das evidências para:

- Conferir pelo menos 100 alunos, 6 turmas e 300 matrículas.
- Demonstrar aceitação de dados válidos e rejeição de violações de integridade.
- Executar e explicar as dez consultas.
- Consultar as views e demonstrar a atualização da materialized view.
- Comparar planos antes e depois dos índices.
- Executar a anomalia e as duas correções em sessões separadas.
- Testar RLS com dois alunos distintos usando os papéis efetivos de aplicação.
- Restaurar um backup em ambiente limpo e validar dados e objetos recuperados.

**Critério de conclusão do README:** outro integrante consegue preparar o banco do zero seguindo somente os arquivos versionados e estas instruções, sem explicações adicionais.

## Evidências e decisões

Cada evidência deve identificar a consulta ou cenário, as condições do teste, os comandos executados, o resultado esperado, o resultado observado e a conclusão.

Os planos de execução devem ser salvos em arquivos próprios. As comparações de índices devem usar condições equivalentes e explicar ganhos, custos de escrita e situações em que o otimizador não escolhe o índice. Não apresentar ganhos que não foram observados.

A documentação operacional deve registrar os comandos reais de backup e restauração, os pré-requisitos e a verificação posterior. Registrar também como os papéis necessários são recriados ou recuperados.

## Colaboração

1. Abrir uma issue com objetivo, entregáveis e critérios de aceite.
2. Definir um responsável e associar ao marco correspondente.
3. Criar uma branch a partir de `main`, como `feat/numero-da-issue-descricao`.
4. Fazer commits pequenos e descritivos, com autoria de quem realizou o trabalho.
5. Abrir um pull request para `main`, informar a validação realizada e usar `Closes #NUMERO` quando a tarefa estiver completa.
6. Solicitar revisão de outro integrante antes de integrar a alteração.
7. Atualizar a documentação e as evidências junto com a implementação.

Exemplos de commits:

```text
chore: organiza estrutura inicial do projeto
feat: implementa restricoes de integridade
feat: adiciona consulta recursiva de pre-requisitos
perf: adiciona indice parcial e compara planos
fix: corrige disputa pela ultima vaga
docs: documenta restauracao em ambiente limpo
```

O histórico de commits integra a avaliação. Todos devem contribuir durante o desenvolvimento e compreender também as frentes dos colegas.

## Autores

As responsabilidades formais devem constar em `AUTORES.md`:

| Integrante | Responsabilidade principal |
| --- | --- |
| A preencher | Modelagem Física e Desempenho |
| A preencher | Transações e Concorrência |
| A preencher | Administração e Operação |

## Apresentação

O seminário tem aproximadamente 18 minutos: demonstração ao vivo de cerca de 9 minutos e arguição individual de cerca de 9 minutos.

A demonstração deve incluir restrições de integridade, anomalia e correção de concorrência, plano com EXPLAIN ANALYZE, RLS e restauração de backup ao vivo. A arguição é cruzada: cada integrante deve se preparar para explicar uma frente diferente da sua.

## Referência

Orientações do Projeto Acadêmico — Sistema de Matrícula Acadêmica, Banco de Dados II, IESB, 2026/2, Prof. Rodrigo Gonçalves. Havendo alteração oficial de requisitos ou datas, atualizar este documento.
