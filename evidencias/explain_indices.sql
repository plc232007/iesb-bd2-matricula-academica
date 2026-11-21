-- =====================================================================
-- evidencias/explain_indices.sql  ·  EXPLAIN antes e depois de cada índice
-- MARCO 2 · Frente: Modelagem Física e Desempenho
--
-- Como rodar (com o banco já criado pelos scripts 01 a 07) e salvar a saída:
--     docker compose exec -T postgres psql -U bd2 -d matricula \
--         < evidencias/explain_indices.sql > evidencias/explain_resultado.txt
--
-- TUDO roda dentro de BEGIN ... ROLLBACK. No final, os dados extras, a
-- desativação do gatilho e os DROP INDEX são desfeitos, e a base volta a
-- ficar igual ao que o 05_indices.sql deixou.
--
-- Por que inserir dados extras: com 440 matrículas a tabela cabe em
-- poucas páginas e o seq scan é mais barato que qualquer índice. O
-- planejador escolhe certo e não usaria o índice. Para o ganho aparecer,
-- simulamos o tamanho de alguns semestres de uma faculdade de verdade:
-- 2.000 turmas, 100 mil alunos, 300 mil matrículas e 300 mil logs.
--
-- Como ler o EXPLAIN (ANALYZE, BUFFERS):
--   Seq Scan          leu a tabela inteira
--   Index Scan        usou o índice e depois buscou a linha na tabela
--   Index Only Scan   respondeu só com o índice, sem ir na tabela
--   Bitmap ... Scan   usou o índice para marcar as páginas e leu só elas
--   Buffers: shared hit=N   páginas de 8 kB lidas (da memória). Quanto
--                           menos, menos trabalho. Não depende do cache.
--   Execution Time    tempo real da execução
-- =====================================================================

SET search_path TO academico, public;
\timing off

BEGIN;

-- Desligado só dentro desta transação, para a carga em massa não esbarrar
-- no limite de vagas. O ROLLBACK religa.
ALTER TABLE tb_matricula_aluno DISABLE TRIGGER tg_tb_valida_vaga;

-- 2.000 turmas extras no período 2026.2, com vagas de sobra
INSERT INTO tb_turma (codigo, disciplina_id, periodo_id, professor_id, turno, vagas)
SELECT 'EXTRA-' || n,
       (SELECT disciplina_id FROM tb_disciplinas ORDER BY disciplina_id OFFSET n % 12 LIMIT 1),
       (SELECT periodo_id FROM tb_periodo_letivo WHERE ano = 2026 AND semestre = 2),
       (SELECT professor_id FROM tb_professor ORDER BY professor_id OFFSET n % 8 LIMIT 1),
       'NOTURNO', 500
FROM generate_series(1, 2000) n;

-- 100 mil alunos extras (CPF começando em 3 para não bater com a carga normal)
INSERT INTO tb_aluno (curso_id, curriculo_id, matricula, nome, cpf, email, nascimento, ingresso)
SELECT c.curso_id, cu.curriculo_id,
       '9' || lpad(n::text, 7, '0'),
       (ARRAY['Ana','Bruno','Carla','Diego','Elisa','Felipe','Gabriela','Henrique','Isabela','João',
              'Karen','Lucas','Mariana','Nicolas','Olívia','Pedro','Rafaela','Samuel','Tatiana','Vitor'])[n % 20 + 1]
         || ' ' ||
       (ARRAY['Almeida','Barbosa','Cardoso','Dias','Ferreira','Gomes','Lima','Machado','Nunes','Oliveira',
              'Pereira','Ramos','Santos','Teixeira','Vieira','Araújo','Castro','Freitas','Melo','Rocha'])[(n / 20) % 20 + 1]
         || ' ' ||
       (ARRAY['Costa','Duarte','Fonseca','Guedes','Lopes','Marques','Moreira','Peixoto','Ribeiro','Siqueira',
              'Tavares','Xavier','Azevedo','Batista','Correia','Farias','Monteiro','Pinto','Soares','Zanetti'])[(n / 400) % 20 + 1],
       lpad((30000000000 + n)::text, 11, '0'),
       'extra' || n || '@iesb.edu.br',
       DATE '2000-01-01' + n % 3000,
       DATE '2026-08-03'
FROM generate_series(1, 100000) n
JOIN tb_curso c      ON c.codigo_curso = 'CCO'
JOIN tb_curriculo cu ON cu.curso_id = c.curso_id AND cu.ativo;

-- 3 matrículas por aluno extra = 300 mil. 1 em cada 10 fica CANCELADO.
-- Datas espalhadas por uns 600 dias, para o índice de data ter o que filtrar.
INSERT INTO tb_matricula_aluno (aluno_id, turma_id, data_matricula, status)
SELECT a.aluno_id,
       t.turma_id,
       TIMESTAMPTZ '2025-01-01 08:00' + make_interval(days => (a.aluno_id * k * 37) % 600,
                                                      mins => (a.aluno_id * k) % 600),
       CASE WHEN (a.aluno_id + k) % 10 = 0 THEN 'CANCELADO'::status_mat_t
            ELSE 'MATRICULADO'::status_mat_t END
