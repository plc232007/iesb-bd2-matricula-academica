-- =====================================================================
-- 02_carga.sql  ·  Carga de dados (dados FICTÍCIOS)  ·  BD2 · CCO072 · IESB
-- Rode DEPOIS do 01_ddl.sql.   Pode ser rodado várias vezes: não duplica nada.
--
-- Volume: 110 alunos · 13 turmas · 440 matrículas (mínimo pedido: 100/6/300)
--
-- COMO O SCRIPT FICA "REPETÍVEL" (idempotente):
--   * INSERT ... ON CONFLICT DO NOTHING
--       Se a linha já existe (viola um UNIQUE/PK), o banco ignora em vez de dar erro.
--   * INSERT ... WHERE NOT EXISTS (...)
--       Só insere se ainda não houver linha equivalente. Usamos isto nas
--       MATRÍCULAS porque o trigger de vagas dispara ANTES do teste de conflito:
--       com ON CONFLICT, uma segunda execução tentaria "matricular de novo" e o
--       trigger reclamaria de turma cheia. O NOT EXISTS evita a tentativa.
--
-- POR QUE USAMOS JOIN EM VEZ DE DIGITAR IDs?
--   As chaves são GENERATED ALWAYS AS IDENTITY: o banco escolhe o número, e a
--   gente nem pode informar. Então localizamos cada pai pelo seu campo natural
--   (código da disciplina, e-mail do professor...) e deixamos o banco devolver o id.
--
-- COMO GERAMOS MUITOS DADOS:
--   generate_series(1, 110) cria os números 1..110, e a partir de cada número
--   montamos nome, CPF, e-mail etc. Não usamos random(): as contas com % (resto
--   da divisão) dão números "parecem aleatórios" mas SEMPRE iguais. Assim todo
--   mundo do grupo obtém exatamente os mesmos dados e as consultas dão o
--   mesmo resultado.
-- =====================================================================

SET search_path TO academico, public;

-- ---------------------------------------------------------------------
-- 1) Geografia, campus, prédios, salas
-- ---------------------------------------------------------------------
INSERT INTO tb_pais (nome_pais) VALUES ('Brasil')
ON CONFLICT DO NOTHING;

INSERT INTO tb_estado (pais_id, nome_estado)
SELECT p.pais_id, v.nome
FROM (VALUES ('Distrito Federal'), ('Goiás')) v(nome)
CROSS JOIN tb_pais p WHERE p.nome_pais = 'Brasil'
ON CONFLICT DO NOTHING;

INSERT INTO tb_cidade (estado_id, nome_cidade)
SELECT e.estado_id, v.cidade
FROM (VALUES ('Distrito Federal', 'Brasília'), ('Goiás', 'Goiânia')) v(estado, cidade)
JOIN tb_estado e ON e.nome_estado = v.estado
ON CONFLICT DO NOTHING;

INSERT INTO tb_campus (cidade_id, nome_campus, endereco, telefone, cep)
SELECT c.cidade_id, v.nome, v.endereco, v.tel, v.cep
FROM (VALUES
        ('IESB Sul',   'Brasília', 'SGAS 613/614, Asa Sul',  '6133064400', '70200730'),
        ('IESB Norte', 'Brasília', 'SGAN 612, Asa Norte',    NULL,         '70830012')
     ) v(nome, cidade, endereco, tel, cep)
JOIN tb_cidade c ON c.nome_cidade = v.cidade
ON CONFLICT DO NOTHING;

INSERT INTO tb_predio (bloco_predio, andar_predio)
VALUES ('A','1'), ('A','2'), ('A','3'), ('B','1'), ('B','2')
ON CONFLICT DO NOTHING;

-- Salas (todas no campus Sul; o campus Norte fica sem sala de propósito:
-- serve para mostrar o LEFT JOIN com contagem zero nas consultas).
INSERT INTO tb_sala (predio_id, campus_id, codigo_sala, capacidade, tipo_sala)
SELECT p.predio_id, c.campus_id, v.cod, v.cap, v.tipo::tipo_sala_t
FROM (VALUES
        ('A','1','A101',60,'TEORICA'),   ('A','1','A102',60,'TEORICA'),
        ('A','2','A201',50,'TEORICA'),   ('A','3','A301',50,'TEORICA'),
        ('B','1','B101',40,'TEORICA'),   ('B','1','B102',30,'LABORATORIO'),
        ('B','2','B201',40,'TEORICA')
     ) v(bloco, andar, cod, cap, tipo)
