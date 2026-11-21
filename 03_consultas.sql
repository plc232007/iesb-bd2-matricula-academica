-- =====================================================================
-- 03_consultas.sql  ·  10 consultas de complexidade crescente
-- BD2 · CCO072 · IESB · 2026/2          Rode depois do 01_ddl.sql e do 02_carga.sql
--
--  #   Técnica principal
--  1   SELECT / WHERE / ORDER BY / LIMIT (+ subconsulta escalar)
--  2   JOIN interno entre várias tabelas
--  3   GROUP BY + HAVING + FILTER
--  4   JUNÇÃO EXTERNA COM AGREGAÇÃO (LEFT JOIN + COUNT)            [obrigatória]
--  5   Anti-join: NOT EXISTS (e a armadilha do NOT IN)
--  6   CTE (WITH) + agregações condicionais
--  7   RECURSIVA: árvore de pré-requisitos de uma disciplina        [obrigatória]
--  8   RECURSIVA: disciplinas que um aluno JÁ PODE cursar           [obrigatória]
--  9   JANELA: ranking + percentil (RANK, PERCENT_RANK, NTILE)      [obrigatória]
-- 10   JANELA: LAG para a evolução do rendimento por período        [obrigatória]
-- =====================================================================

SET search_path TO academico, public;

-- =====================================================================
-- CONSULTA 1 — Alunos do CCO que ingressaram em 2026, em ordem alfabética
-- Técnica: o básico. WHERE filtra linhas, ORDER BY ordena, LIMIT corta.
--          (SELECT ...) entre parênteses é uma "subconsulta escalar":
--          devolve UM valor (o curso_id do CCO) para usarmos no filtro.
-- Como ler: "traga nome, matrícula e ingresso dos alunos ativos do curso CCO
--            que entraram a partir de 01/01/2026".
-- =====================================================================
SELECT nome, matricula, ingresso
FROM   tb_aluno
WHERE  ativo
  AND  ingresso >= DATE '2026-01-01'
  AND  curso_id = (SELECT curso_id FROM tb_curso WHERE codigo_curso = 'CCO')
ORDER  BY nome
LIMIT  10;

-- =====================================================================
-- CONSULTA 2 — Grade de aulas do período mais recente
-- Técnica: JOIN interno (INNER JOIN). Cada JOIN liga uma chave estrangeira à
--          chave primária da tabela pai. Só aparecem linhas que têm par em
--          TODAS as tabelas.
-- Detalhe: (ARRAY[...])[dia_semana] usa o número do dia (1=domingo) como
--          posição no vetor para mostrar o nome do dia.
-- Como ler: "para cada aula, mostre turma, disciplina, professor, sala, dia e hora".
-- =====================================================================
SELECT t.codigo                                   AS turma,
       d.nome_disciplina                          AS disciplina,
       p.nome                                     AS professor,
       s.codigo_sala                              AS sala,
       (ARRAY['dom','seg','ter','qua','qui','sex','sab'])[th.dia_semana] AS dia,
       th.horario_inicio                          AS inicio,
       th.horario_fim                             AS fim
FROM   tb_turma t
JOIN   tb_periodo_letivo pl ON pl.periodo_id    = t.periodo_id
JOIN   tb_disciplinas d     ON d.disciplina_id  = t.disciplina_id
JOIN   tb_professor p       ON p.professor_id   = t.professor_id
JOIN   tb_turma_horario th  ON th.turma_id      = t.turma_id
JOIN   tb_sala s            ON s.sala_id        = th.sala_id
WHERE  pl.periodo_id = (SELECT periodo_id FROM tb_periodo_letivo
                        ORDER BY data_inicio DESC LIMIT 1)   -- último período cadastrado
ORDER  BY s.codigo_sala, th.dia_semana, th.horario_inicio;

