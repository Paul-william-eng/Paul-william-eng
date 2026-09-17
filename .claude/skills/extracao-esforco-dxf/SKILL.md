---
name: extracao-esforco-dxf
description: Lê um arquivo DXF (exportado de projeto de rede aérea de telecomunicações/fibra óptica em AutoCAD) e extrai os marcadores de esforço mecânico (força resultante em kgf + ângulo) já desenhados junto a cada poste, cruzando por coordenada com os pontos de poste do desenho. Gera um CSV pronto pra alimentar a coluna de esforço do CSV de rede exigido pela Enel/JoiN-AS, e um script LISP para reinserir/replicar esses blocos de esforço no AutoCAD com posição, rotação e atributos corretos. Use sempre que o usuário mandar um .dxf de projeto de poste/rede e pedir os esforços de cada ponto, pedir para gerar um LISP de esforço, ou pedir para extrair ângulo e força resultante de um projeto CAD.
---

# Extração de Esforço Mecânico a partir de DXF

## Contexto de origem
Esta skill nasceu da análise de reprovação do projeto Catunda (ver skill `analise-reprovacao-enel`). Descobrimos que:
- A Enel passou a exigir que a coluna de esforço do CSV de rede contenha o **esforço mecânico calculado exercido pelos cabos** (força resultante em kgf, variável por ponto/ângulo), não a capacidade nominal do poste.
- Esse valor calculado **já existe desenhado no projeto DXF**, como blocos de anotação inseridos ao lado de cada poste, com 2 atributos de texto: um com o valor em kgf, outro com o ângulo em graus.
- O nome do bloco **não é padronizado entre projetos** — cada projetista/escritório nomeia do seu jeito. Exemplos reais observados: `Descrição de esforço direita` / `descrição de esforço esquerda` (projeto Catunda), `inddir2` (projeto de referência aprovado, T02).

## Como reconhecer o bloco de esforço num DXF novo (não confiar só no nome)
Um bloco de esforço tem esta assinatura, dentro de uma entidade INSERT:
1. É seguido (no registro de entidades, código de grupo `0`) por exatamente **2 entidades ATTRIB** antes do `SEQEND`.
2. Os dois ATTRIB têm o texto de exibição (código de grupo `1`) no formato de **valor numérico + unidade de força ou de ângulo**: padrões vistos incluem `"70Kgf"`, `"63Kgf"`, `"50,0 kgf"`, `"16.86"` (força) e `"0°"`, `"78°"`, `"0,0°"`, `"26.01"` (ângulo — às vezes sem o símbolo °, deduzir pelo contexto/ordem).
3. A entidade INSERT tem uma rotação (código de grupo `50`) que orienta o bloco na direção do vão/cabo naquele ponto.
4. A tag do atributo (código de grupo `2`) costuma ser um placeholder genérico tipo `"XXX,XXKGF"` reaproveitado nos dois atributos — **não usar a tag pra diferenciar força de ângulo**, usar a ORDEM de aparição (1º ATTRIB, 2º ATTRIB) e o padrão do texto (presença de `°` ou `Kgf`/`kgf`).

Ao processar um DXF novo: primeiro listar todos os nomes de bloco usados em INSERT e sua contagem; blocos candidatos a "esforço" são os que aparecem dezenas/centenas de vezes E cujas instâncias têm exatamente 2 ATTRIB com esse padrão numérico. Confirmar abrindo 2-3 instâncias antes de assumir.

## Processo

1. **Parsear o DXF** (é texto ASCII com pares código/valor, geralmente CRLF — cuidado ao ler linha a linha). Não é necessário nenhuma lib especial, dá pra parsear em Python puro lendo pares `(group code, value)`.
2. **Listar blocos INSERT e suas contagens** para identificar candidatos ao bloco de esforço (ver critério acima).
3. **Extrair todas as instâncias do(s) bloco(s) de esforço**: coordenada de inserção (códigos 10, 20), rotação (código 50), e os 2 valores de ATTRIB (código 1 de cada ATTRIB, na ordem).
4. **Extrair os pontos de poste** (bloco de poste do projeto — no Catunda era `PT_E` para postes existentes; variar por projeto, procurar o bloco mais numeroso que bate com a contagem de postes esperada).
5. **Casar cada marcador de esforço com o poste mais próximo** por distância euclidiana (coordenadas X,Y). Registrar a distância do casamento — se muito grande (fora do padrão dos demais), sinalizar como possível erro de casamento em vez de aceitar silenciosamente.
6. **Reportar cobertura**: quantos postes têm marcador de esforço vs. total de postes no desenho. Não presumir que a cobertura é 100% — em pelo menos um caso real encontramos só ~1/3 dos postes com esforço desenhado, indicando cálculo incompleto do projeto.
7. **Gerar CSV de saída** (id do poste, coordenadas, ângulo, esforço em kgf, distância de casamento) pronto para o usuário conferir e usar para preencher a coluna de esforço do CSV de rede da Enel.
8. **Gerar o LISP de reinserção** (ver modelo abaixo) parametrizado pelo nome do(s) bloco(s) encontrado(s) nesse projeto específico — não reaproveitar um nome fixo de projeto anterior.