JOIN tb_predio p ON p.bloco_predio = v.bloco AND p.andar_predio = v.andar
CROSS JOIN tb_campus c WHERE c.nome_campus = 'IESB Sul'
ON CONFLICT DO NOTHING;

-- Feriados: um nacional, um estadual, um municipal (cada linha aponta p/ UM nível).
INSERT INTO tb_feriado (pais_id, dia_feriado)
SELECT pais_id, d::date
FROM tb_pais, (VALUES ('2026-09-07'), ('2026-11-02'), ('2026-11-15'), ('2026-12-25')) v(d)
WHERE nome_pais = 'Brasil'
ON CONFLICT DO NOTHING;

INSERT INTO tb_feriado (estado_id, dia_feriado)
SELECT estado_id, DATE '2026-11-30' FROM tb_estado WHERE nome_estado = 'Distrito Federal'
ON CONFLICT DO NOTHING;

INSERT INTO tb_feriado (cidade_id, dia_feriado)
SELECT cidade_id, DATE '2026-04-21' FROM tb_cidade WHERE nome_cidade = 'Brasília'
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------
-- 2) Cursos, currículos, disciplinas, pré-requisitos
-- ---------------------------------------------------------------------
INSERT INTO tb_curso (campus_id, codigo_curso, nome_curso, grau, ch_total)
SELECT c.campus_id, v.cod, v.nome, v.grau, v.ch
FROM (VALUES
        ('IESB Sul',   'CCO',  'Ciência da Computação',                  'BACHARELADO', 3200),
        ('IESB Sul',   'ADS',  'Análise e Desenvolvimento de Sistemas',  'TECNOLOGO',   2000),
        ('IESB Norte', 'ENGC', 'Engenharia da Computação',               'BACHARELADO', 3600)
     ) v(campus, cod, nome, grau, ch)
JOIN tb_campus c ON c.nome_campus = v.campus
ON CONFLICT DO NOTHING;

-- Um currículo ativo por curso (o índice parcial uq_tb_curriculo_ativo garante).
-- O CCO tem também um currículo antigo (2020), inativo.
INSERT INTO tb_curriculo (curso_id, ano_vigencia, ativo)
SELECT c.curso_id, v.ano, v.ativo
FROM (VALUES ('CCO',2024,true), ('CCO',2020,false), ('ADS',2024,true), ('ENGC',2024,true))
     v(curso, ano, ativo)
JOIN tb_curso c ON c.codigo_curso = v.curso
ON CONFLICT DO NOTHING;

-- ch_total NÃO é informado: é coluna gerada (teórica + prática).
INSERT INTO tb_disciplinas (codigo_disciplina, nome_disciplina, ch_teorica, ch_pratica, ementa)
VALUES
  ('LOG001', 'Lógica de Programação',      40, 40, 'Raciocínio lógico, fluxogramas e primeiros algoritmos.'),
  ('MAT001', 'Matemática Discreta',        80,  0, 'Conjuntos, relações, indução e combinatória.'),
  ('ALG001', 'Algoritmos',                 40, 40, 'Estruturas de controle, funções, vetores e recursão.'),
  ('CAL001', 'Cálculo I',                  80,  0, 'Limites, derivadas e integrais.'),
  ('EDA001', 'Estruturas de Dados',        40, 40, 'Listas, pilhas, filas, árvores e tabelas hash.'),
  ('BD1001', 'Banco de Dados I',           40, 40, 'Modelagem relacional e SQL básico.'),
  ('TGR001', 'Teoria dos Grafos',          60, 20, 'Representações, percursos e caminhos mínimos.'),
  ('ESW001', 'Engenharia de Software',     60, 20, 'Processos, requisitos e testes.'),
  ('RED001', 'Redes de Computadores',      60, 20, 'Modelo TCP/IP e protocolos.'),
  ('SOP001', 'Sistemas Operacionais',      60, 20, 'Processos, memória e arquivos.'),
  ('BD2001', 'Banco de Dados II',          40, 40, 'SQL avançado, recursão, janelas e desempenho.'),
  ('PIN001', 'Projeto Integrador',         20, 60, 'Projeto em grupo integrando as disciplinas do curso.')
