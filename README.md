# Sistema de Matrícula Acadêmica

Projeto de Banco de Dados II (CCO072) do IESB, semestre 2026/2.

**Professor:** Rodrigo Gonçalves

**Integrantes:**
- André Matos
- Luiz Felipe
- Pedro Campos

A frente de cada um está em [AUTORES.md](AUTORES.md).

## Arquivos

Scripts na ordem de execução:

| Arquivo | Conteúdo |
| --- | --- |
| `01_ddl.sql` | Schema, tipos, domínios, tabelas, restrições e gatilho de vagas |
| `02_carga.sql` | Carga: 110 alunos, 13 turmas e 440 matrículas |
| `03_consultas.sql` | 10 consultas comentadas |
| `04_views.sql` | `vw_oferta`, `vw_vagas`, `vw_historico` e `mv_indicadores` |
| `05_indices.sql` | 4 índices, um deles parcial |
| `06_seguranca.sql` | Papéis `aluno`, `secretaria` e `coordenacao`, GRANT/REVOKE e RLS |
| `07_testes_integridade.sql` | 10 testes mostrando as restrições recusando dado errado |

Outras pastas (não rodam sozinhas):

| Pasta | Conteúdo |
| --- | --- |
| `concorrencia/` | Disputa pela última vaga e as duas correções |
| `evidencias/` | EXPLAIN antes e depois de cada índice (script e saída) |
| `operacao/` | Backup e restauração |

## Subir o banco do zero

Precisa do Docker. Na raiz do projeto:

```sh
docker compose up -d
```

Na primeira vez, o Postgres roda sozinho os scripts `01` a `07`, em ordem.

| Serviço | Endereço | Acesso |
| --- | --- | --- |
| PostgreSQL 16 | `localhost:5432` | usuário `bd2`, senha `bd2`, banco `matricula` |
| pgAdmin | `http://localhost:8080` | `admin@iesb.br` / `admin` |

As tabelas ficam no schema `academico`. No editor SQL, comece com `SET search_path TO academico;`.

Para apagar tudo e criar de novo: `docker compose down -v` e depois `docker compose up -d`.

Se a porta 5432 já estiver em uso: `POSTGRES_PORT=5434 docker compose up -d`.

Sem Docker, num PostgreSQL 16 ou 17 já instalado:

```sh
createdb matricula
for f in 0*.sql; do psql -d matricula -f "$f"; done
```

## Concorrência (disputa pela última vaga)

A turma `BD2-DEMO` tem 1 vaga e dois alunos tentam pegar ao mesmo tempo. Em cada cenário:

1. Prepare a turma:
   `docker compose exec -T postgres psql -U bd2 -d matricula < concorrencia/00_preparar.sql`
2. Em dois terminais, com menos de 5 segundos entre um e outro:
   - `docker compose exec -T postgres psql -U bd2 -d matricula -v aluno=26000101 < concorrencia/01_anomalia.sql`
   - `docker compose exec -T postgres psql -U bd2 -d matricula -v aluno=26000102 < concorrencia/01_anomalia.sql`
3. Confira o resultado:
   `docker compose exec -T postgres psql -U bd2 -d matricula < concorrencia/04_conferir.sql`

Repita trocando `01_anomalia.sql` por `02_bloqueio.sql` e por `03_serializable.sql`.

| Cenário | Resultado |
| --- | --- |
| `01_anomalia` | os dois entram (2 alunos para 1 vaga) |
| `02_bloqueio` | o segundo espera e recebe "sem vagas" |
| `03_serializable` | o segundo recebe erro 40001; rodando de novo, recebe "sem vagas" |

A comparação entre as duas correções está no fim do `concorrencia/04_conferir.sql`.

## Segurança

Usuários de teste criados pelo `06_seguranca.sql`:

| Usuário | Senha | Papel |
| --- | --- | --- |
| `aluno_26000001` | `aluno` | aluno (RA 26000001) |
| `aluno_26000002` | `aluno` | aluno (RA 26000002) |
| `usuario_secretaria` | `secretaria` | secretaria |
| `usuario_coordenacao` | `coordenacao` | coordenacao |

Para ver a RLS funcionando, entre como aluno e consulte o histórico. Só aparecem as notas dele:

```sh
docker compose exec postgres psql -h localhost -U aluno_26000001 -d matricula \
  -c "SELECT aluno, periodo, codigo_disciplina, media_final FROM academico.vw_historico"
```

## Índices (EXPLAIN antes e depois)

```sh
docker compose exec -T postgres psql -U bd2 -d matricula \
  < evidencias/explain_indices.sql > evidencias/explain_resultado.txt
```

O script coloca 100 mil alunos e 300 mil matrículas a mais dentro de uma transação, mede e dá ROLLBACK. A base não muda. Os números medidos estão nos comentários do `05_indices.sql`.

| Índice | Antes | Depois |
| --- | --- | --- |
| `ix_tb_matricula_turma_ativa` (parcial) | 11,4 ms | 0,20 ms |
| `ix_tb_log_matricula_matricula` | 11,8 ms | 0,04 ms |
| `ix_tb_aluno_nome_lower` | 26,4 ms | 0,59 ms |
| `ix_tb_matricula_data` | 12,3 ms | 0,49 ms |

## Backup e restauração

```sh
sh operacao/backup.sh       # gera backups/papeis_*.sql e backups/matricula_*.dump
sh operacao/restaurar.sh    # APAGA o banco matricula e restaura o backup mais recente
```

Teste usado na apresentação: fazer o backup, apagar uma tabela (`DROP TABLE academico.tb_historico CASCADE;`), rodar o `restaurar.sh` e conferir as contagens que ele mostra no final.

No Windows, rode os `.sh` pelo Git Bash ou pelo WSL.
