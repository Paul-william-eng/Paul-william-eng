;;; ImportaEsforcos.lsp
;;; Le um CSV (ponto e virgula) com: pte_index;coord_x;coord_y;rotacao_bloco;angulo_texto;esforco_kgf;bloco_origem;distancia_ao_poste
;;; e insere o bloco de esforco correspondente ("Descricao de esforco direita" ou "esquerda"),
;;; na posicao do poste, com a rotacao e os dois atributos (angulo e kgf) ja preenchidos.
;;;
;;; PRE-REQUISITOS antes de rodar:
;;;  1. Os blocos "Descrição de esforço direita" e "descrição de esforço esquerda" precisam
;;;     ja existir na definicao do desenho (BLOCK table) - copie/insira uma vez a partir do
;;;     DXF original se for um desenho novo.
;;;  2. Ajuste a variavel *csv-path* abaixo para o caminho real do arquivo CSV.
;;;  3. Teste primeiro em uma copia do desenho - este script insere entidades novas.
;;;
;;; Uso no AutoCAD:
;;;   1. Comando APPLOAD -> selecione este arquivo -> botao "Load" -> feche a janela.
;;;   2. Confira na linha de comando se apareceu a mensagem
;;;      "ImportaEsforcos.lsp carregado..." - isso so confirma que CARREGOU, ainda NAO RODOU.
;;;   3. Na linha de comando do AutoCAD, digite: IMPORTAESFORCOS  e aperte Enter.
;;;      (APPLOAD nao executa o comando sozinho, so deixa ele disponivel pra digitar)

(vl-load-com) ;; necessario para as funcoes vlax-/vla- funcionarem

(defun c:IMPORTAESFORCOS ( / *csv-path* f line campos idx x y rot ang kgf blk
                              acadApp acadDoc modelSpace ptIns blkRef atts i att tagPos)

  (setq *csv-path* "C:/CATUNDA/catunda_esforcos_do_dxf.csv") ;; <-- AJUSTE O CAMINHO AQUI

  (if (not (findfile *csv-path*))
    (progn
      (princ (strcat "\nArquivo nao encontrado: " *csv-path*))
      (princ "\nAjuste a variavel *csv-path* dentro do ImportaEsforcos.lsp e rode de novo.")
      (princ)
    )
    (progn
      (setq acadApp (vlax-get-acad-object))
      (setq acadDoc (vla-get-ActiveDocument acadApp))
      (setq modelSpace (vla-get-ModelSpace acadDoc))

      (setq f (open *csv-path* "r"))
      (read-line f) ;; pula cabecalho

      (setq total 0)
      (setq erros 0)

      (while (setq line (read-line f))
        (setq campos (StrToList line ";"))
        (if (>= (length campos) 7)
          (progn
            (setq idx (nth 0 campos))
            (setq x   (atof (nth 1 campos)))
            (setq y   (atof (nth 2 campos)))
            (setq rot (atof (nth 3 campos)))
            (setq ang (nth 4 campos))
            (setq kgf (nth 5 campos))
            (setq blk (nth 6 campos))

            (setq ptIns (vlax-3d-point (list x y 0.0)))

            (if (vl-catch-all-error-p
                  (setq blkRef
                    (vl-catch-all-apply
                      'vla-InsertBlock
                      (list modelSpace ptIns blk 1.0 1.0 1.0 (* rot (/ pi 180.0)))
                    )
                  )
                )
              (progn
                (princ (strcat "\nERRO ao inserir bloco '" blk "' no poste indice " idx
                                " - detalhe: " (vl-catch-all-error-message blkRef)
                                " - verifique se o bloco existe no desenho atual (INSERT manual uma vez pra testar)."))
                (setq erros (1+ erros))
              )
              (progn
                ;; blkRef inserido com sucesso - agora preencher os 2 atributos
                ;; ordem observada no DXF original: atributo 1 = angulo (ex: "78°"), atributo 2 = kgf (ex: "63Kgf")
                (if (= (vlax-get-property blkRef 'HasAttributes) :vlax-true)
                  (progn
                    (setq atts (vlax-safearray->list
                                 (vlax-variant-value (vla-GetAttributes blkRef))))
                    (if (>= (length atts) 2)
                      (progn
                        (vla-put-TextString (nth 0 atts) ang)
                        (vla-put-TextString (nth 1 atts) kgf)
                      )
                      (princ (strcat "\nAVISO: bloco no poste " idx
                                      " nao trouxe os 2 atributos esperados."))
                    )
                  )
                )
                (setq total (1+ total))
              )
            )
          )
        )
      )
      (close f)

      (princ (strcat "\nConcluido: " (itoa total) " blocos de esforco inseridos, "
                      (itoa erros) " erros."))
      (princ "\nConfira o resultado antes de salvar - este script NAO faz undo automatico.")
      (princ)
    )
  )
)

;; ---------------------------------------------------------------
;; Funcao auxiliar: separa uma string por um delimitador (ponto-e-virgula)
(defun StrToList (str delim / pos lst)
  (setq lst '())
  (while (setq pos (vl-string-search delim str))
    (setq lst (append lst (list (substr str 1 pos))))
    (setq str (substr str (+ pos 1 (strlen delim))))
  )
  (setq lst (append lst (list str)))
  lst
)

(princ "\nImportaEsforcos.lsp carregado. Digite IMPORTAESFORCOS para rodar.")
(princ)