## Regras de segurança / não fabricar dado
- Nunca preencher com 0 um ponto que fisicamente tem cabo passando (bloco tipo cabo/NOEQ no CSV) só porque falta o cálculo — 0 nesse tipo de ponto é uma afirmação de engenharia falsa (que o poste não recebe esforço), e isso é diferente de "faltou calcular". Marcar explicitamente como pendente de cálculo.
- 0 é válido apenas para pontos que são genuinamente equipamento sem cabo contínuo (ex. linhas TERM/CTO no CSV de rede).
- Se o casamento marcador↔poste tiver distância muito fora do padrão do restante do projeto, reportar como suspeito em vez de aceitar.
- Sempre reportar a proporção real de cobertura (X de Y postes com esforço calculado) — nunca deixar implícito que está completo se não está.

## NÃO calcular esforço/ângulo do zero por geometria pura — testado e reprovado
Foi tentado (projeto Catunda) inferir o ângulo de deflexão em cada poste a partir só da geometria das polilinhas de cabo (vértice = poste, ângulo entre os dois vãos que se encontram no ponto), pra estender o cálculo aos postes que ainda não tinham esforço/ângulo desenhado. **O teste de validação contra os pontos já calculados corretamente reprovou**: em vários postes o ângulo geométrico calculado ficou 20-80° longe do ângulo real já aprovado (ex.: poste com 84° real deu 1,69° calculado; poste com 43° real deu 92,78°).

Causa raiz: em pontos onde mais de um trecho de cabo se encontra (emendas, reservas técnicas, cruzamento de camadas/layers), a geometria sozinha é ambígua — não dá pra saber por pura distância/coordenada qual par de vãos define o ângulo relevante daquele esforço. Além disso, a fórmula do memorial (T = R×L²/8f) depende da flecha (f), que não está desenhada em lugar nenhum do DXF nem é dedutível só da geometria — vem de tabela de norma (ET 278/2018 / NBR 15214) que não faz parte do desenho.

**Regra permanente desta skill:** não gerar esforço nem ângulo calculado do zero para postes que não têm o marcador já desenhado no DXF. O que É seguro extrair por geometria pura (sem ambiguidade) é o **comprimento do vão** (distância euclidiana entre poste e poste consecutivo na mesma polilinha de cabo) — isso pode ser entregue como apoio para quem for fechar o cálculo manualmente, mas nunca como "esforço calculado". Ver a validação e a extração de vãos feitas no projeto Catunda como referência do método (comparar geometria contra os pontos conhecidos antes de confiar em qualquer extrapolação, em qualquer projeto novo).

## Modelo de LISP de reinserção
Ver `references/ImportaEsforcos_template.lsp` (adaptar o nome do bloco e o caminho do CSV para cada projeto). O script:
- Lê um CSV com colunas: índice do poste, coordenada X, coordenada Y, rotação do bloco, texto do ângulo, texto do esforço, nome do bloco de origem.
- Usa ActiveX (`vla-InsertBlock`) para inserir o bloco na posição/rotação corretas.
- Preenche os 2 atributos (`GetAttributes`) na ordem ângulo → esforço (ou a ordem detectada no projeto de origem).
- Reporta quantos blocos foram inseridos e quantos deram erro (ex.: bloco não existe na definição do desenho de destino — precisa estar importado antes).

## Entregáveis desta skill
1. CSV com todos os pontos calculados encontrados no DXF, casados com o poste correspondente.
2. Relatório de cobertura (quantos faltam, quais têm casamento suspeito).
3. Arquivo `.lsp` pronto pra carregar no AutoCAD (comando `APPLOAD`) que reinsere os blocos de esforço a partir do CSV.
4. Se pedido: atualização do relatório técnico de manifestação (skill `analise-reprovacao-enel`) com os achados.
