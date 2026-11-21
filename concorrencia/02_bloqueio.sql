-- =====================================================================
-- concorrencia/02_bloqueio.sql  ·  Correção 1: bloqueio explícito (FOR UPDATE)
-- MARCO 2 · Frente: Transações e Concorrência
--
-- Mesma forma de rodar do 01 (00_preparar.sql antes, dois terminais):
--   terminal 1:  docker compose exec -T postgres psql -U bd2 -d matricula -v aluno=26000101 < concorrencia/02_bloqueio.sql
--   terminal 2:  docker compose exec -T postgres psql -U bd2 -d matricula -v aluno=26000102 < concorrencia/02_bloqueio.sql
--
-- RESULTADO ESPERADO: o terminal 2 fica PARADO até o 1 dar COMMIT. Depois
-- ele continua e recebe "Turma ... sem vagas (1 de 1)". Fica 1 aluno na turma.
--
-- COMO FUNCIONA
-- SELECT ... FOR UPDATE trava a LINHA da turma em tb_turma até o fim da
-- transação. Outra sessão que pedir FOR UPDATE na mesma linha espera.
-- Cada matrícula na mesma turma passa a acontecer uma de cada vez:
--   tempo  sessão A                         sessão B
--   t0     FOR UPDATE na BD2-DEMO -> pega
--          INSERT, gatilho conta 0 -> ok
--   t1                                      FOR UPDATE na BD2-DEMO -> ESPERA
--   t5     COMMIT (solta a trava)
--   t5                                      pega a trava
--                                           INSERT, gatilho conta 1 -> recusa
-- Por que B conta 1 dessa vez: em READ COMMITTED cada comando tira uma foto
-- nova dos dados. O INSERT de B começa depois do COMMIT de A, então ele
-- enxerga a matrícula de A.
-- Só a linha da BD2-DEMO fica travada. Matrícula em outra turma não espera.
--
-- Ficou no script da sessão para dar para comparar com o 01 sem mexer no
-- gatilho. No sistema de verdade o certo é colocar o FOR UPDATE dentro do
-- fn_tb_valida_vaga, no SELECT das vagas, para nenhum programa esquecer.
-- =====================================================================

SET search_path TO academico, public;

BEGIN;   -- continua READ COMMITTED

SELECT turma_id, vagas
FROM   tb_turma
WHERE  codigo = 'BD2-DEMO'
FOR UPDATE;

INSERT INTO tb_matricula_aluno (aluno_id, turma_id)
SELECT a.aluno_id, t.turma_id
FROM   tb_aluno a, tb_turma t
WHERE  a.matricula = :'aluno' AND t.codigo = 'BD2-DEMO';

SELECT pg_sleep(5);

-- Na sessão que perdeu, o INSERT deu erro e a transação já foi abortada.
-- Aí o COMMIT vira ROLLBACK sozinho (o psql mostra ROLLBACK).
COMMIT;
