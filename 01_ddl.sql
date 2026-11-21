-- =====================================================================
-- BANCO DE DADOS II · CCO072 · IESB · 2026/2
-- MARCO 1  ·  ARQUIVO 1 DE 3  ·  DDL (a estrutura do banco)
--
-- Baseado no modelo lógico do grupo (prefixo tb_) e no modelo de referência
-- do professor. Testado em PostgreSQL 16.
--
-- COMO RODAR (numa base vazia ou já usada):
--     psql -d matricula -f 01_ddl.sql
--
-- IDEMPOTENTE: pode rodar quantas vezes quiser sem erro. Isso é o que o
-- "IF NOT EXISTS" (e os blocos DO) garantem. Atenção: IF NOT EXISTS só
-- evita o erro de "já existe"; ele NÃO altera uma tabela que já existe.
-- Se mudar a definição de uma tabela, apague-a antes (veja o DROP no fim).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. SCHEMA, EXTENSÃO E CAMINHO DE BUSCA
-- ---------------------------------------------------------------------
-- Schema = "pasta" dentro do banco. Usamos "academico", como no ambiente
-- da disciplina, para não misturar com o schema padrão "public".
CREATE SCHEMA IF NOT EXISTS academico;

-- search_path = em quais schemas o PostgreSQL procura nomes sem prefixo.
-- Com isso podemos escrever tb_aluno em vez de academico.tb_aluno.
-- (vale só para esta sessão; os outros arquivos repetem esta linha)
SET search_path TO academico, public;

-- btree_gist ensina o índice GiST a comparar igualdade (=) de inteiros.
-- Precisamos disso na restrição EXCLUDE de tb_turma_horario (seção 3).
CREATE EXTENSION IF NOT EXISTS btree_gist SCHEMA public;


-- ---------------------------------------------------------------------
-- 1. TIPOS E DOMÍNIOS
-- ---------------------------------------------------------------------
-- CREATE TYPE não tem "IF NOT EXISTS" no PostgreSQL. O truque é tentar
-- criar dentro de um bloco DO e ignorar o erro "duplicate_object".
DO $$
BEGIN
    -- ENUM = lista fechada de valores. O banco recusa qualquer outro valor
    -- e ocupa menos espaço que um varchar com CHECK.
    BEGIN CREATE TYPE turno_t      AS ENUM ('MATUTINO','VESPERTINO','NOTURNO');
    EXCEPTION WHEN duplicate_object THEN NULL; END;

    BEGIN CREATE TYPE tipo_disc_t  AS ENUM ('OBRIGATORIA','OPTATIVA');
    EXCEPTION WHEN duplicate_object THEN NULL; END;

    BEGIN CREATE TYPE vinculo_t    AS ENUM ('PRE_REQUISITO','CO_REQUISITO');
    EXCEPTION WHEN duplicate_object THEN NULL; END;

    BEGIN CREATE TYPE status_mat_t AS ENUM ('MATRICULADO','TRANCADO','CANCELADO');
    EXCEPTION WHEN duplicate_object THEN NULL; END;

    BEGIN CREATE TYPE situacao_t   AS ENUM ('CURSANDO','APROVADO','REPROVADO_NOTA','REPROVADO_FALTA');
    EXCEPTION WHEN duplicate_object THEN NULL; END;

    BEGIN CREATE TYPE tipo_sala_t  AS ENUM ('TEORICA','LABORATORIO');
    EXCEPTION WHEN duplicate_object THEN NULL; END;

    -- DOMAIN = um tipo base + uma regra que acompanha o tipo. Escrevemos a
    -- regra UMA vez e todas as colunas que usarem o domínio a herdam.
    -- nota_t: nota de 0 a 10 com duas casas decimais.
    BEGIN CREATE DOMAIN nota_t AS numeric(4,2) CHECK (VALUE >= 0 AND VALUE <= 10);
    EXCEPTION WHEN duplicate_object THEN NULL; END;

    -- pct_t: percentual de 0 a 100 (usado na frequência).
    BEGIN CREATE DOMAIN pct_t AS numeric(5,2) CHECK (VALUE >= 0 AND VALUE <= 100);
    EXCEPTION WHEN duplicate_object THEN NULL; END;

    -- timerange: tipo "intervalo de horas" (ex.: [08:15,11:00)). Permite
    -- perguntar "esses dois intervalos se sobrepõem?" com o operador &&.
    BEGIN CREATE TYPE timerange AS RANGE (subtype = time);
    EXCEPTION WHEN duplicate_object THEN NULL; END;