FROM tb_aluno a
CROSS JOIN generate_series(1, 3) k
JOIN tb_turma t ON t.codigo = 'EXTRA-' || ((a.aluno_id * 3 + k) % 2000 + 1)
WHERE a.matricula LIKE '9%';

-- 1 log por matrícula extra
INSERT INTO tb_log_matricula (matricula_aluno_id, acao, ocorrido_em)
SELECT matricula_aluno_id, 'MATRICULA', data_matricula
FROM tb_matricula_aluno m
JOIN tb_turma t USING (turma_id)
WHERE t.codigo LIKE 'EXTRA-%';

ANALYZE tb_turma;
ANALYZE tb_aluno;
ANALYZE tb_matricula_aluno;
ANALYZE tb_log_matricula;

SELECT (SELECT count(*) FROM tb_aluno)           AS alunos,
       (SELECT count(*) FROM tb_turma)           AS turmas,
       (SELECT count(*) FROM tb_matricula_aluno) AS matriculas,
       (SELECT count(*) FROM tb_log_matricula)   AS logs;

-- Valores usados nos testes (guardados em variáveis do psql com \gset)
SELECT turma_id AS turma_teste FROM tb_turma WHERE codigo = 'EXTRA-1000' \gset
SELECT max(matricula_aluno_id) / 2 AS matricula_teste FROM tb_matricula_aluno \gset


\echo '====================================================================='
\echo '1) ix_tb_matricula_turma_ativa (PARCIAL) - vagas ocupadas de uma turma'
\echo '====================================================================='
DROP INDEX IF EXISTS ix_tb_matricula_turma_ativa;
\echo '--- ANTES'
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM tb_matricula_aluno
WHERE turma_id = :turma_teste AND status = 'MATRICULADO';

CREATE INDEX ix_tb_matricula_turma_ativa ON tb_matricula_aluno (turma_id)
    WHERE status = 'MATRICULADO';
ANALYZE tb_matricula_aluno;
\echo '--- DEPOIS'
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM tb_matricula_aluno
WHERE turma_id = :turma_teste AND status = 'MATRICULADO';

\echo '--- Tamanho do índice parcial comparado com um índice comum na mesma coluna'
CREATE INDEX ix_comparacao_total ON tb_matricula_aluno (turma_id);
SELECT pg_size_pretty(pg_relation_size('ix_tb_matricula_turma_ativa')) AS parcial,
       pg_size_pretty(pg_relation_size('ix_comparacao_total'))         AS comum;
DROP INDEX ix_comparacao_total;


\echo '====================================================================='
\echo '2) ix_tb_log_matricula_matricula - log de uma matrícula'
\echo '====================================================================='
DROP INDEX IF EXISTS ix_tb_log_matricula_matricula;
\echo '--- ANTES'
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM tb_log_matricula WHERE matricula_aluno_id = :matricula_teste;

CREATE INDEX ix_tb_log_matricula_matricula ON tb_log_matricula (matricula_aluno_id);
ANALYZE tb_log_matricula;
\echo '--- DEPOIS'
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM tb_log_matricula WHERE matricula_aluno_id = :matricula_teste;


\echo '====================================================================='
\echo '3) ix_tb_aluno_nome_lower (EXPRESSÃO) - busca pelo começo do nome'
\echo '====================================================================='
DROP INDEX IF EXISTS ix_tb_aluno_nome_lower;
\echo '--- ANTES'
EXPLAIN (ANALYZE, BUFFERS)
SELECT aluno_id, matricula, nome FROM tb_aluno
WHERE lower(nome) LIKE 'ana almeida%';

CREATE INDEX ix_tb_aluno_nome_lower ON tb_aluno (lower(nome) text_pattern_ops);
ANALYZE tb_aluno;
\echo '--- DEPOIS'
EXPLAIN (ANALYZE, BUFFERS)
SELECT aluno_id, matricula, nome FROM tb_aluno
WHERE lower(nome) LIKE 'ana almeida%';


\echo '====================================================================='
\echo '4) ix_tb_matricula_data - matrículas feitas num dia'
\echo '====================================================================='
DROP INDEX IF EXISTS ix_tb_matricula_data;
\echo '--- ANTES'
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM tb_matricula_aluno
WHERE data_matricula >= '2025-03-10' AND data_matricula < '2025-03-11';

CREATE INDEX ix_tb_matricula_data ON tb_matricula_aluno (data_matricula);
ANALYZE tb_matricula_aluno;
\echo '--- DEPOIS'
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM tb_matricula_aluno
WHERE data_matricula >= '2025-03-10' AND data_matricula < '2025-03-11';

ROLLBACK;