-- =====================================================================
-- CONSULTA 3 — Turmas do período mais recente com ocupação a partir de 80%
-- Técnica: GROUP BY agrupa linhas; funções de agregação (count) resumem cada
--          grupo. HAVING filtra GRUPOS depois de agregados (WHERE filtra
--          linhas antes). FILTER (WHERE ...) conta só as linhas que passam na
--          condição, sem precisar de CASE.
-- Como ler: "por turma, conte matrículas ativas e compare com as vagas".
-- Obs.: trancados ficam de fora da conta (status <> MATRICULADO).
-- =====================================================================
SELECT t.codigo                                              AS turma,
       t.vagas,
       count(*) FILTER (WHERE m.status = 'MATRICULADO')      AS ocupadas,
       round(100.0 * count(*) FILTER (WHERE m.status = 'MATRICULADO') / t.vagas, 1) AS pct_ocupacao
FROM   tb_turma t
JOIN   tb_matricula_aluno m ON m.turma_id = t.turma_id
WHERE  t.periodo_id = (SELECT periodo_id FROM tb_periodo_letivo ORDER BY data_inicio DESC LIMIT 1)
GROUP  BY t.turma_id, t.codigo, t.vagas
HAVING 100.0 * count(*) FILTER (WHERE m.status = 'MATRICULADO') / t.vagas >= 80
ORDER  BY pct_ocupacao DESC;

-- =====================================================================
-- CONSULTA 4 — Carga de cada professor no período mais recente   [JUNÇÃO EXTERNA + AGREGAÇÃO]
-- Técnica: LEFT JOIN mantém TODAS as linhas da tabela da esquerda (professor),
--          mesmo sem par na direita; as colunas do outro lado vêm NULL.
--          Com o INNER JOIN da consulta 2, o professor sem turma sumiria.
-- Pontos de atenção:
--   * A condição do período fica no ON, e não no WHERE. Se ficasse no WHERE,
--     ela descartaria as linhas NULL e o LEFT JOIN viraria um INNER JOIN.
--   * count(t.turma_id) conta só valores NÃO nulos: dá 0 para quem não tem turma.
--     (count(*) daria 1, porque a linha do professor existe.)
-- Como ler: "liste todos os professores com nº de turmas e de alunos ativos".
-- =====================================================================
SELECT p.nome                                           AS professor,
       p.titulacao,
       count(DISTINCT t.turma_id)                       AS turmas,
       count(m.matricula_aluno_id)                      AS alunos_ativos
FROM   tb_professor p
LEFT   JOIN tb_turma t
       ON  t.professor_id = p.professor_id
       AND t.periodo_id   = (SELECT periodo_id FROM tb_periodo_letivo ORDER BY data_inicio DESC LIMIT 1)
LEFT   JOIN tb_matricula_aluno m
       ON  m.turma_id = t.turma_id
       AND m.status   = 'MATRICULADO'
GROUP  BY p.professor_id, p.nome, p.titulacao
ORDER  BY alunos_ativos DESC, p.nome;

-- =====================================================================
-- CONSULTA 5 — Alunos que nunca se matricularam em nada
-- Técnica: anti-join com NOT EXISTS ("não existe nenhuma linha em ... que ...").
-- Por que não NOT IN? Se a subconsulta devolver ALGUM NULL, "x NOT IN (...)"
--   vira desconhecido para todo mundo e a consulta retorna ZERO linhas, sem
--   erro nenhum. NOT EXISTS não tem essa armadilha.
--   (Aqui aluno_id é NOT NULL, então daria igual, mas o hábito certo é NOT EXISTS.)
-- Como ler: "alunos para os quais não existe matrícula alguma".
-- =====================================================================
SELECT a.aluno_id, a.matricula, a.nome, a.ingresso
FROM   tb_aluno a
WHERE  NOT EXISTS (SELECT 1
                   FROM   tb_matricula_aluno m
                   WHERE  m.aluno_id = a.aluno_id)
ORDER  BY a.aluno_id;

