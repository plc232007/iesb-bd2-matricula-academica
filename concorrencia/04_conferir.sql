-- =====================================================================
-- concorrencia/04_conferir.sql  ·  Quantos alunos ficaram na turma de teste
-- Rode depois de cada cenário.
--     docker compose exec -T postgres psql -U bd2 -d matricula < concorrencia/04_conferir.sql
--
-- 01_anomalia      -> ocupadas = 2, livres = -1  (o erro)
-- 02_bloqueio      -> ocupadas = 1, livres = 0
-- 03_serializable  -> ocupadas = 1, livres = 0
-- =====================================================================

SET search_path TO academico, public;

SELECT turma, vagas, ocupadas, livres, situacao
FROM   vw_vagas
WHERE  turma = 'BD2-DEMO';

SELECT a.matricula, a.nome, m.data_matricula
FROM   tb_matricula_aluno m
JOIN   tb_aluno a USING (aluno_id)
JOIN   tb_turma t USING (turma_id)
WHERE  t.codigo = 'BD2-DEMO'
ORDER  BY m.data_matricula;

-- COMPARAÇÃO ENTRE AS DUAS CORREÇÕES
--
--                      FOR UPDATE (02)                  SERIALIZABLE (03)
-- O que faz            trava a linha da turma           não trava, cancela uma das
--                                                       transações no conflito
-- Quem perde           espera e depois recebe           recebe erro 40001 na hora
--                      "sem vagas"
-- Retentativa          não precisa                      precisa: o programa tem que
--                                                       capturar o 40001 e repetir
-- Contenção            fila só na turma disputada;      ninguém espera, mas no
--                      outras turmas seguem livres      horário de pico muitas
--                                                       transações são canceladas e
--                                                       refeitas
-- Custo                um lock de linha por matrícula   o banco anota tudo que cada
--                                                       transação lê (vale para TODAS
--                                                       as transações nesse nível)
-- Onde aplicar         só no código da matrícula        no BEGIN de cada transação
--                                                       que precisa da garantia
-- Falso positivo       não tem                          pode cancelar transações que
--                                                       nem disputavam a mesma vaga
--                                                       se a leitura não usar índice
--                                                       (sem índice ele anota a
--                                                       tabela inteira como lida)
--
-- Testamos o falso positivo: duas sessões SERIALIZABLE ao mesmo tempo, uma
-- na BD2-DEMO e outra na RED-N1. As duas deram COMMIT, porque a contagem
-- do gatilho usa o índice parcial ix_tb_matricula_turma_ativa (05_indices),
-- e aí o banco anota só as páginas do índice daquela turma.
-- Também testamos REPEATABLE READ no lugar de SERIALIZABLE: os dois alunos
-- entraram (2 de 1 vaga), como explicado no 03.
--
-- Escolha do grupo para um sistema de verdade: FOR UPDATE dentro do
-- gatilho. A disputa é sempre pela mesma coisa (a linha da turma) e já
-- sabemos qual linha travar. Ninguém precisa escrever laço de retentativa
-- e o aluno que perde recebe direto a mensagem certa ("sem vagas"). O
-- SERIALIZABLE serve melhor quando a regra envolve muitas tabelas e não dá
-- para saber de antemão o que travar.
-- No projeto o gatilho ficou SEM o FOR UPDATE de propósito, senão o 01 não
-- conseguiria mais mostrar a anomalia.
