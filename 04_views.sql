-- =====================================================================
-- 04_views.sql  ·  Views e materialized view  ·  BD2 · CCO072 · IESB
-- MARCO 2 · Frente: Administração e Operação
-- Rode depois do 01_ddl.sql e do 02_carga.sql. Pode rodar de novo sem erro.
--
--  vw_oferta        turmas oferecidas, com professor e horários numa linha só
--  vw_vagas         vagas, ocupadas e livres de cada turma
--  vw_historico     boletim do aluno (respeita a RLS do 06_seguranca.sql)
--  mv_indicadores   aprovação e média por disciplina e período (materializada)
--
-- View comum não guarda dados: é uma consulta salva com nome. Toda vez que
-- alguém faz SELECT nela, o banco roda a consulta de novo nas tabelas.
-- Materialized view guarda o resultado em disco. A leitura é rápida, mas o
-- conteúdo só muda quando rodamos REFRESH.
-- =====================================================================

SET search_path TO academico, public;

-- ---------------------------------------------------------------------
-- 1) vw_oferta: o que o aluno vê na hora de escolher turma
-- ---------------------------------------------------------------------
-- Uma turma tem até 2 linhas em tb_turma_horario (ex.: seg e qua). O
-- string_agg junta essas linhas num texto só, tipo "seg 19:00-20:50 A101".
-- LEFT JOIN no horário: turma ainda sem horário cadastrado continua na oferta
-- (aparece com horarios = NULL) em vez de sumir.
CREATE OR REPLACE VIEW vw_oferta AS
SELECT t.turma_id,
       pl.ano || '.' || pl.semestre                AS periodo,
       t.codigo                                    AS turma,
       d.codigo_disciplina,
       d.nome_disciplina,
       d.ch_total,
       p.nome                                      AS professor,
       t.turno,
       t.vagas,
       string_agg((ARRAY['dom','seg','ter','qua','qui','sex','sab'])[th.dia_semana]
                  || ' ' || to_char(th.horario_inicio, 'HH24:MI')
                  || '-' || to_char(th.horario_fim, 'HH24:MI')
                  || ' ' || s.codigo_sala,
                  ', ' ORDER BY th.dia_semana)     AS horarios
FROM   tb_turma t
JOIN   tb_periodo_letivo pl     ON pl.periodo_id   = t.periodo_id
JOIN   tb_disciplinas d         ON d.disciplina_id = t.disciplina_id
JOIN   tb_professor p           ON p.professor_id  = t.professor_id
LEFT   JOIN tb_turma_horario th ON th.turma_id     = t.turma_id
LEFT   JOIN tb_sala s           ON s.sala_id       = th.sala_id
GROUP  BY t.turma_id, pl.ano, pl.semestre, d.disciplina_id, p.nome;

-- ---------------------------------------------------------------------
-- 2) vw_vagas: ocupação de cada turma
-- ---------------------------------------------------------------------
-- Conta só status MATRICULADO, que é a mesma regra do gatilho
-- fn_tb_valida_vaga. Trancado e cancelado liberam a vaga.
-- count(m.matricula_aluno_id) e não count(*): turma sem nenhuma matrícula
-- tem que dar 0, e com count(*) daria 1 por causa da linha da própria turma.
CREATE OR REPLACE VIEW vw_vagas AS
SELECT t.turma_id,
       pl.ano || '.' || pl.semestre                      AS periodo,
       t.codigo                                          AS turma,
       d.codigo_disciplina,
       t.vagas,
       count(m.matricula_aluno_id)                       AS ocupadas,
       t.vagas - count(m.matricula_aluno_id)             AS livres,
       CASE WHEN count(m.matricula_aluno_id) >= t.vagas
            THEN 'LOTADA' ELSE 'COM VAGA' END            AS situacao
FROM   tb_turma t
JOIN   tb_periodo_letivo pl       ON pl.periodo_id   = t.periodo_id
JOIN   tb_disciplinas d           ON d.disciplina_id = t.disciplina_id
LEFT   JOIN tb_matricula_aluno m  ON m.turma_id      = t.turma_id
                                 AND m.status        = 'MATRICULADO'
GROUP  BY t.turma_id, pl.ano, pl.semestre, d.codigo_disciplina;

