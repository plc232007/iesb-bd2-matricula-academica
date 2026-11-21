-- =====================================================================
-- 05_indices.sql  ·  Índices de desempenho  ·  BD2 · CCO072 · IESB
-- MARCO 2 · Frente: Modelagem Física e Desempenho
-- Rode depois do 04_views.sql. Pode rodar de novo sem erro.
--
-- O PostgreSQL só cria índice sozinho para PRIMARY KEY, UNIQUE e EXCLUDE.
-- Chave estrangeira NÃO ganha índice automático. Os índices abaixo foram
-- escolhidos olhando as consultas que o sistema faz o tempo todo.
--
-- A medição (EXPLAIN ANALYZE antes e depois de cada índice) está em
--     evidencias/explain_indices.sql      (script que mede)
--     evidencias/explain_resultado.txt    (saída completa do script)
-- Com só 440 matrículas, o banco prefere ler a tabela inteira e nenhum
-- índice faz diferença. Por isso o script de medição coloca 100 mil alunos
-- e 300 mil matrículas a mais dentro de uma transação, mede e dá ROLLBACK
-- no final. A base normal não muda.
-- Os tempos abaixo são de uma execução na máquina do grupo e mudam um
-- pouco a cada vez. O número de páginas lidas (Buffers) é mais estável e
-- é o que melhor mostra o trabalho que o índice economiza.
-- =====================================================================

SET search_path TO academico, public;

-- ---------------------------------------------------------------------
-- 1) ÍNDICE PARCIAL: matrículas ativas por turma
-- ---------------------------------------------------------------------
-- Consulta que ele atende (é a mesma que o gatilho fn_tb_valida_vaga roda
-- em TODO insert de matrícula, e a mesma da vw_vagas):
--     SELECT count(*) FROM tb_matricula_aluno
--     WHERE turma_id = ? AND status = 'MATRICULADO';
-- Por que parcial: só as matrículas MATRICULADO ocupam vaga. As trancadas e
-- canceladas nunca são contadas, então não precisam estar no índice. Com o
-- WHERE, o índice fica menor e o banco só o usa quando a consulta também
-- filtra status = 'MATRICULADO'.
-- Medido: 11,4 ms -> 0,20 ms. Antes: Parallel Seq Scan lendo 2.210 páginas
-- (a tabela inteira). Depois: Bitmap Index Scan, 153 páginas.
-- O índice parcial ficou só uns 7% menor que um índice comum (1.904 kB
-- contra 2.040 kB), porque na massa de teste só 10% das matrículas não
-- estão MATRICULADO. Numa base real, com vários semestres encerrados, a
-- diferença seria maior. O ganho principal continua sendo a busca.
CREATE INDEX IF NOT EXISTS ix_tb_matricula_turma_ativa
    ON tb_matricula_aluno (turma_id)
    WHERE status = 'MATRICULADO';

-- ---------------------------------------------------------------------
-- 2) FK do log: tb_log_matricula.matricula_aluno_id
-- ---------------------------------------------------------------------
-- Consulta que ele atende: "o que aconteceu com esta matrícula?"
--     SELECT * FROM tb_log_matricula WHERE matricula_aluno_id = ?;
-- Também ajuda no ON DELETE RESTRICT: antes de apagar uma matrícula, o
-- banco procura se existe log apontando para ela. Sem índice, essa busca lê
-- o log inteiro, e o log só cresce (nunca apagamos auditoria).
-- Medido: 11,8 ms -> 0,04 ms. Antes: 4.626 páginas. Depois: 4 páginas.
CREATE INDEX IF NOT EXISTS ix_tb_log_matricula_matricula
    ON tb_log_matricula (matricula_aluno_id);

-- ---------------------------------------------------------------------
-- 3) ÍNDICE DE EXPRESSÃO: busca de aluno pelo começo do nome
-- ---------------------------------------------------------------------
-- Consulta que ele atende (tela da secretaria, busca sem diferenciar
-- maiúscula de minúscula):
--     SELECT ... FROM tb_aluno WHERE lower(nome) LIKE 'ana almeida%';
-- O índice guarda lower(nome) já calculado. Um índice só em "nome" não
-- serviria, porque a consulta compara lower(nome), não nome.
-- text_pattern_ops: o índice normal segue a ordenação do idioma (collation)
-- e não serve para LIKE 'abc%'. Com text_pattern_ops ele compara caractere
-- por caractere e passa a servir para busca por prefixo.
-- Só funciona com o % no FIM. LIKE '%almeida' continua lendo a tabela toda.
-- Medido: 26,4 ms -> 0,59 ms. Antes: 1.438 páginas. Depois: 254.
CREATE INDEX IF NOT EXISTS ix_tb_aluno_nome_lower
    ON tb_aluno (lower(nome) text_pattern_ops);

-- ---------------------------------------------------------------------
-- 4) Data da matrícula
-- ---------------------------------------------------------------------
-- Consulta que ele atende (relatório da secretaria: matrículas feitas num
-- dia ou numa semana do período de matrícula):
--     SELECT count(*) FROM tb_matricula_aluno
--     WHERE data_matricula >= ? AND data_matricula < ?;
-- B-tree guarda os valores em ordem, então serve para intervalo (>=, <,
-- BETWEEN), não só para igualdade.
-- Medido: 12,3 ms -> 0,49 ms para um dia. Antes: 2.210 páginas. Depois: 503.
CREATE INDEX IF NOT EXISTS ix_tb_matricula_data
    ON tb_matricula_aluno (data_matricula);

-- Atualiza as estatísticas para o planejador saber que os índices existem
-- e quantas linhas cada filtro devolve.
ANALYZE tb_matricula_aluno;
ANALYZE tb_log_matricula;
ANALYZE tb_aluno;

-- Lista os índices do schema (os de PK/UNIQUE também aparecem)
SELECT tablename, indexname
FROM   pg_indexes
WHERE  schemaname = 'academico'
ORDER  BY tablename, indexname;