ON CONFLICT DO NOTHING;

-- Pré-requisitos: (disciplina, exige, tipo de vínculo).
-- Árvore:  LOG → ALG → EDA → TGR / SOP     ALG → BD1 → BD2 → PIN     ALG → ESW → PIN
-- SOP tem RED como CO-requisito (cursa junto; as consultas recursivas filtram só PRÉ).
INSERT INTO tb_pre_requisito (disciplina_id, requisito_id, vinculo)
SELECT d.disciplina_id, r.disciplina_id, v.vinculo::vinculo_t
FROM (VALUES
        ('ALG001','LOG001','PRE_REQUISITO'),
        ('EDA001','ALG001','PRE_REQUISITO'),
        ('BD1001','ALG001','PRE_REQUISITO'),
        ('ESW001','ALG001','PRE_REQUISITO'),
        ('TGR001','EDA001','PRE_REQUISITO'),
        ('SOP001','EDA001','PRE_REQUISITO'),
        ('BD2001','BD1001','PRE_REQUISITO'),
        ('PIN001','BD2001','PRE_REQUISITO'),
        ('PIN001','ESW001','PRE_REQUISITO'),
        ('SOP001','RED001','CO_REQUISITO')
     ) v(disc, req, vinculo)
JOIN tb_disciplinas d ON d.codigo_disciplina = v.disc
JOIN tb_disciplinas r ON r.codigo_disciplina = v.req
ON CONFLICT DO NOTHING;

-- Grade de cada currículo (período sugerido de cada disciplina).
-- As 6 primeiras disciplinas são comuns aos três cursos.
INSERT INTO tb_curriculo_disciplina (curriculo_id, disciplina_id, periodo, tipo)
SELECT cu.curriculo_id, d.disciplina_id, v.periodo, v.tipo::tipo_disc_t
FROM (VALUES
  ('CCO',2024,'LOG001',1,'OBRIGATORIA'), ('CCO',2024,'MAT001',1,'OBRIGATORIA'),
  ('CCO',2024,'ALG001',2,'OBRIGATORIA'), ('CCO',2024,'CAL001',2,'OBRIGATORIA'),
  ('CCO',2024,'EDA001',3,'OBRIGATORIA'), ('CCO',2024,'BD1001',3,'OBRIGATORIA'),
  ('CCO',2024,'RED001',3,'OPTATIVA'),    ('CCO',2024,'TGR001',4,'OBRIGATORIA'),
  ('CCO',2024,'ESW001',4,'OBRIGATORIA'), ('CCO',2024,'SOP001',4,'OBRIGATORIA'),
  ('CCO',2024,'BD2001',4,'OBRIGATORIA'), ('CCO',2024,'PIN001',5,'OBRIGATORIA'),
  ('ADS',2024,'LOG001',1,'OBRIGATORIA'), ('ADS',2024,'MAT001',1,'OBRIGATORIA'),
  ('ADS',2024,'ALG001',2,'OBRIGATORIA'), ('ADS',2024,'CAL001',2,'OPTATIVA'),
  ('ADS',2024,'EDA001',3,'OBRIGATORIA'), ('ADS',2024,'BD1001',3,'OBRIGATORIA'),
  ('ADS',2024,'ESW001',4,'OBRIGATORIA'), ('ADS',2024,'BD2001',4,'OBRIGATORIA'),
  ('ADS',2024,'PIN001',5,'OBRIGATORIA'),
  ('ENGC',2024,'LOG001',1,'OBRIGATORIA'),('ENGC',2024,'MAT001',1,'OBRIGATORIA'),
  ('ENGC',2024,'ALG001',2,'OBRIGATORIA'),('ENGC',2024,'CAL001',2,'OBRIGATORIA'),
  ('ENGC',2024,'EDA001',3,'OBRIGATORIA'),('ENGC',2024,'BD1001',3,'OBRIGATORIA'),
  ('ENGC',2024,'RED001',3,'OBRIGATORIA'), ('ENGC',2024,'SOP001',4,'OBRIGATORIA'),
  ('CCO',2020,'LOG001',1,'OBRIGATORIA'), ('CCO',2020,'ALG001',2,'OBRIGATORIA')
) v(curso, ano, disc, periodo, tipo)
JOIN tb_curso c        ON c.codigo_curso = v.curso
JOIN tb_curriculo cu   ON cu.curso_id = c.curso_id AND cu.ano_vigencia = v.ano
JOIN tb_disciplinas d  ON d.codigo_disciplina = v.disc
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------
-- 3) Professores, períodos letivos, turmas e horários
-- ---------------------------------------------------------------------
-- O professor 8 não recebe nenhuma turma (mostra o 0,N do modelo).
INSERT INTO tb_professor (nome, email, titulacao, status)
VALUES
  ('Rodrigo Pereira',   'prof1@iesb.edu.br', 'DOUTOR',       'MATRICULADO'),
  ('Marina Albuquerque','prof2@iesb.edu.br', 'MESTRE',       'MATRICULADO'),
  ('Carlos Henrique',   'prof3@iesb.edu.br', 'MESTRE',       'MATRICULADO'),
  ('Patrícia Nogueira', 'prof4@iesb.edu.br', 'DOUTOR',       'MATRICULADO'),
  ('Fernando Teixeira', 'prof5@iesb.edu.br', 'ESPECIALISTA', 'MATRICULADO'),
  ('Juliana Barros',    'prof6@iesb.edu.br', 'MESTRE',       'MATRICULADO'),
  ('Eduardo Lacerda',   'prof7@iesb.edu.br', 'ESPECIALISTA', 'MATRICULADO'),
  ('Beatriz Moura',     'prof8@iesb.edu.br', 'MESTRE',       'MATRICULADO')
