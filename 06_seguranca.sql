-- =====================================================================
-- 06_seguranca.sql  ·  Papéis, GRANT/REVOKE e row-level security
-- MARCO 2 · Frente: Administração e Operação
-- Rode depois do 05_indices.sql, como superusuário (bd2 no Docker).
-- Pode rodar de novo sem erro.
--
-- Três papéis de grupo (NOLOGIN, ninguém entra com eles direto):
--   aluno        lê a oferta e as vagas, e SÓ o próprio histórico
--   secretaria   cadastra aluno, faz matrícula e lança nota
--   coordenacao  monta a oferta (turmas e horários) e lê tudo
-- E usuários de login para a demonstração, cada um membro de um papel:
--   aluno_26000001, aluno_26000002, usuario_secretaria, usuario_coordenacao
--
-- Como o banco sabe qual aluno está conectado: o nome do usuário de login é
-- "aluno_" + o número de matrícula (o RA). A função fn_aluno_logado()
-- procura em tb_aluno o aluno com esse RA.
-- =====================================================================

SET search_path TO academico, public;

-- ---------------------------------------------------------------------
-- 1) Papéis e usuários
-- ---------------------------------------------------------------------
-- CREATE ROLE não tem IF NOT EXISTS, por isso o mesmo truque do DDL:
-- tenta criar e ignora o erro de "já existe".
DO $$
BEGIN
    BEGIN CREATE ROLE aluno       NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END;
    BEGIN CREATE ROLE secretaria  NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END;
    BEGIN CREATE ROLE coordenacao NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END;

    -- Senhas simples só porque é ambiente de aula. Em produção cada
    -- pessoa teria a sua senha e o usuário seria criado no cadastro.
    BEGIN CREATE ROLE aluno_26000001 LOGIN PASSWORD 'aluno' IN ROLE aluno;
    EXCEPTION WHEN duplicate_object THEN NULL; END;
    BEGIN CREATE ROLE aluno_26000002 LOGIN PASSWORD 'aluno' IN ROLE aluno;
    EXCEPTION WHEN duplicate_object THEN NULL; END;
    BEGIN CREATE ROLE usuario_secretaria LOGIN PASSWORD 'secretaria' IN ROLE secretaria;
    EXCEPTION WHEN duplicate_object THEN NULL; END;
    BEGIN CREATE ROLE usuario_coordenacao LOGIN PASSWORD 'coordenacao' IN ROLE coordenacao;
    EXCEPTION WHEN duplicate_object THEN NULL; END;
END
$$;

-- ---------------------------------------------------------------------
-- 2) Primeiro tira tudo, depois dá só o necessário
-- ---------------------------------------------------------------------
-- PUBLIC é "todo mundo que conecta no banco". Tirando dele, um usuário novo
-- não enxerga nada até receber GRANT de algum papel.
REVOKE ALL ON SCHEMA academico FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA academico FROM PUBLIC, aluno, secretaria, coordenacao;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA academico FROM PUBLIC;

-- USAGE no schema = poder "entrar na pasta". Sem isso nem o GRANT na
-- tabela adianta.
GRANT USAGE ON SCHEMA academico TO aluno, secretaria, coordenacao;

-- O gatilho de vagas roda com a permissão de quem faz o INSERT, então a
-- secretaria precisa poder executar a função.
GRANT EXECUTE ON FUNCTION fn_tb_valida_vaga() TO secretaria;

-- ---------------------------------------------------------------------
-- 3) GRANT por papel
-- ---------------------------------------------------------------------
-- aluno: tabelas de catálogo (o que é público na faculdade) e as views.
-- tb_aluno, tb_matricula_aluno e tb_historico ele também lê, mas a RLS
-- (seção 5) filtra para só as linhas dele. As tabelas são necessárias
-- porque a vw_historico é security_invoker e lê as tabelas com a
-- permissão do aluno.
-- Não recebe tb_professor (tem e-mail), tb_log_matricula nem
-- mv_indicadores.
GRANT SELECT ON tb_curso, tb_curriculo, tb_curriculo_disciplina, tb_disciplinas,
                tb_pre_requisito, tb_periodo_letivo, tb_turma, tb_turma_horario,
                tb_sala, tb_campus
             TO aluno;
GRANT SELECT ON tb_aluno, tb_matricula_aluno, tb_historico TO aluno;
GRANT SELECT ON vw_oferta, vw_vagas, vw_historico TO aluno;

-- secretaria: lê tudo; escreve no cadastro de aluno, na matrícula, no
-- histórico (notas) e no log. Não recebe DELETE em matrícula: matrícula
-- se cancela pelo status, para não perder o histórico e o log.
GRANT SELECT ON ALL TABLES IN SCHEMA academico TO secretaria;
GRANT INSERT, UPDATE ON tb_aluno, tb_matricula_aluno, tb_historico TO secretaria;
GRANT INSERT ON tb_log_matricula TO secretaria;

-- coordenacao: lê tudo (inclusive mv_indicadores) e monta a oferta.
-- Não mexe em nota nem em matrícula.
GRANT SELECT ON ALL TABLES IN SCHEMA academico TO coordenacao;
GRANT INSERT, UPDATE, DELETE ON tb_turma, tb_turma_horario,
                                tb_curriculo, tb_curriculo_disciplina,
                                tb_disciplinas, tb_pre_requisito
                             TO coordenacao;

