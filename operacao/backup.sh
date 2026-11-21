#!/bin/sh
# =====================================================================
# operacao/backup.sh  ·  Backup do banco matricula
# MARCO 2 · Frente: Administração e Operação
#
# Rode da raiz do projeto, com o Docker no ar:
#     sh operacao/backup.sh
# Gera dois arquivos em backups/ (a pasta está no .gitignore):
#     papeis_AAAAMMDD_HHMM.sql      usuários e papéis (aluno, secretaria...)
#     matricula_AAAAMMDD_HHMM.dump  o banco inteiro (formato custom)
#
# Por que dois arquivos: o pg_dump salva UM banco, e papéis não pertencem a
# um banco, pertencem ao servidor inteiro. Sem o papeis.sql, a restauração
# num servidor novo daria erro em todo GRANT e em toda POLICY, porque os
# papéis citados não existiriam. O pg_dumpall --roles-only salva só eles.
#
# Formato custom (-Fc): sai compactado e o pg_restore consegue escolher o
# que restaurar. Um .sql puro só daria para rodar inteiro.
# =====================================================================
set -e

mkdir -p backups
DATA=$(date +%Y%m%d_%H%M)

docker compose exec -T postgres pg_dumpall -U bd2 --roles-only > "backups/papeis_$DATA.sql"
docker compose exec -T postgres pg_dump -U bd2 -d matricula -Fc > "backups/matricula_$DATA.dump"

echo "Backup gerado:"
ls -lh "backups/papeis_$DATA.sql" "backups/matricula_$DATA.dump"
