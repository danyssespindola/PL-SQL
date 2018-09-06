create or replace
PACKAGE BODY PCK_SISGT_STATUS_NEG_FINAL AS

  PROCEDURE ATUALIZA_STATUS_BASE AS
  BEGIN
    FOR REG IN (SELECT PRLS_SQ_PRCS_LBRC_SRVC_ENGR
                FROM PROCESSO_LIBERACAO_SRVC_ENGR PRLS
                WHERE EXISTS (SELECT 'X' FROM AVALIACAO_SEPAV_TOTAL AVST
                               WHERE AVST.PRLI_SQ_PROCESSO_LIBERACAO = PRLS.PRLI_SQ_PROCESSO_LIBERACAO))
    LOOP
      BEGIN
        VERIFICAR_STATUS(REG.PRLS_SQ_PRCS_LBRC_SRVC_ENGR);
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
    END LOOP;
  END;

  FUNCTION VERIFICA_LIBERADO_CONSTRUCAO(P_ID_PRLS IN NUMBER) RETURN NUMBER AS 
    V_ID_PRLI_VINCULADO         PROCESSO_LIBERACAO.PRLI_SQ_PRCS_LBRC_VINCULADO%TYPE;
    CT_PLS_LIBERADOS            NUMBER(5);
    CT_PLS_LIBERADOS_DEMOLICAO  NUMBER(5);
    CT_PLS_LIBERADOS_CONSTRUCAO  NUMBER(5);
  BEGIN 
    
    select PRLI.PRLI_SQ_PRCS_LBRC_VINCULADO           
    into  V_ID_PRLI_VINCULADO          
    from PROCESSO_LIBERACAO_SRVC_ENGR PRLS, PROCESSO_LIBERACAO PRLI
    where PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
    and PRLI.PRLI_SQ_PROCESSO_LIBERACAO = PRLS.PRLI_SQ_PROCESSO_LIBERACAO;
    
    -- caso nao h� vinculo, significa que o PL � unico da ficha. Portanto j� pode ser liberado para constru��o
    if (V_ID_PRLI_VINCULADO IS NULL) then
      return 9;
    end if;
    
    select count(*), sum(decode(PRLS.SILI_SQ_SITUACAO_LIBERACAO,6,1,0)), sum(decode(PRLS.SILI_SQ_SITUACAO_LIBERACAO,9,1,0))
    into CT_PLS_LIBERADOS, CT_PLS_LIBERADOS_DEMOLICAO, CT_PLS_LIBERADOS_CONSTRUCAO
    from PROCESSO_LIBERACAO PRLI, PROCESSO_LIBERACAO_SRVC_ENGR PRLS
    where PRLS.PRLI_SQ_PROCESSO_LIBERACAO = PRLI.PRLI_SQ_PROCESSO_LIBERACAO
    and PRLS.PRLS_SQ_PRCS_LBRC_SRVC_ENGR != P_ID_PRLS
    and (PRLI.PRLI_SQ_PRCS_LBRC_VINCULADO = V_ID_PRLI_VINCULADO or PRLI.PRLI_SQ_PROCESSO_LIBERACAO = V_ID_PRLI_VINCULADO);
    
    if (CT_PLS_LIBERADOS = CT_PLS_LIBERADOS_CONSTRUCAO) then
      return 9;
    else
      if (CT_PLS_LIBERADOS = CT_PLS_LIBERADOS_DEMOLICAO) then
        return 9;
      else
        return 0;
      end if;
    end if;
  END;
  
  PROCEDURE DESFAZER_LIBERACAO_MANUAL (P_ID_PRLS     IN NUMBER,
                                       P_ID_USUARIO  IN NUMBER) AS
  
    V_ID_TINE             TIPO_NEGOCIACAO.TINE_SQ_TIPO_NEGOCIACAO%TYPE;
    V_ID_SINE             SITUACAO_NEGOCIACAO.SINE_SQ_SITUACAO_NEGOCIACAO%TYPE;
    V_ID_SIAJ             SITUACAO_ACAO_JUDICIAL.SIAJ_SQ_SITC_ACAO_JUDICIAL%TYPE;
    V_ID_SILI             SITUACAO_LIBERACAO.SILI_SQ_SITUACAO_LIBERACAO%TYPE := null;
    V_ID_PRLI             PROCESSO_LIBERACAO.PRLI_SQ_PROCESSO_LIBERACAO%TYPE;
    V_ID_SIWO             SITUACAO_WORKFLOW.SIWO_SQ_SITUACAO_WORKFLOW%TYPE := null;  
    V_ID_SIOB_PRLI        SITUACAO_OBJETO.SIOB_SQ_SITUACAO_OBJETO%TYPE;
    V_ID_SIOB_FICA        SITUACAO_OBJETO.SIOB_SQ_SITUACAO_OBJETO%TYPE;
    
    V_TX_HISTORICO        REGISTRO_OCORRENCIA.REOC_TX_REGISTRO_OCORRENCIA%TYPE := 'Libera��o da Obra Cancelada Manualmente';
  BEGIN
    select  PRLS.TINE_SQ_TIPO_NEGOCIACAO, 
            PRLS.SIAJ_SQ_SITC_ACAO_JUDICIAL, 
            PRLS.SINE_SQ_SITUACAO_NEGOCIACAO,
            PRLI.PRLI_SQ_PROCESSO_LIBERACAO,
            PRLI.SIOB_SQ_SITUACAO_OBJETO,
            FICA.SIOB_SQ_SITUACAO_OBJETO
    into V_ID_TINE, V_ID_SIAJ, V_ID_SINE, V_ID_PRLI, V_ID_SIOB_PRLI, V_ID_SIOB_FICA
    from PROCESSO_LIBERACAO_SRVC_ENGR PRLS, PROCESSO_LIBERACAO PRLI, FICHA_CADASTRAL FICA
    where PRLS.PRLI_SQ_PROCESSO_LIBERACAO = PRLI.PRLI_SQ_PROCESSO_LIBERACAO
    and PRLI.FICA_SQ_FICHA_CADASTRAL = FICA.FICA_SQ_FICHA_CADASTRAL
    and PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS;
    
    if V_ID_TINE in (2,8) then
      
      if V_ID_TINE = 2 then
        V_ID_SILI := 2;
        V_ID_SIWO := 9;
      end if;
      
      if V_ID_TINE = 8 then
        if V_ID_SIAJ in (1,5,6,7) then
          V_ID_SILI := 2;          
          V_ID_SIWO := 9;          
        elsif V_ID_SIAJ = 3 then
          V_ID_SILI := 7;
          V_ID_SIWO := 9;
        end if;
      end if;
      
      if V_ID_SILI is not null then
        update PROCESSO_LIBERACAO_SRVC_ENGR set
          SILI_SQ_SITUACAO_LIBERACAO = V_ID_SILI
        where PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS;
        
        PCK_SISGT_REVISAO.INSERIR_HISTORICO_NEGOCIACAO(P_ID_PRLS, V_TX_HISTORICO);  
        
        update OCORRENCIA_NEGOCIACAO set
          OCNE_DT_FINALIZACAO = null,
          SIOC_SQ_SITUACAO_OCORRENCIA = 1
        where PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS;
        
        commit;
      end if;
      
      if V_ID_SIWO is not null then
        /* Altera o Status Workflow do PL */
        
        insert into MOVIMENTO_WORKFLOW
        ( MOWO_SQ_MOVIMENTO_WORKFLOW
        , PRLI_SQ_PROCESSO_LIBERACAO
        , SIOB_SQ_SITC_FICHA_CADASTRAL
        , SIOB_SQ_SITC_PRCS_LIBERACAO
        , SIWO_SQ_SITUACAO_WORKFLOW
        , USUA_SQ_USUARIO_MOVIMENTO
        , FMWK_DT_ULTIMA_ATUALIZACAO)
        (select SQ_MOWO_SQ_MOVIMENTO_WORKFLOW.nextval,
                V_ID_PRLI,
                V_ID_SIOB_FICA,
                V_ID_SIOB_PRLI,
                V_ID_SIWO,
                P_ID_USUARIO,
                sysdate
              from dual);
      end if;
    end if;
  END;
  
  PROCEDURE SET_LIBERACAO_MANUAL (P_ID_PRLS     IN NUMBER,
                                  P_ID_USUARIO  IN NUMBER) AS
  
    V_ID_TINE             TIPO_NEGOCIACAO.TINE_SQ_TIPO_NEGOCIACAO%TYPE;
    V_ID_SINE             SITUACAO_NEGOCIACAO.SINE_SQ_SITUACAO_NEGOCIACAO%TYPE;
    V_ID_SIAJ             SITUACAO_ACAO_JUDICIAL.SIAJ_SQ_SITC_ACAO_JUDICIAL%TYPE;
    V_ID_SILI             SITUACAO_LIBERACAO.SILI_SQ_SITUACAO_LIBERACAO%TYPE := null;
    V_ID_PRLI             PROCESSO_LIBERACAO.PRLI_SQ_PROCESSO_LIBERACAO%TYPE;
    V_ID_SIWO             SITUACAO_WORKFLOW.SIWO_SQ_SITUACAO_WORKFLOW%TYPE := null;  
    V_ID_SIOB_PRLI        SITUACAO_OBJETO.SIOB_SQ_SITUACAO_OBJETO%TYPE;
    V_ID_SIOB_FICA        SITUACAO_OBJETO.SIOB_SQ_SITUACAO_OBJETO%TYPE;
    
    V_TX_HISTORICO        REGISTRO_OCORRENCIA.REOC_TX_REGISTRO_OCORRENCIA%TYPE := 'Liberado para Obra Manualmente';
  BEGIN
    select  PRLS.TINE_SQ_TIPO_NEGOCIACAO, 
            PRLS.SIAJ_SQ_SITC_ACAO_JUDICIAL, 
            PRLS.SINE_SQ_SITUACAO_NEGOCIACAO,
            PRLI.PRLI_SQ_PROCESSO_LIBERACAO,
            PRLI.SIOB_SQ_SITUACAO_OBJETO,
            FICA.SIOB_SQ_SITUACAO_OBJETO
    into V_ID_TINE, V_ID_SIAJ, V_ID_SINE, V_ID_PRLI, V_ID_SIOB_PRLI, V_ID_SIOB_FICA
    from PROCESSO_LIBERACAO_SRVC_ENGR PRLS, PROCESSO_LIBERACAO PRLI, FICHA_CADASTRAL FICA
    where PRLS.PRLI_SQ_PROCESSO_LIBERACAO = PRLI.PRLI_SQ_PROCESSO_LIBERACAO
    and PRLI.FICA_SQ_FICHA_CADASTRAL = FICA.FICA_SQ_FICHA_CADASTRAL
    and PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS;
    
    if V_ID_TINE in (2,8) then
      
      if V_ID_TINE = 2 then
        V_ID_SILI := 6;
        V_ID_SIWO := 12;
      end if;
      
      if V_ID_TINE = 8 then
        if V_ID_SIAJ in (1,5,6,7) then
          V_ID_SILI := 6;
          if V_ID_SIAJ = 5 then
            V_ID_SIWO := 10;
          else
            V_ID_SIWO := 12;
          end if;
        elsif V_ID_SIAJ = 3 then
          V_ID_SILI := 5;
          V_ID_SIWO := 9;
        end if;
      end if;
      
      if V_ID_SILI is not null then
        if V_ID_SILI = 6 then
          V_ID_SILI := VERIFICA_LIBERADO_CONSTRUCAO(P_ID_PRLS);
          
          if V_ID_SILI = 0 then
            V_ID_SILI := 6;
          end if;
        end if;
      
        update PROCESSO_LIBERACAO_SRVC_ENGR set
          SILI_SQ_SITUACAO_LIBERACAO = V_ID_SILI
        where PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS;
        
        PCK_SISGT_REVISAO.INSERIR_HISTORICO_NEGOCIACAO(P_ID_PRLS, V_TX_HISTORICO);  
        
        update OCORRENCIA_NEGOCIACAO set
          OCNE_DT_FINALIZACAO = sysdate,
          SIOC_SQ_SITUACAO_OCORRENCIA = 2
        where PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS; 
        
        commit;
      end if;
      
      if V_ID_SIWO != 9 and V_ID_SIWO is not null then
        /* Altera o Status Workflow do PL */
        insert into MOVIMENTO_WORKFLOW
        ( MOWO_SQ_MOVIMENTO_WORKFLOW
        , PRLI_SQ_PROCESSO_LIBERACAO
        , SIOB_SQ_SITC_FICHA_CADASTRAL
        , SIOB_SQ_SITC_PRCS_LIBERACAO
        , SIWO_SQ_SITUACAO_WORKFLOW
        , USUA_SQ_USUARIO_MOVIMENTO
        , FMWK_DT_ULTIMA_ATUALIZACAO)
        (select SQ_MOWO_SQ_MOVIMENTO_WORKFLOW.nextval,
                V_ID_PRLI,
                V_ID_SIOB_FICA,
                V_ID_SIOB_PRLI,
                V_ID_SIWO,
                P_ID_USUARIO,
                sysdate
              from dual);
      end if;
    end if;
  END;
  
  PROCEDURE SET_STATUS_WORKFLOW(P_ID_PRLI IN NUMBER, 
                                P_ID_TINE IN NUMBER, 
                                P_ID_SINE IN NUMBER, 
                                P_ID_SIAJ IN NUMBER,
                                P_ID_SILI IN NUMBER,
                                P_ID_USUARIO IN NUMBER) AS
    
    V_ID_SIWO       SITUACAO_WORKFLOW.SIWO_SQ_SITUACAO_WORKFLOW%TYPE := null; 
    V_ID_SIWO_ATUAL SITUACAO_WORKFLOW.SIWO_SQ_SITUACAO_WORKFLOW%TYPE := null; 
    
    V_ID_SIOB_FICA  SITUACAO_OBJETO.SIOB_SQ_SITUACAO_OBJETO%TYPE;
    V_ID_SIOB_PRLI  SITUACAO_OBJETO.SIOB_SQ_SITUACAO_OBJETO%TYPE;
  BEGIN
    if P_ID_TINE = 5 then -- Aquisi��o
      if (P_ID_SIAJ in (1,7) and P_ID_SINE in (2,3,4,5,6,7,8,9))
        or (P_ID_SIAJ = 3)
        or (P_ID_SIAJ = 4 and P_ID_SINE in (5,10,11,12))
        or (P_ID_SIAJ in (5,6) and P_ID_SINE = 5)
      then
        V_ID_SIWO := 9;
      end if;
      
      if (P_ID_SIAJ in (1,6) and P_ID_SINE = 10)
        or (P_ID_SIAJ in (4,5) and P_ID_SINE in (2,3,4,6,7,8,9))
        or (P_ID_SIAJ = 5 and P_ID_SINE = 10)
      then
        V_ID_SIWO := 10;
      end if;
      
      if (P_ID_SIAJ in (1,7) and P_ID_SINE = 11)
        or (P_ID_SIAJ = 5 and P_ID_SINE in (11,12))
        or (P_ID_SIAJ = 6 and P_ID_SINE in (2,3,4,67,8,910,11))
      then
        V_ID_SIWO := 11;
      end if;
      
      if P_ID_SIAJ in (1,6,7) and P_ID_SINE = 12 then
        V_ID_SIWO := 12;
      end if;
    end if;
    
    if P_ID_TINE = 6 then -- Servid�o
      if (P_ID_SIAJ in (1,3,7) and P_ID_SINE in (2,3,4,5,6,7,8,9))
        or (P_ID_SIAJ in (3,4) and P_ID_SINE in (10,11))
        or (P_ID_SIAJ in (4,5,6) and P_ID_SINE = 5)
      then
        V_ID_SIWO := 9;
      end if;
      
      if (P_ID_SIAJ in (4,5) and P_ID_SINE in (2,3,4,6,7,8,9))
        or (P_ID_SIAJ = 4 and P_ID_SINE = 10)
        or (P_ID_SIAJ in (1,7) and P_ID_SINE = 10)
      then
        V_ID_SIWO := 10;
      end if;
      
      if P_ID_SIAJ = 5 and P_ID_SINE = 11 then
        V_ID_SIWO := 11;
      end if;
      
      if (P_ID_SIAJ in (1,7) and P_ID_SINE = 11)
        or (P_ID_SIAJ = 6 and P_ID_SINE in (2,3,4,6,7,8,9,10,11))
      then
        V_ID_SIWO := 12;
      end if;
    end if;
    
    if P_ID_TINE = 1 then -- Somente Danos Diretos
      if (P_ID_SIAJ in (1,7) and P_ID_SINE in (2,3,4,5,6,7,8))
        or (P_ID_SIAJ = 3 and P_ID_SINE in (2,3,4,5,6,7,8,13))
        or (P_ID_SIAJ in (4,5,6) and P_ID_SINE = 5)
        or (P_ID_SIAJ = 4 and P_ID_SINE = 13)
      then
        V_ID_SIWO := 9;
      end if;
      
      if (P_ID_SIAJ in (4,5) and P_ID_SINE in (2,3,4,6,7,8))
        or (P_ID_SIAJ = 5 and P_ID_SINE = 13)
      then
        V_ID_SIWO := 10;
      end if;
      
      if (P_ID_SIAJ in (1,7) and P_ID_SINE = 13)
        or (P_ID_SIAJ = 6 and P_ID_SINE in (2,3,4,6,7,8,9))
      then
        V_ID_SIWO := 12;
      end if;
    end if;
    
    if P_ID_TINE = 4 then -- Interfer�ncia
      if (P_ID_SIAJ in (1,3,7) and P_ID_SINE = 14)
        or (P_ID_SIAJ in (3,4) and P_ID_SINE = 15)
      then
        V_ID_SIWO := 9;
      end if;
      
      if (P_ID_SIAJ in (4,5) and P_ID_SINE = 14)
        or (P_ID_SIAJ = 5 and P_ID_SINE = 15)
      then  
        V_ID_SIWO := 10;
      end if;
      
      if (P_ID_SIAJ in (1,6,7) and P_ID_SINE = 15)
        or (P_ID_SIAJ = 6 and P_ID_SINE = 15)
      then
        V_ID_SIWO := 12;
      end if;
    end if;
    
    if P_ID_TINE in (3,7) then -- �reas P�blicas e Contratos
      if P_ID_SINE = 14 then
        V_ID_SIWO := 9;
      end if;
      
      if P_ID_SINE = 15 then
        V_ID_SIWO := 12;
      end if;
    end if;
    
    if P_ID_TINE in (2,8) then --Im�vel Petrobr�s e Outros
      V_ID_SIWO := 9;
    end if;
    
    if P_ID_SILI != 9 and V_ID_SIWO != 9 and P_ID_TINE in (5,6,1,4,8) then
      V_ID_SIWO := 9;
    end if;
    
    if nvl(V_ID_SIWO,9) != 9 then      
    
      select SIWO_SQ_SITUACAO_WORKFLOW
      into V_ID_SIWO_ATUAL
      from MOVIMENTO_WORKFLOW
      where MOWO_SQ_MOVIMENTO_WORKFLOW = 
        (select max(MOWO_SQ_MOVIMENTO_WORKFLOW) 
        from MOVIMENTO_WORKFLOW 
        where PRLI_SQ_PROCESSO_LIBERACAO = P_ID_PRLI);
      
      if V_ID_SIWO > V_ID_SIWO_ATUAL then
        select FICA.SIOB_SQ_SITUACAO_OBJETO, PRLI.SIOB_SQ_SITUACAO_OBJETO
        into V_ID_SIOB_FICA, V_ID_SIOB_PRLI
        from PROCESSO_LIBERACAO PRLI, FICHA_CADASTRAL FICA
        where FICA.FICA_SQ_FICHA_CADASTRAL = PRLI.FICA_SQ_FICHA_CADASTRAL
        and PRLI.PRLI_SQ_PROCESSO_LIBERACAO = P_ID_PRLI;
      
        /* Altera o Status Workflow do PL */
        insert into MOVIMENTO_WORKFLOW
        ( MOWO_SQ_MOVIMENTO_WORKFLOW
        , PRLI_SQ_PROCESSO_LIBERACAO
        , SIOB_SQ_SITC_FICHA_CADASTRAL
        , SIOB_SQ_SITC_PRCS_LIBERACAO
        , SIWO_SQ_SITUACAO_WORKFLOW
        , USUA_SQ_USUARIO_MOVIMENTO
        , FMWK_DT_ULTIMA_ATUALIZACAO)
        (select SQ_MOWO_SQ_MOVIMENTO_WORKFLOW.nextval,
                P_ID_PRLI,
                V_ID_SIOB_FICA,
                V_ID_SIOB_PRLI,
                V_ID_SIWO,
                P_ID_USUARIO,
                sysdate
              from dual);
      end if;
    end if;
  END;
     
  PROCEDURE ATUALIZA_STATUS_LBRC_WORKFLOW (P_ID_PRLS IN NUMBER, P_ID_USUARIO IN NUMBER) AS
    V_ID_TINE             TIPO_NEGOCIACAO.TINE_SQ_TIPO_NEGOCIACAO%TYPE;
    V_ID_SINE             SITUACAO_NEGOCIACAO.SINE_SQ_SITUACAO_NEGOCIACAO%TYPE;
    V_ID_SIAJ             SITUACAO_ACAO_JUDICIAL.SIAJ_SQ_SITC_ACAO_JUDICIAL%TYPE;
    V_ID_SILI             SITUACAO_LIBERACAO.SILI_SQ_SITUACAO_LIBERACAO%TYPE;
    V_ID_PRLI             PROCESSO_LIBERACAO.PRLI_SQ_PROCESSO_LIBERACAO%TYPE;
    V_ID_PRLI_VINCULADO   PROCESSO_LIBERACAO.PRLI_SQ_PRCS_LBRC_VINCULADO%TYPE;
    V_ID_SIOB             SITUACAO_OBJETO.SIOB_SQ_SITUACAO_OBJETO%TYPE;
    V_IN_REVISAO          PROCESSO_LIBERACAO.PRLI_IN_REVISAO%TYPE;
    CT_PRLI               number(5); 
    CT_PRLI_LIBERADO_DEM  number(5); 
  BEGIN
    select PRLS.TINE_SQ_TIPO_NEGOCIACAO, 
           PRLS.SINE_SQ_SITUACAO_NEGOCIACAO, 
           PRLS.SIAJ_SQ_SITC_ACAO_JUDICIAL,           
           PRLI.PRLI_SQ_PROCESSO_LIBERACAO,
           PRLI.PRLI_SQ_PRCS_LBRC_VINCULADO,
           PRLI.SIOB_SQ_SITUACAO_OBJETO,
           PRLI.PRLI_IN_REVISAO
    into  V_ID_TINE, 
          V_ID_SINE, 
          V_ID_SIAJ,           
          V_ID_PRLI,
          V_ID_PRLI_VINCULADO,
          V_ID_SIOB,
          V_IN_REVISAO
    from PROCESSO_LIBERACAO_SRVC_ENGR PRLS, PROCESSO_LIBERACAO PRLI
    where PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
    and PRLI.PRLI_SQ_PROCESSO_LIBERACAO = PRLS.PRLI_SQ_PROCESSO_LIBERACAO;
    
    if (V_ID_TINE = 5) then --Aquisi��o
      V_ID_SILI := F_SILI_AQUISICAO(V_ID_SIAJ, V_ID_SINE);
    end if;
    
    if V_ID_TINE = 6 then -- Servid�o
      V_ID_SILI := F_SILI_SERVIDAO(V_ID_SIAJ, V_ID_SINE);
    end if;
    
    if V_ID_TINE = 1 then -- Dano Direto
      V_ID_SILI := F_SILI_DANOS_DIRETOS(V_ID_SIAJ, V_ID_SINE);
    end if;
    
    if V_ID_TINE = 4 then -- Interfer�ncia
      if V_ID_SIAJ in (1,6) and V_ID_SINE in (14) then
        V_ID_SILI := 1;
      end if;
      
      if (V_ID_SIAJ in (1,6) and V_ID_SINE = 15) or
        (V_ID_SIAJ in (3,4) and V_ID_SINE = 14) or
        (V_ID_SIAJ = 5)
      then
        V_ID_SILI := 6;
      end if;
      
      if V_ID_SIAJ in (2,3) and V_ID_SINE = 15 then
        V_ID_SILI := 5;
      end if;
    end if;
    
    if V_ID_TINE in (3,7) then -- �rea P�blicas e Contratos
      if V_ID_SINE = 14 then
        V_ID_SILI := 1;
      end if;
      
      if V_ID_SINE = 15 then
        V_ID_SILI := 6;
      end if;
    end if; 
    
    if V_ID_TINE = 2 then -- Im�vel Petrobr�s
      V_ID_SILI := 2;
    end if;
    
    if V_ID_TINE = 8 then --Outros
      if V_ID_SIAJ in (1,5,6,7) then
        V_ID_SILI := 2;
      end if;
      
      if V_ID_SIAJ = 3 then
        V_ID_SILI := 7;
      end if;      
    end if;
    
    if V_ID_SIOB = 2 and V_IN_REVISAO = 'N' then
      update PROCESSO_LIBERACAO_SRVC_ENGR set
        SILI_SQ_SITUACAO_LIBERACAO = 8
      where PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS;      
    else    
      if V_ID_SILI is not null then
        if (V_ID_TINE = 2 and V_ID_SILI = 2) 
          or (V_ID_TINE = 8 and V_ID_SILI in (2,7))
          or V_ID_TINE not in (2,8) then /* "if" para n�o desfazer libera��o manual */
          
            if V_ID_SILI = 6 and V_ID_SIAJ in (1,6,7) then
              V_ID_SILI := VERIFICA_LIBERADO_CONSTRUCAO(P_ID_PRLS);
              
              if V_ID_SILI = 0 then
                V_ID_SILI := 6;
              end if;
            end if;
          
            update PROCESSO_LIBERACAO_SRVC_ENGR set
              SILI_SQ_SITUACAO_LIBERACAO = V_ID_SILI        
            where PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS;
        end if;
      end if; 
    end if;
    
    SET_STATUS_WORKFLOW(V_ID_PRLI, V_ID_TINE, V_ID_SINE, V_ID_SIAJ, V_ID_SILI, P_ID_USUARIO);
    
    commit;
  END;
   
  FUNCTION F_SILI_AQUISICAO (P_ID_SIAJ IN NUMBER, P_ID_SINE IN NUMBER) return number AS
    V_ID_SILI SITUACAO_LIBERACAO.SILI_SQ_SITUACAO_LIBERACAO%TYPE;
  BEGIN
    if P_ID_SIAJ in (1,6) and P_ID_SINE = 2 then
      V_ID_SILI := 2;
    end if;
    
    if P_ID_SIAJ = 3 and P_ID_SINE in (2,3,4,5,6,7,8) then
      V_ID_SILI := 7;
    end if;
  
    if (P_ID_SIAJ in (1,7) and P_ID_SINE in (3,4,5))
      or (P_ID_SIAJ in (4,5,6) and P_ID_SINE = 5)
    then
      V_ID_SILI := 3;
    end if;
    
    if P_ID_SIAJ in (1,7) and P_ID_SINE in (6,7,8) then
      V_ID_SILI := 4;
    end if;
    
    if (P_ID_SIAJ in (1,7) and P_ID_SINE in (9,10,11,12)) or
      (P_ID_SIAJ in (4,5,6) and P_ID_SINE in (2,3,4)) or
      (P_ID_SIAJ = 4 and P_ID_SINE in (6,7,8,9)) or
      (P_ID_SIAJ in (5,6) and P_ID_SINE in (6,7,8,9,10,11,12))
    then
      V_ID_SILI := 6;
    end if;
  
    if (P_ID_SIAJ in (1,7) and P_ID_SINE = 8) or
      (P_ID_SIAJ = 3 and P_ID_SINE in (9,10,11,12)) or
      (P_ID_SIAJ = 4 and P_ID_SINE in (10,11,12))
    then
      V_ID_SILI := 5;
    end if;
    
    return V_ID_SILI;  
  END;
  
  FUNCTION F_SILI_SERVIDAO (P_ID_SIAJ IN NUMBER, P_ID_SINE IN NUMBER) return number AS
    V_ID_SILI SITUACAO_LIBERACAO.SILI_SQ_SITUACAO_LIBERACAO%TYPE;
  BEGIN
    if P_ID_SIAJ in (1,6) and P_ID_SINE = 2 then
      V_ID_SILI := 2;
    end if;
    
    if P_ID_SIAJ = 2 and P_ID_SINE in (2,3,4,5,6,7,8) then
      V_ID_SILI := 7;
    end if;
  
    if (P_ID_SIAJ in (1,6) and P_ID_SINE in (3,4,5))
      or (P_ID_SIAJ in (3,4,5) and P_ID_SINE = 5)
    then
      V_ID_SILI := 3;
    end if;
    
    if P_ID_SIAJ in (1,6) and P_ID_SINE in (6,7,8) then
      V_ID_SILI := 4;
    end if;
    
    if (P_ID_SIAJ in (1,6) and P_ID_SINE in (10,11)) or
      (P_ID_SIAJ in (3,4,5) and P_ID_SINE in (2,3,4)) or
      (P_ID_SIAJ = 3 and P_ID_SINE in (6,7,8,9)) or
      (P_ID_SIAJ in (4,5) and P_ID_SINE in (6,7,8,9,10,11))
    then
      V_ID_SILI := 6;
    end if;
  
    if (P_ID_SIAJ in (1,6) and P_ID_SINE = 9) or
      (P_ID_SIAJ = 2 and P_ID_SINE in (9,10,11)) or
      (P_ID_SIAJ = 3 and P_ID_SINE in (10,11))
    then
      V_ID_SILI := 5;
    end if;
    
    return V_ID_SILI;  
  END;
  
  FUNCTION F_SILI_DANOS_DIRETOS (P_ID_SIAJ IN NUMBER, P_ID_SINE IN NUMBER) return number AS
    V_ID_SILI SITUACAO_LIBERACAO.SILI_SQ_SITUACAO_LIBERACAO%TYPE;
  BEGIN
    if P_ID_SIAJ in (1,6) and P_ID_SINE = 2 then
      V_ID_SILI := 2;
    end if;
    
    if P_ID_SIAJ = 2 and P_ID_SINE in (2,3,4,5,6,7,8) then
      V_ID_SILI := 7;
    end if;
  
    if (P_ID_SIAJ in (1,6) and P_ID_SINE in (3,4,5))
      or (P_ID_SIAJ in (3,4,5) and P_ID_SINE = 5)
    then
      V_ID_SILI := 3;
    end if;
    
    if P_ID_SIAJ in (1,6) and P_ID_SINE in (6,7,8) then
      V_ID_SILI := 4;
    end if;
    
    if (P_ID_SIAJ in (1,6) and P_ID_SINE in (13)) or
      (P_ID_SIAJ in (3,4,5) and P_ID_SINE in (2,3,4)) or
      (P_ID_SIAJ = 3 and P_ID_SINE in (6,7,8)) or
      (P_ID_SIAJ in (4,5) and P_ID_SINE in (6,7,8,13))
    then
      V_ID_SILI := 6;
    end if;
  
    if (P_ID_SIAJ = 2 and P_ID_SINE = 13)
    then
      V_ID_SILI := 5;
    end if;
    
    return V_ID_SILI;  
  END;
    
  PROCEDURE BUSCA_STATUS_NEGOCIACAO(P_ID_PRLS IN NUMBER, P_ID_TP_NEG IN NUMBER) AS
    V_REG_DOCUMENTO REG_EXISTE_DOCT; 
    I number := 0;
  BEGIN
  
  -- Tipo Negocia��o: Aquisi��o
  -- Tipo Negocia��o: Servid�o
  -- Tipo Negocia��o: Somente danos diretos
  IF( P_ID_TP_NEG = 5 OR P_ID_TP_NEG = 6 OR P_ID_TP_NEG = 1 ) THEN
      -- Status "N�O NEGOCIADO": Primeiro Status ao promover.      
      T_AVALIA_STATUS_NEG(2) := REG_AVALIA_STATUS(2, 1, 1);
      
      -- Status "Em Negocia��o":	Ao distribuir PL entre negociadores.
      T_AVALIA_STATUS_NEG(3) := REG_AVALIA_STATUS(3, VERIFICA_DISTRIBUICAO_PL(P_ID_PRLS), 1 );
      
      -- Status "Carta de Apresenta��o": Assinada	Ao anexar carta de apresenta��o.
      T_AVALIA_STATUS_NEG(4) := REG_AVALIA_STATUS(4, F_EXISTE_DOCUMENTO(156), 1 );
      
      -- Status NEGOCIA��O INCOMPLETA:
      T_AVALIA_STATUS_NEG(5) := REG_AVALIA_STATUS(5, VERIFICA_SIT_NEG_INC( P_ID_PRLS, 2 ), 1 );
      
      -- Status Declara��o de Compromisso Assinada:	Quando todos os itens avaliados (inclusive terra nua) estiverem contidos em alguma declara��o de compromisso
      T_AVALIA_STATUS_NEG(6) := REG_AVALIA_STATUS(6, EXISTE_DECLARACAO_COMPLETA( P_ID_PRLS, 2 ), 1 );
      
      -- Status PAGAMENTO SOLICITADO	Ao anexar solicita��o de pagamento (Tipo Indeniza��o)
      T_AVALIA_STATUS_NEG(7) := REG_AVALIA_STATUS(7, EXISTE_FORM_PAG_POR_TIPO( P_ID_PRLS, 1, 2 ), 1 );
      
      -- Status PAGAMENTO LIBERADO:	Ao anexar todos os documentos de pagamento necess�rios para pagamento das solicita��es existentes
      T_AVALIA_STATUS_NEG(8) := REG_AVALIA_STATUS(8, EXISTE_ITEM_SEM_PAG( P_ID_PRLS ), 1 );
      
      IF( P_ID_TP_NEG = 5 OR P_ID_TP_NEG = 6 ) THEN
          -- Status ESCRITURA PARCIAL:	Ao anexar "Escritura de Cess�o de Posse/Instrumento Particular"
          T_AVALIA_STATUS_NEG(9) := REG_AVALIA_STATUS(9, F_EXISTE_DOCUMENTO(175), 1 );
           
          -- Status ESCRITURA ASSINADA:
          -- Ao anexar escritura p�blica de aquisi��o
          IF( P_ID_TP_NEG = 5 ) THEN
              T_AVALIA_STATUS_NEG(10) := REG_AVALIA_STATUS(10, F_EXISTE_DOCUMENTO(177), 1 );
          -- Ao anexar escritura p�blica de servid�o
          ELSIF( P_ID_TP_NEG = 6 ) THEN
              T_AVALIA_STATUS_NEG(10) := REG_AVALIA_STATUS(10, F_EXISTE_DOCUMENTO(178), 1 );
          END IF;
          
          -- Status Registro de Escritura em Cart�rio:	Ao anexar registro da escritura
          T_AVALIA_STATUS_NEG(11) := REG_AVALIA_STATUS(11, F_EXISTE_DOCUMENTO(179), 1 );
          
          -- Status IPTU/ITR Transferido:	Ao anexar comprovante de transfer�ncia de IPTU ou ITR (somente aquisi��o)
          IF( P_ID_TP_NEG = 5 ) THEN
              T_AVALIA_STATUS_NEG(12) := REG_AVALIA_STATUS(12, F_EXISTE_DOCUMENTO(180), 1 );
          END IF;
      ELSIF( P_ID_TP_NEG = 1 ) THEN
          -- Status ESCRITURA/Instrumento ASSINADO:	Ao anexar escritura ou instrumento assinado
          T_AVALIA_STATUS_NEG(13) := REG_AVALIA_STATUS(13, F_EXISTE_DOCUMENTO(175), 1 );
      END IF;
        
    -- Tipo Negocia��o: Interfer�ncia ou �rea P�blica
    ELSIF( P_ID_TP_NEG = 3 OR P_ID_TP_NEG = 4 ) THEN
        -- Status Conv�nio/Contrato FUTURO:	Primeiro status ao promover
        T_AVALIA_STATUS_NEG(14) := REG_AVALIA_STATUS(14, 1, 1);
        
        -- Status Conv�nio/Contrato Assinado:	Ao anexar Conv�nio/Contrato/Permiss�o de Passagem
        T_AVALIA_STATUS_NEG(15) := REG_AVALIA_STATUS(15, F_EXISTE_DOCUMENTO(164), 1 );
    
    -- Tipo Negocia��o: Contratos
    ELSIF( P_ID_TP_NEG = 7 ) THEN
        -- Status Contrato FUTURO:	Primeiro status ao promover1;
        T_AVALIA_STATUS_NEG(14) := REG_AVALIA_STATUS(14, 1, 1);
        
        -- Status Contrato Assinado:	Ao anexar Contrato
        T_AVALIA_STATUS_NEG(15) := REG_AVALIA_STATUS(15, F_EXISTE_DOCUMENTO(170), 1 );
    -- Tipo Negocia��o: Im�vel Petrobras ou Outros
    ELSE
        T_AVALIA_STATUS_NEG(1) := REG_AVALIA_STATUS(1, 1, 1);
    END IF;
  END;
  
  PROCEDURE BUSCAR_STATUS_ACAO(P_ID_PRLS IN NUMBER) AS
  BEGIN
    
    -- Status A��o Solicitada*:	Ao anexar DIP de Encaminhamento do Dossi�
    T_AVALIA_STATUS_ACAO(2) := REG_AVALIA_STATUS(2, F_EXISTE_DOCUMENTO(185), 1 );
    
    -- Status A��o Iniciada*:	Ao anexar Cita��o
    T_AVALIA_STATUS_ACAO(3) := REG_AVALIA_STATUS(3, F_EXISTE_DOCUMENTO(186), 1 );
        
    -- Status Imiss�o na Posse*: Ao anexar auto de imiss�o na posse
    T_AVALIA_STATUS_ACAO(4) := REG_AVALIA_STATUS(4, F_EXISTE_DOCUMENTO(188), 1 );
        
    -- Status Senten�a Obtida:	Ao anexar senten�a
    T_AVALIA_STATUS_ACAO(5) := REG_AVALIA_STATUS(5, F_EXISTE_DOCUMENTO(192), 1 );
    
    -- Status Registro de Senten�a Efetuado: Ao anexar registro da senten�a em cart�rio
    T_AVALIA_STATUS_ACAO(6) := REG_AVALIA_STATUS(6, F_EXISTE_DOCUMENTO(193), 1 );
    
    -- Status A��o Cancelada: Ao anexar DIP de Solicita��o de Cancelamento
    T_AVALIA_STATUS_ACAO(7) := REG_AVALIA_STATUS(7, F_EXISTE_DOCUMENTO(184), 1 );
  END;
  
  -- Verifica se o PL est� distribu�do
  FUNCTION VERIFICA_DISTRIBUICAO_PL(P_ID_PRLS IN NUMBER) return NUMBER AS
      COUNT_PL NUMBER(5);
  BEGIN
      SELECT COUNT(*)
        INTO COUNT_PL
        FROM DISTRIBUICAO_PRCS_LIBERACAO
       WHERE PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS;
      
      IF( COUNT_PL > 0 ) THEN
          RETURN 1;
      ELSE
          RETURN 0;
      END IF;
  END;
  
  -- Verifica se existe documento ativo de solicita��o de pagamento, do tipo indeniza��o, para um determinado processo de libera��o
  FUNCTION EXISTE_FORM_PAG_POR_TIPO(P_ID_PRLS IN NUMBER, P_ID_TIPO_PAG IN NUMBER, P_ID_SIT_DOC IN NUMBER) return NUMBER AS
      COUNT_PL NUMBER(5);
  BEGIN
      SELECT COUNT(*)
        INTO COUNT_PL
        FROM FORMULARIO_PAGAMENTO FOPA
       INNER JOIN ARQUIVO_NEGOCIACAO ARNE ON FOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO = ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO
       WHERE ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
         AND ARNE.SIDO_SQ_SITUACAO_DOCUMENTO  = P_ID_SIT_DOC
         AND FOPA.TIPA_SQ_TIPO_PAGAMENTO      = P_ID_TIPO_PAG;
      
      IF( COUNT_PL > 0 ) THEN
          RETURN 1;
      ELSE
          RETURN 0;
      END IF;
  END;
  
  -- Verifica se existe algum item de pagamento, de um formul�rio de pagamento ativo de um determinado PL, sem estar vinculado a um documento documento de pagamento ativo
  FUNCTION EXISTE_ITEM_SEM_PAG(P_ID_PRLS IN NUMBER) return NUMBER AS
      COUNT_PL NUMBER(5);
  BEGIN      
      SELECT COUNT(*)
        INTO COUNT_PL
        FROM FORMULARIO_PAGAMENTO FOPA
       INNER JOIN ARQUIVO_NEGOCIACAO  ARFP ON FOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO   = ARFP.ARNE_SQ_ARQUIVO_NEGOCIACAO
       INNER JOIN ITEM_PAGAMENTO      ITPA ON FOPA.FOPA_SQ_FORMULARIO_PAGAMENTO = ITPA.FOPA_SQ_FORMULARIO_PAGAMENTO
       RIGHT JOIN DOCUMENTO_PAGAMENTO DOPA ON ITPA.ITPA_SQ_ITEM_PAGAMENTO       = DOPA.ITPA_SQ_ITEM_PAGAMENTO
       RIGHT JOIN ARQUIVO_NEGOCIACAO  ARDP ON DOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO   = ARDP.ARNE_SQ_ARQUIVO_NEGOCIACAO
       WHERE ARFP.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
         AND ARFP.SIDO_SQ_SITUACAO_DOCUMENTO  = 2
         AND ARDP.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
         AND ARDP.SIDO_SQ_SITUACAO_DOCUMENTO  = 2;
      
      IF( COUNT_PL > 0 ) THEN
          RETURN 1;
      ELSE
          RETURN 0;
      END IF;
  END;
  
  -- Verifica se existe alguma declara��o de compromisso com todos os itens avaliados pelo laudos preenchidos
  FUNCTION EXISTE_DECLARACAO_COMPLETA(P_ID_PRLS IN NUMBER, P_ID_SIT_DOC IN NUMBER) return NUMBER AS
      COUNT_PL NUMBER(5);
  BEGIN      
      SELECT COUNT(*)
        INTO COUNT_PL
        FROM DECLARACAO_COMPROMISSO DECO
       INNER JOIN ARQUIVO_NEGOCIACAO           ARNE ON DECO.ARNE_SQ_ARQUIVO_NEGOCIACAO  = ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO
       INNER JOIN PROCESSO_LIBERACAO_SRVC_ENGR PRLS ON ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = PRLS.PRLS_SQ_PRCS_LBRC_SRVC_ENGR
       INNER JOIN AVALIACAO_SEPAV_TOTAL        AVSP ON PRLS.PRLI_SQ_PROCESSO_LIBERACAO  = AVSP.PRLI_SQ_PROCESSO_LIBERACAO
       WHERE ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
         AND ARNE.SIDO_SQ_SITUACAO_DOCUMENTO  = P_ID_SIT_DOC
         AND ( ( nvl(AVSP.AVST_VL_TAXA_PRIMARIA_INDC,0)    = 0 OR nvl(DECO.DECO_VL_TAXA_PRIMARIA_INDC,0)    > 0 ) AND
               ( nvl(AVSP.AVST_VL_DANO_DIRT_TERRA_NUA,0)   = 0 OR nvl(DECO.DECO_VL_DANO_DIRT_TERRA_NUA,0)   > 0 ) AND
               ( nvl(AVSP.AVST_VL_DANO_DIRT_CONSTRUCAO,0)  = 0 OR nvl(DECO.DECO_VL_DANO_DIRT_CONSTRUCAO,0)  > 0 ) AND
               ( nvl(AVSP.AVST_VL_DANO_DIRT_EQUIPAMENTO,0) = 0 OR nvl(DECO.DECO_VL_DANO_DIRT_EQUIPAMENTO,0) > 0 ) AND
               ( nvl(AVSP.AVST_VL_DANO_DIRT_VEGETACAO,0)   = 0 OR nvl(DECO.DECO_VL_DANO_DIRT_VEGETACAO,0)   > 0 ) AND
               ( nvl(AVSP.AVST_VL_LUCRO_CSNT_VEGETACAO,0)  = 0 OR nvl(DECO.DECO_VL_LUCRO_CSNT_VEGETACAO,0)  > 0 ) AND
               ( nvl(AVSP.AVST_VL_DANO_DIRT_ATVD_ECNC,0)   = 0 OR nvl(DECO.DECO_VL_DANO_DIRT_ATVD_ECNC,0)   > 0 ) AND
               ( nvl(AVSP.AVST_VL_LUCRO_CSNT_ATVD_ECNC,0)  = 0 OR nvl(DECO.DECO_VL_LUCRO_CSNT_ATVD_ECNC,0)  > 0 ) );
      
      IF( COUNT_PL > 0 ) THEN
          RETURN 1;
      ELSE
          RETURN 0;
      END IF;
  END;
  
  -- Verifica se existe alguma declara��o de compromisso com todos os itens avaliados pelo laudos preenchidos
  FUNCTION VERIFICA_SIT_NEG_INC(P_ID_PRLS IN NUMBER, P_ID_SIT_DOC IN NUMBER) return NUMBER AS
      COUNT_PL NUMBER(5);
  BEGIN
      -- 1 - Quando houver declara��o de compromisso, mas algum dos itens (inclusive terra nua) n�o estiver contemplado pelas declara��es.
      SELECT COUNT(*)
        INTO COUNT_PL
        FROM DECLARACAO_COMPROMISSO DECO
       INNER JOIN ARQUIVO_NEGOCIACAO           ARNE ON DECO.ARNE_SQ_ARQUIVO_NEGOCIACAO  = ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO
       INNER JOIN PROCESSO_LIBERACAO_SRVC_ENGR PRLS ON ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = PRLS.PRLS_SQ_PRCS_LBRC_SRVC_ENGR
       INNER JOIN AVALIACAO_SEPAV_TOTAL        AVSP ON PRLS.PRLI_SQ_PROCESSO_LIBERACAO  = AVSP.PRLI_SQ_PROCESSO_LIBERACAO
       WHERE ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
         AND ARNE.SIDO_SQ_SITUACAO_DOCUMENTO  = P_ID_SIT_DOC
         AND ( ( nvl(AVSP.AVST_VL_TAXA_PRIMARIA_INDC,0)     > 0 AND nvl(DECO.DECO_VL_TAXA_PRIMARIA_INDC,0)     > 0 ) OR
               ( nvl(AVSP.AVST_VL_DANO_DIRT_TERRA_NUA,0)    > 0 AND nvl(DECO.DECO_VL_DANO_DIRT_TERRA_NUA,0)    > 0 ) OR
               ( nvl(AVSP.AVST_VL_DANO_DIRT_CONSTRUCAO,0)   > 0 AND nvl(DECO.DECO_VL_DANO_DIRT_CONSTRUCAO,0)   > 0 ) OR
               ( nvl(AVSP.AVST_VL_DANO_DIRT_EQUIPAMENTO,0)  > 0 AND nvl(DECO.DECO_VL_DANO_DIRT_EQUIPAMENTO,0)  > 0 ) OR
               ( nvl(AVSP.AVST_VL_DANO_DIRT_VEGETACAO,0)    > 0 AND nvl(DECO.DECO_VL_DANO_DIRT_VEGETACAO,0)    > 0 ) OR
               ( nvl(AVSP.AVST_VL_LUCRO_CSNT_VEGETACAO,0)   > 0 AND nvl(DECO.DECO_VL_LUCRO_CSNT_VEGETACAO,0)   > 0 ) OR
               ( nvl(AVSP.AVST_VL_DANO_DIRT_ATVD_ECNC,0)    > 0 AND nvl(DECO.DECO_VL_DANO_DIRT_ATVD_ECNC,0)    > 0 ) OR
               ( nvl(AVSP.AVST_VL_LUCRO_CSNT_ATVD_ECNC,0)   > 0 AND nvl(DECO.DECO_VL_LUCRO_CSNT_ATVD_ECNC,0)   > 0 ) );
      
      IF( COUNT_PL > 0 ) THEN
          RETURN 1;
      END IF;
      
      -- 2 - Quando houver "auto de imiss�o na posse, carta de senten�a ou registro de senten�a", mas houver constru��es n�o pagas (considerar que a imiss�o na posse n�o libera contru��es)
       SELECT COUNT(*)
         INTO COUNT_PL
         FROM FORMULARIO_PAGAMENTO FOPA
        INNER JOIN ITEM_PAGAMENTO      ITPA ON FOPA.FOPA_SQ_FORMULARIO_PAGAMENTO = ITPA.FOPA_SQ_FORMULARIO_PAGAMENTO
        INNER JOIN ARQUIVO_NEGOCIACAO  ARFP ON FOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO   = ARFP.ARNE_SQ_ARQUIVO_NEGOCIACAO
        RIGHT JOIN DOCUMENTO_PAGAMENTO DOPA ON ITPA.ITPA_SQ_ITEM_PAGAMENTO       = DOPA.ITPA_SQ_ITEM_PAGAMENTO
        RIGHT JOIN ARQUIVO_NEGOCIACAO  ARDP ON DOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO   = ARDP.ARNE_SQ_ARQUIVO_NEGOCIACAO
        WHERE FOPA.TIPA_SQ_TIPO_PAGAMENTO = 1
          AND ITPA.ITPA_NM_ITEM_PAGAMENTO LIKE ( '%Benfeitorias%' )
          AND ARFP.SIDO_SQ_SITUACAO_DOCUMENTO  = P_ID_SIT_DOC
          AND ARDP.SIDO_SQ_SITUACAO_DOCUMENTO  = P_ID_SIT_DOC
          AND ARFP.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
          AND ARDP.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS;
      
      IF( COUNT_PL > 0 ) THEN
          RETURN 1;
      ELSE
          RETURN 0;
      END IF;
  END;
  
  ----------------------------------------------
  
  PROCEDURE VERIFICAR_STATUS(P_ID_PRLS IN NUMBER) IS
  BEGIN 
    VERIFICAR_STATUS(P_ID_PRLS, null);
  END;
  
  PROCEDURE VERIFICAR_STATUS(P_ID_PRLS IN NUMBER, P_ID_USUARIO IN NUMBER) IS
    V_ID_TINE       TIPO_NEGOCIACAO.TINE_SQ_TIPO_NEGOCIACAO%TYPE;
    V_ID_STATUS_NEG SITUACAO_NEGOCIACAO.SINE_SQ_SITUACAO_NEGOCIACAO%TYPE;
    V_ID_STATUS_ACJ SITUACAO_ACAO_JUDICIAL.SIAJ_SQ_SITC_ACAO_JUDICIAL%TYPE;
    
    V_ID_STATUS_NEG_LOOP SITUACAO_NEGOCIACAO.SINE_SQ_SITUACAO_NEGOCIACAO%TYPE;
    V_ID_STATUS_ACJ_LOOP SITUACAO_ACAO_JUDICIAL.SIAJ_SQ_SITC_ACAO_JUDICIAL%TYPE;
  BEGIN
  
    T_AVALIA_STATUS_NEG.delete();
    T_AVALIA_STATUS_ACAO.delete();   
  
    select TINE_SQ_TIPO_NEGOCIACAO
    into V_ID_TINE
    from PROCESSO_LIBERACAO_SRVC_ENGR
    where PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS;
  
    ATUALIZA_LISTA_DOCUMENTOS(P_ID_PRLS);
    CARREGAR_VALORES_SEPAV(P_ID_PRLS);
    CARREGAR_VALORES_DECO(P_ID_PRLS);
    CARREGAR_MARGEM(P_ID_PRLS);
    
    BUSCA_STATUS_NEGOCIACAO(P_ID_PRLS,V_ID_TINE);
    
    -- Status Sem A��o:	Primeiro Status ao Promover
    T_AVALIA_STATUS_ACAO(1) := REG_AVALIA_STATUS(1, 1, 1);
    
    IF( V_ID_TINE NOT IN ( 2, 3, 7 ) ) THEN
      BUSCAR_STATUS_ACAO(P_ID_PRLS);      
    END IF;
    
    VERIFICAR_PENDENCIAS(P_ID_PRLS,V_ID_TINE);
    
    if T_AVALIA_STATUS_NEG is not null and T_AVALIA_STATUS_NEG.count > 0 then
      V_ID_STATUS_NEG_LOOP := T_AVALIA_STATUS_NEG.FIRST;
      
      while V_ID_STATUS_NEG_LOOP is not null loop
        if (nvl(T_AVALIA_STATUS_NEG(V_ID_STATUS_NEG_LOOP).VERIFICACAO_STATUS,0) * nvl(T_AVALIA_STATUS_NEG(V_ID_STATUS_NEG_LOOP).VERIFICACAO_PENDENCIA,0)) = 1
        then
           V_ID_STATUS_NEG := T_AVALIA_STATUS_NEG(V_ID_STATUS_NEG_LOOP).ID_STATUS;
        end if;
        
        V_ID_STATUS_NEG_LOOP := T_AVALIA_STATUS_NEG.next(V_ID_STATUS_NEG_LOOP);
      end loop;
      
    end if;
    
    if T_AVALIA_STATUS_ACAO is not null and T_AVALIA_STATUS_ACAO.count > 0 then
      V_ID_STATUS_ACJ_LOOP := T_AVALIA_STATUS_ACAO.FIRST;
      
      while V_ID_STATUS_ACJ_LOOP is not null loop
        if (nvl(T_AVALIA_STATUS_ACAO(V_ID_STATUS_ACJ_LOOP).VERIFICACAO_STATUS,0) * nvl(T_AVALIA_STATUS_ACAO(V_ID_STATUS_ACJ_LOOP).VERIFICACAO_PENDENCIA,0)) = 1
        then
           V_ID_STATUS_ACJ := T_AVALIA_STATUS_ACAO(V_ID_STATUS_ACJ_LOOP).ID_STATUS;
        end if;
        
        V_ID_STATUS_ACJ_LOOP := T_AVALIA_STATUS_ACAO.next(V_ID_STATUS_ACJ_LOOP);
      end loop;
    end if;
    
    update PROCESSO_LIBERACAO_SRVC_ENGR set
      SINE_SQ_SITUACAO_NEGOCIACAO = V_ID_STATUS_NEG,
      SIAJ_SQ_SITC_ACAO_JUDICIAL = V_ID_STATUS_ACJ
    where PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS;
    
    commit;
    
    ATUALIZA_STATUS_LBRC_WORKFLOW(P_ID_PRLS, P_ID_USUARIO);    
  END;
  ----------------------------------------------------
  
  PROCEDURE VERIFICAR_PENDENCIAS(P_ID_PRLS IN NUMBER, V_ID_TINE IN NUMBER) IS    
  BEGIN
    LIMPAR_PENDENCIAS(P_ID_PRLS);
    
    if V_ID_TINE in (5,6,1) then
      AQUISICAO_DESAPROPIACAO(P_ID_PRLS);
      CARTA_APRESENTACAO(P_ID_PRLS);
      P_VALOR_DECLARACAO(P_ID_PRLS);
      P_SOLICITACAO_NAO_VINCULADA(P_ID_PRLS);
      P_REC_ESCRITURA(P_ID_PRLS);
      P_VALOR_NEG_PAGO(P_ID_PRLS);
      
      if V_ID_TINE in (5,6) then
        P_DECLARACAO_TERRA_NUA(P_ID_PRLS);
        P_CONTROL_IMOB_NAO_ANEXADO(P_ID_PRLS);
        P_ESCRITURA_PUB_NAO_INSERIDA(P_ID_PRLS);
      end if; 
      
      if V_ID_TINE = 5 then
        P_ESCRITURA_NAO_INSERIDA(P_ID_PRLS);
      end if;
      
      if V_ID_TINE = 1 then
        P_SEM_IPTU(P_ID_PRLS);
      end if;
      
      if V_EXISTE_MARGEM = 'N' then      
        INSERIR_PENDENCIA(P_ID_PRLS, 'N�o h� Margem de Negocia��o vinculada.', 'N', 'S');
        
        ATUALIZA_STATUS_NEG(5,0);
      end if;
      P_MARGEM_NEGOCIACAO(P_ID_PRLS);
      
    end if;
    
    if V_ID_TINE in (5,6,1,8) then
      P_SOLICT_VALOR_DIF(P_ID_PRLS);
      P_CONSTRUCAO_ACAO(P_ID_PRLS);
      P_PAGAMENTO_INDENIZACAO(P_ID_PRLS);
    end if;
       
    if V_ID_TINE in (5,6,7) then
      P_CERTIDAO_INT_TEOR(P_ID_PRLS);
    end if;
    
    if V_ID_TINE in (5,6,1,7) then
      P_CERTIDAO_NEG_DEBITO(P_ID_PRLS);
    end if;
    
    if V_ID_TINE = 4 then
      P_INTERFERENCIAS(P_ID_PRLS);
    end if;
    
    if V_ID_TINE in (5,6,1,4,8) then
      P_ACAO_JUDICIAL(P_ID_PRLS);
      P_PAGAMENTO_ACAO_JUDICIAL(P_ID_PRLS);
    end if;
    
    if V_ID_TINE in (4,3,7,8) then
      P_PAGAMENTO_CONTRATO_CONV(P_ID_PRLS);
    end if;
    
    P_PAGAMENTO_TODOS(P_ID_PRLS);
  END;
  
  
  PROCEDURE AQUISICAO_DESAPROPIACAO(P_ID_PRLS IN NUMBER) AS
    V_EX_TIDO_199 number(1); -- Relat�rio da Comiss�o de Arquisi��o e Servid�o
    V_EX_TIDO_200 number(1); -- DIP Solict. Parecer Juridico para relat�rio da Comiss�o 
    V_EX_TIDO_201 number(1); -- Parecer Jur�dico para Relat�rio da Comiss�o
    V_EX_TIDO_202 number(1); -- DIP Solicit. Aprova��o do Rel. da Comiss�o e Parecer Jur�dico
    V_EX_TIDO_203 number(1); -- Aprova��o do relat�rio da Comiss�o e Parecer Jur�dico
    
    V_DS_MENSAGEM PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
  BEGIN
    V_EX_TIDO_199 := F_EXISTE_DOCUMENTO(199);
    V_EX_TIDO_200 := F_EXISTE_DOCUMENTO(200);
    V_EX_TIDO_201 := F_EXISTE_DOCUMENTO(201);
    V_EX_TIDO_202 := F_EXISTE_DOCUMENTO(202);
    V_EX_TIDO_203 := F_EXISTE_DOCUMENTO(203);
  
    if (V_EX_TIDO_199 = 0 and
      (V_EX_TIDO_200  = 1 or
       V_EX_TIDO_201  = 1 or
       V_EX_TIDO_202  = 1 or
       V_EX_TIDO_203  = 1))      
    then
      ATUALIZA_STATUS_NEG(6,0);
      V_DS_MENSAGEM := 'O Relat�rio da Comiss�o para Aquisi��o e Desapropia��o de �reas n�o foi inserido no sistema';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM , 'N', 'S');
      
    end if; 
    
    if (V_EX_TIDO_200 = 0 and
      (V_EX_TIDO_201  = 1 or
       V_EX_TIDO_202  = 1 or
       V_EX_TIDO_203  = 1))
    then    
      V_DS_MENSAGEM := 'O DIP de Solicita��o do Parecer Jur�dico para relat�rio da Comiss�o de Aquisi��o e Desapropia��o de �reas n�o foi inserido no sistema';
    
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'N');
    end if;
    
    if (V_EX_TIDO_201 = 0 and
      (V_EX_TIDO_202  = 1 or
       V_EX_TIDO_203  = 1))
    then
      V_DS_MENSAGEM := 'O Parecer Jur�dico do Relat�rio da Comiss�o de Aquisi��o e Desapropia��o de �reas n�o foi inserido no sistema';
      
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'N');
    end if;
    
    if (V_EX_TIDO_202 = 0 and V_EX_TIDO_203 =  1) then
      V_DS_MENSAGEM := 'O DIP de Solicita��o de Aprova��o do Relat�rio da Comiss�o de Aquisi��o e Desapropia��o de �reas e do Parecer Jur�dico n�o foi inserido no sistema';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N','N');
    end if;
  END;

  PROCEDURE CARTA_APRESENTACAO(P_ID_PRLS IN NUMBER) AS
    V_EX_FORM_PAGTO number := 0;
    CT_FORM_PAGTO   number;
    V_EX_DOCU_PAGTO number := 0;
    CT_DOCU_PAGTO   number;
    V_EX_RECB_PAGTO number := 0;
    CT_RECB_PAGTO   number;
    
    V_DS_MENSAGEM PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
  BEGIN
    /* Verifica se existe o Tipo Documento Formul�rio Solicita��o de Pagamento do Tipo Indeniza��o */
    if (F_EXISTE_DOCUMENTO(157)=1) then
      select count(*)
      into CT_FORM_PAGTO
      from  FORMULARIO_PAGAMENTO FOPA,
            ARQUIVO_NEGOCIACAO ARNE,
            DOCUMENTO DOCU
      where FOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO = ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO
      and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
      and DOCU.DOCU_SQ_DOCUMENTO = ARNE.DOCU_SQ_DOCUMENTO
      and DOCU.TIDO_SQ_TIPO_DOCUMENTO = 157
      and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
      and FOPA.TIPA_SQ_TIPO_PAGAMENTO = 1;
      
      if CT_FORM_PAGTO > 0 then
        V_EX_FORM_PAGTO := 1;
      end if;
    end if;
    
    /* Verifica se existe o Tipo Documento Documento de Pagamento do Tipo Indeniza��o */
    if (F_EXISTE_DOCUMENTO(159)=1) then
      select count(*)
      into CT_DOCU_PAGTO
      from  FORMULARIO_PAGAMENTO FOPA,
            ARQUIVO_NEGOCIACAO ARNE,
            DOCUMENTO DOCU
      where FOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO = ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO
      and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
      and DOCU.DOCU_SQ_DOCUMENTO = ARNE.DOCU_SQ_DOCUMENTO
      and DOCU.TIDO_SQ_TIPO_DOCUMENTO = 159
      and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
      and FOPA.TIPA_SQ_TIPO_PAGAMENTO = 1;
      
      if CT_DOCU_PAGTO > 0 then
        V_EX_DOCU_PAGTO := 1;
      end if;      
    end if;

    /* Verifica se existe o Tipo Documento Recibo de Pagamento do Tipo Indeniza��o */
    if (F_EXISTE_DOCUMENTO(161)=1) then
      select count(*)
      into CT_RECB_PAGTO
      from  FORMULARIO_PAGAMENTO FOPA,
            ARQUIVO_NEGOCIACAO ARNE,
            DOCUMENTO DOCU
      where FOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO = ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO
      and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
      and DOCU.DOCU_SQ_DOCUMENTO = ARNE.DOCU_SQ_DOCUMENTO
      and DOCU.TIDO_SQ_TIPO_DOCUMENTO = 161
      and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
      and FOPA.TIPA_SQ_TIPO_PAGAMENTO = 1;
      
      if CT_RECB_PAGTO > 0 then
        V_EX_RECB_PAGTO := 1;
      end if;
    end if;
  
    if (F_EXISTE_DOCUMENTO(156) = 0 and -- Carta de Apresenta��o
      (F_EXISTE_DOCUMENTO(171) = 1 or   -- Declara��o de Compromisso
       V_EX_FORM_PAGTO = 1 or           -- Solicita��o de Pagamento do tipo Indeniza��o
       V_EX_DOCU_PAGTO = 1 or           -- Documento de Pagamento do tipo Indeniza��o
       V_EX_RECB_PAGTO = 1 or           -- Recibo de Pagamento do tipo Indeniza��o
       F_EXISTE_DOCUMENTO(175) = 1 or   -- Escritura de Cess�o de Posse/Instrumento Particular
       F_EXISTE_DOCUMENTO(177) = 1 or   -- Escritura P�blica de Compra e Venda (Aquisi��o)
       F_EXISTE_DOCUMENTO(178) = 1 or   -- Escritura P�blica de Servid�o
       F_EXISTE_DOCUMENTO(179) = 1))    -- Registro de Escritura
    then
      V_DS_MENSAGEM := 'A Carta de Apresenta��o n�o foi inserida no Sistema';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'N');
    end if;
  END;

  PROCEDURE P_VALOR_DECLARACAO (P_ID_PRLS IN NUMBER) AS
    V_EX_APROV_REL            NUMBER(1);
    V_VL_REL_COM_AQUI_SERV    NUMBER(38,2);
    
    V_TX_ITENS                VARCHAR2(100) := null;
    
    V_DS_MENSAGEM       PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
    V_VL_ACIMA_MARGEM   PROCESSO_LIBERACAO.PRLI_VL_ACIMA_MARGEM_NGCC%TYPE;
  BEGIN
    if F_EXISTE_DOCUMENTO(171) = 1 then      
      
      if (V_TOTAL_BRUTO_DECO < (V_TOTAL_BRUTO_SEPAV - (V_TOTAL_BRUTO_SEPAV * (V_ROW_MARGEM.MANE_PR_MARGEM_NEGOCIACAO/100)))) then      
                
        ATUALIZA_STATUS_NEG(6,0);
        
        V_DS_MENSAGEM := 'Valor Total das declara��es de compromisso est� abaixo da margem do PL';
        INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'S', 'S');
      end if;
      
      V_EX_APROV_REL := F_EXISTE_DOCUMENTO(203);
      
      select nvl(PRLI_VL_ACIMA_MARGEM_NGCC,0)
      into V_VL_ACIMA_MARGEM
      from PROCESSO_LIBERACAO
      where PRLI_SQ_PROCESSO_LIBERACAO = 
        (select PRLI_SQ_PROCESSO_LIBERACAO 
         from PROCESSO_LIBERACAO_SRVC_ENGR 
         where PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS);
      
      if (V_TOTAL_BRUTO_DECO > (V_TOTAL_BRUTO_SEPAV + (V_TOTAL_BRUTO_SEPAV * (V_ROW_MARGEM.MANE_PR_MARGEM_NEGOCIACAO/100)))) then 
        if V_EX_APROV_REL =  0 and nvl(V_VL_ACIMA_MARGEM,0) = 0 then
          
          ATUALIZA_STATUS_NEG(5,0);
          
          V_DS_MENSAGEM := 'Valor negociado nas declara��es de compromisso est� acima da margem do PL';
          INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
        end if;
      end if;
        
      if V_EX_APROV_REL = 1 and F_EXISTE_DOCUMENTO(199) = 1 then
        begin
          select sum(TO_NUMBER(nvl(ATDO_TX_ATRIBUTO_DOCUMENTO,0)))
          into V_VL_REL_COM_AQUI_SERV
          from  ATRIBUTO_DOCUMENTO ATDO,
                ATRIBUTO_TIPO_DOCUMENTO ATTD,
                DOCUMENTO DOCU,
                ARQUIVO_NEGOCIACAO ARNE
          where ARNE.DOCU_SQ_DOCUMENTO = DOCU.DOCU_SQ_DOCUMENTO
          and DOCU.TIDO_SQ_TIPO_DOCUMENTO = ATTD.TIDO_SQ_TIPO_DOCUMENTO
          and ATDO.DOCU_SQ_DOCUMENTO = DOCU.DOCU_SQ_DOCUMENTO
          and ATTD.ATTD_SQ_ATRIBUTO_TIPO_DOCT = ATDO.ATTD_SQ_ATRIBUTO_TIPO_DOCT
          and ATTD.ATTD_NM_ATRIBUTO_TIPO_DOCT = 'Valor Aprovado'
          and DOCU.TIDO_SQ_TIPO_DOCUMENTO = 199
          and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
          and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS;
          
        exception when no_data_found then
          V_VL_REL_COM_AQUI_SERV := 0;
        end;
        
        if V_VL_REL_COM_AQUI_SERV != V_TOTAL_BRUTO_DECO then
          ATUALIZA_STATUS_NEG(6,0);
          
          V_DS_MENSAGEM := 'O valor negociado nas declara��es de compromisso est� diferente do valor aprovado pela comiss�o de aquisi��o e desapropia��o de �reas';
          INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
        end if;        
      end if;
      
      if nvl(V_VL_ACIMA_MARGEM,0) > 0 and V_TOTAL_BRUTO_DECO > nvl(V_VL_ACIMA_MARGEM,0) then
        ATUALIZA_STATUS_NEG(5,0);
        
        V_DS_MENSAGEM := 'O valor negociado nas declara��es de compromisso est� acima do valor aprovado pelo "Parecer Jur�dico para Complementa��o de Indeniza��o';
        INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
        
      end if;
      
      if V_VL_TPI_DECO < V_VL_TPI then
                
        ATUALIZA_STATUS_NEG(5,0);
        
        V_DS_MENSAGEM := 'O valor da TPI nas declara��es de compromisso n�o foi considerado ou est� abaixo do valor definido no laudo';
        INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'S', 'S');
      end if;
    
      if V_VL_TPI_DECO > V_VL_TPI then
                
        ATUALIZA_STATUS_NEG(5,0);
        
        V_DS_MENSAGEM := 'O valor da TPI nas declara��es de compromisso est� maior do valor definido no laudo';
        INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
      end if;
    
      if (F_EXISTE_DOCUMENTO(188) = 0 and F_EXISTE_DOCUMENTO(192) = 0 and F_EXISTE_DOCUMENTO(193) = 0) then
        if (V_VL_DD_CONSTRUCAO > 0 and V_VL_DD_CONSTRUCAO_DECO = 0) then
          V_TX_ITENS := 'Constru��o';
        end if;
        
        if (V_VL_DD_EQUIPAMENTO > 0 and V_VL_DD_EQUIPAMENTO_DECO = 0) then
          if V_TX_ITENS is null then
            V_TX_ITENS := 'Equipamento';
          else
            V_TX_ITENS := V_TX_ITENS||', Equipamento';
          end if;
        end if;
        
        if (V_VL_DD_VEGETACAO > 0 and V_VL_DD_VEGETACAO_DECO = 0) then
          if V_TX_ITENS is null then
            V_TX_ITENS := 'Vegeta��o';
          else
            V_TX_ITENS := V_TX_ITENS||', Vegeta��o';
          end if;          
        end if;
        
        if (V_VL_LC_VEGETACAO > 0 and V_VL_LC_VEGETACAO_DECO = 0) then
          if V_TX_ITENS is null then
            V_TX_ITENS := 'lucro cessante Vegeta��o';
          else
            V_TX_ITENS := V_TX_ITENS||', Lucro Cessante de Vegeta��o';
          end if;          
        end if;
        
        if (V_VL_DD_ATVD_ECNC > 0 and V_VL_DD_ATVD_ECNC_DECO = 0) then
          if V_TX_ITENS is null then
            V_TX_ITENS := 'Atividade Econ�mica';
          else
            V_TX_ITENS := V_TX_ITENS||', Atividade Econ�mica';
          end if;
        end if;
        
        if (V_VL_LC_ATVD_ECNC > 0 and V_VL_LC_ATVD_ECNC_DECO = 0) then
          if V_TX_ITENS is null then
            V_TX_ITENS := 'lucro cessante Atividade Econ�mica';
          else
            V_TX_ITENS := V_TX_ITENS||', Lucro Cessante de Atividade Econ�mica';
          end if;
        end if;
        
        if V_TX_ITENS is not null then          
        
          ATUALIZA_STATUS_NEG(6,0);
          
          V_DS_MENSAGEM := 'O grupo de itens avali�veis de '||V_TX_ITENS||' est� pendente de negocia��o';
          INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
        end if;
      end if;
    end if;    
  END;

  PROCEDURE P_DECLARACAO_TERRA_NUA (P_ID_PRLS IN NUMBER) AS
    V_DS_MENSAGEM PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
  BEGIN
    if (F_EXISTE_DOCUMENTO(171) = 1 and F_EXISTE_DOCUMENTO(188) = 0 and F_EXISTE_DOCUMENTO(192) = 0 and F_EXISTE_DOCUMENTO(193) = 0)
    then
      
      if (V_VL_DD_TERRA_NUA > 0 and V_VL_DD_TERRA_NUA_DECO = 0) then
        
        ATUALIZA_STATUS_NEG(6,0);
        --ATUALIZA_STATUS_NEG(9,1);
        
        V_DS_MENSAGEM := 'A Terra Nua do PL est� pendente de negocia��o';
        
        INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
      end if;
    end if;
  END;

  PROCEDURE P_SOLICITACAO_NAO_VINCULADA(P_ID_PRLS IN NUMBER) AS
    CT_SOLIC_INDENIZACAO  number(5); 
    V_DS_MENSAGEM PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
  BEGIN
    if (F_EXISTE_DOCUMENTO(157) = 1) then
      select count(*)
      into CT_SOLIC_INDENIZACAO
      from  FORMULARIO_PAGAMENTO FOPA,
            ARQUIVO_NEGOCIACAO ARNE
      where ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO = FOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO
      and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
      and FOPA.TIPA_SQ_TIPO_PAGAMENTO = 1
      and SIDO_SQ_SITUACAO_DOCUMENTO = 2
      and FOPA.DECO_SQ_DECLARACAO_COMPROMISSO is null;
      
      if CT_SOLIC_INDENIZACAO > 0 then        
        ATUALIZA_STATUS_NEG(7,0);
        
        V_DS_MENSAGEM := 'A solicita��o de pagamento indeniza��o n�o est� vinculada a uma declara��o de compromisso';
        INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
      end if;
    end if;
  END;
  
  PROCEDURE P_CONTROL_IMOB_NAO_ANEXADO(P_ID_PRLS IN NUMBER) AS
    CT_SOLIC_INDENIZACAO_TN  number(5);
    V_DS_MENSAGEM PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
  BEGIN
    select count(*)
      into CT_SOLIC_INDENIZACAO_TN
      from  FORMULARIO_PAGAMENTO FOPA,
            ARQUIVO_NEGOCIACAO ARNE
      where ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO = FOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO
      and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
      and FOPA.TIPA_SQ_TIPO_PAGAMENTO = 1
      and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
      and exists (select 'x' from ITEM_PAGAMENTO ITPA
                  where ITPA.FOPA_SQ_FORMULARIO_PAGAMENTO = FOPA.FOPA_SQ_FORMULARIO_PAGAMENTO
                  and upper(ITPA_NM_ITEM_PAGAMENTO) like '%TERRA NUA%');
    
    
    if(F_EXISTE_DOCUMENTO(172) = 0 and
       (CT_SOLIC_INDENIZACAO_TN > 0 or
        F_EXISTE_DOCUMENTO(177) = 1 or
        F_EXISTE_DOCUMENTO(178) = 1 or
        F_EXISTE_DOCUMENTO(179) = 1 or
        F_EXISTE_DOCUMENTO(181) = 1))
    then
      
      ATUALIZA_STATUS_NEG(7,0);
      
      V_DS_MENSAGEM := 'O Formul�rio de Controle Imobili�rio n�o foi anexado';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end if;
  END;

  PROCEDURE P_SOLICT_VALOR_DIF(P_ID_PRLS IN NUMBER) AS
    V_VL_BRUTO_FORM       number(38,2);
    V_VL_IMPOSTO_RENDA    number(38,2);
    CT_SOLIC_INDENIZACAO  number(5); 
    V_DS_MENSAGEM PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
  BEGIN
    select count(*)
    into CT_SOLIC_INDENIZACAO
    from  FORMULARIO_PAGAMENTO FOPA,
          ARQUIVO_NEGOCIACAO ARNE
    where ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO = FOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO
    and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
    and FOPA.TIPA_SQ_TIPO_PAGAMENTO = 1
    and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
    and FOPA.DECO_SQ_DECLARACAO_COMPROMISSO is not null;
    
    if (CT_SOLIC_INDENIZACAO) > 0 then
      select nvl(sum(ITPA_VL_BRUTO),0), nvl(sum(ITPA_VL_IMPOSTO_RENDA),0)
      into V_VL_BRUTO_FORM, V_VL_IMPOSTO_RENDA
      from   ITEM_PAGAMENTO ITPA,
             FORMULARIO_PAGAMENTO FOPA,
             ARQUIVO_NEGOCIACAO ARNE
      where ITPA.FOPA_SQ_FORMULARIO_PAGAMENTO = FOPA.FOPA_SQ_FORMULARIO_PAGAMENTO
      and ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO = FOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO
      and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
      and FOPA.TIPA_SQ_TIPO_PAGAMENTO = 1
      and FOPA.DECO_SQ_DECLARACAO_COMPROMISSO is not null
      and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2; 
     
      if (V_VL_BRUTO_FORM != V_TOTAL_BRUTO_DECO) then
        
        ATUALIZA_STATUS_NEG(7,0);
        
        V_DS_MENSAGEM := 'As solicita��es de pagamento de indeniza��o possuem valor diferente do valor das declara��es de compromisso';
        INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
      end if;
      
      if (V_VL_IMPOSTO_RENDA != V_VL_IMPOSTO_RENDA_DECO) then
        ATUALIZA_STATUS_NEG(7,0);
        
        V_DS_MENSAGEM := 'O valor do imposto nas solicita��es de pagamento est�o diferentes do imposto nas declara��es de compromisso';
        INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
      end if;  
    end if;      
  END;

  PROCEDURE P_SEM_IPTU(P_ID_PRLS IN NUMBER) AS    
    V_DS_MENSAGEM PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
  BEGIN
    if (F_EXISTE_DOCUMENTO(182) = 0 and
        V_VL_DD_CONSTRUCAO_DECO > 0 and
          (F_EXISTE_DOCUMENTO(175) = 1 or
           F_EXISTE_DOCUMENTO(177) = 1 or
           F_EXISTE_DOCUMENTO(178) = 1 or
           F_EXISTE_DOCUMENTO(179) = 1 ))
    then      
      ATUALIZA_STATUS_NEG(13,0);
      
      V_DS_MENSAGEM := 'N�o foi inserido o documento comprovante de baixa do IPTU da posse';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'S', 'S');
    end if;
  END;

  PROCEDURE P_CERTIDAO_INT_TEOR(P_ID_PRLS IN NUMBER) AS
    V_DS_MENSAGEM PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
  BEGIN
    if (F_EXISTE_DOCUMENTO(177) = 1 or
        F_EXISTE_DOCUMENTO(178) = 1 or
        F_EXISTE_DOCUMENTO(175) = 1 or
        F_EXISTE_DOCUMENTO(170) = 1 or
        F_EXISTE_DOCUMENTO(179) = 1) and
       F_EXISTE_DOCUMENTO(162) = 0
    then
      ATUALIZA_STATUS_NEG(9,0);
      ATUALIZA_STATUS_NEG(10,0);
      ATUALIZA_STATUS_NEG(13,0);
      ATUALIZA_STATUS_NEG(17,0);
      
      V_DS_MENSAGEM := 'A certid�o inteiro teor n�o foi inserida no sistema';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end if;
  END;
  
  PROCEDURE P_CERTIDAO_NEG_DEBITO(P_ID_PRLS IN NUMBER) AS
    V_DS_MENSAGEM PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
  BEGIN
    if (F_EXISTE_DOCUMENTO(177) = 1 or
        F_EXISTE_DOCUMENTO(178) = 1 or
        F_EXISTE_DOCUMENTO(175) = 1 or
        F_EXISTE_DOCUMENTO(170) = 1 or
        F_EXISTE_DOCUMENTO(179) = 1) and
       F_EXISTE_DOCUMENTO(165) = 0
    then
      ATUALIZA_STATUS_NEG(9,0);
      ATUALIZA_STATUS_NEG(10,0);
      ATUALIZA_STATUS_NEG(13,0);
      ATUALIZA_STATUS_NEG(17,0);
      
      V_DS_MENSAGEM := 'A certid�o negativa de d�bito n�o foi inserida no sistema';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end if;
  END;

  PROCEDURE P_REC_ESCRITURA (P_ID_PRLS IN NUMBER) AS
    CT_RECIBO     number(5);
    V_DS_MENSAGEM PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
  BEGIN
    if (F_EXISTE_DOCUMENTO(177) = 1 or
        F_EXISTE_DOCUMENTO(178) = 1 or
        F_EXISTE_DOCUMENTO(175) = 1 or
        F_EXISTE_DOCUMENTO(179) = 1)
    then
      select count(*)
      into CT_RECIBO
      from  RECIBO_PAGAMENTO REPA,
            ARQUIVO_NEGOCIACAO ARNE
      where REPA.ARNE_SQ_ARQUIVO_NEGOCIACAO = ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO
      and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
      and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
      and REPA.TIPA_SQ_TIPO_PAGAMENTO = 1;
      
      if CT_RECIBO = 0 then
        ATUALIZA_STATUS_NEG(9,0);
        ATUALIZA_STATUS_NEG(10,0);
        ATUALIZA_STATUS_NEG(13,0);
      
        V_DS_MENSAGEM := 'N�o h� recibo de pagamento correspondente � escritura ou ao instrumento particular inserido(a) no sistema';
        INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
      end if;
    end if;
  END;

  PROCEDURE P_ESCRITURA_PUB_NAO_INSERIDA(P_ID_PRLS IN NUMBER) AS
    V_DS_MENSAGEM PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
  BEGIN
    if (F_EXISTE_DOCUMENTO(179) = 1 and
        F_EXISTE_DOCUMENTO(177) = 0 and
        F_EXISTE_DOCUMENTO(178) = 0)
    then
      ATUALIZA_STATUS_NEG(11,0);
      
      V_DS_MENSAGEM := 'A escritura p�blica de Aquisi��o ou Servid�o n�o foi inserida no sistema';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end if;
  END;

  PROCEDURE P_ESCRITURA_NAO_INSERIDA(P_ID_PRLS IN NUMBER) AS
    V_DS_MENSAGEM PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
  BEGIN
    if (F_EXISTE_DOCUMENTO(181) = 1 and
        F_EXISTE_DOCUMENTO(179) = 0 and
        F_EXISTE_DOCUMENTO(193) = 0)
    then
      ATUALIZA_STATUS_NEG(12,0);
      
      V_DS_MENSAGEM := 'O registro da escritura n�o foi inserido no sistema';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end if;
  END;
  
  PROCEDURE P_VALOR_NEG_PAGO(P_ID_PRLS IN NUMBER) AS
    V_DS_MENSAGEM         PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
    
    V_VL_TOTAL_PAGO       NUMBER(38,2);
    V_VL_LIMITE           NUMBER(38,2);
    V_VL_ACIMA_MARGEM     PROCESSO_LIBERACAO.PRLI_VL_ACIMA_MARGEM_NGCC%TYPE;
    V_TX_JUSTIFICATIVA    PROCESSO_LIBERACAO.PRLI_TX_JSTF_ACIMA_MARGEM_NGCC%TYPE;
  BEGIN
    V_VL_TOTAL_PAGO := F_TOTAL_PAGO(P_ID_PRLS);
    V_VL_LIMITE := V_TOTAL_BRUTO_SEPAV + (V_TOTAL_BRUTO_SEPAV * (V_ROW_MARGEM.MANE_PR_MARGEM_NEGOCIACAO/100));
    
    select PRLI_VL_ACIMA_MARGEM_NGCC, PRLI_TX_JSTF_ACIMA_MARGEM_NGCC
    into V_VL_ACIMA_MARGEM, V_TX_JUSTIFICATIVA
    from PROCESSO_LIBERACAO
    where PRLI_SQ_PROCESSO_LIBERACAO = 
      (select PRLI_SQ_PROCESSO_LIBERACAO
       from PROCESSO_LIBERACAO_SRVC_ENGR
       where PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS);
    
    if V_TOTAL_BRUTO_DECO > V_VL_LIMITE or V_VL_TOTAL_PAGO > V_VL_LIMITE
      and F_EXISTE_DOCUMENTO(168) = 0
      and V_TX_JUSTIFICATIVA is null
    then
      ATUALIZA_STATUS_NEG(9,0);
      ATUALIZA_STATUS_NEG(10,0);
      ATUALIZA_STATUS_NEG(13,0);
      
      V_DS_MENSAGEM := 'O valor negociado ou o valor pago do PL est� acima do valor limite estabelecido pela margem';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'S', 'S');        
    end if;    
    
    /* O valor negociado ou o valor pago do PL est� diferente do valor aprovado 
     pela comiss�o e desapropia��o de �reas */
    
    if V_TX_JUSTIFICATIVA is not null and 
      (V_TOTAL_BRUTO_DECO > V_VL_ACIMA_MARGEM) or
      (V_VL_TOTAL_PAGO > V_VL_ACIMA_MARGEM)
    then
      ATUALIZA_STATUS_NEG(9,0);
      ATUALIZA_STATUS_NEG(10,0);
      ATUALIZA_STATUS_NEG(13,0);
      
      V_DS_MENSAGEM := 'O valor negociado ou o valor pago do PL est� acima do aprovado pelo "Parecer Jur�dico para Complementa��o de Indeniza��o"';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'S', 'S'); 
    end if;
  END;
  
  PROCEDURE P_INTERFERENCIAS(P_ID_PRLS IN NUMBER) IS
    V_DS_MENSAGEM PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
  BEGIN
    if F_EXISTE_DOCUMENTO(164) = 1 and F_EXISTE_DOCUMENTO(169) = 0 then
      V_DS_MENSAGEM := '� necess�rio inserir a "Carta de Entrega de As Built" no sistema';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'S', 'S');
    end if;
  END;

  PROCEDURE P_MARGEM_NEGOCIACAO(P_ID_PRLS IN NUMBER) AS
    CT_ARQUIVO_MARGEM     number(5);
    V_DS_MENSAGEM PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
  BEGIN
    if V_EXISTE_MARGEM = 'S' then 
      select count(*)
      into CT_ARQUIVO_MARGEM
      from  ARQUIVO_MARGEM_NEGOCIACAO ARMN,
            RELATORIO_MARGEM_NEGOCIACAO REMN,         
            DOCUMENTO DOCU
      where ARMN.REMN_SQ_RELATORIO_MRGN_NGCC = REMN.REMN_SQ_RELATORIO_MRGN_NGCC
      and REMN.MANE_SQ_MARGEM_NEGOCIACAO = V_ROW_MARGEM.MANE_SQ_MARGEM_NEGOCIACAO    
      and ARMN.DOCU_SQ_DOCUMENTO = DOCU.DOCU_SQ_DOCUMENTO
      and DOCU.TIDO_SQ_TIPO_DOCUMENTO = 151
      and REMN_IN_APROVADO = 'S';
      
      if CT_ARQUIVO_MARGEM = 0 then
        V_DS_MENSAGEM := 'A margem de negocia��o '||V_ROW_MARGEM.MANE_NM_MARGEM_NEGOCIACAO||' n�o possui o documento DIP de Encaminhamento do Relat�rio com Margem';
        INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'N');
      end if;
      
      select count(*)
      into CT_ARQUIVO_MARGEM
      from  ARQUIVO_MARGEM_NEGOCIACAO ARMN,
            RELATORIO_MARGEM_NEGOCIACAO REMN,         
            DOCUMENTO DOCU
      where ARMN.REMN_SQ_RELATORIO_MRGN_NGCC = REMN.REMN_SQ_RELATORIO_MRGN_NGCC
      and REMN.MANE_SQ_MARGEM_NEGOCIACAO = V_ROW_MARGEM.MANE_SQ_MARGEM_NEGOCIACAO    
      and ARMN.DOCU_SQ_DOCUMENTO = DOCU.DOCU_SQ_DOCUMENTO
      and DOCU.TIDO_SQ_TIPO_DOCUMENTO = 152
      and REMN_IN_APROVADO = 'S';
      
      if CT_ARQUIVO_MARGEM = 0 then
        V_DS_MENSAGEM := 'A margem de negocia��o '||V_ROW_MARGEM.MANE_NM_MARGEM_NEGOCIACAO||' n�o possui o documento Parecer Jur�dico';
        INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'N');
      end if;
      
      select count(*)
      into CT_ARQUIVO_MARGEM
      from  ARQUIVO_MARGEM_NEGOCIACAO ARMN,
            RELATORIO_MARGEM_NEGOCIACAO REMN,
            DOCUMENTO DOCU
      where ARMN.REMN_SQ_RELATORIO_MRGN_NGCC = REMN.REMN_SQ_RELATORIO_MRGN_NGCC
      and REMN.MANE_SQ_MARGEM_NEGOCIACAO = V_ROW_MARGEM.MANE_SQ_MARGEM_NEGOCIACAO
      and ARMN.DOCU_SQ_DOCUMENTO = DOCU.DOCU_SQ_DOCUMENTO
      and DOCU.TIDO_SQ_TIPO_DOCUMENTO = 153
      and REMN_IN_APROVADO = 'S';
      
      if CT_ARQUIVO_MARGEM = 0 then
        V_DS_MENSAGEM := 'A margem de negocia��o '||V_ROW_MARGEM.MANE_NM_MARGEM_NEGOCIACAO||' n�o possui o documento "DIP de Solicita��o de Aprova��o da D.E."';
        INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'N');
      end if;
      
      select count(*)
      into CT_ARQUIVO_MARGEM
      from  ARQUIVO_MARGEM_NEGOCIACAO ARMN,
            RELATORIO_MARGEM_NEGOCIACAO REMN,
            DOCUMENTO DOCU
      where ARMN.REMN_SQ_RELATORIO_MRGN_NGCC = REMN.REMN_SQ_RELATORIO_MRGN_NGCC
      and REMN.MANE_SQ_MARGEM_NEGOCIACAO = V_ROW_MARGEM.MANE_SQ_MARGEM_NEGOCIACAO
      and ARMN.DOCU_SQ_DOCUMENTO = DOCU.DOCU_SQ_DOCUMENTO
      and DOCU.TIDO_SQ_TIPO_DOCUMENTO = 154
      and REMN_IN_APROVADO = 'S';
      
      if CT_ARQUIVO_MARGEM = 0 then
        V_DS_MENSAGEM := 'A margem de negocia��o '||V_ROW_MARGEM.MANE_NM_MARGEM_NEGOCIACAO||' n�o possui o documento "Ata de Aprova��o da DE"';
        INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'N');
      end if;
    end if;
  END;

  PROCEDURE P_PAGAMENTO_INDENIZACAO (P_ID_PRLS IN NUMBER) AS
    CT_RECIBO     number(5);
    V_VL_DOPA     number(38,2);
    V_DS_MENSAGEM PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
  BEGIN
    for reg in (select ITPA_NM_ITEM_PAGAMENTO
                from  FORMULARIO_PAGAMENTO FOPA,
                      ITEM_PAGAMENTO ITPA,                      
                      ARQUIVO_NEGOCIACAO ARNE
                where ITPA.FOPA_SQ_FORMULARIO_PAGAMENTO = FOPA.FOPA_SQ_FORMULARIO_PAGAMENTO
                and ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO = FOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO
                and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
                and FOPA.TIPA_SQ_TIPO_PAGAMENTO = 1
                and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
                and not exists (select 'x' from DOCUMENTO_PAGAMENTO DOPA
                                where DOPA.ITPA_SQ_ITEM_PAGAMENTO = ITPA.ITPA_SQ_ITEM_PAGAMENTO))
    loop
      ATUALIZA_STATUS_NEG(8,0);
      V_DS_MENSAGEM := 'N�o foi anexado documento de pagamento de indeniza��o para o item de pagamento '||REG.ITPA_NM_ITEM_PAGAMENTO;
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end loop;
    
    for reg in (select DOPA.DOPA_DS_REFERENCIA_PAGAMENTO
                from DOCUMENTO_PAGAMENTO DOPA,
                     ARQUIVO_NEGOCIACAO ARNE
                where DOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO = ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO
                and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
                and DOPA.TIPA_SQ_TIPO_PAGAMENTO = 1
                and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
                and DOPA.ITPA_SQ_ITEM_PAGAMENTO is null)
    loop
      ATUALIZA_STATUS_NEG(8,0);
      V_DS_MENSAGEM := 'O documento de pagamento de indeniza��o '||REG.DOPA_DS_REFERENCIA_PAGAMENTO||' n�o est� associado a uma solicita��o de pagamento';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end loop;
    
    for reg in (select DOPA.DOPA_DS_REFERENCIA_PAGAMENTO
                from DOCUMENTO_PAGAMENTO DOPA,
                     ARQUIVO_NEGOCIACAO ARNE
                where DOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO = ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO
                and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
                and DOPA.TIPA_SQ_TIPO_PAGAMENTO = 1
                and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
                and DOPA.REPA_SQ_RECIBO_PAGAMENTO is null)
    loop
      ATUALIZA_STATUS_NEG(9,0);
      ATUALIZA_STATUS_NEG(10,0);
      ATUALIZA_STATUS_NEG(13,0);
      V_DS_MENSAGEM := 'O documento de pagamento de indeniza��o '||REG.DOPA_DS_REFERENCIA_PAGAMENTO||' n�o possui recibo/comprovante de pagamento/dep�sito';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end loop;
    
    for reg in (select DOPA.DOPA_DS_REFERENCIA_PAGAMENTO
                from DOCUMENTO_PAGAMENTO DOPA,
                     ITEM_PAGAMENTO ITPA,
                     ARQUIVO_NEGOCIACAO ARNE
                where DOPA.ITPA_SQ_ITEM_PAGAMENTO = ITPA.ITPA_SQ_ITEM_PAGAMENTO
                and DOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO = ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO
                and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
                and DOPA.TIPA_SQ_TIPO_PAGAMENTO = 1
                and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
                and ITPA.ITPA_VL_LIQUIDO != DOPA.DOPA_VL_DOCUMENTO_PAGAMENTO) 
    loop
      ATUALIZA_STATUS_NEG(8,0);
      V_DS_MENSAGEM := 'O valor do documento de pagamento de indeniza��o '||REG.DOPA_DS_REFERENCIA_PAGAMENTO||' est� diferente do valor l�quido na solicita��o de pagamento correspondente';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end loop;
    
    for reg in (select REPA.REPA_SQ_RECIBO_PAGAMENTO, REPA.REPA_VL_RECIBO
                from  RECIBO_PAGAMENTO REPA,
                      ARQUIVO_NEGOCIACAO ARNE
                where ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO = REPA.ARNE_SQ_ARQUIVO_NEGOCIACAO
                and REPA.TIPA_SQ_TIPO_PAGAMENTO = 1
                and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
                and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS)
    loop
      select count(*)
      into CT_RECIBO
      from DOCUMENTO_PAGAMENTO DOPA
      where DOPA.REPA_SQ_RECIBO_PAGAMENTO = REG.REPA_SQ_RECIBO_PAGAMENTO;
      
      if CT_RECIBO = 0 then
        ATUALIZA_STATUS_NEG(9,0);
        ATUALIZA_STATUS_NEG(10,0);
        ATUALIZA_STATUS_NEG(13,0);
        
        V_DS_MENSAGEM := 'O recibo/comprovante de pagamento de indeniza��o n�o est� associado a um documento de pagamento';
      else
        select sum(nvl(DOPA.DOPA_VL_DOCUMENTO_PAGAMENTO,0))
        into V_VL_DOPA
        from DOCUMENTO_PAGAMENTO DOPA, ARQUIVO_NEGOCIACAO ARNE
        where ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO = DOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO
        and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
        and DOPA.REPA_SQ_RECIBO_PAGAMENTO = REG.REPA_SQ_RECIBO_PAGAMENTO;
        
        if (V_VL_DOPA != REG.REPA_VL_RECIBO) then
          ATUALIZA_STATUS_NEG(9,0);
          ATUALIZA_STATUS_NEG(10,0);
          ATUALIZA_STATUS_NEG(13,0);
        
          V_DS_MENSAGEM := 'O recibo/comprovante de pagamento de indeniza��o est� diferente dos valores dos documentos de pagamento correspondentes';
          INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
        end if;
      end if;
      
    end loop;
  END;
  
  PROCEDURE P_PAGAMENTO_CONTRATO_CONV (P_ID_PRLS IN NUMBER) AS
    CT_RECIBO     number(5);
    V_VL_DOPA     number(38,2);
    V_DS_MENSAGEM PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
  BEGIN
    for reg in (select ITPA_NM_ITEM_PAGAMENTO
                from  FORMULARIO_PAGAMENTO FOPA,
                      ITEM_PAGAMENTO ITPA,                      
                      ARQUIVO_NEGOCIACAO ARNE
                where ITPA.FOPA_SQ_FORMULARIO_PAGAMENTO = FOPA.FOPA_SQ_FORMULARIO_PAGAMENTO
                and ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO = FOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO
                and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
                and FOPA.TIPA_SQ_TIPO_PAGAMENTO = 2
                and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
                and not exists (select 'x' from DOCUMENTO_PAGAMENTO DOPA, ARQUIVO_NEGOCIACAO ARNED
                                where DOPA.ITPA_SQ_ITEM_PAGAMENTO = ITPA.ITPA_SQ_ITEM_PAGAMENTO
                                and ARNED.ARNE_SQ_ARQUIVO_NEGOCIACAO = DOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO
                                and ARNED.SIDO_SQ_SITUACAO_DOCUMENTO = 2))
    loop
      ATUALIZA_STATUS_NEG(15,0);
      V_DS_MENSAGEM := 'N�o foi anexado documento de pagamento de conv�nio/contrato para o item de pagamento '||REG.ITPA_NM_ITEM_PAGAMENTO;
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end loop;
    
    for reg in (select DOPA.DOPA_DS_REFERENCIA_PAGAMENTO
                from DOCUMENTO_PAGAMENTO DOPA,
                     ARQUIVO_NEGOCIACAO ARNE
                where DOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO = ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO
                and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
                and DOPA.TIPA_SQ_TIPO_PAGAMENTO = 2
                and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
                and DOPA.ITPA_SQ_ITEM_PAGAMENTO is null)
    loop
      ATUALIZA_STATUS_NEG(15,0);
      V_DS_MENSAGEM := 'O documento de pagamento de conv�nio/contrato '||REG.DOPA_DS_REFERENCIA_PAGAMENTO||' n�o est� associado a uma solicita��o de pagamento';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end loop;
    
    for reg in (select DOPA.DOPA_DS_REFERENCIA_PAGAMENTO
                from DOCUMENTO_PAGAMENTO DOPA,
                     ARQUIVO_NEGOCIACAO ARNE
                where DOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO = ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO
                and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
                and DOPA.TIPA_SQ_TIPO_PAGAMENTO = 2
                and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
                and DOPA.REPA_SQ_RECIBO_PAGAMENTO is null)
    loop
      ATUALIZA_STATUS_NEG(15,0);      
      V_DS_MENSAGEM := 'O documento de pagamento de conv�nio/contrato '||REG.DOPA_DS_REFERENCIA_PAGAMENTO||' n�o possui recibo/comprovante de pagamento/dep�sito';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end loop;
    
    for reg in (select DOPA.DOPA_DS_REFERENCIA_PAGAMENTO
                from DOCUMENTO_PAGAMENTO DOPA,
                     ITEM_PAGAMENTO ITPA,
                     ARQUIVO_NEGOCIACAO ARNE
                where DOPA.ITPA_SQ_ITEM_PAGAMENTO = ITPA.ITPA_SQ_ITEM_PAGAMENTO
                and DOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO = ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO
                and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
                and DOPA.TIPA_SQ_TIPO_PAGAMENTO = 2
                and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
                and ITPA.ITPA_VL_LIQUIDO != DOPA.DOPA_VL_DOCUMENTO_PAGAMENTO) 
    loop
      ATUALIZA_STATUS_NEG(15,0);
      V_DS_MENSAGEM := 'O valor do documento de pagamento de conv�nio/contrato '||REG.DOPA_DS_REFERENCIA_PAGAMENTO||' est� diferente do valor l�quido na solicita��o de pagamento correspondente';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end loop;
    
    for reg in (select REPA.REPA_SQ_RECIBO_PAGAMENTO, REPA.REPA_VL_RECIBO
                from  RECIBO_PAGAMENTO REPA,
                      ARQUIVO_NEGOCIACAO ARNE
                where ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO = REPA.ARNE_SQ_ARQUIVO_NEGOCIACAO
                and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
                and REPA.TIPA_SQ_TIPO_PAGAMENTO = 2
                and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2)
    loop
      select count(*)
      into CT_RECIBO
      from DOCUMENTO_PAGAMENTO DOPA
      where DOPA.REPA_SQ_RECIBO_PAGAMENTO = REG.REPA_SQ_RECIBO_PAGAMENTO;
      
      if CT_RECIBO = 0 then
        ATUALIZA_STATUS_NEG(15,0);
        
        V_DS_MENSAGEM := 'O recibo/comprovante de pagamento de conv�nio/contrato n�o est� associado a um documento de pagamento';
        INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
      else
        select sum(nvl(DOPA.DOPA_VL_DOCUMENTO_PAGAMENTO,0))
        into V_VL_DOPA
        from DOCUMENTO_PAGAMENTO DOPA, ARQUIVO_NEGOCIACAO ARNE
        where ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO = DOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO
        and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
        and DOPA.REPA_SQ_RECIBO_PAGAMENTO = REG.REPA_SQ_RECIBO_PAGAMENTO;
        
        if (V_VL_DOPA != REG.REPA_VL_RECIBO) then
          ATUALIZA_STATUS_NEG(15,0);
          
          V_DS_MENSAGEM := 'O recibo/comprovante de pagamento de conv�nio/contrato n�o est� diferente dos valores dos documentos de pagamento correspondentes';
          INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
        end if;
      end if;
      
    end loop;
  END;

  PROCEDURE P_PAGAMENTO_TODOS (P_ID_PRLS IN NUMBER) AS
    CT_RECIBO     number(5);
    V_VL_DOPA     number(38,2);
    V_DS_MENSAGEM PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
  BEGIN
    for reg in (select ITPA_NM_ITEM_PAGAMENTO, TIPA_NM_TIPO_PAGAMENTO
                from  FORMULARIO_PAGAMENTO FOPA,
                      ITEM_PAGAMENTO ITPA,
                      TIPO_PAGAMENTO TIPA,
                      ARQUIVO_NEGOCIACAO ARNE
                where ITPA.FOPA_SQ_FORMULARIO_PAGAMENTO = FOPA.FOPA_SQ_FORMULARIO_PAGAMENTO
                and ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO = FOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO
                and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS                
                and TIPA.TIPA_SQ_TIPO_PAGAMENTO = FOPA.TIPA_SQ_TIPO_PAGAMENTO
                and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
                and not exists (select 'x' from DOCUMENTO_PAGAMENTO DOPA
                                where DOPA.ITPA_SQ_ITEM_PAGAMENTO = ITPA.ITPA_SQ_ITEM_PAGAMENTO))
    loop      
      V_DS_MENSAGEM := 'N�o foi anexado documento de pagamento para o item de pagamento '||REG.ITPA_NM_ITEM_PAGAMENTO||' do tipo '||REG.TIPA_NM_TIPO_PAGAMENTO;
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end loop;
    
    for reg in (select DOPA.DOPA_DS_REFERENCIA_PAGAMENTO
                from DOCUMENTO_PAGAMENTO DOPA,
                     ARQUIVO_NEGOCIACAO ARNE
                where DOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO = ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO
                and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
                and DOPA.TIPA_SQ_TIPO_PAGAMENTO not in (1,2)
                and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
                and DOPA.ITPA_SQ_ITEM_PAGAMENTO is null)
    loop
      
      V_DS_MENSAGEM := 'O documento de pagamento '||REG.DOPA_DS_REFERENCIA_PAGAMENTO||' n�o est� associado a uma solicita��o de pagamento';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end loop;
    
    for reg in (select DOPA.DOPA_DS_REFERENCIA_PAGAMENTO
                from DOCUMENTO_PAGAMENTO DOPA,
                     ARQUIVO_NEGOCIACAO ARNE
                where DOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO = ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO
                and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
                and DOPA.TIPA_SQ_TIPO_PAGAMENTO not in (1,2)
                and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
                and DOPA.REPA_SQ_RECIBO_PAGAMENTO is null)
    loop      
      V_DS_MENSAGEM := 'O documento de pagamento '||REG.DOPA_DS_REFERENCIA_PAGAMENTO||' n�o possui recibo/comprovante de pagamento/dep�sito';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end loop;
    
    for reg in (select DOPA.DOPA_DS_REFERENCIA_PAGAMENTO
                from DOCUMENTO_PAGAMENTO DOPA,
                     ITEM_PAGAMENTO ITPA,
                     ARQUIVO_NEGOCIACAO ARNE
                where DOPA.ITPA_SQ_ITEM_PAGAMENTO = ITPA.ITPA_SQ_ITEM_PAGAMENTO
                and DOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO = ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO
                and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
                and DOPA.TIPA_SQ_TIPO_PAGAMENTO not in (1,2)
                and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
                and ITPA.ITPA_VL_LIQUIDO != DOPA.DOPA_VL_DOCUMENTO_PAGAMENTO) 
    loop      
      V_DS_MENSAGEM := 'O valor do documento de pagamento '||REG.DOPA_DS_REFERENCIA_PAGAMENTO||' est� diferente do valor l�quido na solicita��o de pagamento correspondente';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end loop;
    
    for reg in (select REPA.REPA_SQ_RECIBO_PAGAMENTO, REPA.REPA_VL_RECIBO
                from  RECIBO_PAGAMENTO REPA,
                      ARQUIVO_NEGOCIACAO ARNE
                where ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO = REPA.ARNE_SQ_ARQUIVO_NEGOCIACAO
                and REPA.TIPA_SQ_TIPO_PAGAMENTO not in (1,2)
                and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2)
    loop
      select count(*)
      into CT_RECIBO
      from DOCUMENTO_PAGAMENTO DOPA
      where DOPA.REPA_SQ_RECIBO_PAGAMENTO = REG.REPA_SQ_RECIBO_PAGAMENTO;
      
      if CT_RECIBO = 0 then       
        
        V_DS_MENSAGEM := 'O recibo/comprovante de pagamento n�o est� associado a um documento de pagamento';
        INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
      else
        select sum(nvl(DOPA.DOPA_VL_DOCUMENTO_PAGAMENTO,0))
        into V_VL_DOPA
        from DOCUMENTO_PAGAMENTO DOPA, ARQUIVO_NEGOCIACAO ARNE
        where ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO = DOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO
        and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
        and DOPA.REPA_SQ_RECIBO_PAGAMENTO = REG.REPA_SQ_RECIBO_PAGAMENTO;
        
        if (V_VL_DOPA != REG.REPA_VL_RECIBO) then          
        
          V_DS_MENSAGEM := 'O recibo/comprovante de pagamento est� diferente dos valores dos documentos de pagamento correspondentes';
          INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
        end if;
      end if;
      
    end loop;
  END;

  FUNCTION F_EXISTE_DOCUMENTO(P_ID_TIPO_DOCUMENTO IN NUMBER) RETURN NUMBER AS
    V_RETORNO NUMBER(1) := 0;
  BEGIN
    if T_DOCUMENTOS is null or T_DOCUMENTOS.count=0 then
      return 0;
    end if;
    
    for i in T_DOCUMENTOS.FIRST..T_DOCUMENTOS.LAST loop    
      if T_DOCUMENTOS(I).ID_TIPO_DOCUMENTO = P_ID_TIPO_DOCUMENTO THEN
        return T_DOCUMENTOS(I).EXISTE_DOCUMENTO;
      end if;
    end loop;
  
    return V_RETORNO;
  END;

  PROCEDURE ATUALIZA_STATUS_NEG(P_ID_STATUS IN NUMBER, P_PERMITE_STATUS NUMBER) IS
    V_ID_STATUS   SITUACAO_NEGOCIACAO.SINE_SQ_SITUACAO_NEGOCIACAO%TYPE;    
  BEGIN
    if(T_AVALIA_STATUS_NEG.EXISTS(P_ID_STATUS)) then
      T_AVALIA_STATUS_NEG(P_ID_STATUS).VERIFICACAO_PENDENCIA := P_PERMITE_STATUS;
            
      if T_AVALIA_STATUS_NEG(P_ID_STATUS).VERIFICACAO_STATUS is null then
        T_AVALIA_STATUS_NEG(P_ID_STATUS).ID_STATUS := P_ID_STATUS;
        T_AVALIA_STATUS_NEG(P_ID_STATUS).VERIFICACAO_STATUS := P_PERMITE_STATUS;
      end if;  
      
      if P_PERMITE_STATUS = 0 then
        --for i in T_AVALIA_STATUS_NEG.FIRST..T_AVALIA_STATUS_NEG.LAST loop
        V_ID_STATUS := T_AVALIA_STATUS_NEG.FIRST;
        
        while V_ID_STATUS is not null loop
          if T_AVALIA_STATUS_NEG(V_ID_STATUS).ID_STATUS > P_ID_STATUS then
            T_AVALIA_STATUS_NEG(V_ID_STATUS).VERIFICACAO_STATUS := 0;        
          end if;
          V_ID_STATUS := T_AVALIA_STATUS_NEG.NEXT(V_ID_STATUS);
        end loop;
      end if;
    end if;
  END;

  PROCEDURE ATUALIZA_LISTA_DOCUMENTOS(P_ID_PRLS IN NUMBER) AS
      CT_ARNE         NUMBER(20);
      V_REG_DOCUMENTO REG_EXISTE_DOCT; 
      V_EXISTE_DOCT   NUMBER(1);
      I               NUMBER := 1;
      CT_T_DOCT       NUMBER(5);
  BEGIN
  
    T_DOCUMENTOS := T_EXISTE_DOCT();
  
    for REG in (select TIDO_SQ_TIPO_DOCUMENTO,
                       tido.sutd_sq_subcategoria_tipo_doct
                from TIPO_DOCUMENTO TIDO,
                     SUBCATEGORIA_TIPO_DOCUMENTO SUTD,
                     CATEGORIA_TIPO_DOCUMENTO CATD
                where catd.catd_sq_categoria_tipo_doct = 8 /* Categoria de Negocia��o */
                and sutd.catd_sq_categoria_tipo_doct = catd.catd_sq_categoria_tipo_doct                
                and tido.sutd_sq_subcategoria_tipo_doct = sutd.sutd_sq_subcategoria_tipo_doct)
    loop
    
      if (REG.sutd_sq_subcategoria_tipo_doct != 36) then      
        select count(*)
        into CT_ARNE
        from ARQUIVO_NEGOCIACAO ARNE, DOCUMENTO DOCU
        where ARNE.DOCU_SQ_DOCUMENTO = DOCU.DOCU_SQ_DOCUMENTO
        and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
        and DOCU.TIDO_SQ_TIPO_DOCUMENTO = REG.TIDO_SQ_TIPO_DOCUMENTO
        and SIDO_SQ_SITUACAO_DOCUMENTO = 2; /* Apenas Documentos Ativos */         
      else            
        select count(*)
        into CT_ARNE
        from ARQUIVO_ACAO_JUDICIAL ARAJ, DOCUMENTO DOCU, acao_judicial acju
        where ARAJ.DOCU_SQ_DOCUMENTO = DOCU.DOCU_SQ_DOCUMENTO
        and acju.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
        and acju.acju_sq_acao_judicial = araj.acju_sq_acao_judicial        
        and DOCU.TIDO_SQ_TIPO_DOCUMENTO = REG.TIDO_SQ_TIPO_DOCUMENTO
        and SIDO_SQ_SITUACAO_DOCUMENTO = 2; /* Apenas Documentos Ativos de Acao */    
      end if;
      
      if (CT_ARNE >0) then
        V_EXISTE_DOCT := 1;
      else
        V_EXISTE_DOCT := 0;
      end if;
      
      V_REG_DOCUMENTO := REG_EXISTE_DOCT(REG.TIDO_SQ_TIPO_DOCUMENTO, V_EXISTE_DOCT);
      
      T_DOCUMENTOS.extend(1);
      
      T_DOCUMENTOS(I) := V_REG_DOCUMENTO;
      I := I+1;
      
    end loop;
  END;
  
  PROCEDURE CARREGAR_VALORES_SEPAV(P_ID_PRLS IN NUMBER) IS
  BEGIN
    select AVST_VL_TOTAL_LAUDO, 
           AVST_VL_TAXA_PRIMARIA_INDC,
           AVST_VL_DANO_DIRT_TERRA_NUA,
           AVST_VL_DANO_DIRT_CONSTRUCAO,
           AVST_VL_DANO_DIRT_EQUIPAMENTO,
           AVST_VL_DANO_DIRT_VEGETACAO,
           AVST_VL_LUCRO_CSNT_VEGETACAO,
           AVST_VL_DANO_DIRT_ATVD_ECNC,
           AVST_VL_LUCRO_CSNT_ATVD_ECNC
      into V_TOTAL_BRUTO_SEPAV, 
           V_VL_TPI,
           V_VL_DD_TERRA_NUA,
           V_VL_DD_CONSTRUCAO,
           V_VL_DD_EQUIPAMENTO,
           V_VL_DD_VEGETACAO,
           V_VL_LC_VEGETACAO,
           V_VL_DD_ATVD_ECNC,
           V_VL_LC_ATVD_ECNC
      from AVALIACAO_SEPAV_TOTAL AVST,
           PROCESSO_LIBERACAO_SRVC_ENGR PRLS
      where PRLS.PRLI_SQ_PROCESSO_LIBERACAO = AVST.PRLI_SQ_PROCESSO_LIBERACAO
      and PRLS.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS;
  END;
  
  PROCEDURE CARREGAR_VALORES_DECO(P_ID_PRLS IN NUMBER) IS
  BEGIN
    select nvl(sum(DECO_VL_TOTAL_BRUTO),0), 
           nvl(sum(DECO_VL_TAXA_PRIMARIA_INDC),0),  
           nvl(sum(DECO_VL_DANO_DIRT_TERRA_NUA),0),
           nvl(sum(DECO_VL_DANO_DIRT_CONSTRUCAO),0),
           nvl(sum(DECO_VL_DANO_DIRT_VEGETACAO),0),
           nvl(sum(DECO_VL_DANO_DIRT_ATVD_ECNC),0),
           nvl(sum(DECO_VL_DANO_DIRT_EQUIPAMENTO),0),
           nvl(sum(DECO_VL_LUCRO_CSNT_VEGETACAO),0),
           nvl(sum(DECO_VL_LUCRO_CSNT_ATVD_ECNC),0),
           nvl(sum(DECO_VL_IMPOSTO_RENDA),0)
      into V_TOTAL_BRUTO_DECO, 
           V_VL_TPI_DECO,
           V_VL_DD_TERRA_NUA_DECO,
           V_VL_DD_CONSTRUCAO_DECO,
           V_VL_DD_VEGETACAO_DECO,
           V_VL_DD_ATVD_ECNC_DECO,
           V_VL_DD_EQUIPAMENTO_DECO,
           V_VL_LC_VEGETACAO_DECO,
           V_VL_LC_ATVD_ECNC_DECO,
           V_VL_IMPOSTO_RENDA_DECO
      from  DECLARACAO_COMPROMISSO DECO,
            ARQUIVO_NEGOCIACAO ARNE,
            DOCUMENTO DOCU
      where DECO.ARNE_SQ_ARQUIVO_NEGOCIACAO = ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO
      and DOCU.DOCU_SQ_DOCUMENTO = ARNE.DOCU_SQ_DOCUMENTO
      and DOCU.TIDO_SQ_TIPO_DOCUMENTO = 171
      and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
      and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS;
  END;
  
  PROCEDURE CARREGAR_MARGEM(P_ID_PRLS IN NUMBER) IS
  BEGIN
    select MANE.*
      into V_ROW_MARGEM
      from MARGEM_NEGOCIACAO MANE,
           MARGEM_NGCC_PROCESSO_LBRC MANP,
           PROCESSO_LIBERACAO_SRVC_ENGR PRLS
      where MANE.MANE_SQ_MARGEM_NEGOCIACAO = MANP.MANE_SQ_MARGEM_NEGOCIACAO
      and MANP.PRLI_SQ_PROCESSO_LIBERACAO = PRLS.PRLI_SQ_PROCESSO_LIBERACAO
      and PRLS.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS;
      
      V_EXISTE_MARGEM := 'S';
  EXCEPTION when NO_DATA_FOUND then
    V_EXISTE_MARGEM := 'N';
  END;  
  
   /* IN�CIO A��O JUDICIAL */
  PROCEDURE P_ACAO_JUDICIAL(P_ID_PRLS IN NUMBER) IS
    V_EX_DOC_185  number := F_EXISTE_DOCUMENTO(185);
    V_EX_DOC_186  number := F_EXISTE_DOCUMENTO(186);
    V_EX_DOC_187  number := F_EXISTE_DOCUMENTO(187);
    V_EX_DOC_188  number := F_EXISTE_DOCUMENTO(188);
    V_EX_DOC_192  number := F_EXISTE_DOCUMENTO(192);
    V_EX_DOC_193  number := F_EXISTE_DOCUMENTO(193);
    
    CT_TIPO_ACAO_JUDICIAL number(5); 
    CT_SOLICITACAO        number(5);
    CT_DUP                number(5);
    
    V_DS_MENSAGEM PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
    
  BEGIN
    if V_EX_DOC_185 = 1 then
      select count(ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO)
      into CT_TIPO_ACAO_JUDICIAL
      from  ATRIBUTO_DOCUMENTO ATDO,
            ATRIBUTO_TIPO_DOCUMENTO ATTD,
            DOCUMENTO DOCU,
            ARQUIVO_NEGOCIACAO ARNE
      where ARNE.DOCU_SQ_DOCUMENTO = DOCU.DOCU_SQ_DOCUMENTO
      and DOCU.TIDO_SQ_TIPO_DOCUMENTO = ATTD.TIDO_SQ_TIPO_DOCUMENTO
      and ATDO.DOCU_SQ_DOCUMENTO = DOCU.DOCU_SQ_DOCUMENTO
      and ATTD.ATTD_SQ_ATRIBUTO_TIPO_DOCT = ATDO.ATTD_SQ_ATRIBUTO_TIPO_DOCT
      and ATTD.ATTD_SQ_ATRIBUTO_TIPO_DOCT = 117
      and DOCU.TIDO_SQ_TIPO_DOCUMENTO = 185
      and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
      and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
      and ATDO_TX_ATRIBUTO_DOCUMENTO in ('A��o de Desapropia��o','A��o de Institui��o de Servid�o de passagem');
    end if;
  
    select count(*)
    into CT_DUP
    from ARQUIVO_OBRA AROB, DOCUMENTO DOCU
    where DOCU.DOCU_SQ_DOCUMENTO = AROB.DOCU_SQ_DOCUMENTO
    and OBRA_SQ_OBRA = V_ROW_MARGEM.OBRA_SQ_OBRA
    and DOCU.TIDO_SQ_TIPO_DOCUMENTO = 205;
  
    if CT_DUP = 0 and
      (V_EX_DOC_185 = 1 or
       V_EX_DOC_186 = 1 or
       V_EX_DOC_187 = 1 or
       V_EX_DOC_188 = 1 or
       V_EX_DOC_192 = 1 or
       V_EX_DOC_193 = 1) 
    then
      V_DS_MENSAGEM := 'O Decreto de Utilidade P�blica n�o foi inserido para esta Obra';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'N');
    end if;
    
    if V_EX_DOC_185  = 0 and  
      (V_EX_DOC_186 = 1 or
       V_EX_DOC_187 = 1 or
       V_EX_DOC_188 = 1 or
       V_EX_DOC_192 = 1 or
       V_EX_DOC_193 = 1)
    then
      V_DS_MENSAGEM := 'O DIP de Encaminhamento do Dossi� para a��o judicial n�o foi inserido no sistema';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'N');
    end if;
    
    if V_EX_DOC_186 = 0 and
      (V_EX_DOC_188 = 1 or
       V_EX_DOC_192 = 1 or
       V_EX_DOC_193 = 1)
    then
      ATUALIZA_STATUS_ACJ(4,0);
      V_DS_MENSAGEM := 'O documento de "Cita��o" da a��o judicial n�o foi inserido no sistema';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end if;
    
    if V_EX_DOC_187 = 0 and 
       V_EX_DOC_185 = 1 and
       (V_EX_DOC_188 = 1 or
        V_EX_DOC_192 = 1 or
        V_EX_DOC_193 = 1)
    then
      if CT_TIPO_ACAO_JUDICIAL > 0 then
        ATUALIZA_STATUS_ACJ(4,0);
        
        V_DS_MENSAGEM := 'O Mandado de Imiss�o na posse n�o foi inserido no sistema';
        INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
      end if;
    end if;
    
    if (V_EX_DOC_187 = 1 or
        V_EX_DOC_192 = 1 or
        V_EX_DOC_193 = 1) and
        V_EX_DOC_185 = 1 and
       CT_TIPO_ACAO_JUDICIAL > 0 
    then
      select count(*) 
      into CT_SOLICITACAO
      from  FORMULARIO_PAGAMENTO FOPA,
            ARQUIVO_NEGOCIACAO ARNE
      where ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO = FOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO
      and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
      and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
      and FOPA.TIPA_SQ_TIPO_PAGAMENTO = 3;
      
      if CT_SOLICITACAO = 0 then
        ATUALIZA_STATUS_ACJ(4,0);
        V_DS_MENSAGEM := 'A solicita��o de pagamento para dep�sito em ju�zo n�o foi inserida no sistema';
        INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
      end if;
    end if;
    
    if V_EX_DOC_188 = 0 and V_EX_DOC_185 = 1 and
       CT_TIPO_ACAO_JUDICIAL > 0  and
       (V_EX_DOC_192 = 1 or V_EX_DOC_193 = 1)
    then
      ATUALIZA_STATUS_ACJ(4,0);
      V_DS_MENSAGEM := 'O Auto de Imiss�o na posse n�o foi inserido no sistema';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end if;
    
    if V_EX_DOC_192 = 0 and V_EX_DOC_193 = 1 then
      ATUALIZA_STATUS_ACJ(5,0);
      V_DS_MENSAGEM := 'A carta de senten�a n�o foi inserida no sistema';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end if;
  END;
  
  PROCEDURE P_CONSTRUCAO_ACAO(P_ID_PRLS IN NUMBER) IS
    V_DS_MENSAGEM PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
  BEGIN
    if (F_EXISTE_DOCUMENTO(187) = 1 or
        F_EXISTE_DOCUMENTO(192) = 1 or
        F_EXISTE_DOCUMENTO(193) = 1) and
       ((F_EXISTE_DOCUMENTO(177) = 0 or
         F_EXISTE_DOCUMENTO(178) = 0 or
         F_EXISTE_DOCUMENTO(175) = 0) or
        (V_VL_DD_CONSTRUCAO_DECO = 0 and V_VL_DD_CONSTRUCAO > 0))
    then
      --ATUALIZA_STATUS_NEG(1,0);
      --ATUALIZA_STATUS_NEG(2,0);
      ATUALIZA_STATUS_NEG(3,0);
      ATUALIZA_STATUS_NEG(4,0);
      ATUALIZA_STATUS_NEG(5,1);
      ATUALIZA_STATUS_NEG(6,0);
      
      V_DS_MENSAGEM := ' As constru��es do PL liberado por a��o n�o foram negociadas';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'S', 'S');
      
    end if;
  END;
  
  PROCEDURE P_PAGAMENTO_ACAO_JUDICIAL (P_ID_PRLS IN NUMBER) AS
    CT_RECIBO     number(5);
    V_VL_DOPA     number(38,2);
    V_DS_MENSAGEM PENDENCIA_PRCS_SRVC_NEGOCIACAO.PEPS_TX_PENDENCIA%TYPE;
  BEGIN
    for reg in (select ITPA_NM_ITEM_PAGAMENTO
                from  FORMULARIO_PAGAMENTO FOPA,
                      ITEM_PAGAMENTO ITPA,                      
                      ARQUIVO_NEGOCIACAO ARNE
                where ITPA.FOPA_SQ_FORMULARIO_PAGAMENTO = FOPA.FOPA_SQ_FORMULARIO_PAGAMENTO
                and ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO = FOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO
                and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
                and FOPA.TIPA_SQ_TIPO_PAGAMENTO in (3,4)
                and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
                and not exists (select 'x' from DOCUMENTO_PAGAMENTO DOPA
                                where DOPA.ITPA_SQ_ITEM_PAGAMENTO = ITPA.ITPA_SQ_ITEM_PAGAMENTO))
    loop
      ATUALIZA_STATUS_ACJ(4,0);
      ATUALIZA_STATUS_ACJ(5,0);
      ATUALIZA_STATUS_ACJ(6,0);
      
      V_DS_MENSAGEM := 'N�o foi anexado documento de pagamento de dep�sito em ju�zo/custas processuais para o item de pagamento '||REG.ITPA_NM_ITEM_PAGAMENTO;
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end loop;
    
    for reg in (select DOPA.DOPA_DS_REFERENCIA_PAGAMENTO
                from DOCUMENTO_PAGAMENTO DOPA,
                     ARQUIVO_NEGOCIACAO ARNE
                where DOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO = ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO
                and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
                and DOPA.TIPA_SQ_TIPO_PAGAMENTO in (3,4)
                and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
                and DOPA.ITPA_SQ_ITEM_PAGAMENTO is null)
    loop
      ATUALIZA_STATUS_ACJ(4,0);
      ATUALIZA_STATUS_ACJ(5,0);
      ATUALIZA_STATUS_ACJ(6,0);
      
      V_DS_MENSAGEM := 'O documento de pagamento de dep�sito em ju�zo/custas processuais '||REG.DOPA_DS_REFERENCIA_PAGAMENTO||' n�o est� associado a uma solicita��o de pagamento';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end loop;
    
    for reg in (select DOPA.DOPA_DS_REFERENCIA_PAGAMENTO
                from DOCUMENTO_PAGAMENTO DOPA,
                     ARQUIVO_NEGOCIACAO ARNE
                where DOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO = ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO
                and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
                and DOPA.TIPA_SQ_TIPO_PAGAMENTO in (3,4)
                and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
                and DOPA.REPA_SQ_RECIBO_PAGAMENTO is null)
    loop
      ATUALIZA_STATUS_ACJ(4,0);
      ATUALIZA_STATUS_ACJ(5,0);
      ATUALIZA_STATUS_ACJ(6,0);     
      
      V_DS_MENSAGEM := 'O documento de pagamento de dep�sito em ju�zo/custas processuais '||REG.DOPA_DS_REFERENCIA_PAGAMENTO||' n�o possui recibo/comprovante de pagamento/dep�sito';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end loop;
    
    for reg in (select DOPA.DOPA_DS_REFERENCIA_PAGAMENTO
                from DOCUMENTO_PAGAMENTO DOPA,
                     ITEM_PAGAMENTO ITPA,
                     ARQUIVO_NEGOCIACAO ARNE
                where DOPA.ITPA_SQ_ITEM_PAGAMENTO = ITPA.ITPA_SQ_ITEM_PAGAMENTO
                and DOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO = ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO
                and ARNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
                and DOPA.TIPA_SQ_TIPO_PAGAMENTO in (3,4)
                and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2
                and ITPA.ITPA_VL_LIQUIDO != DOPA.DOPA_VL_DOCUMENTO_PAGAMENTO) 
    loop
      ATUALIZA_STATUS_ACJ(4,0);
      ATUALIZA_STATUS_ACJ(5,0);
      ATUALIZA_STATUS_ACJ(6,0);
      
      V_DS_MENSAGEM := 'O valor do documento de pagamento de dep�sito em ju�zo/custas processuais '||REG.DOPA_DS_REFERENCIA_PAGAMENTO||' est� diferente do valor l�quido na solicita��o de pagamento correspondente';
      INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
    end loop;
    
    for reg in (select REPA.REPA_SQ_RECIBO_PAGAMENTO, REPA.REPA_VL_RECIBO
                from  RECIBO_PAGAMENTO REPA,
                      ARQUIVO_NEGOCIACAO ARNE
                where ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO = REPA.ARNE_SQ_ARQUIVO_NEGOCIACAO
                and REPA.TIPA_SQ_TIPO_PAGAMENTO in (3,4)
                and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO = 2)
    loop
      select count(*)
      into CT_RECIBO
      from DOCUMENTO_PAGAMENTO DOPA
      where DOPA.REPA_SQ_RECIBO_PAGAMENTO = REG.REPA_SQ_RECIBO_PAGAMENTO;
      
      if CT_RECIBO = 0 then
        ATUALIZA_STATUS_ACJ(4,0);
        ATUALIZA_STATUS_ACJ(5,0);
        ATUALIZA_STATUS_ACJ(6,0);
        
        V_DS_MENSAGEM := 'O recibo/comprovante de pagamento de dep�sito em ju�zo/custas processuais n�o est� associado a um documento de pagamento';
        INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
      else
        select sum(nvl(DOPA.DOPA_VL_DOCUMENTO_PAGAMENTO,0))
        into V_VL_DOPA
        from DOCUMENTO_PAGAMENTO DOPA, ARQUIVO_NEGOCIACAO ARNE
        where ARNE.ARNE_SQ_ARQUIVO_NEGOCIACAO = DOPA.ARNE_SQ_ARQUIVO_NEGOCIACAO
        and ARNE.SIDO_SQ_SITUACAO_DOCUMENTO in (3,4)
        and DOPA.REPA_SQ_RECIBO_PAGAMENTO = REG.REPA_SQ_RECIBO_PAGAMENTO;
        
        if (V_VL_DOPA != REG.REPA_VL_RECIBO) then
          ATUALIZA_STATUS_ACJ(4,0);
          ATUALIZA_STATUS_ACJ(5,0);
          ATUALIZA_STATUS_ACJ(6,0);
          
          V_DS_MENSAGEM := 'O recibo/comprovante de pagamento de dep�sito em ju�zo/custas processuais n�o est� diferente dos valores dos documentos de pagamento correspondentes';
          INSERIR_PENDENCIA(P_ID_PRLS, V_DS_MENSAGEM, 'N', 'S');
        end if;
      end if;
      
    end loop;
  END;
    
  /* FIM A��O JUDICIAL */
  
  PROCEDURE ATUALIZA_STATUS_ACJ(P_ID_STATUS IN NUMBER, P_PERMITE_STATUS NUMBER) IS 
    V_ID_STATUS   SITUACAO_ACAO_JUDICIAL.SIAJ_SQ_SITC_ACAO_JUDICIAL%TYPE;    
  BEGIN
    
    T_AVALIA_STATUS_ACAO(P_ID_STATUS).VERIFICACAO_PENDENCIA := P_PERMITE_STATUS;
    if T_AVALIA_STATUS_ACAO(P_ID_STATUS).VERIFICACAO_STATUS is null then
      T_AVALIA_STATUS_ACAO(P_ID_STATUS).VERIFICACAO_STATUS := P_PERMITE_STATUS;
      T_AVALIA_STATUS_ACAO(P_ID_STATUS).ID_STATUS := P_ID_STATUS;
    end if;     
    
  END;
  
  PROCEDURE LIMPAR_PENDENCIAS(P_ID_PRLS IN NUMBER) AS
    CT_PENDENCIA NUMBER;
  BEGIN
    delete from pendencia_prcs_srvc_negociacao
    where PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
    and PEPS_IN_TIPO_PENDENCIA = 'S'
    and PEPS_DS_JUSTIFICATIVA is null;
    
    commit;
  END LIMPAR_PENDENCIAS;
  
  PROCEDURE INSERIR_PENDENCIA(P_ID_PRLS IN NUMBER, P_DS_MENSAGEM IN VARCHAR2, P_IN_JUSTIFICAVEL IN VARCHAR2, P_IN_IMPEDITIVA IN VARCHAR2) AS
    CT_PENDENCIA number(5);
  BEGIN
    select count(*)
    into CT_PENDENCIA
    from PENDENCIA_PRCS_SRVC_NEGOCIACAO
    where PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
    and PEPS_IN_TIPO_PENDENCIA = 'S' 
    and PEPS_TX_PENDENCIA = P_DS_MENSAGEM;
    
    if CT_PENDENCIA = 0 then
  
      insert into PENDENCIA_PRCS_SRVC_NEGOCIACAO
      ( PEPS_SQ_PENDENCIA_PRCS_SRVC
      , PRLS_SQ_PRCS_LBRC_SRVC_ENGR
      , PEPS_DT_PENDENCIA
      , PEPS_TX_PENDENCIA
      , PEPS_IN_JUSTIFICAVEL
      , PEPS_IN_IMPEDITIVA
      , PEPS_IN_TIPO_PENDENCIA
      , PEPS_IN_RESOLVIDO
      , FMWK_DT_ULTIMA_ATUALIZACAO)
      (select SQ_PEPS_SQ_PENDENCIA_PRCS_SRVC.nextval,
              P_ID_PRLS,
              sysdate,
              P_DS_MENSAGEM,              
              P_IN_JUSTIFICAVEL,
              P_IN_IMPEDITIVA,
              'S',
              'N',
              sysdate
       from dual);
       
       commit;
    end if;
  END INSERIR_PENDENCIA;
END PCK_SISGT_STATUS_NEG_FINAL;