ON CONFLICT DO NOTHING;

-- 2025.1 fica SEM turmas de propósito. 2026.2 é o período corrente.
INSERT INTO tb_periodo_letivo (ano, semestre, data_inicio, data_fim)
VALUES (2025,1,'2025-02-03','2025-06-30'), (2025,2,'2025-08-04','2025-12-12'),
       (2026,1,'2026-02-02','2026-06-30'), (2026,2,'2026-08-03','2026-12-11')
ON CONFLICT DO NOTHING;

-- 13 turmas. A turma RED-N1 não terá matrículas (mostra o 0,N com contagem zero).
INSERT INTO tb_turma (codigo, disciplina_id, periodo_id, professor_id, turno, vagas)
SELECT v.cod, d.disciplina_id, pl.periodo_id, pr.professor_id, v.turno::turno_t, v.vagas
FROM (VALUES
  ('LOG-N1','LOG001',2025,2,'prof1@iesb.edu.br','NOTURNO',  45),
  ('MAT-N1','MAT001',2025,2,'prof2@iesb.edu.br','NOTURNO',  45),
  ('ALG-N1','ALG001',2026,1,'prof3@iesb.edu.br','NOTURNO',  45),
  ('CAL-N1','CAL001',2026,1,'prof4@iesb.edu.br','NOTURNO',  45),
  ('LOG-N2','LOG001',2026,1,'prof1@iesb.edu.br','NOTURNO',  45),
  ('MAT-N2','MAT001',2026,1,'prof2@iesb.edu.br','NOTURNO',  45),
  ('EDA-N1','EDA001',2026,2,'prof5@iesb.edu.br','NOTURNO',  45),
  ('BD1-N1','BD1001',2026,2,'prof6@iesb.edu.br','NOTURNO',  45),
  ('ALG-N2','ALG001',2026,2,'prof3@iesb.edu.br','NOTURNO',  45),
  ('CAL-N2','CAL001',2026,2,'prof4@iesb.edu.br','NOTURNO',  45),
  ('LOG-M1','LOG001',2026,2,'prof1@iesb.edu.br','MATUTINO', 30),
  ('MAT-M1','MAT001',2026,2,'prof2@iesb.edu.br','MATUTINO', 30),
  ('RED-N1','RED001',2026,2,'prof7@iesb.edu.br','NOTURNO',  30)
) v(cod, disc, ano, sem, prof, turno, vagas)
JOIN tb_disciplinas d     ON d.codigo_disciplina = v.disc
JOIN tb_periodo_letivo pl ON pl.ano = v.ano AND pl.semestre = v.sem
JOIN tb_professor pr      ON pr.email = v.prof
ON CONFLICT DO NOTHING;