-- =====================================================================
-- CONSULTA 6 — Taxa de aprovação e média por disciplina (períodos encerrados)
-- Técnica: CTE (WITH nome AS (...)) dá nome a uma subconsulta e deixa a
--          consulta principal limpa, como uma "tabela temporária" só desta
--          consulta. Mais agregações condicionais com FILTER.
-- Passos: (1) a CTE junta matrícula → turma → disciplina → histórico e ignora
--         quem ainda está CURSANDO; (2) a principal resume por disciplina.
-- Como ler: "em cada disciplina, que % foi aprovada e qual a média das médias?".
-- =====================================================================
WITH encerradas AS (
    SELECT d.disciplina_id,
           d.codigo_disciplina,
           d.nome_disciplina,
           h.situacao,
           h.media_final
    FROM   tb_historico h
    JOIN   tb_matricula_aluno m ON m.matricula_aluno_id = h.matricula_aluno_id
    JOIN   tb_turma t           ON t.turma_id           = m.turma_id
    JOIN   tb_disciplinas d     ON d.disciplina_id      = t.disciplina_id
    WHERE  h.situacao <> 'CURSANDO'
)
SELECT codigo_disciplina,
       nome_disciplina,
       count(*)                                                       AS cursaram,
       count(*) FILTER (WHERE situacao = 'APROVADO')                  AS aprovados,
       round(100.0 * count(*) FILTER (WHERE situacao = 'APROVADO') / count(*), 1) AS pct_aprovacao,
       round(avg(media_final), 2)                                     AS media_geral
FROM   encerradas
GROUP  BY disciplina_id, codigo_disciplina, nome_disciplina
ORDER  BY pct_aprovacao, nome_disciplina;

-- =====================================================================
-- CONSULTA 7 — Árvore completa de pré-requisitos do Projeto Integrador   [RECURSIVA]
-- Técnica: WITH RECURSIVE tem duas partes unidas por UNION ALL:
--   (a) parte âncora: o ponto de partida (pré-requisitos DIRETOS do PIN001);
--   (b) parte recursiva: pega o resultado anterior e procura "os pré-requisitos
--       dos pré-requisitos", de novo e de novo, até não achar mais nada.
-- Colunas auxiliares:
--   nivel   : 1 = direto, 2 = pré-requisito do pré-requisito, ...
--   caminho : vetor com os códigos já percorridos. A condição
--             "NOT cod = ANY(caminho)" impede loop infinito caso alguém cadastre
--             um ciclo por engano (A exige B, B exige A).
-- Filtramos vinculo = 'PRE_REQUISITO' para ignorar co-requisitos (que são
-- "cursar junto", e não "ter feito antes").
-- Como ler: "o que preciso ter cursado, em cadeia, antes do Projeto Integrador?".
-- =====================================================================
WITH RECURSIVE arvore AS (
    -- (a) âncora
    SELECT d.codigo_disciplina                       AS disciplina,
           r.codigo_disciplina                       AS exige,
           r.nome_disciplina                         AS nome_exigida,
           r.disciplina_id                           AS exige_id,
           1                                         AS nivel,
           ARRAY[d.codigo_disciplina, r.codigo_disciplina]::text[] AS caminho
    FROM   tb_pre_requisito pr
    JOIN   tb_disciplinas d ON d.disciplina_id = pr.disciplina_id
    JOIN   tb_disciplinas r ON r.disciplina_id = pr.requisito_id
    WHERE  d.codigo_disciplina = 'PIN001'
      AND  pr.vinculo = 'PRE_REQUISITO'

    UNION ALL

    -- (b) recursão: sobe mais um degrau a partir de cada "exige" encontrado
    SELECT a.exige,
           r.codigo_disciplina,
           r.nome_disciplina,
           r.disciplina_id,
           a.nivel + 1,
           a.caminho || r.codigo_disciplina
    FROM   arvore a
    JOIN   tb_pre_requisito pr ON pr.disciplina_id = a.exige_id
                              AND pr.vinculo = 'PRE_REQUISITO'
    JOIN   tb_disciplinas r    ON r.disciplina_id = pr.requisito_id
    WHERE  NOT r.codigo_disciplina = ANY (a.caminho)       -- guarda contra ciclo
)
SELECT nivel,
       repeat('    ', nivel - 1) || '└─ ' || exige || ' · ' || nome_exigida AS arvore,
       array_to_string(caminho, ' > ')                                      AS caminho
FROM   arvore
ORDER  BY array_to_string(caminho, ' > ');