END
$$;


-- ---------------------------------------------------------------------
-- 2. LOCALIZAÇÃO E ESTRUTURA INSTITUCIONAL
-- ---------------------------------------------------------------------
-- Vocabulário das colunas, que se repete em todas as tabelas:
--   GENERATED ALWAYS AS IDENTITY  -> o banco gera 1, 2, 3... sozinho. É a
--                                    forma padrão (SQL) do antigo SERIAL;
--                                    "ALWAYS" impede inserir um id à mão.
--   PRIMARY KEY (PK)              -> identifica a linha. Já é NOT NULL e UNIQUE.
--   NOT NULL                      -> a coluna é obrigatória.
--   UNIQUE                        -> proíbe valores repetidos na coluna.
--   CHECK (...)                   -> regra que todo valor precisa cumprir.
--   REFERENCES tabela (FK)        -> chave estrangeira: o valor tem de existir
--                                    na tabela apontada (integridade referencial).
--   ON DELETE ...                 -> o que fazer com as linhas filhas quando a
--                                    linha pai é apagada:
--        RESTRICT  = proíbe apagar o pai enquanto houver filhos (o mais seguro)
--        CASCADE   = apaga os filhos junto
--        SET NULL  = mantém o filho e zera a FK (a coluna precisa aceitar NULL;
--                    não é usado neste modelo, só está aqui para você conhecer)

