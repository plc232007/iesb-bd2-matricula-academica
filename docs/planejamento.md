# Planejamento

As tarefas estão abertas no GitHub, com critérios de aceite, dependências, labels e marcos. Os responsáveis serão definidos pelo grupo conforme AUTORES.md. Nenhuma implementação foi concluída nesta preparação.

| Issue | Tarefa | Marco | Branch sugerida |
| --- | --- | --- | --- |
| [#1](https://github.com/plc232007/iesb-bd2-matricula-academica/issues/1) | Preparar ambiente oficial e definir integrantes | Marco 1 | `feat/1-ambiente` |
| [#2](https://github.com/plc232007/iesb-bd2-matricula-academica/issues/2) | Implementar DDL e restrições de integridade | Marco 1 | `feat/2-ddl` |
| [#3](https://github.com/plc232007/iesb-bd2-matricula-academica/issues/3) | Preparar carga de dados acadêmicos | Marco 1 | `feat/3-carga` |
| [#4](https://github.com/plc232007/iesb-bd2-matricula-academica/issues/4) | Escrever as dez consultas comentadas | Marco 1 | `feat/4-consultas` |
| [#5](https://github.com/plc232007/iesb-bd2-matricula-academica/issues/5) | Criar views e indicadores materializados | Marco 2 | `feat/5-views` |
| [#6](https://github.com/plc232007/iesb-bd2-matricula-academica/issues/6) | Criar índices e comparar planos de execução | Marco 2 | `feat/6-indices` |
| [#7](https://github.com/plc232007/iesb-bd2-matricula-academica/issues/7) | Reproduzir a disputa pela última vaga | Marco 2 | `feat/7-anomalia` |
| [#8](https://github.com/plc232007/iesb-bd2-matricula-academica/issues/8) | Corrigir concorrência com bloqueio explícito | Marco 2 | `feat/8-bloqueio` |
| [#9](https://github.com/plc232007/iesb-bd2-matricula-academica/issues/9) | Corrigir por isolamento e comparar abordagens | Marco 2 | `feat/9-isolamento` |
| [#10](https://github.com/plc232007/iesb-bd2-matricula-academica/issues/10) | Configurar papéis e segurança por aluno | Marco 2 | `feat/10-seguranca` |
| [#11](https://github.com/plc232007/iesb-bd2-matricula-academica/issues/11) | Documentar e validar backup e restauração | Marco 2 | `feat/11-restauracao` |
| [#12](https://github.com/plc232007/iesb-bd2-matricula-academica/issues/12) | Preparar demonstração e revisão cruzada | Seminário | `feat/12-seminario` |
| [#13](https://github.com/plc232007/iesb-bd2-matricula-academica/issues/13) | Avaliar bônus de particionamento ou JSONB | Marco 2 | `feat/13-bonus` |

## Fluxo de trabalho

A estrutura inicial está na branch `chore/estrutura-inicial`, proposta para integração em `main` por pull request. Criar a branch de cada tarefa a partir da `main` atualizada quando o trabalho começar, evitando branches vazias que fiquem desatualizadas. Abrir um pull request usando o modelo do repositório e relacionar a issue.

```bash
git switch main
git pull --ff-only
git switch -c feat/NUMERO-descricao
```

O Marco 1 mantém a data do PDF (14/09/2026), já passada no momento desta organização; confirmar o calendário com o professor. Marco 2: 06/11/2026. Seminário: 09/11 ou 16/11, a definir na escala de 26/10. O bônus é opcional.
