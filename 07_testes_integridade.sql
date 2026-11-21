-- =====================================================================
-- 07_testes_integridade.sql  ·  As restrições do DDL recusando dado errado
-- MARCO 2 · Frente: Modelagem Física e Desempenho (usado na demonstração)
-- Rode depois dos scripts 01 e 02. Não altera nada na base.
--
-- Cada bloco DO tenta gravar um dado que viola uma regra do 01_ddl.sql.
-- Se o banco recusar, cai no EXCEPTION e mostra "OK" com a mensagem do
-- PostgreSQL. Se aceitar, mostra "FALHOU". O erro desfaz só o que foi
-- feito dentro do bloco, então nenhum dado de teste fica gravado.
-- =====================================================================

SET search_path TO academico, public;

-- 1) DOMÍNIO nota_t: nota maior que 10
DO $$
BEGIN
    UPDATE tb_historico SET nota_a1 = 11
    WHERE matricula_aluno_id = (SELECT min(matricula_aluno_id) FROM tb_historico);
    RAISE NOTICE 'FALHOU 1: aceitou nota 11';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK 1 (domínio nota_t): %', SQLERRM;
END $$;

-- 2) CHECK com expressão regular: CPF com letra
DO $$
BEGIN
    UPDATE tb_aluno SET cpf = '1234567890X' WHERE matricula = '26000001';
    RAISE NOTICE 'FALHOU 2: aceitou CPF com letra';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK 2 (CHECK do CPF): %', SQLERRM;
END $$;

-- 3) CHECK entre duas colunas: ingresso antes do nascimento
DO $$
BEGIN
    UPDATE tb_aluno SET ingresso = nascimento - 1 WHERE matricula = '26000001';
    RAISE NOTICE 'FALHOU 3: aceitou ingresso antes do nascimento';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK 3 (CHECK ingresso > nascimento): %', SQLERRM;
END $$;

-- 4) UNIQUE (aluno_id, turma_id): mesmo aluno duas vezes na mesma turma
DO $$
BEGIN
    INSERT INTO tb_matricula_aluno (aluno_id, turma_id, status)
    SELECT aluno_id, turma_id, 'TRANCADO'      -- TRANCADO para o gatilho de vaga não reclamar antes
    FROM   tb_matricula_aluno LIMIT 1;
    RAISE NOTICE 'FALHOU 4: aceitou matrícula repetida';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'OK 4 (UNIQUE aluno/turma): %', SQLERRM;
END $$;

-- 5) FOREIGN KEY: matrícula numa turma que não existe
DO $$
BEGIN
    INSERT INTO tb_matricula_aluno (aluno_id, turma_id, status)
    VALUES ((SELECT min(aluno_id) FROM tb_aluno), 999999, 'TRANCADO');
    RAISE NOTICE 'FALHOU 5: aceitou turma inexistente';
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'OK 5 (FK turma): %', SQLERRM;
END $$;

-- 6) EXCLUDE: duas turmas na mesma sala, no mesmo dia, em horário que se cruza.
-- A EDA-N1 usa a A101 na segunda das 20:50 às 22:40. Tentamos colocar a
-- RED-N1 na A101 na segunda das 21:00 às 22:00.
DO $$
BEGIN
    INSERT INTO tb_turma_horario (turma_id, sala_id, dia_semana, horario_inicio, horario_fim)
    SELECT t.turma_id, s.sala_id, 2, '21:00', '22:00'
    FROM   tb_turma t, tb_sala s
    WHERE  t.codigo = 'RED-N1' AND s.codigo_sala = 'A101';
    RAISE NOTICE 'FALHOU 6: aceitou sala ocupada';
EXCEPTION WHEN exclusion_violation THEN
    RAISE NOTICE 'OK 6 (EXCLUDE sala ocupada): %', SQLERRM;
END $$;

-- 7) CHECK: disciplina como pré-requisito dela mesma
DO $$
BEGIN
    INSERT INTO tb_pre_requisito (disciplina_id, requisito_id)
    SELECT disciplina_id, disciplina_id FROM tb_disciplinas WHERE codigo_disciplina = 'BD2001';
    RAISE NOTICE 'FALHOU 7: aceitou pré-requisito de si mesma';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK 7 (CHECK pré-requisito): %', SQLERRM;
END $$;

-- 8) ÍNDICE ÚNICO PARCIAL: segundo currículo ativo para o CCO
DO $$
BEGIN
    UPDATE tb_curriculo SET ativo = true
    WHERE  ano_vigencia = 2020
      AND  curso_id = (SELECT curso_id FROM tb_curso WHERE codigo_curso = 'CCO');
    RAISE NOTICE 'FALHOU 8: aceitou dois currículos ativos';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'OK 8 (um currículo ativo por curso): %', SQLERRM;
END $$;

-- 9) COLUNA GERADA: tentar gravar a média final na mão
DO $$
BEGIN
    UPDATE tb_historico SET media_final = 10
    WHERE matricula_aluno_id = (SELECT min(matricula_aluno_id) FROM tb_historico);
    RAISE NOTICE 'FALHOU 9: aceitou média digitada';
EXCEPTION WHEN generated_always THEN
    RAISE NOTICE 'OK 9 (coluna gerada media_final): %', SQLERRM;
END $$;

-- 10) GATILHO de vagas: matrícula numa turma lotada.
-- Reduz as vagas da LOG-M1 para o número de alunos que ela já tem e tenta
-- matricular mais um. O UPDATE das vagas também é desfeito pelo erro.
DO $$
BEGIN
    UPDATE tb_turma t SET vagas = (SELECT count(*) FROM tb_matricula_aluno m
                                   WHERE m.turma_id = t.turma_id AND m.status = 'MATRICULADO')
    WHERE  t.codigo = 'LOG-M1';

    INSERT INTO tb_matricula_aluno (aluno_id, turma_id)
    SELECT a.aluno_id, t.turma_id
    FROM   tb_aluno a, tb_turma t
    WHERE  a.matricula = '26000105' AND t.codigo = 'LOG-M1';
    RAISE NOTICE 'FALHOU 10: aceitou matrícula em turma lotada';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK 10 (gatilho de vagas): %', SQLERRM;
END $$;
