---
name: analise-reprovacao-enel
description: Analisa projetos de regularização de postes/infraestrutura para provedores (licença de uso Enel) que foram reprovados no sistema da Enel, compara contra um projeto de referência já aprovado, identifica se o motivo de reprovação procede e gera um relatório técnico / manifestação técnica pronta para reenvio. Use sempre que o usuário mencionar reprovação da Enel, parecer de reprovação, CSV de rede, esforço mecânico em kgf, ART de projeto de poste, ou pedir para comparar um projeto novo com um projeto aprovado.
---

# Análise de Reprovação Enel — Regularização de Postes

## Objetivo
Dado (a) um parecer de reprovação da Enel e (b) os arquivos do projeto reprovado — e, se disponível, (c) os arquivos de um projeto irmão já aprovado usado como referência — produzir:
1. Um diagnóstico item a item do motivo de reprovação (procede / não procede / parcialmente procede).
2. Uma manifestação técnica formal, pronta para anexar ao reenvio.

## Arquivos necessários (pedir ao usuário se não vierem anexados)
- CSV de rede/cabos do projeto reprovado
- Memorial descritivo
- ART (Anotação de Responsabilidade Técnica)
- Planilha de cálculo de esforço mecânico
- (Opcional, mas recomendado) os mesmos 4 arquivos do projeto de referência já aprovado
- Texto/print do parecer de reprovação da Enel

Nunca tente acessar caminhos de disco local do usuário (ex. `E:\...`, `C:\...`) — este ambiente não tem acesso ao computador do usuário. Sempre peça para anexar os arquivos no chat, ou usar um conector de nuvem (Google Drive) se disponível e autorizado.

## Checklist de verificação (baseado nos motivos recorrentes de reprovação Enel para projetos de rede de provedores)

Para cada item, conferir contra os arquivos reais — não supor.

1. **Coluna J do CSV — Esforço mecânico (kgf)**
   - Toda linha do CSV deve ter a coluna J preenchida.
   - Linhas sem esforço aplicável devem ter `0`, nunca célula vazia.
   - Verificar se algum cabo projetado ficou sem valor.

2. **Coluna N do CSV — Tipo (NOEQ vs FIBR)**
   - Onde a coluna N estiver `NOEQ` mas a linha se referir a um cabo (não a um equipamento físico), deve ser `FIBR`.
   - `NOEQ` só é válido para itens que realmente não são equipamento nem cabo (ex. linhas de estrutura/apoio, se aplicável ao layout do CSV do provedor).

3. **Memorial descritivo**
   - Deve declarar explicitamente a quantidade de rede nova / cabo projetado (metragem total, preferencialmente por trecho e total geral).
   - Comparar o valor citado no memorial com o somatório real do CSV — devem bater.

4. **Postes de terceiros**
   - Nenhum poste do projeto pode ser de propriedade de terceiros (fora da concessionária/Enel).
   - Cruzar a relação de postes do CSV/planilha com cadastro Enel, se disponível, ou pelo menos confirmar que todos são postes Enel homologados.

5. **ART — Endereços**
   - Todos os endereços do projeto devem constar na ART.
   - Se a ART tiver campo limitado, os endereços excedentes devem estar no campo "Observação".
   - Conferir a lista de endereços do projeto (CSV/memorial) contra o que está na ART; listar quais faltam.

6. **Planilha de cálculo de esforço — Unidade**
   - A planilha deve expressar o esforço em **kgf**.
   - Se estiver em outra unidade (N, kgf/m, daN etc.), sinalizar como erro e recalcular/converter.

## Processo

1. Ler todos os arquivos fornecidos (CSV, memorial, ART, planilha de esforço) do projeto reprovado.
2. Se houver projeto de referência aprovado, ler os mesmos arquivos dele e comparar estrutura/preenchimento lado a lado — isso revela rapidamente diferenças de preenchimento entre os dois (ex: coluna N preenchida diferente, memorial sem a metragem, etc.).
3. Rodar o checklist acima item a item contra os dados reais (não contra a descrição do usuário).
4. Para cada item do parecer de reprovação, classificar:
   - **Procede** — erro real encontrado nos arquivos, com localização exata (linha do CSV, seção do memorial, campo da ART).
   - **Não procede** — o item já está correto nos arquivos; a reprovação parece equivocada ou baseada em outra leitura.
   - **Parcialmente procede** — correto em parte dos casos, errado em outros (ex: 40 de 45 linhas do CSV corretas, 5 sem preenchimento).
5. Gerar o relatório final usando o template abaixo.
6. Entregar como artifact (documento) para o usuário revisar e reenviar à Enel.

## Template do relatório / manifestação técnica

```
MANIFESTAÇÃO TÉCNICA — RESPOSTA À REPROVAÇÃO DE PROJETO
Projeto: [nome/código do projeto — ex. Catunda]
Referência: [protocolo/parecer da Enel, se houver]
Data: [data]

1. RESUMO DO PARECER DE REPROVAÇÃO
[reproduzir os pontos do parecer da Enel]

2. ANÁLISE TÉCNICA POR ITEM

2.1 [Item do parecer]
Status: [Procede / Não procede / Parcialmente procede]
Constatação: [o que foi encontrado nos arquivos, com referência exata]
Ação corretiva: [o que foi/será alterado]

[repetir para cada item]

3. CORREÇÕES APLICADAS
[lista objetiva de cada correção feita nos arquivos antes do reenvio]

4. CONCLUSÃO
[projeto corrigido e pronto para reenvio / pontos que precisam de decisão do usuário]
```

## Observações importantes
- Não afirmar que um item "não procede" sem ter conferido o dado real no arquivo — isso é uma manifestação técnica formal enviada a uma concessionária, erros de leitura têm custo (novo ciclo de reprovação).
- Se um arquivo necessário não foi enviado, parar e pedir explicitamente antes de gerar conclusões sobre aquele item.
- Preferir sempre comparar contra o projeto aprovado quando disponível — é a evidência mais forte de que "o processo é o mesmo" ou não.