CREATE TABLE IF NOT EXISTS tb_pais (
    pais_id    integer      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_pais  varchar(100) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS tb_estado (
    estado_id    integer      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pais_id      integer      NOT NULL REFERENCES tb_pais ON DELETE RESTRICT,
    nome_estado  varchar(200) NOT NULL,
    -- UNIQUE com duas colunas: o par não pode repetir (dois países podem
    -- ter um estado com o mesmo nome, mas o mesmo país não).
    UNIQUE (pais_id, nome_estado)
);

CREATE TABLE IF NOT EXISTS tb_cidade (
    cidade_id    integer      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    estado_id    integer      NOT NULL REFERENCES tb_estado ON DELETE RESTRICT,
    nome_cidade  varchar(200) NOT NULL,
    UNIQUE (estado_id, nome_cidade)
);

CREATE TABLE IF NOT EXISTS tb_predio (
    predio_id     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    bloco_predio  char(3) NOT NULL,
    andar_predio  char(3) NOT NULL,
    UNIQUE (bloco_predio, andar_predio)
);

CREATE TABLE IF NOT EXISTS tb_campus (
    campus_id    smallint     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cidade_id    integer      NOT NULL REFERENCES tb_cidade ON DELETE RESTRICT,
    nome_campus  varchar(60)  NOT NULL UNIQUE,
    endereco     varchar(200) NOT NULL,
    telefone     varchar(20),                       -- opcional
    -- "~" é o operador de expressão regular: o CEP tem de ser 8 dígitos.
    cep          char(8)      NOT NULL CHECK (cep ~ '^[0-9]{8}$')
);

CREATE TABLE IF NOT EXISTS tb_curso (
    curso_id      smallint     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    campus_id     smallint     NOT NULL REFERENCES tb_campus ON DELETE RESTRICT,
    codigo_curso  varchar(10)  NOT NULL UNIQUE,
    nome_curso    varchar(120) NOT NULL,
    grau          varchar(20)  NOT NULL
                  CHECK (grau IN ('BACHARELADO','LICENCIATURA','TECNOLOGO')),
    ch_total      integer      NOT NULL CHECK (ch_total > 0)
);

CREATE TABLE IF NOT EXISTS tb_curriculo (
    curriculo_id  smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- CASCADE: se o curso for apagado, seus currículos vão junto.
    curso_id      smallint NOT NULL REFERENCES tb_curso ON DELETE CASCADE,
    ano_vigencia  smallint NOT NULL CHECK (ano_vigencia BETWEEN 2000 AND 2100),
    ativo         boolean  NOT NULL DEFAULT false,   -- DEFAULT = valor se não informarem
    UNIQUE (curso_id, ano_vigencia)
);

-- Índice ÚNICO PARCIAL: só as linhas com ativo = true entram no índice, e
-- dentro delas o curso_id não pode repetir. Resultado: no máximo UM
-- currículo ativo por curso. É regra de negócio (integridade), não de
-- desempenho. Fica fora do CREATE TABLE porque o WHERE só existe em índice.
CREATE UNIQUE INDEX IF NOT EXISTS uq_tb_curriculo_ativo
    ON tb_curriculo (curso_id) WHERE ativo;


-- ---------------------------------------------------------------------
-- 3. DISCIPLINAS, PROFESSORES E SALAS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_disciplinas (
    disciplina_id      integer      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo_disciplina  varchar(10)  NOT NULL UNIQUE,
    nome_disciplina    varchar(120) NOT NULL,
    ch_teorica         smallint     NOT NULL CHECK (ch_teorica >= 0),
    ch_pratica         smallint     NOT NULL CHECK (ch_pratica >= 0),
    -- COLUNA GERADA: o banco calcula sozinho a partir das outras colunas.
    -- STORED = o valor é gravado no disco (e recalculado a cada UPDATE).
    -- Não dá para inserir nela; assim ela nunca fica inconsistente.
    ch_total           smallint     GENERATED ALWAYS AS (ch_teorica + ch_pratica) STORED,
    ementa             text,
    -- CHECK no fim da tabela olha para mais de uma coluna ao mesmo tempo.
    CHECK (ch_teorica + ch_pratica > 0)
);

CREATE TABLE IF NOT EXISTS tb_curriculo_disciplina (
    curriculo_id   smallint    NOT NULL REFERENCES tb_curriculo   ON DELETE CASCADE,
    disciplina_id  integer     NOT NULL REFERENCES tb_disciplinas ON DELETE RESTRICT,
    periodo        smallint    NOT NULL CHECK (periodo BETWEEN 1 AND 12),
    tipo           tipo_disc_t NOT NULL DEFAULT 'OBRIGATORIA',
    -- CHAVE PRIMÁRIA COMPOSTA: o par é a identidade. A mesma disciplina pode
    -- estar em vários currículos, mas só uma vez em cada um.
    PRIMARY KEY (curriculo_id, disciplina_id)
);

-- AUTO-RELACIONAMENTO: as DUAS colunas apontam para tb_disciplinas.
-- "disciplina_id exige requisito_id". É esta tabela que alimenta a consulta
-- recursiva da árvore de pré-requisitos.
CREATE TABLE IF NOT EXISTS tb_pre_requisito (
    disciplina_id  integer   NOT NULL REFERENCES tb_disciplinas ON DELETE CASCADE,
    requisito_id   integer   NOT NULL REFERENCES tb_disciplinas ON DELETE RESTRICT,
    vinculo        vinculo_t NOT NULL DEFAULT 'PRE_REQUISITO',
    PRIMARY KEY (disciplina_id, requisito_id),
    -- uma disciplina não pode ser pré-requisito de si mesma
    CHECK (disciplina_id <> requisito_id)
);

CREATE TABLE IF NOT EXISTS tb_professor (
    professor_id  integer      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome          varchar(120) NOT NULL,
    email         varchar(120) NOT NULL UNIQUE
                  CHECK (email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[a-z]{2,}$'),
    titulacao     varchar(20)  NOT NULL
                  CHECK (titulacao IN ('ESPECIALISTA','MESTRE','DOUTOR')),
    status        status_mat_t NOT NULL DEFAULT 'MATRICULADO'
);

CREATE TABLE IF NOT EXISTS tb_sala (
    sala_id      integer      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    predio_id    integer      NOT NULL REFERENCES tb_predio ON DELETE RESTRICT,
    campus_id    smallint     NOT NULL REFERENCES tb_campus ON DELETE RESTRICT,
    codigo_sala  varchar(10)  NOT NULL,
    capacidade   smallint     NOT NULL CHECK (capacidade > 0),
    tipo_sala    tipo_sala_t  NOT NULL DEFAULT 'TEORICA',
    UNIQUE (campus_id, codigo_sala)      -- o código só precisa ser único dentro do campus
);


-- ---------------------------------------------------------------------
-- 4. OFERTA: PERÍODO, FERIADO, TURMA E HORÁRIO
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_periodo_letivo (
    periodo_id   smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ano          smallint NOT NULL,
    semestre     smallint NOT NULL CHECK (semestre IN (1, 2)),
    data_inicio  date     NOT NULL,
    data_fim     date     NOT NULL,
    UNIQUE (ano, semestre),
    CHECK (data_fim > data_inicio)
);

-- Um feriado vale para UM âmbito: país (nacional), estado (estadual) ou
-- cidade (municipal). Por isso as três FKs aceitam NULL, mas o CHECK exige
-- que exatamente uma esteja preenchida.
CREATE TABLE IF NOT EXISTS tb_feriado (
    feriado_id   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pais_id      integer REFERENCES tb_pais   ON DELETE CASCADE,
    estado_id    integer REFERENCES tb_estado ON DELETE CASCADE,
    cidade_id    integer REFERENCES tb_cidade ON DELETE CASCADE,
    dia_feriado  date    NOT NULL,
    -- num_nonnulls conta quantos argumentos não são NULL.
    CHECK (num_nonnulls(pais_id, estado_id, cidade_id) = 1),
    -- Em UNIQUE comum, NULL é sempre "diferente" de NULL, então duplicatas
    -- passariam. NULLS NOT DISTINCT (PostgreSQL 15+) trata NULLs como iguais.
    UNIQUE NULLS NOT DISTINCT (dia_feriado, pais_id, estado_id, cidade_id)
);

CREATE TABLE IF NOT EXISTS tb_turma (
    turma_id       integer     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo         varchar(20) NOT NULL,
    disciplina_id  integer     NOT NULL REFERENCES tb_disciplinas     ON DELETE RESTRICT,
    periodo_id     smallint    NOT NULL REFERENCES tb_periodo_letivo  ON DELETE RESTRICT,
    -- Toda turma tem exatamente 1 professor (cardinalidade 1,1 no modelo): no IESB o
    -- professor já está alocado à disciplina antes da turma ser formada.
    -- RESTRICT: não dá para apagar um professor que ainda tem turmas.
    professor_id   integer     NOT NULL REFERENCES tb_professor ON DELETE RESTRICT,
    turno          turno_t     NOT NULL,
    vagas          smallint    NOT NULL CHECK (vagas > 0),
    UNIQUE (codigo, periodo_id, disciplina_id)
);

-- Uma turma pode ter vários horários (ex.: segunda e quarta), cada um numa
-- sala. O dia da semana e o horário ficam AQUI (e não em tb_turma), porque
-- a regra "a mesma sala não pode receber duas turmas ao mesmo tempo" precisa
-- de sala + dia + horário na mesma tabela.
CREATE TABLE IF NOT EXISTS tb_turma_horario (
    horario_id      integer  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    turma_id        integer  NOT NULL REFERENCES tb_turma ON DELETE CASCADE,
    sala_id         integer  NOT NULL REFERENCES tb_sala  ON DELETE RESTRICT,
    dia_semana      smallint NOT NULL CHECK (dia_semana BETWEEN 1 AND 7),   -- 1 = domingo
    horario_inicio  time     NOT NULL,
    horario_fim     time     NOT NULL,
    CHECK (horario_fim > horario_inicio),
    -- EXCLUDE = "UNIQUE generalizado": em vez de proibir linhas IGUAIS,
    -- proíbe linhas que se SOBREPÕEM. Lê-se: não podem existir duas linhas
    -- com a mesma sala (=), o mesmo dia (=) e horários que se cruzam (&&).
    CONSTRAINT ex_tb_sala_ocupada
        EXCLUDE USING gist (
            sala_id    WITH =,
            dia_semana WITH =,
            (timerange(horario_inicio, horario_fim)) WITH &&
        )
);


-- ---------------------------------------------------------------------
-- 5. VIDA ACADÊMICA
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_aluno (
    aluno_id      integer      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    curso_id      smallint     NOT NULL REFERENCES tb_curso     ON DELETE RESTRICT,
    curriculo_id  smallint     NOT NULL REFERENCES tb_curriculo ON DELETE RESTRICT,
    matricula     varchar(12)  NOT NULL UNIQUE,     -- número de matrícula do aluno (o "RA")
    nome          varchar(120) NOT NULL,
    cpf           char(11)     NOT NULL UNIQUE CHECK (cpf ~ '^[0-9]{11}$'),
    email         varchar(120) NOT NULL UNIQUE
                  CHECK (email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[a-z]{2,}$'),
    nascimento    date         NOT NULL,
    ingresso      date         NOT NULL,
    ativo         boolean      NOT NULL DEFAULT true,
    -- Compara duas colunas da mesma linha (ninguém ingressa antes de nascer).
    CHECK (ingresso > nascimento)
);

-- A matrícula do aluno EM UMA TURMA (não confundir com tb_aluno.matricula).
CREATE TABLE IF NOT EXISTS tb_matricula_aluno (
    matricula_aluno_id  integer      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- CASCADE: apagar o aluno apaga as matrículas dele.
    aluno_id            integer      NOT NULL REFERENCES tb_aluno ON DELETE CASCADE,
    turma_id            integer      NOT NULL REFERENCES tb_turma ON DELETE RESTRICT,
    data_matricula      timestamptz  NOT NULL DEFAULT now(),
    status              status_mat_t NOT NULL DEFAULT 'MATRICULADO',
    -- o mesmo aluno não pode se matricular duas vezes na mesma turma
    UNIQUE (aluno_id, turma_id)
);

-- Relação 1:1 com a matrícula: a PK é, ao mesmo tempo, a FK. Assim cada
-- matrícula tem no máximo um histórico.
CREATE TABLE IF NOT EXISTS tb_historico (
    matricula_aluno_id  integer PRIMARY KEY
                        REFERENCES tb_matricula_aluno ON DELETE CASCADE,
    nota_a1     nota_t,                 -- domínio: 0 a 10, aceita NULL (ainda sem nota)
    nota_a2     nota_t,
    nota_a3     nota_t,                 -- prova substitutiva (P3 no modelo do professor)
    frequencia  pct_t      NOT NULL DEFAULT 100,
    situacao    situacao_t NOT NULL DEFAULT 'CURSANDO',
    -- Média final calculada pelo banco. Regra: MF = 0,4*A1 + 0,6*A2.
    -- Com a substitutiva (A3), ela troca a nota menos favorável.
    -- Sem A1 ou A2 ainda lançadas, a média fica NULL.
    media_final numeric(4,2) GENERATED ALWAYS AS (
        CASE
            WHEN nota_a1 IS NULL OR nota_a2 IS NULL THEN NULL
            WHEN nota_a3 IS NULL THEN round(0.4*nota_a1 + 0.6*nota_a2, 2)
            ELSE round(greatest(0.4*nota_a3 + 0.6*nota_a2,
                                0.4*nota_a1 + 0.6*nota_a3), 2)
        END
    ) STORED
);

-- Trilha de auditoria. Cada ação gera uma linha nova, então a PK é um
-- número próprio (log_id) e matricula_aluno_id é só FK: uma matrícula pode
-- ter vários logs. RESTRICT protege a auditoria: uma matrícula que já tem
-- log não pode ser apagada (cancele pelo status).
CREATE TABLE IF NOT EXISTS tb_log_matricula (
    log_id              bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    matricula_aluno_id  integer      NOT NULL REFERENCES tb_matricula_aluno ON DELETE RESTRICT,
    acao                varchar(20)  NOT NULL,
    ocorrido_em         timestamptz  NOT NULL DEFAULT now(),
    usuario             name         NOT NULL DEFAULT CURRENT_USER,   -- quem executou
    detalhe             jsonb                                         -- dados livres em JSON
);


-- ---------------------------------------------------------------------
-- 6. REGRA DE NEGÓCIO: LIMITE DE VAGAS (GATILHO / TRIGGER)
-- ---------------------------------------------------------------------
-- Trigger = função que o banco executa SOZINHO antes/depois de um
-- INSERT/UPDATE/DELETE. Aqui ela recusa a matrícula quando a turma lotou.
-- SET search_path na função: o gatilho roda na sessão de quem fez o INSERT.
-- Se essa pessoa não tiver dado SET search_path (ex.: a secretaria entrando
-- pelo DBeaver), "tb_turma" não seria encontrada e a matrícula daria erro.
CREATE OR REPLACE FUNCTION fn_tb_valida_vaga() RETURNS trigger
LANGUAGE plpgsql
SET search_path = academico, public
AS $$
DECLARE
    v_vagas     smallint;
    v_ocupadas  integer;
BEGIN
    -- só matrícula ATIVA ocupa vaga; trancada/cancelada passa direto
    IF NEW.status <> 'MATRICULADO' THEN
        RETURN NEW;
    END IF;

    -- NEW = a linha que está tentando entrar
    SELECT vagas INTO v_vagas FROM tb_turma WHERE turma_id = NEW.turma_id;

    SELECT count(*) INTO v_ocupadas
      FROM tb_matricula_aluno
     WHERE turma_id = NEW.turma_id
       AND status   = 'MATRICULADO'
       AND matricula_aluno_id <> COALESCE(NEW.matricula_aluno_id, -1);  -- não conta a si mesma

    IF v_ocupadas >= v_vagas THEN
        RAISE EXCEPTION 'Turma % sem vagas (% de %)', NEW.turma_id, v_ocupadas, v_vagas
              USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;   -- devolver NEW autoriza a gravação
END
$$;

-- ATENÇÃO (frente de Transações): este gatilho lê a contagem sem bloquear
-- a linha da turma. Sob concorrência duas sessões enxergam a mesma última
-- vaga e ocorre overbooking. NÃO adicione FOR UPDATE aqui: reproduzir a
-- anomalia e depois corrigi-la é parte do trabalho.
CREATE OR REPLACE TRIGGER tg_tb_valida_vaga
    BEFORE INSERT OR UPDATE ON tb_matricula_aluno
    FOR EACH ROW EXECUTE FUNCTION fn_tb_valida_vaga();


-- ---------------------------------------------------------------------
-- NOTAS FINAIS
-- ---------------------------------------------------------------------
-- * Índices de desempenho (além dos que PK/UNIQUE já criam) ficam para a
--   etapa de EXPLAIN ANALYZE: é preciso medir ANTES de criar cada índice
--   para comprovar o ganho DEPOIS. Lembre que o PostgreSQL não indexa FK
--   automaticamente.
-- * Para recomeçar do zero (APAGA TUDO do schema):
--       DROP SCHEMA academico CASCADE;
--   CUIDADO: no banco "matricula" do professor esse schema TAMBÉM guarda as
--   tabelas dele. Por isso o roteiro recomenda criar um banco só seu (marco1):
--   aí recomeçar é só  DROP DATABASE marco1;  sem risco para o ambiente dele.