-- ---------------------------------------------------------------------
-- 3) vw_historico: boletim (notas, média, frequência e situação)
-- ---------------------------------------------------------------------
-- security_invoker = true (PostgreSQL 15+) faz a view rodar com as
-- permissões de QUEM CONSULTA, e não do dono da view. Sem isso, um aluno
-- consultando a view leria tb_historico como se fosse o dono (bd2) e a
-- política de RLS seria ignorada: ele veria o histórico de todo mundo.
-- O teste disso está no fim do 06_seguranca.sql.
CREATE OR REPLACE VIEW vw_historico WITH (security_invoker = true) AS
SELECT a.aluno_id,
       a.matricula,
       a.nome                          AS aluno,
       pl.ano || '.' || pl.semestre    AS periodo,
       d.codigo_disciplina,
       d.nome_disciplina,
       t.codigo                        AS turma,
       m.status                        AS status_matricula,
       h.nota_a1,
       h.nota_a2,
       h.nota_a3,
       h.media_final,
       h.frequencia,
       h.situacao
FROM   tb_historico h
JOIN   tb_matricula_aluno m ON m.matricula_aluno_id = h.matricula_aluno_id
JOIN   tb_aluno a           ON a.aluno_id           = m.aluno_id
JOIN   tb_turma t           ON t.turma_id           = m.turma_id
JOIN   tb_periodo_letivo pl ON pl.periodo_id        = t.periodo_id
JOIN   tb_disciplinas d     ON d.disciplina_id      = t.disciplina_id;

-- ---------------------------------------------------------------------
-- 4) mv_indicadores: números que a coordenação acompanha
-- ---------------------------------------------------------------------
-- Uma linha por disciplina em cada período: quantos cursaram, quantos
-- passaram, reprovaram por nota ou por falta, média e taxa de aprovação.
-- A taxa só considera quem já tem situação final (ignora CURSANDO);
-- NULLIF evita divisão por zero no período corrente, em que todos estão
-- cursando.
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_indicadores AS
SELECT pl.periodo_id,
       pl.ano || '.' || pl.semestre                                   AS periodo,
       d.disciplina_id,
       d.codigo_disciplina,
       d.nome_disciplina,
       count(*)                                                       AS matriculas,
       count(*) FILTER (WHERE h.situacao = 'CURSANDO')                AS cursando,
       count(*) FILTER (WHERE h.situacao = 'APROVADO')                AS aprovados,
       count(*) FILTER (WHERE h.situacao = 'REPROVADO_NOTA')          AS reprovados_nota,
       count(*) FILTER (WHERE h.situacao = 'REPROVADO_FALTA')         AS reprovados_falta,
       round(avg(h.media_final), 2)                                   AS media,
       round(100.0 * count(*) FILTER (WHERE h.situacao = 'APROVADO')
             / NULLIF(count(*) FILTER (WHERE h.situacao <> 'CURSANDO'), 0), 1) AS pct_aprovacao
FROM   tb_historico h
JOIN   tb_matricula_aluno m ON m.matricula_aluno_id = h.matricula_aluno_id
JOIN   tb_turma t           ON t.turma_id           = m.turma_id
JOIN   tb_periodo_letivo pl ON pl.periodo_id        = t.periodo_id
JOIN   tb_disciplinas d     ON d.disciplina_id      = t.disciplina_id
GROUP  BY pl.periodo_id, pl.ano, pl.semestre, d.disciplina_id;

-- O REFRESH ... CONCURRENTLY exige um índice ÚNICO na materialized view.
-- É por ele que o banco descobre qual linha mudou entre o resultado antigo
-- e o novo.
CREATE UNIQUE INDEX IF NOT EXISTS uq_mv_indicadores
    ON mv_indicadores (periodo_id, disciplina_id);

-- POLÍTICA DE ATUALIZAÇÃO
-- Os indicadores só mudam quando a secretaria lança nota ou fecha a
-- situação dos alunos, o que acontece no fim de cada bimestre (A1, A2 e
-- P3). Na matrícula, durante o semestre, eles não mudam. Então não faz
-- sentido recalcular a cada consulta (seria uma view comum) nem por
-- gatilho a cada INSERT. A regra do grupo é:
--   * rodar o REFRESH depois de cada fechamento de notas;
--   * usar CONCURRENTLY, porque ele não bloqueia quem está lendo a view
--     durante a atualização (o REFRESH normal bloqueia todo mundo até
--     terminar). O custo é ser um pouco mais lento e precisar do índice
--     único acima.
-- Comando usado pela secretaria depois de lançar as notas:
--     REFRESH MATERIALIZED VIEW CONCURRENTLY academico.mv_indicadores;
-- Entre um REFRESH e outro, os números podem estar defasados. Para
-- indicador de aprovação isso não é problema, porque ninguém decide
-- matrícula com base nele.
REFRESH MATERIALIZED VIEW mv_indicadores;

-- ---------------------------------------------------------------------
-- Conferência rápida
-- ---------------------------------------------------------------------
SELECT * FROM vw_vagas WHERE periodo = '2026.2' ORDER BY turma;
SELECT periodo, codigo_disciplina, matriculas, aprovados, pct_aprovacao
FROM   mv_indicadores ORDER BY periodo, codigo_disciplina;
