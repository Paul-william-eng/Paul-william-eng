---
name: extracao-esforco-dxf
description: Lê um arquivo DXF (exportado de projeto de rede aérea de telecomunicações/fibra óptica em AutoCAD) e extrai os marcadores de esforço mecânico (força resultante em kgf + ângulo) já desenhados junto a cada poste, cruzando por coordenada com os pontos de poste do desenho. Para postes de vão único ainda sem cálculo, também CALCULA o esforço usando a fórmula real da planilha de cálculo (T = 5×R×L, com peso/diâmetro do cabo tirados da tabela de referência do próprio arquivo .xlsx do projeto) aplicada ao vão medido na geometria do DXF. Gera um CSV pronto pra alimentar a coluna de esforço do CSV de rede exigido pela Enel/JoiN-AS, e um script LISP para reinserir/replicar esses blocos de esforço no AutoCAD com posição, rotação e atributos corretos. Use sempre que o usuário mandar um .dxf de projeto de poste/rede (com ou sem a planilha de cálculo de esforço junto) e pedir os esforços de cada ponto, pedir para gerar um LISP de esforço, ou pedir para extrair/calcular ângulo e força resultante de um projeto CAD.
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
7. **Se o usuário também mandar a planilha `.xlsx` de cálculo de esforço**: abrir e ler as FÓRMULAS das células (não só os valores), achar a tabela de cabo (faixa nomeada, geralmente numa aba tipo `db`) e a fórmula de tração por vão — ver seção "A fórmula real" abaixo. Extrair as polilinhas de cabo do DXF (camada com o nome/especificação do cabo) pra medir o vão real de cada poste que ainda não tem esforço calculado.
8. **Para postes com 1 vão só (sem deflexão):** calcular com a fórmula validada `T = 5×R×L`, ângulo = 0°. Entregar como "calculado", não como pendente.
9. **Para postes com 2+ vãos (deflexão):** NÃO calcular o resultado combinado nem o ângulo — ver seção de limitação abaixo. Entregar como pendente, com os vãos individuais listados.
10. **Gerar CSV de saída** (id do poste, coordenadas, ângulo, esforço em kgf, distância de casamento, método/status) pronto para o usuário conferir e usar para preencher a coluna de esforço do CSV de rede da Enel.
11. **Gerar o LISP de reinserção** (ver modelo abaixo) parametrizado pelo nome do(s) bloco(s) encontrado(s) nesse projeto específico — não reaproveitar um nome fixo de projeto anterior.

## Regras de segurança / não fabricar dado
- Nunca preencher com 0 um ponto que fisicamente tem cabo passando (bloco tipo cabo/NOEQ no CSV) só porque falta o cálculo — 0 nesse tipo de ponto é uma afirmação de engenharia falsa (que o poste não recebe esforço), e isso é diferente de "faltou calcular". Marcar explicitamente como pendente de cálculo.
- 0 é válido apenas para pontos que são genuinamente equipamento sem cabo contínuo (ex. linhas TERM/CTO no CSV de rede).
- Se o casamento marcador↔poste tiver distância muito fora do padrão do restante do projeto, reportar como suspeito em vez de aceitar.
- Sempre reportar a proporção real de cobertura (X de Y postes com esforço calculado) — nunca deixar implícito que está completo se não está.

## A fórmula real, achada dentro da planilha de cálculo (não do memorial em prosa)
O memorial descritivo (texto) dá uma versão simplificada da fórmula. **A fórmula que realmente vale está nas células da planilha de cálculo de esforço (`.xlsx`), como fórmula do Excel — não confiar só no texto do memorial, abrir a planilha e ler `<f>` (fórmula) de cada célula, não só o valor calculado.**

Fórmula decodificada e validada numericamente (bateu exato, casa decimal por casa decimal, contra vários postes já calculados do projeto Catunda):

```
T = 5 × R × L        (kgf, válido para poste de vão único / sem deflexão, ângulo = 0)
R = sqrt(P² + (40×D)²)
```

Onde:
- `P` = peso do cabo (kg/m) — **varia por tipo de cabo**, vem de uma tabela de consulta (aba `db` da planilha, faixa nomeada `cabo`, colunas: nome do cabo / peso / diâmetro externo em metros). Cada projeto pode usar um cabo diferente — sempre ler essa tabela do arquivo, nunca fixar um valor.
- `D` = diâmetro externo do cabo (m), mesma tabela.
- `40` = constante de pressão do vento embutida na planilha (equivalente a uma velocidade de vento fixa adotada pelo escritório — não é exatamente o V=20m/s citado no memorial em prosa; usar o valor real da fórmula, 40, não o do texto).
- `L` = comprimento do vão (m) — **extraído com segurança da geometria do DXF**: distância euclidiana entre um poste e o próximo, seguindo a polilinha de cabo (camada nomeada com a especificação do cabo, ex. `CFOA-SM-AS-120-S-12-NR`). Os vértices dessa polilinha coincidem (distância ~0) com os pontos de poste do desenho — é assim que se casa vão↔poste.
- A flecha (f) não aparece como incógnita separada porque a planilha já assume **f = 2,5% do vão** (embutido na fórmula, não é uma variável livre); por isso `T = R×L²/(8×0,025×L) = 5×R×L`.

**Isso resolve o caso mais comum (poste reto, um vão só de cada lado, ângulo 0°) de forma 100% confiável, sem precisar de nenhum ponto de referência já calculado** — só precisa da planilha de cálculo (pra tabela de cabo) e do DXF (pra vão).

## O que continua NÃO sendo seguro calcular do zero: postes com deflexão (2+ vãos)
Quando o poste tem mais de um vão se encontrando (mudança de direção do cabo), a planilha combina as trações dos dois vãos por lei dos cossenos, usando um **ângulo de entrada (`C22` na planilha, um valor que o próprio engenheiro digita manualmente por bloco)** — esse ângulo **não é simplesmente o ângulo geométrico entre os dois vãos no desenho**. Foi testado (poste 27 do Catunda: ângulo real 84°, ângulo geométrico bruto entre os vetores calculado em 178,3°) e mesmo usando o ângulo bruto (não a versão "desvio de 180°") o resultado da fórmula não bateu com o valor real (deu 15,89 ou 107,81 kgf contra o real 49 kgf) — ou seja, falta alguma informação que não está só na geometria da polilinha principal (pode ser um terceiro trecho de cabo em outra camada, um jumper, ou um dado que só existe na cabeça de quem desenhou).

**Regra permanente:** para poste com 1 vão só (dead-end/passagem reta), calcular com a fórmula acima usando `T = 5×R×L` e `ângulo = 0°` — seguro. Para poste com 2+ vãos, **não inventar o ângulo nem o resultado combinado** — reportar como pendente, com os vãos individuais (comprimento) e a tração de cada vão isolado (`5×R×L` por vão, que É confiável) para apoiar quem for fechar o cálculo manualmente, mas nunca entregar como "esforço final calculado".

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
