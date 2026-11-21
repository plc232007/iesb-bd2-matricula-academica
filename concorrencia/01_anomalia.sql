-- =====================================================================
-- concorrencia/01_anomalia.sql  ·  A disputa pela última vaga (o problema)
-- MARCO 2 · Frente: Transações e Concorrência
--
-- Abra DOIS terminais. Rode o 00_preparar.sql e depois, em menos de 5
-- segundos entre um e outro:
--   terminal 1:  docker compose exec -T postgres psql -U bd2 -d matricula -v aluno=26000101 < concorrencia/01_anomalia.sql
--   terminal 2:  docker compose exec -T postgres psql -U bd2 -d matricula -v aluno=26000102 < concorrencia/01_anomalia.sql
-- Depois confira com o 04_conferir.sql.
--
-- RESULTADO ESPERADO: os dois terminais mostram COMMIT e a turma fica com
-- 2 alunos para 1 vaga (overbooking).
--
-- POR QUE ACONTECE
-- O gatilho fn_tb_valida_vaga faz um SELECT count(*) para ver se ainda tem
-- vaga e depois deixa o INSERT acontecer. Nível de isolamento padrão do
-- PostgreSQL: READ COMMITTED. Nele cada comando só enxerga o que já foi
-- confirmado (COMMIT).
--   tempo  sessão A (aluno 101)              sessão B (aluno 102)
--   t0     BEGIN; INSERT
--          gatilho conta 0 ocupadas -> ok
--   t1                                       BEGIN; INSERT
--                                            gatilho conta 0 ocupadas -> ok
--                                            (o INSERT de A ainda não tem COMMIT,
--                                             então B não enxerga)
--   t5     COMMIT
--   t6                                       COMMIT
-- Os dois "viram" a vaga livre. Nada travou B, porque contar linhas com
-- SELECT não bloqueia ninguém, e os dois INSERTs são de linhas diferentes.
-- É o problema clássico de "ler, decidir e gravar" sem proteger a leitura.
-- =====================================================================

SET search_path TO academico, public;

BEGIN;   -- READ COMMITTED (padrão)

INSERT INTO tb_matricula_aluno (aluno_id, turma_id)
SELECT a.aluno_id, t.turma_id
FROM   tb_aluno a, tb_turma t
WHERE  a.matricula = :'aluno' AND t.codigo = 'BD2-DEMO';

-- Segura a transação aberta por 5 segundos, simulando o tempo entre o
-- aluno clicar em "matricular" e o sistema confirmar. É nessa janela que a
-- outra sessão entra.
SELECT pg_sleep(5);

COMMIT;