-- =====================================================================
-- CONSULTA 8 — Disciplinas que um aluno JÁ PODE cursar   [RECURSIVA]
-- (trocar o aluno: altere o número 1 na CTE "alvo")
-- Ideia: uma disciplina está liberada quando
--   • está no currículo do aluno,
--   • ele ainda NÃO foi aprovado nela e NÃO está cursando agora,
--   • e TODOS os seus pré-requisitos (diretos e indiretos) já foram aprovados.
-- Passos:
--   exigidas  : (recursiva) para cada disciplina, TODOS os pré-requisitos em
--               cadeia, não só os diretos. Mesma ideia da consulta 7, mas para
--               todas as disciplinas ao mesmo tempo.
--   aprovadas : disciplinas em que o aluno tem situacao = APROVADO.
--   cursando  : disciplinas em que ele está matriculado agora.
--   final     : NOT EXISTS de qualquer exigida que não esteja em "aprovadas".
-- Disciplinas reprovadas aparecem de novo (podem ser refeitas) com o motivo.
-- Aqui usamos NOT IN sem risco: disciplina_id é NOT NULL, então as subconsultas
-- nunca devolvem NULL (veja a armadilha explicada na consulta 5).
-- =====================================================================
WITH RECURSIVE
alvo AS (SELECT 1 AS aluno_id),                         -- << aluno consultado

exigidas (disciplina_id, requisito_id) AS (
    SELECT disciplina_id, requisito_id
    FROM   tb_pre_requisito
    WHERE  vinculo = 'PRE_REQUISITO'
  UNION                                                 -- UNION (e não ALL) remove repetições
    SELECT e.disciplina_id, pr.requisito_id
    FROM   exigidas e
    JOIN   tb_pre_requisito pr ON pr.disciplina_id = e.requisito_id
                              AND pr.vinculo = 'PRE_REQUISITO'
),
aprovadas AS (
    SELECT DISTINCT t.disciplina_id
    FROM   alvo
    JOIN   tb_matricula_aluno m ON m.aluno_id = alvo.aluno_id
    JOIN   tb_historico h       ON h.matricula_aluno_id = m.matricula_aluno_id
    JOIN   tb_turma t           ON t.turma_id = m.turma_id
    WHERE  h.situacao = 'APROVADO'
),
cursando AS (
    SELECT DISTINCT t.disciplina_id
    FROM   alvo
    JOIN   tb_matricula_aluno m ON m.aluno_id = alvo.aluno_id AND m.status = 'MATRICULADO'
    JOIN   tb_historico h       ON h.matricula_aluno_id = m.matricula_aluno_id
    JOIN   tb_turma t           ON t.turma_id = m.turma_id
    WHERE  h.situacao = 'CURSANDO'
)
SELECT d.codigo_disciplina,
       d.nome_disciplina,
       cd.periodo                                   AS periodo_sugerido,
       cd.tipo,
       CASE WHEN EXISTS (SELECT 1 FROM tb_matricula_aluno m JOIN tb_turma t USING (turma_id)
                         WHERE m.aluno_id = (SELECT aluno_id FROM alvo)
                           AND t.disciplina_id = d.disciplina_id)
            THEN 'refazer (reprovou antes)' ELSE 'primeira vez' END AS situacao
FROM   alvo
JOIN   tb_aluno a                    ON a.aluno_id = alvo.aluno_id
JOIN   tb_curriculo_disciplina cd    ON cd.curriculo_id = a.curriculo_id
JOIN   tb_disciplinas d              ON d.disciplina_id = cd.disciplina_id
WHERE  d.disciplina_id NOT IN (SELECT disciplina_id FROM aprovadas)
  AND  d.disciplina_id NOT IN (SELECT disciplina_id FROM cursando)
  AND  NOT EXISTS (SELECT 1
                   FROM   exigidas e
                   WHERE  e.disciplina_id = d.disciplina_id
                     AND  e.requisito_id NOT IN (SELECT disciplina_id FROM aprovadas))
ORDER  BY cd.periodo, d.codigo_disciplina;