-- Horários: cada turma tem aulas em 2 dias (dia 1 = domingo ... 7 = sábado).
-- unnest(dias) transforma o vetor {2,4} em duas linhas (segunda e quarta).
-- Blocos: noite 19:00-20:50 / 20:50-22:40 · manhã 07:30-09:20.
-- ATENÇÃO: a restrição ex_tb_sala_ocupada NÃO conhece o período letivo, então o
-- mesmo par (sala, dia, horário) só pode aparecer uma vez em TODA a base.
-- Por isso as turmas de períodos diferentes usam combinações diferentes.
INSERT INTO tb_turma_horario (turma_id, sala_id, dia_semana, horario_inicio, horario_fim)
SELECT t.turma_id, s.sala_id, dia, v.ini::time, v.fim::time
FROM (VALUES
  ('LOG-N1',2025,2,'A101',ARRAY[2,4],'19:00','20:50'),
  ('MAT-N1',2025,2,'A102',ARRAY[2,4],'19:00','20:50'),
  ('ALG-N1',2026,1,'A101',ARRAY[3,5],'19:00','20:50'),
  ('CAL-N1',2026,1,'A102',ARRAY[3,5],'19:00','20:50'),
  ('LOG-N2',2026,1,'A201',ARRAY[2,4],'19:00','20:50'),
  ('MAT-N2',2026,1,'A301',ARRAY[2,4],'19:00','20:50'),
  ('EDA-N1',2026,2,'A101',ARRAY[2,4],'20:50','22:40'),
  ('BD1-N1',2026,2,'A301',ARRAY[3,5],'19:00','20:50'),
  ('ALG-N2',2026,2,'A102',ARRAY[2,4],'20:50','22:40'),
  ('CAL-N2',2026,2,'A201',ARRAY[3,5],'19:00','20:50'),
  ('LOG-M1',2026,2,'A301',ARRAY[3,5],'07:30','09:20'),
  ('MAT-M1',2026,2,'B101',ARRAY[2,4],'07:30','09:20'),
  ('RED-N1',2026,2,'B102',ARRAY[6],  '19:00','20:50')
) v(turma, ano, sem, sala, dias, ini, fim)
JOIN tb_periodo_letivo pl ON pl.ano = v.ano AND pl.semestre = v.sem
JOIN tb_turma t           ON t.codigo = v.turma AND t.periodo_id = pl.periodo_id
JOIN tb_sala s            ON s.codigo_sala = v.sala
CROSS JOIN LATERAL unnest(v.dias) AS dia
WHERE NOT EXISTS (SELECT 1 FROM tb_turma_horario h
                  WHERE h.turma_id = t.turma_id AND h.dia_semana = dia);

-- ---------------------------------------------------------------------
-- 4) Alunos (generate_series)
-- ---------------------------------------------------------------------
-- 3 coortes por data de ingresso:
--    alunos   1-40  : ingresso 2025.2   (já cursaram 2 períodos + o corrente)
--    alunos  41-80  : ingresso 2026.1
--    alunos  81-100 : ingresso 2026.2
--    alunos 101-110 : ingresso tardio (set/2026), AINDA SEM MATRÍCULA
-- Curso: resto n % 5 → 0,1,2 = CCO · 3 = ADS · 4 = ENGC. Cada aluno entra no currículo ATIVO do curso.
INSERT INTO tb_aluno (curso_id, curriculo_id, matricula, nome, cpf, email, nascimento, ingresso, ativo)
SELECT c.curso_id, cu.curriculo_id,
       '26' || lpad(n::text, 6, '0'),
       (ARRAY['Ana','Bruno','Carla','Diego','Elisa','Felipe','Gabriela','Henrique','Isabela','João',
              'Karen','Lucas','Mariana','Nicolas','Olívia','Pedro','Rafaela','Samuel','Tatiana','Vitor'])[n % 20 + 1]
         || ' ' ||
       (ARRAY['Almeida','Barbosa','Cardoso','Dias','Ferreira','Gomes','Lima','Machado','Nunes','Oliveira',
              'Pereira','Ramos','Santos','Teixeira','Vieira','Araújo','Castro','Freitas','Melo','Rocha'])[(n * 7) % 20 + 1]
         || ' ' ||
       (ARRAY['Costa','Duarte','Fonseca','Guedes','Lopes','Marques','Moreira','Peixoto','Ribeiro','Siqueira',
              'Tavares','Xavier','Azevedo','Batista','Correia','Farias','Monteiro','Pinto','Soares','Zanetti'])[(n * 11) % 20 + 1],
       lpad((10000000000 + n * 7919)::text, 11, '0'),           -- 11 dígitos, único por aluno
       'aluno' || n || '@iesb.edu.br',
       DATE '2003-01-01' + (n * 53 % 2500),
       CASE WHEN n <= 40  THEN DATE '2025-08-04'
            WHEN n <= 80  THEN DATE '2026-02-02'
            WHEN n <= 100 THEN DATE '2026-08-03'
            ELSE               DATE '2026-09-01' END,
       true
