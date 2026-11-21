# Sistema de Matrícula Acadêmica

Projeto de Banco de Dados II (CCO072) do IESB, semestre 2026/2.

## Arquivos

| Arquivo | Conteúdo |
| --- | --- |
| `01_ddl.sql` | Criação do schema, tabelas e restrições |
| `02_carga.sql` | Carga dos dados |
| `03_consultas.sql` | Consultas comentadas |

## Como rodar

Em um PostgreSQL 16, execute os arquivos na ordem:

```sh
createdb matricula
psql -d matricula -f 01_ddl.sql
psql -d matricula -f 02_carga.sql
psql -d matricula -f 03_consultas.sql
```