-- ---------------------------------------------------------------------
-- 4) Função que devolve o aluno conectado
-- ---------------------------------------------------------------------
-- SECURITY DEFINER: roda com a permissão do DONO da função (bd2). Ela
-- precisa ler tb_aluno sem passar pela RLS. Se fosse uma consulta normal
-- dentro da política de tb_aluno, a política chamaria ela mesma.
-- Atenção ao session_user: dentro de uma função SECURITY DEFINER o
-- current_user vira o dono (bd2). session_user continua sendo quem fez o
-- login, que é o que interessa aqui.
-- SET search_path fixo: sem isso alguém poderia criar uma tabela tb_aluno
-- falsa em outro schema e enganar a função.
CREATE OR REPLACE FUNCTION fn_aluno_logado() RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = academico, pg_temp
AS $$
    SELECT aluno_id FROM tb_aluno WHERE 'aluno_' || matricula = session_user;
$$;

REVOKE ALL ON FUNCTION fn_aluno_logado() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_aluno_logado() TO aluno;

-- ---------------------------------------------------------------------
-- 5) Row-level security (RLS)
-- ---------------------------------------------------------------------
-- Com RLS ligada, cada SELECT/INSERT/UPDATE/DELETE na tabela ganha um
-- filtro extra, definido pela política (POLICY). Quem não tem nenhuma
-- política que libere não vê nenhuma linha (não dá erro, só volta vazio).
-- O dono da tabela e o superusuário não passam pela RLS.
ALTER TABLE tb_aluno           ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_matricula_aluno ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_historico       ENABLE ROW LEVEL SECURITY;

-- DROP antes do CREATE porque CREATE POLICY não tem IF NOT EXISTS
DROP POLICY IF EXISTS pol_aluno_proprio      ON tb_aluno;
DROP POLICY IF EXISTS pol_matricula_propria  ON tb_matricula_aluno;
DROP POLICY IF EXISTS pol_historico_proprio  ON tb_historico;
DROP POLICY IF EXISTS pol_aluno_equipe       ON tb_aluno;
DROP POLICY IF EXISTS pol_matricula_equipe   ON tb_matricula_aluno;
DROP POLICY IF EXISTS pol_historico_equipe   ON tb_historico;

-- O aluno só enxerga a própria linha, as próprias matrículas e o próprio
-- histórico. tb_historico não tem aluno_id, então a política sobe pela
-- matrícula para descobrir de quem é a nota.
CREATE POLICY pol_aluno_proprio ON tb_aluno
    FOR SELECT TO aluno
    USING (aluno_id = fn_aluno_logado());

CREATE POLICY pol_matricula_propria ON tb_matricula_aluno
    FOR SELECT TO aluno
    USING (aluno_id = fn_aluno_logado());

CREATE POLICY pol_historico_proprio ON tb_historico
    FOR SELECT TO aluno
    USING (EXISTS (SELECT 1
                   FROM   tb_matricula_aluno m
                   WHERE  m.matricula_aluno_id = tb_historico.matricula_aluno_id
                     AND  m.aluno_id = fn_aluno_logado()));

-- Secretaria e coordenação trabalham com todos os alunos. USING (true)
-- libera todas as linhas. O que cada um pode FAZER já foi limitado pelo
-- GRANT da seção 3.
CREATE POLICY pol_aluno_equipe ON tb_aluno
    FOR ALL TO secretaria, coordenacao USING (true) WITH CHECK (true);
CREATE POLICY pol_matricula_equipe ON tb_matricula_aluno
    FOR ALL TO secretaria, coordenacao USING (true) WITH CHECK (true);
CREATE POLICY pol_historico_equipe ON tb_historico
    FOR ALL TO secretaria, coordenacao USING (true) WITH CHECK (true);

-- ---------------------------------------------------------------------
-- 6) Teste (o mesmo que mostramos na apresentação)
-- ---------------------------------------------------------------------
-- SET SESSION AUTHORIZATION troca o session_user (só superusuário pode).
-- SET ROLE não serviria, porque não muda o session_user que a
-- fn_aluno_logado() usa.
-- Ao vivo dá para fazer igual entrando com o usuário:
--     psql -h localhost -U aluno_26000001 -d matricula      (senha: aluno)

-- Aluno 1: deve ver só a própria matrícula e o próprio histórico
SET SESSION AUTHORIZATION aluno_26000001;
SELECT session_user AS conectado_como,
       (SELECT count(*) FROM academico.tb_aluno)           AS alunos_visiveis,
       (SELECT count(*) FROM academico.tb_historico)       AS historicos_visiveis,
       (SELECT count(DISTINCT aluno_id) FROM academico.vw_historico) AS alunos_no_boletim;
-- Tentando ler o histórico do aluno 2 de propósito: volta vazio
SELECT count(*) AS historico_do_aluno_2
FROM   academico.vw_historico WHERE matricula = '26000002';
-- vw_vagas continua mostrando a ocupação de todas as turmas: a view é do
-- bd2 (não é security_invoker), então a contagem não passa pela RLS. O
-- aluno vê quantas vagas tem, mas não QUEM está matriculado.
SELECT count(*) AS turmas_em_vw_vagas FROM academico.vw_vagas;
RESET SESSION AUTHORIZATION;

-- Secretaria: vê todos
SET SESSION AUTHORIZATION usuario_secretaria;
SELECT session_user AS conectado_como,
       (SELECT count(*) FROM academico.tb_historico) AS historicos_visiveis;
RESET SESSION AUTHORIZATION;

-- Aluno tentando ler tabela sem GRANT: o bloco captura o erro e mostra a
-- mensagem, para o script seguir até o fim.
SET SESSION AUTHORIZATION aluno_26000001;
DO $$
BEGIN
    PERFORM * FROM academico.tb_professor;
    RAISE NOTICE 'ERRO NO TESTE: o aluno conseguiu ler tb_professor';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK, aluno sem acesso a tb_professor: %', SQLERRM;
END
$$;
RESET SESSION AUTHORIZATION;