FROM generate_series(1, 110) AS n
JOIN tb_curso c ON c.codigo_curso = CASE n % 5 WHEN 3 THEN 'ADS' WHEN 4 THEN 'ENGC' ELSE 'CCO' END
JOIN tb_curriculo cu ON cu.curso_id = c.curso_id AND cu.ativo
ORDER BY n          -- garante aluno_id 1,2,3... na mesma ordem de n (e da matrícula)
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------
-- 5) Matrículas (440) — cada coorte segue a sua trilha de disciplinas
-- ---------------------------------------------------------------------
-- plano = "quem cursa o quê, em qual turma". Cada coorte só se matricula em
-- disciplinas cujo pré-requisito já foi cursado em período anterior.
--   coorte A: 2025.2 LOG+MAT · 2026.1 ALG+CAL · 2026.2 EDA+BD1   (6 × 40 = 240)
--   coorte B: 2026.1 LOG+MAT · 2026.2 ALG+CAL                    (4 × 40 = 160)
--   coorte C: 2026.2 LOG+MAT                                      (2 × 20 =  40)
-- Alguns da coorte A trancam no período corrente (aluno_id múltiplo de 13).
-- data_matricula: alguns dias antes do início do período, em horas diferentes
-- (isso dá "movimento no tempo" para a função LAG).
INSERT INTO tb_matricula_aluno (aluno_id, turma_id, data_matricula, status)
SELECT a.aluno_id, t.turma_id,
       (pl.data_inicio::timestamp
          - make_interval(days => 1 + a.aluno_id % 20)
          + make_interval(hours => 8 + a.aluno_id % 9, mins => (a.aluno_id * 7) % 60))::timestamptz,
       CASE WHEN p.coorte = 'A' AND pl.ano = 2026 AND pl.semestre = 2 AND a.aluno_id % 13 = 0
            THEN 'TRANCADO'::status_mat_t ELSE 'MATRICULADO'::status_mat_t END
FROM (VALUES
  ('A',2025,2,'LOG-N1'), ('A',2025,2,'MAT-N1'),
  ('A',2026,1,'ALG-N1'), ('A',2026,1,'CAL-N1'),
  ('A',2026,2,'EDA-N1'), ('A',2026,2,'BD1-N1'),
  ('B',2026,1,'LOG-N2'), ('B',2026,1,'MAT-N2'),
  ('B',2026,2,'ALG-N2'), ('B',2026,2,'CAL-N2'),
  ('C',2026,2,'LOG-M1'), ('C',2026,2,'MAT-M1')
) p(coorte, ano, sem, turma)
JOIN tb_aluno a ON a.ingresso = CASE p.coorte WHEN 'A' THEN DATE '2025-08-04'
                                              WHEN 'B' THEN DATE '2026-02-02'
                                              ELSE          DATE '2026-08-03' END
JOIN tb_periodo_letivo pl ON pl.ano = p.ano AND pl.semestre = p.sem
JOIN tb_turma t ON t.codigo = p.turma AND t.periodo_id = pl.periodo_id
WHERE NOT EXISTS (SELECT 1 FROM tb_matricula_aluno m
                  WHERE m.aluno_id = a.aluno_id AND m.turma_id = t.turma_id);

