#!/bin/sh
# =====================================================================
# operacao/restaurar.sh  ·  Restauração do banco matricula a partir do backup
# MARCO 2 · Frente: Administração e Operação
#
# Rode da raiz do projeto, com o Docker no ar:
#     sh operacao/restaurar.sh                                 (usa o backup mais recente)
#     sh operacao/restaurar.sh backups/matricula_20261121_1530.dump
#
# ATENÇÃO: APAGA o banco matricula atual e cria de novo a partir do dump.
#
# Passos:
#   1. recria os papéis (no mesmo servidor eles já existem e o psql só
#      avisa "already exists" e segue; num servidor novo é aqui que eles
#      nascem)
#   2. derruba as conexões abertas e apaga o banco (dropdb --force)
#   3. cria o banco vazio
#   4. pg_restore recria tudo na ordem certa: extensão, tipos, tabelas,
#      dados, índices, FKs, gatilho, views, RLS, GRANTs e o conteúdo da
#      materialized view
#   5. mostra as contagens para comparar com as de antes
# =====================================================================
set -e

DUMP=${1:-$(ls -t backups/matricula_*.dump | head -1)}
PAPEIS=$(echo "$DUMP" | sed 's/matricula_/papeis_/; s/\.dump$/.sql/')

echo "Restaurando $DUMP (papéis: $PAPEIS)"

docker compose exec -T postgres psql -U bd2 -d postgres -q < "$PAPEIS" 2>&1 | grep -vE "already exists|already been granted" || true
docker compose exec -T postgres dropdb -U bd2 --if-exists --force matricula
docker compose exec -T postgres createdb -U bd2 matricula
docker compose exec -T postgres pg_restore -U bd2 -d matricula < "$DUMP"

docker compose exec -T postgres psql -U bd2 -d matricula -c "
SELECT (SELECT count(*) FROM academico.tb_aluno)           AS alunos,
       (SELECT count(*) FROM academico.tb_turma)           AS turmas,
       (SELECT count(*) FROM academico.tb_matricula_aluno) AS matriculas,
       (SELECT count(*) FROM academico.tb_historico)       AS historicos,
       (SELECT count(*) FROM academico.mv_indicadores)     AS linhas_indicadores,
       (SELECT count(*) FROM pg_policies WHERE schemaname = 'academico') AS politicas_rls;"
