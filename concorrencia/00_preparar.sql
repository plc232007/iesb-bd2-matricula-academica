-- =====================================================================
-- concorrencia/00_preparar.sql  ·  Turma de teste com UMA vaga
-- MARCO 2 · Frente: Transações e Concorrência
--
-- Rode antes de CADA cenário (01, 02 e 03). Ele zera a turma de teste.
--     docker compose exec -T postgres psql -U bd2 -d matricula < concorrencia/00_preparar.sql
--
-- Cenário: a turma BD2-DEMO (Banco de Dados II, 2026.2) tem 1 vaga. Dois
-- alunos que ainda não têm matrícula nenhuma (RA 26000101 e 26000102)
-- tentam pegar essa vaga ao mesmo tempo.
-- =====================================================================

SET search_path TO academico, public;

-- Cria a turma se ainda não existir. Professora 8, que não tem turma na
-- carga. Não precisa de horário nem de sala para o teste.
INSERT INTO tb_turma (codigo, disciplina_id, periodo_id, professor_id, turno, vagas)
SELECT 'BD2-DEMO', d.disciplina_id, pl.periodo_id, p.professor_id, 'NOTURNO', 1
FROM   tb_disciplinas d, tb_periodo_letivo pl, tb_professor p
WHERE  d.codigo_disciplina = 'BD2001'
  AND  pl.ano = 2026 AND pl.semestre = 2
  AND  p.email = 'prof8@iesb.edu.br'
ON CONFLICT DO NOTHING;

-- Volta ao estado inicial: 1 vaga e nenhuma matrícula
UPDATE tb_turma SET vagas = 1 WHERE codigo = 'BD2-DEMO';
DELETE FROM tb_matricula_aluno
WHERE  turma_id = (SELECT turma_id FROM tb_turma WHERE codigo = 'BD2-DEMO');

SELECT turma, vagas, ocupadas, livres FROM vw_vagas WHERE turma = 'BD2-DEMO';