-- ---------------------------------------------------------------------
-- 6) Histórico (notas e frequência) — uma linha por matrícula
-- ---------------------------------------------------------------------
-- Notas "pseudo-aleatórias" feitas com resto da divisão (sempre iguais).
-- Regras para o conjunto ficar coerente:
--   * LOG e ALG (pré-requisitos de outras) nos períodos passados: nota ≥ 6 e freq ≥ 75
--     → todo aluno que avançou foi de fato aprovado antes.
--   * MAT e CAL passados: podem ter nota baixa (A3 substitutiva para alguns) e faltas.
--   * Período corrente (2026.2): só A1 lançada, A2 vazia, situação CURSANDO.
-- media_final NÃO entra no INSERT: é coluna gerada pelo banco.
INSERT INTO tb_historico (matricula_aluno_id, nota_a1, nota_a2, nota_a3, frequencia)
SELECT m.matricula_aluno_id,
       q.a1,
       CASE WHEN q.atual THEN NULL ELSE q.a2 END,
       CASE WHEN NOT q.atual AND NOT q.gate AND (0.4*q.a1 + 0.6*q.a2) < 6 AND q.h % 2 = 0
            THEN 7.0 END,                                 -- substitutiva só p/ quem ficou abaixo
       q.freq
FROM tb_matricula_aluno m
JOIN tb_turma t ON t.turma_id = m.turma_id
JOIN tb_periodo_letivo pl ON pl.periodo_id = t.periodo_id
JOIN tb_disciplinas d ON d.disciplina_id = t.disciplina_id
CROSS JOIN LATERAL (
    SELECT (pl.ano = 2026 AND pl.semestre = 2)                      AS atual,
           (d.codigo_disciplina IN ('LOG001','ALG001'))             AS gate,
           (m.aluno_id * 37 + d.disciplina_id * 17)                 AS h
) k
CROSS JOIN LATERAL (
    SELECT k.atual, k.gate, k.h,
           CASE WHEN k.gate AND NOT k.atual THEN 6.0 + (k.h % 41) / 10.0
                ELSE 3.0 + (k.h % 71) / 10.0 END                    AS a1,
           CASE WHEN k.gate AND NOT k.atual THEN 6.0 + ((k.h * 3 + 5) % 41) / 10.0
                ELSE 3.0 + ((k.h * 3 + 5) % 71) / 10.0 END          AS a2,
           CASE WHEN k.gate AND NOT k.atual THEN 75 + (k.h % 26)
                ELSE 60 + (k.h % 41) END                            AS freq
) q
WHERE NOT EXISTS (SELECT 1 FROM tb_historico h WHERE h.matricula_aluno_id = m.matricula_aluno_id);

-- Situação final dos períodos já encerrados (só mexe em quem ainda está CURSANDO
-- e já tem A2, então rodar de novo não muda nada).
UPDATE tb_historico
SET situacao = CASE WHEN frequencia < 75   THEN 'REPROVADO_FALTA'::situacao_t
                    WHEN media_final >= 6  THEN 'APROVADO'::situacao_t
                    ELSE                        'REPROVADO_NOTA'::situacao_t END
WHERE situacao = 'CURSANDO' AND nota_a2 IS NOT NULL;

-- ---------------------------------------------------------------------
-- 7) Log de matrículas (campo jsonb com dados livres)
-- ---------------------------------------------------------------------
INSERT INTO tb_log_matricula (matricula_aluno_id, acao, ocorrido_em, detalhe)
SELECT m.matricula_aluno_id,
       CASE m.status WHEN 'TRANCADO' THEN 'TRANCAMENTO' ELSE 'MATRICULA' END,
       m.data_matricula,
       jsonb_build_object('turma', t.codigo, 'status', m.status)
FROM tb_matricula_aluno m
JOIN tb_turma t ON t.turma_id = m.turma_id
WHERE NOT EXISTS (SELECT 1 FROM tb_log_matricula l WHERE l.matricula_aluno_id = m.matricula_aluno_id);

-- ---------------------------------------------------------------------
-- 8) Conferência rápida (o que o professor vai pedir): contagens
-- ---------------------------------------------------------------------
SELECT (SELECT count(*) FROM tb_aluno)            AS alunos,
       (SELECT count(*) FROM tb_turma)            AS turmas,
       (SELECT count(*) FROM tb_matricula_aluno)  AS matriculas,
       (SELECT count(*) FROM tb_historico)        AS historicos,
       (SELECT count(*) FROM tb_log_matricula)    AS logs;

ANALYZE;
