-- =====================================================================
-- concorrencia/03_serializable.sql  ·  Correção 2: nível de isolamento SERIALIZABLE
-- MARCO 2 · Frente: Transações e Concorrência
--
-- Mesma forma de rodar do 01 (00_preparar.sql antes, dois terminais):
--   terminal 1:  docker compose exec -T postgres psql -U bd2 -d matricula -v aluno=26000101 < concorrencia/03_serializable.sql
--   terminal 2:  docker compose exec -T postgres psql -U bd2 -d matricula -v aluno=26000102 < concorrencia/03_serializable.sql
--
-- RESULTADO ESPERADO: nenhum dos dois espera. Um dá COMMIT e o outro
-- recebe o erro
--     ERROR: could not serialize access due to read/write dependencies
--     among transactions   (SQLSTATE 40001)
-- Fica 1 aluno na turma. Se rodar de novo a sessão que falhou (a
-- RETENTATIVA), ela já enxerga a turma cheia e recebe "sem vagas".
--
-- COMO FUNCIONA
-- Em SERIALIZABLE o PostgreSQL garante que o resultado final é igual ao de
-- ALGUMA ordem em fila das transações (primeiro A e depois B, ou o
-- contrário). Ele não trava a leitura. Ele anota o que cada transação leu
-- e, se perceber que A leu algo que B escreveu e B leu algo que A escreveu,
-- cancela uma das duas. Em fila, a segunda veria a primeira e seria
-- recusada pelo gatilho. Como as duas aconteceram juntas, não existe fila
-- que explique as duas terem passado.
--
-- Por que não REPEATABLE READ: nele cada transação usa uma foto fixa do
-- começo da transação. A e B continuam vendo 0 ocupadas, cada uma insere
-- uma linha diferente, não tem conflito de escrita na mesma linha e as
-- duas passam. O overbooking continua (é a anomalia chamada write skew).
-- Só o SERIALIZABLE detecta esse caso.
-- =====================================================================

SET search_path TO academico, public;

BEGIN ISOLATION LEVEL SERIALIZABLE;

INSERT INTO tb_matricula_aluno (aluno_id, turma_id)
SELECT a.aluno_id, t.turma_id
FROM   tb_aluno a, tb_turma t
WHERE  a.matricula = :'aluno' AND t.codigo = 'BD2-DEMO';

SELECT pg_sleep(5);

COMMIT;