-- =====================================================================
-- CONSULTA 9 — Ranking e percentil dos alunos dentro de cada curso   [FUNÇÃO DE JANELA]
-- Técnica: função de janela calcula sobre um conjunto de linhas relacionadas
--          SEM colapsá-las (diferente do GROUP BY, que junta as linhas).
--   OVER (PARTITION BY curso ORDER BY media DESC) define a "janela":
--     PARTITION BY = recomeça a conta em cada curso;  ORDER BY = ordem dentro dele.
--   RANK()          : posição; empates dividem a posição e pulam a seguinte (1,2,2,4).
--   PERCENT_RANK()  : (posição-1)/(total-1): 0 = melhor, 1 = pior.
--                     Usamos 1 - PERCENT_RANK para ler como "% de colegas abaixo de mim".
--   NTILE(4)        : divide o curso em 4 faixas iguais (1 = melhor quartil).
-- A CTE calcula a média de cada aluno (só quem tem ao menos 2 disciplinas
-- encerradas); a consulta de fora mostra os 3 melhores de cada curso.
-- =====================================================================
WITH media_aluno AS (
    SELECT a.aluno_id, a.nome, c.codigo_curso,
           round(avg(h.media_final), 2) AS media,
           count(*)                     AS disciplinas
    FROM   tb_aluno a
    JOIN   tb_curso c            ON c.curso_id = a.curso_id
    JOIN   tb_matricula_aluno m  ON m.aluno_id = a.aluno_id
    JOIN   tb_historico h        ON h.matricula_aluno_id = m.matricula_aluno_id
    WHERE  h.media_final IS NOT NULL                    -- só disciplinas já encerradas
    GROUP  BY a.aluno_id, a.nome, c.codigo_curso
    HAVING count(*) >= 2
),
classificado AS (
    SELECT codigo_curso, nome, media, disciplinas,
           RANK()         OVER w                                   AS posicao,
           round(100 * (1 - PERCENT_RANK() OVER w)::numeric, 1)    AS pct_colegas_abaixo,
           NTILE(4)       OVER w                                   AS quartil
    FROM   media_aluno
    WINDOW w AS (PARTITION BY codigo_curso ORDER BY media DESC)    -- janela com nome, reaproveitada
)
SELECT *
FROM   classificado
WHERE  posicao <= 3
ORDER  BY codigo_curso, posicao;

-- =====================================================================
-- CONSULTA 10 — Evolução do rendimento de cada aluno entre períodos   [JANELA com LAG]
-- Técnica: LAG(coluna) OVER (PARTITION BY aluno ORDER BY período) devolve o
--          valor da linha ANTERIOR dentro da mesma partição, ou seja, a média
--          do período passado do MESMO aluno, na mesma linha do período atual.
--          Com isso a variação é uma simples subtração.
--   O primeiro período de cada aluno não tem anterior → LAG devolve NULL;
--   por isso o filtro "media_anterior IS NOT NULL" na consulta externa.
--   (não dá para filtrar por uma coluna de janela no WHERE da mesma consulta;
--    por isso a janela fica numa subconsulta e o filtro vem de fora.)
-- Como ler: "quem mais melhorou (e piorou) de um período para o seguinte?".
-- =====================================================================
WITH media_periodo AS (
    SELECT a.aluno_id, a.nome,
           pl.ano, pl.semestre,
           pl.ano || '.' || pl.semestre  AS periodo,
           round(avg(h.media_final), 2)  AS media
    FROM   tb_aluno a
    JOIN   tb_matricula_aluno m ON m.aluno_id = a.aluno_id
    JOIN   tb_historico h       ON h.matricula_aluno_id = m.matricula_aluno_id
    JOIN   tb_turma t           ON t.turma_id = m.turma_id
    JOIN   tb_periodo_letivo pl ON pl.periodo_id = t.periodo_id
    WHERE  h.media_final IS NOT NULL
    GROUP  BY a.aluno_id, a.nome, pl.periodo_id, pl.ano, pl.semestre
),
com_lag AS (
    SELECT aluno_id, nome, periodo, media,
           LAG(media) OVER (PARTITION BY aluno_id ORDER BY ano, semestre) AS media_anterior
    FROM   media_periodo
)
SELECT aluno_id, nome, periodo, media_anterior, media,
       media - media_anterior                                  AS variacao,
       CASE WHEN media - media_anterior >  0.5 THEN 'melhorou'
            WHEN media - media_anterior < -0.5 THEN 'piorou'
            ELSE                                    'estável' END AS tendencia
FROM   com_lag
WHERE  media_anterior IS NOT NULL
ORDER  BY variacao DESC, nome
LIMIT  10;
