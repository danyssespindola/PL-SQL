create or replace
PACKAGE BODY PCK_SISGT_REVISAO AS

  procedure DELETE_CASCADE(P_ID_ANTIGO           IN NUMBER,                           
                           P_NM_TABELA           IN VARCHAR2) AS
    TYPE NumList IS TABLE OF NUMBER;  
    V_IDS_ANTIGOS   NumList;  
    V_ID_ANTIGO     NUMBER;
    I   NUMBER;
    
    V_COLUNA_PAI        VARCHAR2(30);
    V_COLUNA_PK_FILHA   VARCHAR2(30);
    V_CONS_PAI          VARCHAR2(30);
    V_SELECT            VARCHAR2(2000);
  BEGIN  
    select c3.column_name coluna_pai, c1.constraint_name
    into V_COLUNA_PAI, V_CONS_PAI
    from user_constraints c1, user_cons_columns c3
    where c3.constraint_name = c1.constraint_name              
    and c1.constraint_type = 'P'  
    and c1.owner = 'SISGT_OWNER'              
    and c3.owner = 'SISGT_OWNER'              
    and c1.table_name = P_NM_TABELA;
    
    for reg in (SELECT CN.TABLE_NAME TABELA_FILHA, CL.COLUMN_NAME COLUNA_FILHA
                FROM USER_CONSTRAINTS CN, USER_CONS_COLUMNS CL 
                WHERE CN.R_CONSTRAINT_NAME = V_CONS_PAI
                AND CL.CONSTRAINT_NAME = CN.CONSTRAINT_NAME)
    loop
 --     if(reg.tabela_filha != 'FICHA_CADASTRAL') then
        SELECT CL.COLUMN_NAME 
        into V_COLUNA_PK_FILHA
        FROM USER_CONSTRAINTS CT, USER_CONS_COLUMNS CL
        WHERE CT.TABLE_NAME = REG.TABELA_FILHA
        AND CL.TABLE_NAME = CT.TABLE_NAME
        AND CONSTRAINT_TYPE = 'P'
        AND CL.CONSTRAINT_NAME = CT.CONSTRAINT_NAME;
        
        V_SELECT := 'SELECT '||V_COLUNA_PK_FILHA||' FROM '||REG.TABELA_FILHA||' where '||reg.coluna_filha||'='||P_ID_ANTIGO;
                
        EXECUTE IMMEDIATE V_SELECT
        BULK COLLECT INTO V_IDS_ANTIGOS;
        
        FOR i IN 1..V_IDS_ANTIGOS.count LOOP
          V_ID_ANTIGO := V_IDS_ANTIGOS(I);
          
          DELETE_CASCADE(V_ID_ANTIGO,REG.TABELA_FILHA);  
          
        END LOOP;
        v_select :=  'DELETE FROM '||REG.TABELA_FILHA||' WHERE '||REG.COLUNA_FILHA||'='||P_ID_ANTIGO; 
        
        EXECUTE IMMEDIATE v_select;      
        EXECUTE IMMEDIATE 'commit';  
        
        dbms_output.put_line(v_select);
--      end if;
    end loop;
    
    EXECUTE IMMEDIATE 'DELETE FROM '||P_NM_TABELA||' WHERE '||V_COLUNA_PAI||'='||P_ID_ANTIGO;
    EXECUTE IMMEDIATE 'commit';  
  END DELETE_CASCADE;

  procedure REVISA_GRUPO_PESSOA(P_ID_FICHA_ANT IN NUMBER
                              , P_ID_FICHA_NOVA IN NUMBER) AS
    V_ID_PSFC     number(20);
    V_ID_PRLI     number(20);
  BEGIN
    for reg in (select * from 
                GRUPO_PSSA_PROCESSO_LIBERACAO 
                where PRLI_SQ_PROCESSO_LIBERACAO in 
                  (select PRLI_SQ_PROCESSO_LIBERACAO 
                  from PROCESSO_LIBERACAO 
                  where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA_ANT
                  and siob_sq_situacao_objeto !=2))
    loop
      select PSFC_SQ_PSSA_VSND_FICHA_CDTL 
      into V_ID_PSFC
      from PSSA_VSND_FICHA_CADASTRAL
      where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA_NOVA
      and PESE_SQ_PESSOA_SRVC_ENGENHARIA = 
      (select PESE_SQ_PESSOA_SRVC_ENGENHARIA    
      from PSSA_VSND_FICHA_CADASTRAL
      where PSFC_SQ_PSSA_VSND_FICHA_CDTL = reg.PSFC_SQ_PSSA_VSND_FICHA_CDTL);
      
      select PRLI_SQ_PROCESSO_LIBERACAO
      into V_ID_PRLI
      from PROCESSO_LIBERACAO
      where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA_NOVA
      and (PRLI_NR_PROCESSO_LIBERACAO, PRLI_CD_REVISAO_PRCS_LIBERACAO) =
      (select PRLI_NR_PROCESSO_LIBERACAO, PRLI_CD_REVISAO_PRCS_LIBERACAO
       from PROCESSO_LIBERACAO
       where PRLI_SQ_PROCESSO_LIBERACAO = reg.PRLI_SQ_PROCESSO_LIBERACAO);
      
      INSERT INTO GRUPO_PSSA_PROCESSO_LIBERACAO
      ( GRPP_SQ_GRUPO_PSSA_PROCESSO
      , PSFC_SQ_PSSA_VSND_FICHA_CDTL
      , PRLI_SQ_PROCESSO_LIBERACAO
      , FMWK_DT_ULTIMA_ATUALIZACAO)
      (SELECT   SQ_GRPP_SQ_GRUPO_PSSA_PROCESSO.nextval
              , V_ID_PSFC
              , V_ID_PRLI
              , sysdate
      FROM dual);
      
      commit;
    end loop;
    PCK_SISGT_PENDENCIAS.GERAR_PENDENCIAS(P_ID_FICHA_NOVA);
  EXCEPTION WHEN OTHERS THEN
    rollback;
    raise_application_error(-20001, 'Erro na Revisão.'||chr(13)||SQLERRM);
  END REVISA_GRUPO_PESSOA;

  procedure REVISAR_DEPENDENCIAS_ARQUIVO(P_ID_ANTIGO_PAI   IN NUMBER, 
                                         P_ID_NOVO_PAI     IN NUMBER,
                                         P_NM_TABELA       IN VARCHAR2,
                                         P_COLUNA_PAI      IN VARCHAR2,
                                         P_COLUNA_PK       IN VARCHAR2) AS
                                         
    TYPE NumList IS TABLE OF NUMBER;  
    V_IDS_DOCU_ANTIGOS   NumList;
    V_IDS_ARQU_ANTIGOS   NumList;
    V_ID_DOCU_NOVO       NUMBER;
    V_ID_ARQU_NOVO       NUMBER;
    V_ID_DOCU_ANTIGO     NUMBER;
    V_ID_ARQU_ANTIGO     NUMBER;
    I   NUMBER;
    
    V_SELECT_DOCU        VARCHAR2(2000);                                         
    V_SELECT_ARQU        VARCHAR2(2000);                                         
                                         
  BEGIN
    V_SELECT_DOCU := 'SELECT DISTINCT '||'DOCU_SQ_DOCUMENTO'||' FROM '||P_NM_TABELA||' where '||P_COLUNA_PAI||'='||P_ID_ANTIGO_PAI||' order by 1';

    EXECUTE IMMEDIATE V_SELECT_DOCU
    BULK COLLECT INTO V_IDS_DOCU_ANTIGOS;
    
    FOR i IN 1..V_IDS_DOCU_ANTIGOS.count LOOP
      V_ID_DOCU_ANTIGO := V_IDS_DOCU_ANTIGOS(I);
      
      V_ID_DOCU_NOVO := COPIAR_DADOS(V_ID_DOCU_ANTIGO, 'DOCUMENTO');
      
      V_SELECT_ARQU := 'SELECT '||P_COLUNA_PK||' FROM '||P_NM_TABELA||' where '||P_COLUNA_PAI||'='||P_ID_ANTIGO_PAI||' and DOCU_SQ_DOCUMENTO = '||V_ID_DOCU_ANTIGO;
      
      EXECUTE IMMEDIATE V_SELECT_ARQU
      BULK COLLECT INTO V_IDS_ARQU_ANTIGOS;
      
      FOR i IN 1..V_IDS_ARQU_ANTIGOS.count LOOP
        V_ID_ARQU_ANTIGO := V_IDS_ARQU_ANTIGOS(I);
      
        V_ID_ARQU_NOVO := COPIAR_DADOS_VERSIONAR(V_ID_ARQU_ANTIGO, P_NM_TABELA, P_ID_NOVO_PAI, P_COLUNA_PAI, 'DOCU_SQ_DOCUMENTO', V_ID_DOCU_NOVO);
      END LOOP;
    END LOOP;
  END;

  procedure REVISAR_DEPENDENCIAS(P_ID_ANTIGO           IN NUMBER, 
                                 P_ID_NOVO             IN NUMBER,
                                 P_NM_TABELA           IN VARCHAR2) AS
    TYPE NumList IS TABLE OF NUMBER;  
    V_IDS_ANTIGOS   NumList;
    V_ID_NOVO       NUMBER := P_ID_NOVO;
    V_ID_ANTIGO     NUMBER;
    I   NUMBER;
    
    V_COLUNA_PAI    VARCHAR2(30);
    V_CONS_PAI      VARCHAR2(30);
    V_SELECT        VARCHAR2(2000);
  BEGIN  
    select c3.column_name coluna_pai, c1.constraint_name
    into V_COLUNA_PAI, V_CONS_PAI
    from all_constraints c1, all_cons_columns c3
    where c3.constraint_name = c1.constraint_name              
    and c1.constraint_type = 'P'  
    and c1.owner = 'SISGT_OWNER'              
    and c3.owner = 'SISGT_OWNER'              
    and c1.table_name = P_NM_TABELA;
    
    for reg in (select c2.table_name TABELA_FILHA, c5.column_name coluna_pk_filha
                from all_constraints c2, all_constraints c4, all_cons_columns c5
                where V_CONS_PAI = c2.r_constraint_name              
                and c4.table_name = c2.table_name
                and c4.constraint_type = 'P'  
                and c5.constraint_name = c4.constraint_name
                and c5.table_name = c4.table_name              
                and c2.owner = 'SISGT_OWNER'
                and c4.owner = 'SISGT_OWNER'
                and c5.owner = 'SISGT_OWNER')
    loop  
       V_SELECT := 'SELECT '||REG.coluna_pk_filha||' FROM '||REG.TABELA_FILHA||' where '||V_COLUNA_PAI||'='||P_ID_ANTIGO||' order by 1';
      
      if (P_NM_TABELA = 'PROCESSO_LIBERACAO' and (REG.TABELA_FILHA IN ('MOVIMENTO_WORKFLOW', 'PROCESSO_LIBERACAO', 'PROCESSO_LIBERACAO_SRVC_ENGR','AVALIACAO_SEPAV_TOTAL'))) then        
        null;
      elsif ( REG.TABELA_FILHA LIKE ('ARQUIVO_%') ) then
        REVISAR_DEPENDENCIAS_ARQUIVO(P_ID_ANTIGO, P_ID_NOVO, REG.TABELA_FILHA, V_COLUNA_PAI, REG.coluna_pk_filha);
      else
        EXECUTE IMMEDIATE V_SELECT
        BULK COLLECT INTO V_IDS_ANTIGOS;
        
        FOR i IN 1..V_IDS_ANTIGOS.count LOOP
          V_ID_ANTIGO := V_IDS_ANTIGOS(I);
          
          V_ID_NOVO := COPIAR_DADOS(V_ID_ANTIGO, REG.TABELA_FILHA, P_ID_NOVO, V_COLUNA_PAI);
          
          
          REVISAR_DEPENDENCIAS(V_ID_ANTIGO,V_ID_NOVO,REG.TABELA_FILHA);      
        END LOOP;
      end if;
    end loop;
   EXCEPTION WHEN OTHERS THEN
    rollback;
    raise_application_error(-20001, 'Erro na Revisão.'||chr(13)||SQLERRM);
  END REVISAR_DEPENDENCIAS;

  procedure REVISAR_DEPENDENCIAS_FICHA(P_ID_ANTIGO           IN NUMBER, 
                                       P_ID_NOVO             IN NUMBER,
                                       P_NM_TABELA           IN VARCHAR2,
                                       P_NM_TABELA_CONDICAO  IN VARCHAR2,
                                       P_DS_CONDICAO         IN VARCHAR2) AS
    TYPE NumList IS TABLE OF NUMBER;  
    V_IDS_ANTIGOS   NumList;
    V_ID_NOVO       NUMBER := P_ID_NOVO;
    V_ID_ANTIGO     NUMBER;
    I   NUMBER;
    
    V_COLUNA_PAI    VARCHAR2(30);
    V_CONS_PAI      VARCHAR2(30);
    V_SELECT        VARCHAR2(2000);
  BEGIN  
    select c3.column_name coluna_pai, c1.constraint_name
    into V_COLUNA_PAI, V_CONS_PAI
    from all_constraints c1, all_cons_columns c3
    where c3.constraint_name = c1.constraint_name              
    and c1.constraint_type = 'P'  
    and c1.owner = 'SISGT_OWNER'              
    and c3.owner = 'SISGT_OWNER'              
    and c1.table_name = P_NM_TABELA;
    
    for reg in (select c2.table_name TABELA_FILHA, c5.column_name coluna_pk_filha
                from all_constraints c2, all_constraints c4, all_cons_columns c5
                where V_CONS_PAI = c2.r_constraint_name              
                and c4.table_name = c2.table_name
                and c4.constraint_type = 'P'  
                and c5.constraint_name = c4.constraint_name
                and c5.table_name = c4.table_name              
                and c2.owner = 'SISGT_OWNER'
                and c4.owner = 'SISGT_OWNER'
                and c5.owner = 'SISGT_OWNER')
    loop 
      V_SELECT := 'SELECT '||REG.coluna_pk_filha||' FROM '||REG.TABELA_FILHA||' where '||V_COLUNA_PAI||'='||P_ID_ANTIGO;
      
      IF (P_NM_TABELA_CONDICAO = REG.TABELA_FILHA) THEN
        V_SELECT := V_SELECT||' and '||P_DS_CONDICAO;
      END IF;
      
      V_SELECT := V_SELECT||' order by 1';
      
      if P_NM_TABELA = 'PROCESSO_LIBERACAO' and REG.TABELA_FILHA IN ('PROCESSO_LIBERACAO','PROCESSO_LIBERACAO_SRVC_ENGR') then
        null;
      else
        IF REG.TABELA_FILHA not in ('FICHA_CADASTRAL','GRUPO_PSSA_PROCESSO_LIBERACAO','PENDENCIA_FICHA_CADASTRAL') THEN
          EXECUTE IMMEDIATE V_SELECT
          BULK COLLECT INTO V_IDS_ANTIGOS;
            
          FOR i IN 1..V_IDS_ANTIGOS.count LOOP
            V_ID_ANTIGO := V_IDS_ANTIGOS(I);
            
            V_ID_NOVO := COPIAR_DADOS(V_ID_ANTIGO, REG.TABELA_FILHA, P_ID_NOVO, V_COLUNA_PAI);   
            
            REVISAR_DEPENDENCIAS_FICHA(V_ID_ANTIGO,V_ID_NOVO,REG.TABELA_FILHA,P_NM_TABELA_CONDICAO,P_DS_CONDICAO);      
            
          END LOOP;
        END IF;
      end if;
    end loop;
    
    if P_NM_TABELA = 'FICHA_CADASTRAL' then
      REFAZER_VINCULO_PLS(P_ID_ANTIGO, P_ID_NOVO);
    end if;
    
  EXCEPTION WHEN OTHERS THEN
    rollback;
    raise_application_error(-20001, 'Erro na Revisão.'||chr(13)||SQLERRM);
  END REVISAR_DEPENDENCIAS_FICHA;

  procedure REFAZER_VINCULO_PLS(P_ID_FICHA_ANT IN NUMBER, P_ID_FICHA_NOVO in NUMBER) AS
    V_NR_PL         PROCESSO_LIBERACAO.PRLI_NR_PROCESSO_LIBERACAO%TYPE;
    V_CD_REVISAO_PL PROCESSO_LIBERACAO.PRLI_CD_REVISAO_PRCS_LIBERACAO%TYPE;
    V_ID_PL_VINCULO PROCESSO_LIBERACAO.PRLI_SQ_PROCESSO_LIBERACAO%TYPE;
  begin
    for REG in (select distinct PRLI_SQ_PRCS_LBRC_VINCULADO
                from PROCESSO_LIBERACAO
                where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA_NOVO)
    loop
      select PRLI_NR_PROCESSO_LIBERACAO, PRLI_CD_REVISAO_PRCS_LIBERACAO
      into V_NR_PL, V_CD_REVISAO_PL
      from PROCESSO_LIBERACAO
      where PRLI_SQ_PROCESSO_LIBERACAO = REG.PRLI_SQ_PRCS_LBRC_VINCULADO;
      
      begin
        select PRLI_SQ_PROCESSO_LIBERACAO
        into V_ID_PL_VINCULO
        from PROCESSO_LIBERACAO
        where PRLI_NR_PROCESSO_LIBERACAO = V_NR_PL
        and PRLI_CD_REVISAO_PRCS_LIBERACAO = V_CD_REVISAO_PL
        and FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA_NOVO;
      exception when no_data_found then
        V_ID_PL_VINCULO := NULL;
      end;
      
      update PROCESSO_LIBERACAO set
        PRLI_SQ_PRCS_LBRC_VINCULADO = V_ID_PL_VINCULO
      where PRLI_SQ_PRCS_LBRC_VINCULADO = REG.PRLI_SQ_PRCS_LBRC_VINCULADO
      and FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA_NOVO;
      
      commit;
    end loop;
  end;

  procedure REVISAR_FICHA_CADASTRAL(P_ID_FICHA_ANTIGA    IN NUMBER
                                  , P_ID_USUARIO_SERVICO IN NUMBER) AS
    V_NM_TABELA            VARCHAR2(100) := 'FICHA_CADASTRAL';
    V_ID_FICHA_NOVA        NUMBER;
    V_CD_REVISAO_ANTIGO    VARCHAR2(2);
    V_CD_REVISAO_NOVO      VARCHAR2(2);  
    V_ID_SITUACAO          NUMBER;
    
    V_ID_MORC              NUMBER(20);
  BEGIN
    
    select FICA_CD_REVISAO_FICHA_CDTL, SIOB_SQ_SITUACAO_OBJETO
    into V_CD_REVISAO_ANTIGO, V_ID_SITUACAO
    from FICHA_CADASTRAL
    where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA_ANTIGA;
    
    V_CD_REVISAO_NOVO := GERAR_CODIGO_REVISAO(V_CD_REVISAO_ANTIGO);  
    
    if V_CD_REVISAO_ANTIGO != V_CD_REVISAO_NOVO and V_ID_SITUACAO = 1 then
      SELECT SQ_FICA_SQ_FICHA_CADASTRAL.nextval
      INTO V_ID_FICHA_NOVA
      FROM DUAL;    
    
      insert into FICHA_CADASTRAL
      ( FICA_SQ_FICHA_CADASTRAL
      , USPS_SQ_USUA_CRIACAO_FICHA
      , IMSE_SQ_IMOVEL_SRVC_ENGENHARIA
      , SUOB_SQ_SUBAREA_OBRA
      , FMWK_DT_ULTIMA_ATUALIZACAO
      , INSE_SQ_INTF_SRVC_ENGR
      , TIFC_SQ_TIPO_FICHA_CADASTRAL
      , SIOB_SQ_SITUACAO_OBJETO
      , FICA_TX_OBSERVACAO
      , FICA_DT_CRIACAO
      , FICA_SQ_FICHA_CDTL_VINCULADA
      , FICA_NR_FICHA_CADASTRAL
      , FICA_IN_ABRANGENCIA_CADASTRO
      , FICA_CD_REVISAO_FICHA_CDTL
      , TIAR_SQ_TIPO_AREA
      , fica_nr_base_ficha_cadastral
      )    
      (SELECT V_ID_FICHA_NOVA
            , P_ID_USUARIO_SERVICO
            , IMSE_SQ_IMOVEL_SRVC_ENGENHARIA
            , SUOB_SQ_SUBAREA_OBRA
            , sysdate
            , INSE_SQ_INTF_SRVC_ENGR
            , TIFC_SQ_TIPO_FICHA_CADASTRAL
            , SIOB_SQ_SITUACAO_OBJETO
            , FICA_TX_OBSERVACAO
            , sysdate
            , FICA_SQ_FICHA_CDTL_VINCULADA
            , FICA_NR_FICHA_CADASTRAL
            , FICA_IN_ABRANGENCIA_CADASTRO
            , V_CD_REVISAO_NOVO
            , TIAR_SQ_TIPO_AREA
            , fica_nr_base_ficha_cadastral
      FROM FICHA_CADASTRAL
      WHERE FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA_ANTIGA); 
      
      COMMIT;
                              
      REVISAR_DEPENDENCIAS_FICHA(P_ID_FICHA_ANTIGA,V_ID_FICHA_NOVA,V_NM_TABELA,'PROCESSO_LIBERACAO','siob_sq_situacao_objeto != 2'); 
      
      /* Acerta dos dados para Grupo de Pessoas e de Área de Interesse */
      
      REVISA_GRUPO_PESSOA(P_ID_FICHA_ANTIGA,V_ID_FICHA_NOVA);
      
      /* Cancela todos os Processos de Liberação da Ficha Revisada */
      V_ID_MORC := MOTIVO_REVISAO('Cancelado por Revisão');
      
      update PROCESSO_LIBERACAO set
        SIOB_SQ_SITUACAO_OBJETO = 2,
        MORC_SQ_MOTIVO_REVS_CNCT = V_ID_MORC,
        PRLI_TX_JSTF_REVS_CNCT = 'Cancelado por Revisão de Ficha'
      where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA_ANTIGA
      and SIOB_SQ_SITUACAO_OBJETO != 2;
      
      /* Cancela a Ficha Cadastral Revisada */
      update FICHA_CADASTRAL set
        SIOB_SQ_SITUACAO_OBJETO = 2,
        MORC_SQ_MOTIVO_REVS_CNCT = V_ID_MORC,
        FICA_TX_JSTF_REVS_CNCT = 'Cancelada por Revisão Automática'
      where SIOB_SQ_SITUACAO_OBJETO = 1
      and FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA_ANTIGA;
      
      update FICHA_CADASTRAL set
        FICA_SQ_FICHA_CDTL_VINCULADA = V_ID_FICHA_NOVA
      where FICA_SQ_FICHA_CDTL_VINCULADA = P_ID_FICHA_ANTIGA;
      
      COMMIT;
      
      PCK_SISGT_PENDENCIAS.GERAR_PENDENCIAS(V_ID_FICHA_NOVA);
    end if;  
  EXCEPTION WHEN OTHERS THEN
    rollback;    
    DELETE_CASCADE(V_ID_FICHA_NOVA, 'FICHA_CADASTRAL');
    raise_application_error(-20001, 'Erro na Revisão.'||chr(13)||SQLERRM);
  END REVISAR_FICHA_CADASTRAL;
  
  procedure REVISAR_FICHA_POR_IMOVEL( P_ID_USUARIO_SERVICO  IN NUMBER
                                    , P_ID_IMSE_ANTIGO      IN NUMBER
                                    , P_ID_IMSE_NOVO        IN NUMBER) AS
    V_NM_TABELA            VARCHAR2(100) := 'FICHA_CADASTRAL';
    V_ID_FICHA_NOVA        NUMBER;
    V_CD_REVISAO_ANTIGO    VARCHAR2(2);
    V_CD_REVISAO_NOVO      VARCHAR2(2);  
    V_ID_SITUACAO          NUMBER;
    
    V_ID_MORC              NUMBER(20);
  BEGIN
    for reg in (select FICA_SQ_FICHA_CADASTRAL 
                from FICHA_CADASTRAL
                where IMSE_SQ_IMOVEL_SRVC_ENGENHARIA = P_ID_IMSE_ANTIGO
                and SIOB_SQ_SITUACAO_OBJETO = 1)
    loop      
      
      select FICA_CD_REVISAO_FICHA_CDTL, SIOB_SQ_SITUACAO_OBJETO
      into V_CD_REVISAO_ANTIGO, V_ID_SITUACAO
      from FICHA_CADASTRAL
      where FICA_SQ_FICHA_CADASTRAL = REG.FICA_SQ_FICHA_CADASTRAL;
      
      V_CD_REVISAO_NOVO := GERAR_CODIGO_REVISAO(V_CD_REVISAO_ANTIGO);  
      
      if V_CD_REVISAO_ANTIGO != V_CD_REVISAO_NOVO and V_ID_SITUACAO = 1 then
      
        SELECT SQ_FICA_SQ_FICHA_CADASTRAL.nextval
        INTO V_ID_FICHA_NOVA
        FROM DUAL;
      
        insert into FICHA_CADASTRAL
        ( FICA_SQ_FICHA_CADASTRAL
        , USPS_SQ_USUA_CRIACAO_FICHA
        , IMSE_SQ_IMOVEL_SRVC_ENGENHARIA
        , SUOB_SQ_SUBAREA_OBRA
        , FMWK_DT_ULTIMA_ATUALIZACAO
        , INSE_SQ_INTF_SRVC_ENGR
        , TIFC_SQ_TIPO_FICHA_CADASTRAL
        , SIOB_SQ_SITUACAO_OBJETO
        , FICA_TX_OBSERVACAO
        , FICA_DT_CRIACAO
        , FICA_SQ_FICHA_CDTL_VINCULADA
        , FICA_NR_FICHA_CADASTRAL
        , FICA_IN_ABRANGENCIA_CADASTRO
        , FICA_CD_REVISAO_FICHA_CDTL
        , TIAR_SQ_TIPO_AREA
        , fica_nr_base_ficha_cadastral
        )    
        (SELECT V_ID_FICHA_NOVA
              , P_ID_USUARIO_SERVICO
              , P_ID_IMSE_NOVO
              , SUOB_SQ_SUBAREA_OBRA
              , sysdate
              , null
              , TIFC_SQ_TIPO_FICHA_CADASTRAL
              , SIOB_SQ_SITUACAO_OBJETO
              , FICA_TX_OBSERVACAO
              , sysdate
              , FICA_SQ_FICHA_CDTL_VINCULADA
              , FICA_NR_FICHA_CADASTRAL
              , FICA_IN_ABRANGENCIA_CADASTRO
              , V_CD_REVISAO_NOVO
              , TIAR_SQ_TIPO_AREA
              , fica_nr_base_ficha_cadastral
        FROM FICHA_CADASTRAL
        WHERE FICA_SQ_FICHA_CADASTRAL = REG.FICA_SQ_FICHA_CADASTRAL); 
        
        COMMIT;
                                
        REVISAR_DEPENDENCIAS_FICHA(REG.FICA_SQ_FICHA_CADASTRAL,V_ID_FICHA_NOVA,V_NM_TABELA,'PROCESSO_LIBERACAO','siob_sq_situacao_objeto != 2'); 
        
        /* Acerta dos dados para Grupo de Pessoas e de Área de Interesse */
        
        REVISA_GRUPO_PESSOA(REG.FICA_SQ_FICHA_CADASTRAL,V_ID_FICHA_NOVA);
        
        /* Cancela todos os Processos de Liberação da Ficha Revisada */
        V_ID_MORC := MOTIVO_REVISAO('Cancelado por Revisão');
        
        update PROCESSO_LIBERACAO set
          SIOB_SQ_SITUACAO_OBJETO = 2,
          MORC_SQ_MOTIVO_REVS_CNCT = V_ID_MORC,
          PRLI_TX_JSTF_REVS_CNCT = 'Cancelado por Revisão de Ficha'
        where FICA_SQ_FICHA_CADASTRAL = REG.FICA_SQ_FICHA_CADASTRAL
        and SIOB_SQ_SITUACAO_OBJETO != 2;
        
        /* Cancela a Ficha Cadastral Revisada */
        update FICHA_CADASTRAL set
          SIOB_SQ_SITUACAO_OBJETO = 2,
          MORC_SQ_MOTIVO_REVS_CNCT = V_ID_MORC,
          FICA_TX_JSTF_REVS_CNCT = 'Cancelada por Revisão Automática'          
        where SIOB_SQ_SITUACAO_OBJETO = 1
        and FICA_SQ_FICHA_CADASTRAL = REG.FICA_SQ_FICHA_CADASTRAL;
        
        update FICHA_CADASTRAL set
          FICA_SQ_FICHA_CDTL_VINCULADA = V_ID_FICHA_NOVA
        where FICA_SQ_FICHA_CDTL_VINCULADA = REG.FICA_SQ_FICHA_CADASTRAL;
        
        COMMIT;
        
        PCK_SISGT_PENDENCIAS.GERAR_PENDENCIAS(V_ID_FICHA_NOVA);
      end if;  
    end loop;
  EXCEPTION WHEN OTHERS THEN
    rollback;
    DELETE_CASCADE(V_ID_FICHA_NOVA, 'FICHA_CADASTRAL');  
    raise_application_error(-20001, 'Erro na Revisão.('||P_ID_USUARIO_SERVICO||', '||P_ID_IMSE_ANTIGO||', '||P_ID_IMSE_NOVO||')'||chr(13)||SQLERRM);      
  END REVISAR_FICHA_POR_IMOVEL;
  
  procedure REVISAR_FICHA_POR_INTF( P_ID_USUARIO_SERVICO  IN NUMBER
                                  , P_ID_INSE_ANTIGO      IN NUMBER
                                  , P_ID_INSE_NOVO        IN NUMBER) AS
    V_NM_TABELA            VARCHAR2(100) := 'FICHA_CADASTRAL';
    V_ID_FICHA_NOVA        NUMBER;
    V_CD_REVISAO_ANTIGO    VARCHAR2(2);
    V_CD_REVISAO_NOVO      VARCHAR2(2);  
    V_ID_SITUACAO          NUMBER;
    
    V_ID_MORC              NUMBER(20);
  BEGIN
    for reg in (select FICA_SQ_FICHA_CADASTRAL 
                from FICHA_CADASTRAL
                where INSE_SQ_INTF_SRVC_ENGR = P_ID_INSE_ANTIGO
                and SIOB_SQ_SITUACAO_OBJETO = 1)
    loop      
      
      select FICA_CD_REVISAO_FICHA_CDTL
      into V_CD_REVISAO_ANTIGO
      from FICHA_CADASTRAL
      where FICA_SQ_FICHA_CADASTRAL = REG.FICA_SQ_FICHA_CADASTRAL;
      
      V_CD_REVISAO_NOVO := GERAR_CODIGO_REVISAO(V_CD_REVISAO_ANTIGO);  
      
      if V_CD_REVISAO_ANTIGO != V_CD_REVISAO_NOVO then
      
        SELECT SQ_FICA_SQ_FICHA_CADASTRAL.nextval
        INTO V_ID_FICHA_NOVA
        FROM DUAL;
      
        insert into FICHA_CADASTRAL
        ( FICA_SQ_FICHA_CADASTRAL
        , USPS_SQ_USUA_CRIACAO_FICHA
        , IMSE_SQ_IMOVEL_SRVC_ENGENHARIA
        , SUOB_SQ_SUBAREA_OBRA
        , FMWK_DT_ULTIMA_ATUALIZACAO
        , INSE_SQ_INTF_SRVC_ENGR
        , TIFC_SQ_TIPO_FICHA_CADASTRAL
        , SIOB_SQ_SITUACAO_OBJETO
        , FICA_TX_OBSERVACAO
        , FICA_DT_CRIACAO
        , FICA_SQ_FICHA_CDTL_VINCULADA
        , FICA_NR_FICHA_CADASTRAL
        , FICA_IN_ABRANGENCIA_CADASTRO
        , FICA_CD_REVISAO_FICHA_CDTL
        , TIAR_SQ_TIPO_AREA
        , fica_nr_base_ficha_cadastral
        )    
        (SELECT V_ID_FICHA_NOVA
              , P_ID_USUARIO_SERVICO
              , null
              , SUOB_SQ_SUBAREA_OBRA
              , sysdate
              , P_ID_INSE_NOVO
              , TIFC_SQ_TIPO_FICHA_CADASTRAL
              , SIOB_SQ_SITUACAO_OBJETO
              , FICA_TX_OBSERVACAO
              , sysdate
              , FICA_SQ_FICHA_CDTL_VINCULADA
              , FICA_NR_FICHA_CADASTRAL
              , FICA_IN_ABRANGENCIA_CADASTRO
              , V_CD_REVISAO_NOVO
              , TIAR_SQ_TIPO_AREA
              , fica_nr_base_ficha_cadastral
        FROM FICHA_CADASTRAL
        WHERE FICA_SQ_FICHA_CADASTRAL = REG.FICA_SQ_FICHA_CADASTRAL); 
        
        COMMIT;
                                
        REVISAR_DEPENDENCIAS_FICHA(REG.FICA_SQ_FICHA_CADASTRAL,V_ID_FICHA_NOVA,V_NM_TABELA,'PROCESSO_LIBERACAO','siob_sq_situacao_objeto != 2'); 
        
        /* Acerta dos dados para Grupo de Pessoas e de Área de Interesse */
        
        REVISA_GRUPO_PESSOA(REG.FICA_SQ_FICHA_CADASTRAL,V_ID_FICHA_NOVA);
                
        /* Cancela todos os Processos de Liberação da Ficha Revisada */
        V_ID_MORC := MOTIVO_REVISAO('Cancelado por Revisão');
        
        update PROCESSO_LIBERACAO set
          SIOB_SQ_SITUACAO_OBJETO = 2,
          MORC_SQ_MOTIVO_REVS_CNCT = V_ID_MORC,
          PRLI_TX_JSTF_REVS_CNCT = 'Cancelado por Revisão de Ficha'
        where FICA_SQ_FICHA_CADASTRAL = REG.FICA_SQ_FICHA_CADASTRAL
        and SIOB_SQ_SITUACAO_OBJETO != 2;
        
        /* Cancela a Ficha Cadastral Revisada */
        update FICHA_CADASTRAL set
          SIOB_SQ_SITUACAO_OBJETO = 2,
          MORC_SQ_MOTIVO_REVS_CNCT = V_ID_MORC,
          FICA_TX_JSTF_REVS_CNCT = 'Cancelada por Revisão Automática'
        where SIOB_SQ_SITUACAO_OBJETO = 1
        and FICA_SQ_FICHA_CADASTRAL = REG.FICA_SQ_FICHA_CADASTRAL;
        
        update FICHA_CADASTRAL set
          FICA_SQ_FICHA_CDTL_VINCULADA = V_ID_FICHA_NOVA
        where FICA_SQ_FICHA_CDTL_VINCULADA = REG.FICA_SQ_FICHA_CADASTRAL;
        
        COMMIT;
        
        PCK_SISGT_PENDENCIAS.GERAR_PENDENCIAS(V_ID_FICHA_NOVA);
      end if;  
    end loop;
  EXCEPTION WHEN OTHERS THEN
    rollback;
    DELETE_CASCADE(V_ID_FICHA_NOVA, 'FICHA_CADASTRAL');  
    raise_application_error(-20001, 'Erro na Revisão.'||chr(13)||SQLERRM);     
  END REVISAR_FICHA_POR_INTF;
  
  procedure REVISAR_PROCESSO_LIBERACAO(P_ID_ANTIGO  IN NUMBER
                                     , P_ID_USUARIO IN NUMBER) AS
    V_NM_TABELA            VARCHAR2(100) := 'PROCESSO_LIBERACAO';
    V_ID_NOVO              NUMBER(20);
    V_CD_REVISAO_ANTIGO    VARCHAR2(2);
    V_CD_REVISAO_NOVO      VARCHAR2(2);
    V_ID_FICHA             NUMBER(20);
    V_ID_FC_TRANSF         NUMBER(20);
    V_ID_SITUACAO          NUMBER(20);
    V_SITUACAO_WORKFLOW    NUMBER(20) := 1; /* Em Edição */
    
    V_ID_MORC              NUMBER(20);
    V_NM_MORC              VARCHAR2(70);
    V_ID_PRLS              NUMBER(20);
    
  BEGIN
    
    select FICA_SQ_FICHA_CADASTRAL, PRLI_CD_REVISAO_PRCS_LIBERACAO, SIOB_SQ_SITUACAO_OBJETO
    into V_ID_FICHA, V_CD_REVISAO_ANTIGO, V_ID_SITUACAO
    from PROCESSO_LIBERACAO
    where PRLI_SQ_PROCESSO_LIBERACAO = P_ID_ANTIGO;
    
    select FICA_SQ_FICHA_CDTL_ORIGEM
    into V_ID_FC_TRANSF
    from FICHA_CADASTRAL
    where FICA_SQ_FICHA_CADASTRAL = V_ID_FICHA;
    
    V_CD_REVISAO_NOVO := GERAR_CODIGO_REVISAO(V_CD_REVISAO_ANTIGO);  
    
    if V_CD_REVISAO_ANTIGO != V_CD_REVISAO_NOVO then
    
      SELECT SQ_PRLI_SQ_PROCESSO_LIBERACAO.nextval
      INTO V_ID_NOVO
      FROM DUAL;
    
      insert into PROCESSO_LIBERACAO 
      ( PRLI_SQ_PROCESSO_LIBERACAO
      , FICA_SQ_FICHA_CADASTRAL
      , PRLI_NR_PROCESSO_LIBERACAO
      , PRLI_CD_REVISAO_PRCS_LIBERACAO
      , FMWK_DT_ULTIMA_ATUALIZACAO
      , SIOB_SQ_SITUACAO_OBJETO
      , MORC_SQ_MOTIVO_REVS_CNCT
      , PRLI_TX_JSTF_REVS_CNCT
      , PRLI_IN_PROPRIETARIO
      , PRLI_IN_AREA_NOVA_AVALIAVEL
      , PRLI_IN_AREA_EXST_AVALIAVEL
      , PRLI_IN_AREA_NOVA_NEDF_AVLV
      , PRLI_IN_AREA_EXST_NEDF_AVLV
      , PRLI_IN_PPDD_PETROBRAS_AVLV
      , PRLI_SQ_PRCS_LBRC_VINCULADO
      , OBCA_SQ_OBJETIVO_CADASTRO
      , PRLI_IN_REVISAO)
      (SELECT V_ID_NOVO
            , FICA_SQ_FICHA_CADASTRAL
            , PRLI_NR_PROCESSO_LIBERACAO
            , V_CD_REVISAO_NOVO
            , SYSDATE
            , 1
            , MORC_SQ_MOTIVO_REVS_CNCT
            , PRLI_TX_JSTF_REVS_CNCT            
            , PRLI_IN_PROPRIETARIO
            , PRLI_IN_AREA_NOVA_AVALIAVEL
            , PRLI_IN_AREA_EXST_AVALIAVEL
            , PRLI_IN_AREA_NOVA_NEDF_AVLV
            , PRLI_IN_AREA_EXST_NEDF_AVLV
            , PRLI_IN_PPDD_PETROBRAS_AVLV
            , PRLI_SQ_PRCS_LBRC_VINCULADO
            , OBCA_SQ_OBJETIVO_CADASTRO
            , 'N'
      FROM PROCESSO_LIBERACAO
      WHERE PRLI_SQ_PROCESSO_LIBERACAO = P_ID_ANTIGO); 
      
      insert into movimento_workflow
        (MOWO_SQ_MOVIMENTO_WORKFLOW
        ,PRLI_SQ_PROCESSO_LIBERACAO
        ,SIOB_SQ_SITC_FICHA_CADASTRAL
        ,SIOB_SQ_SITC_PRCS_LIBERACAO
        ,SIWO_SQ_SITUACAO_WORKFLOW
        ,USUA_SQ_USUARIO_MOVIMENTO        
        ,FMWK_DT_ULTIMA_ATUALIZACAO)
      (select   SQ_MOWO_SQ_MOVIMENTO_WORKFLOW.NEXTVAL
              , V_ID_NOVO
              , 1
              , 1
              , 1
              , P_ID_USUARIO             
              , sysdate
      from DUAL);
      
      COMMIT;
                              
      REVISAR_DEPENDENCIAS(P_ID_ANTIGO,V_ID_NOVO,V_NM_TABELA); 
      
      VERIFICA_ATUALIZACAO_PESSOAS(V_ID_FICHA, V_ID_NOVO);
      
      /* Cancela o Processo de Liberação Revisado */
      if(V_ID_FC_TRANSF is not null) then
        V_ID_MORC := MOTIVO_REVISAO('Revisão de PL Transferido de Outro Serviço');     
      end if;
      
      update PROCESSO_LIBERACAO set
        SIOB_SQ_SITUACAO_OBJETO = 2,
        MORC_SQ_MOTIVO_REVS_CNCT = NVL(V_ID_MORC,MORC_SQ_MOTIVO_REVS_CNCT),
        PRLI_TX_JSTF_REVS_CNCT = 'Cancelado por Revisão'
      where PRLI_SQ_PROCESSO_LIBERACAO = P_ID_ANTIGO;
      
      update PROCESSO_LIBERACAO set
        PRLI_SQ_PRCS_LBRC_VINCULADO = V_ID_NOVO
      where PRLI_SQ_PRCS_LBRC_VINCULADO = P_ID_ANTIGO;
      
      /* Ativa a Ficha Cadastral */
      update FICHA_CADASTRAL set
        SIOB_SQ_SITUACAO_OBJETO = 1
      where SIOB_SQ_SITUACAO_OBJETO != 1
      and FICA_SQ_FICHA_CADASTRAL = V_ID_FICHA;
      
      /* Caso o Processo já tenha sido liberado, gera um registro no histórico */
      begin
        select PRLS_SQ_PRCS_LBRC_SRVC_ENGR
        into V_ID_PRLS
        from PROCESSO_LIBERACAO_SRVC_ENGR
        where PRLI_SQ_PROCESSO_LIBERACAO = P_ID_ANTIGO
        and PRLS_SQ_PRCS_LBRC_SRVC_DESTINO is null;        
        
        select MORC_SQ_MOTIVO_REVS_CNCT
        into V_ID_MORC
        from PROCESSO_LIBERACAO
        where PRLI_SQ_PROCESSO_LIBERACAO = P_ID_ANTIGO;
      
        if (V_ID_MORC is not null) then
          select MORC_NM_MOTIVO_REVS_CNCT
          into V_NM_MORC
          from MOTIVO_REVISAO_CANCELAMENTO
          where MORC_SQ_MOTIVO_REVS_CNCT = V_ID_MORC;
        else
          V_NM_MORC := 'Não informado';
        end if;
        
        INSERIR_HISTORICO_NEGOCIACAO(V_ID_PRLS, 'Motivo da Revisão: '||V_NM_MORC);
        COMMIT;
      exception when no_data_found then
        /* Significa que o Processo não foi liberado */
        null;
      end;
      
      COMMIT;
      PCK_SISGT_PENDENCIAS.GERAR_PENDENCIAS(V_ID_FICHA);
    end if; 
  EXCEPTION WHEN OTHERS THEN
    rollback;
    DELETE_CASCADE(V_ID_NOVO, 'PROCESSO_LIBERACAO');
    raise_application_error(-20001, 'Erro na Revisão.'||chr(13)||SQLERRM);   
  END REVISAR_PROCESSO_LIBERACAO;  
  
  procedure REVISAR_PL_POR_PESSOA(P_ID_PESE_ANTIGO  IN NUMBER
                                , P_ID_PESE_NOVO    IN NUMBER
                                , P_ID_USUARIO      IN NUMBER) AS
    V_NM_TABELA            VARCHAR2(100) := 'PROCESSO_LIBERACAO';
    V_ID_NOVO              NUMBER;
    
    V_CD_REVISAO_NOVO      VARCHAR2(2);
    
    
    V_ID_PSFC_ANTIGO       NUMBER;
    V_ID_PSFC_NOVO         NUMBER;
    V_SITUACAO_WORKFLOW    NUMBER := 1; /* Em Edição */
    
    V_SIOB_FICHA           SITUACAO_OBJETO.SIOB_SQ_SITUACAO_OBJETO%TYPE;
    V_ID_MORC              NUMBER(20);
  BEGIN    
    for reg in (SELECT PRLI.PRLI_SQ_PROCESSO_LIBERACAO,
                       PRLI.FICA_SQ_FICHA_CADASTRAL,
                       PRLI.SIOB_SQ_SITUACAO_OBJETO,
                       PRLI.PRLI_CD_REVISAO_PRCS_LIBERACAO
                FROM  PROCESSO_LIBERACAO PRLI,
                      GRUPO_PSSA_PROCESSO_LIBERACAO GPPL,
                      PSSA_VSND_FICHA_CADASTRAL PVFC
                WHERE PRLI.PRLI_SQ_PROCESSO_LIBERACAO = GPPL.PRLI_SQ_PROCESSO_LIBERACAO
                AND GPPL.PSFC_SQ_PSSA_VSND_FICHA_CDTL = PVFC.PSFC_SQ_PSSA_VSND_FICHA_CDTL
                AND PVFC.PESE_SQ_PESSOA_SRVC_ENGENHARIA = P_ID_PESE_ANTIGO
                /*AND PRLI.SIOB_SQ_SITUACAO_OBJETO = 1*/)
    loop
      select SIOB_SQ_SITUACAO_OBJETO
      into V_SIOB_FICHA
      from FICHA_CADASTRAL
      where FICA_SQ_FICHA_CADASTRAL = REG.FICA_SQ_FICHA_CADASTRAL;
      
      if V_SIOB_FICHA = 1 and REG.SIOB_SQ_SITUACAO_OBJETO = 1 then
      
        V_CD_REVISAO_NOVO := GERAR_CODIGO_REVISAO(REG.PRLI_CD_REVISAO_PRCS_LIBERACAO);  
        
        if REG.PRLI_CD_REVISAO_PRCS_LIBERACAO != V_CD_REVISAO_NOVO then
        
          SELECT SQ_PRLI_SQ_PROCESSO_LIBERACAO.nextval
          INTO V_ID_NOVO
          FROM DUAL;
        
          insert into PROCESSO_LIBERACAO 
          ( PRLI_SQ_PROCESSO_LIBERACAO
          , FICA_SQ_FICHA_CADASTRAL
          , PRLI_NR_PROCESSO_LIBERACAO
          , PRLI_CD_REVISAO_PRCS_LIBERACAO
          , FMWK_DT_ULTIMA_ATUALIZACAO
          , SIOB_SQ_SITUACAO_OBJETO
          , MORC_SQ_MOTIVO_REVS_CNCT
          , PRLI_TX_JSTF_REVS_CNCT
          , PRLI_IN_PROPRIETARIO
          , PRLI_IN_AREA_NOVA_AVALIAVEL
          , PRLI_IN_AREA_EXST_AVALIAVEL
          , PRLI_IN_AREA_NOVA_NEDF_AVLV
          , PRLI_IN_AREA_EXST_NEDF_AVLV
          , PRLI_IN_PPDD_PETROBRAS_AVLV
          , PRLI_SQ_PRCS_LBRC_VINCULADO
          , OBCA_SQ_OBJETIVO_CADASTRO
          , PRLI_IN_REVISAO)
          (SELECT V_ID_NOVO
                , FICA_SQ_FICHA_CADASTRAL
                , PRLI_NR_PROCESSO_LIBERACAO
                , V_CD_REVISAO_NOVO
                , SYSDATE
                , 1
                , MORC_SQ_MOTIVO_REVS_CNCT
                , PRLI_TX_JSTF_REVS_CNCT
                , PRLI_IN_PROPRIETARIO
                , PRLI_IN_AREA_NOVA_AVALIAVEL
                , PRLI_IN_AREA_EXST_AVALIAVEL
                , PRLI_IN_AREA_NOVA_NEDF_AVLV
                , PRLI_IN_AREA_EXST_NEDF_AVLV
                , PRLI_IN_PPDD_PETROBRAS_AVLV
                , PRLI_SQ_PRCS_LBRC_VINCULADO
                , OBCA_SQ_OBJETIVO_CADASTRO
                , 'N'
          FROM PROCESSO_LIBERACAO
          WHERE PRLI_SQ_PROCESSO_LIBERACAO = REG.PRLI_SQ_PROCESSO_LIBERACAO); 
          
          insert into movimento_workflow
          (MOWO_SQ_MOVIMENTO_WORKFLOW
          ,PRLI_SQ_PROCESSO_LIBERACAO
          ,SIOB_SQ_SITC_FICHA_CADASTRAL
          ,SIOB_SQ_SITC_PRCS_LIBERACAO
          ,SIWO_SQ_SITUACAO_WORKFLOW
          ,USUA_SQ_USUARIO_MOVIMENTO        
          ,FMWK_DT_ULTIMA_ATUALIZACAO)
          (select   SQ_MOWO_SQ_MOVIMENTO_WORKFLOW.NEXTVAL
                  , V_ID_NOVO
                  , 1
                  , 1
                  , 1
                  , P_ID_USUARIO              
                  , sysdate
          from DUAL);
          
          COMMIT;
                                  
          REVISAR_DEPENDENCIAS(REG.PRLI_SQ_PROCESSO_LIBERACAO,V_ID_NOVO,V_NM_TABELA); 
          
          /* Insere a Pessoa Nova nas Pessoas da FC */
          INSERIR_NOVA_PESE_FICHA(REG.FICA_SQ_FICHA_CADASTRAL, V_ID_NOVO, P_ID_PESE_ANTIGO, P_ID_PESE_NOVO);
          
          /* Cancela o Processo de Liberação Revisado */
          V_ID_MORC := MOTIVO_REVISAO('Cancelado por Revisão');
          
          update PROCESSO_LIBERACAO set
            SIOB_SQ_SITUACAO_OBJETO = 2,
            MORC_SQ_MOTIVO_REVS_CNCT = V_ID_MORC,
            PRLI_TX_JSTF_REVS_CNCT = 'Cancelado por Revisão'
          where PRLI_SQ_PROCESSO_LIBERACAO = REG.PRLI_SQ_PROCESSO_LIBERACAO;
          
          update PROCESSO_LIBERACAO set
            PRLI_SQ_PRCS_LBRC_VINCULADO = V_ID_NOVO
          where PRLI_SQ_PRCS_LBRC_VINCULADO = REG.PRLI_SQ_PROCESSO_LIBERACAO;
          
          /* Ativa a Ficha Cadastral */
          /*update FICHA_CADASTRAL set
            SIOB_SQ_SITUACAO_OBJETO = 1
          where SIOB_SQ_SITUACAO_OBJETO != 1
          and FICA_SQ_FICHA_CADASTRAL = 
            ( select FICA_SQ_FICHA_CADASTRAL 
              from PROCESSO_LIBERACAO 
              where PRLI_SQ_PROCESSO_LIBERACAO = REG.PRLI_SQ_PROCESSO_LIBERACAO);*/
          
          COMMIT;
          
          PCK_SISGT_PENDENCIAS.GERAR_PENDENCIAS(REG.FICA_SQ_FICHA_CADASTRAL);
        end if; 
      else
        /* Apenas Insere a Pessoa Nova nas Pessoas da FC */
        INSERIR_NOVA_PESE_FICHA(REG.FICA_SQ_FICHA_CADASTRAL, P_ID_PESE_ANTIGO, P_ID_PESE_NOVO);
      end if;
    end loop;
  EXCEPTION WHEN OTHERS THEN
    rollback;
    DELETE_CASCADE(V_ID_NOVO, 'PROCESSO_LIBERACAO');
    raise_application_error(-20001, 'Erro na Revisão.'||chr(13)||SQLERRM);
  END REVISAR_PL_POR_PESSOA;
  
  procedure VERIFICA_ATUALIZACAO_PESSOAS(P_ID_FICHA   IN NUMBER
                                        ,P_ID_PRLI    IN NUMBER
                                        ) AS
                                        
    V_ID_PESE_NOVA        NUMBER(20);
    V_NR_MAX_VERSAO_PESS  NUMBER(20);
  begin
    for reg in (select  PESE.PESE_SQ_PESSOA_SRVC_ENGENHARIA, 
                        PESS.PESS_CD_PESSOA, 
                        PESE.SEEN_SQ_SERVICO_ENGENHARIA
                from  GRUPO_PSSA_PROCESSO_LIBERACAO GPPL,
                      PSSA_VSND_FICHA_CADASTRAL PSFC,
                      PESSOA_SERVICO_ENGENHARIA PESE,
                      PESSOA_VERSIONADA PEVE,
                      PESSOA PESS
                where GPPL.PRLI_SQ_PROCESSO_LIBERACAO = P_ID_PRLI
                and PSFC.PSFC_SQ_PSSA_VSND_FICHA_CDTL = GPPL.PSFC_SQ_PSSA_VSND_FICHA_CDTL
                and PESE.PESE_SQ_PESSOA_SRVC_ENGENHARIA = PSFC.PESE_SQ_PESSOA_SRVC_ENGENHARIA
                and PEVE.PEVE_SQ_PESSOA_VERSIONADA = PESE.PEVE_SQ_PESSOA_VERSIONADA
                and PESS.PESS_SQ_PESSOA = PEVE.PESS_SQ_PESSOA
                and PESE.PESE_IN_VERSAO_ATUAL = 'N')
    loop
      begin
        select PESE_SQ_PESSOA_SRVC_ENGENHARIA
        into V_ID_PESE_NOVA
        from  PESSOA_SERVICO_ENGENHARIA PESE,
              PESSOA_VERSIONADA PEVE,
              PESSOA PESS
        where PEVE.PEVE_SQ_PESSOA_VERSIONADA = PESE.PEVE_SQ_PESSOA_VERSIONADA
        and PEVE.PESS_SQ_PESSOA = PESS.PESS_SQ_PESSOA
        and PESE.SEEN_SQ_SERVICO_ENGENHARIA = REG.SEEN_SQ_SERVICO_ENGENHARIA
        and PESE.PESE_IN_VERSAO_ATUAL = 'S'
        and PESS.PESS_CD_PESSOA = REG.PESS_CD_PESSOA;
      exception when no_data_found then        
        select MAX(PEVE_NR_VERSAO_PESSOA)        
        into V_NR_MAX_VERSAO_PESS
        from  PESSOA_SERVICO_ENGENHARIA PESE,
              PESSOA_VERSIONADA PEVE,
              PESSOA PESS
        where PEVE.PEVE_SQ_PESSOA_VERSIONADA = PESE.PEVE_SQ_PESSOA_VERSIONADA
        and PEVE.PESS_SQ_PESSOA = PESS.PESS_SQ_PESSOA
        and PESE.SEEN_SQ_SERVICO_ENGENHARIA = REG.SEEN_SQ_SERVICO_ENGENHARIA
        and PESS.PESS_CD_PESSOA = REG.PESS_CD_PESSOA;
        
        select PESE_SQ_PESSOA_SRVC_ENGENHARIA
        into V_ID_PESE_NOVA
        from PESSOA_SERVICO_ENGENHARIA PESE,
              PESSOA_VERSIONADA PEVE,
              PESSOA PESS
        where PEVE.PEVE_SQ_PESSOA_VERSIONADA = PESE.PEVE_SQ_PESSOA_VERSIONADA
        and PEVE.PESS_SQ_PESSOA = PESS.PESS_SQ_PESSOA
        and PESE.SEEN_SQ_SERVICO_ENGENHARIA = REG.SEEN_SQ_SERVICO_ENGENHARIA
        and PESS.PESS_CD_PESSOA = REG.PESS_CD_PESSOA
        and PEVE.PEVE_NR_VERSAO_PESSOA = V_NR_MAX_VERSAO_PESS;
        
        update PESSOA_SERVICO_ENGENHARIA set
          PESE_IN_VERSAO_ATUAL = 'S',
          PESE_IN_ATLZ_VERSAO_PESSOA = 'S'
        where PESE_SQ_PESSOA_SRVC_ENGENHARIA = V_ID_PESE_NOVA;
      end;
      
      INSERIR_NOVA_PESE_FICHA(P_ID_FICHA, P_ID_PRLI, REG.PESE_SQ_PESSOA_SRVC_ENGENHARIA, V_ID_PESE_NOVA);
      PCK_SISGT_PENDENCIAS.GERAR_PENDENCIAS(P_ID_FICHA);
    end loop; 
  EXCEPTION WHEN OTHERS THEN
    rollback;    
    raise_application_error(-20001, 'Erro na Revisão.'||chr(13)||SQLERRM);
  end;
  
  procedure INSERIR_NOVA_PESE_FICHA (P_ID_FICHA       IN NUMBER                                    
                                    ,P_ID_PESE_ANTIGO IN NUMBER
                                    ,P_ID_PESE_NOVO   IN NUMBER
                                    ) AS
  begin
    INSERIR_NOVA_PESE_FICHA (P_ID_FICHA, null, P_ID_PESE_ANTIGO, P_ID_PESE_NOVO);
  end;
  
  procedure INSERIR_NOVA_PESE_FICHA (P_ID_FICHA       IN NUMBER
                                    ,P_ID_PRLI        IN NUMBER
                                    ,P_ID_PESE_ANTIGO IN NUMBER
                                    ,P_ID_PESE_NOVO   IN NUMBER
                                    ) AS
                                    
    V_ID_PSFC_ANTIGO      number(20);
    V_ID_PSFC_NOVO        number(20);
    V_CT_PESE_NOVO        number(5);
  begin
  
    select count(*)
    into V_CT_PESE_NOVO
    from PSSA_VSND_FICHA_CADASTRAL
    where PESE_SQ_PESSOA_SRVC_ENGENHARIA = P_ID_PESE_NOVO
    and FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA;
    
    if (V_CT_PESE_NOVO = 0) then
      select SQ_PSFC_SQ_PSSA_VSND_FCHA_CDTL.nextval
      into V_ID_PSFC_NOVO
      from dual;
    
      insert into PSSA_VSND_FICHA_CADASTRAL
      (PSFC_SQ_PSSA_VSND_FICHA_CDTL
      ,PESE_SQ_PESSOA_SRVC_ENGENHARIA
      ,CLOC_SQ_CLSF_OCUPANTE
      ,FICA_SQ_FICHA_CADASTRAL
      ,FMWK_DT_ULTIMA_ATUALIZACAO)        
      (select V_ID_PSFC_NOVO,
      P_ID_PESE_NOVO,
      CLOC_SQ_CLSF_OCUPANTE,
      FICA_SQ_FICHA_CADASTRAL,
      sysdate
      from PSSA_VSND_FICHA_CADASTRAL
      where PESE_SQ_PESSOA_SRVC_ENGENHARIA = P_ID_PESE_ANTIGO
      and FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA);
    else
      select PSFC_SQ_PSSA_VSND_FICHA_CDTL 
      into V_ID_PSFC_NOVO
      from PSSA_VSND_FICHA_CADASTRAL
      where PESE_SQ_PESSOA_SRVC_ENGENHARIA = P_ID_PESE_NOVO
      and FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA;
    end if;
    
    select PSFC_SQ_PSSA_VSND_FICHA_CDTL
    into V_ID_PSFC_ANTIGO
    from PSSA_VSND_FICHA_CADASTRAL
    where PESE_SQ_PESSOA_SRVC_ENGENHARIA = P_ID_PESE_ANTIGO
    and FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA;
    
    if P_ID_PRLI is not null then      
      update GRUPO_PSSA_PROCESSO_LIBERACAO 
      set PSFC_SQ_PSSA_VSND_FICHA_CDTL = V_ID_PSFC_NOVO
      where PRLI_SQ_PROCESSO_LIBERACAO = P_ID_PRLI
      and PSFC_SQ_PSSA_VSND_FICHA_CDTL = V_ID_PSFC_ANTIGO;
    end if;  
    
    delete from PSSA_VSND_FICHA_CADASTRAL
    where PSFC_SQ_PSSA_VSND_FICHA_CDTL = V_ID_PSFC_ANTIGO
    and FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA
    and not exists (select 'x' from GRUPO_PSSA_PROCESSO_LIBERACAO
                    where PSFC_SQ_PSSA_VSND_FICHA_CDTL = V_ID_PSFC_ANTIGO);
    
    commit;
  EXCEPTION WHEN OTHERS THEN
    rollback;    
    raise_application_error(-20001, 'Erro na Atualização de Pessoa na FC.'||chr(13)||SQLERRM);
  end;
  
  procedure ATUALIZAR_FC_NOVO_IMOVEL(P_ID_IMSE_ANTIGO IN NUMBER
                                    ,P_ID_IMSE_NOVO   IN NUMBER) AS
  begin
    for reg in (select FICA_SQ_FICHA_CADASTRAL 
                from FICHA_CADASTRAL
                where IMSE_SQ_IMOVEL_SRVC_ENGENHARIA = P_ID_IMSE_ANTIGO
                and SIOB_SQ_SITUACAO_OBJETO = 1)
    loop
      update FICHA_CADASTRAL set
        IMSE_SQ_IMOVEL_SRVC_ENGENHARIA = P_ID_IMSE_NOVO
      where FICA_SQ_FICHA_CADASTRAL = reg.FICA_SQ_FICHA_CADASTRAL;
      
      commit;
      
      PCK_SISGT_PENDENCIAS.GERAR_PENDENCIAS(REG.FICA_SQ_FICHA_CADASTRAL);
    end loop;
  EXCEPTION WHEN OTHERS THEN
    rollback;    
    raise_application_error(-20001, 'Erro na Atualização do Imóvel na FC.'||chr(13)||SQLERRM);
  end;
  
  procedure ATUALIZAR_PL_NOVA_PESE(P_ID_PESE_ANTIGO IN NUMBER
                                  ,P_ID_PESE_NOVO   IN NUMBER) AS
  begin
    for reg in (select PSFC.FICA_SQ_FICHA_CADASTRAL, 
                       count(PRLI.PRLI_SQ_PROCESSO_LIBERACAO) CT_PRLI_PESE    
                from  PSSA_VSND_FICHA_CADASTRAL PSFC
                left join GRUPO_PSSA_PROCESSO_LIBERACAO GPPL on GPPL.PSFC_SQ_PSSA_VSND_FICHA_CDTL = PSFC.PSFC_SQ_PSSA_VSND_FICHA_CDTL
                left join PROCESSO_LIBERACAO PRLI on PRLI.PRLI_SQ_PROCESSO_LIBERACAO = GPPL.PRLI_SQ_PROCESSO_LIBERACAO and PRLI.SIOB_SQ_SITUACAO_OBJETO = 1
                where PSFC.PESE_SQ_PESSOA_SRVC_ENGENHARIA = P_ID_PESE_ANTIGO
                group by PSFC.FICA_SQ_FICHA_CADASTRAL)    
    loop
      if REG.CT_PRLI_PESE = 0 then
        INSERIR_NOVA_PESE_FICHA(REG.FICA_SQ_FICHA_CADASTRAL                               
                               ,P_ID_PESE_ANTIGO
                               ,P_ID_PESE_NOVO);
      else  
        for reg1 in (select PRLI.PRLI_SQ_PROCESSO_LIBERACAO
                    from  PSSA_VSND_FICHA_CADASTRAL PSFC,
                          GRUPO_PSSA_PROCESSO_LIBERACAO GPPL,
                          PROCESSO_LIBERACAO PRLI
                    where PSFC.PESE_SQ_PESSOA_SRVC_ENGENHARIA = P_ID_PESE_ANTIGO
                    and GPPL.PSFC_SQ_PSSA_VSND_FICHA_CDTL = PSFC.PSFC_SQ_PSSA_VSND_FICHA_CDTL
                    and PRLI.PRLI_SQ_PROCESSO_LIBERACAO = GPPL.PRLI_SQ_PROCESSO_LIBERACAO
                    and PRLI.SIOB_SQ_SITUACAO_OBJETO = 1)
        loop
          INSERIR_NOVA_PESE_FICHA(REG.FICA_SQ_FICHA_CADASTRAL
                                 ,REG1.PRLI_SQ_PROCESSO_LIBERACAO
                                 ,P_ID_PESE_ANTIGO
                                 ,P_ID_PESE_NOVO);                  
        end loop;
      end if;
      PCK_SISGT_PENDENCIAS.GERAR_PENDENCIAS(REG.FICA_SQ_FICHA_CADASTRAL);
    end loop;
  EXCEPTION WHEN OTHERS THEN
    rollback;    
    raise_application_error(-20001, 'Erro na Atualização de Pessoa na FC.'||chr(13)||SQLERRM);
  end;
  
  procedure ATUALIZAR_PROPRIETARIOS(P_ID_IMSE IN NUMBER) AS
    V_ID_PSFC     NUMBER(20);
    V_ID_CLOC     NUMBER(20) := 2; /* Classificação Ocupante de Proprietário */
    V_CT_PESE     NUMBER(5);
  begin
    for reg in (select FICA_SQ_FICHA_CADASTRAL 
                from FICHA_CADASTRAL
                where IMSE_SQ_IMOVEL_SRVC_ENGENHARIA = P_ID_IMSE)
    loop
      for reg1 in (select PESE_SQ_PESSOA_SRVC_ENGENHARIA
                  from PROPRIETARIO_IMOVEL PRIM
                  where PRIM.IMSE_SQ_IMOVEL_SRVC_ENGENHARIA = P_ID_IMSE
                  and not exists
                    (select 'x' from PSSA_VSND_FICHA_CADASTRAL PSFC
                    where PSFC.FICA_SQ_FICHA_CADASTRAL = reg.FICA_SQ_FICHA_CADASTRAL
                    and PSFC.PESE_SQ_PESSOA_SRVC_ENGENHARIA = PRIM.PESE_SQ_PESSOA_SRVC_ENGENHARIA
                    and PSFC.CLOC_SQ_CLSF_OCUPANTE = V_ID_CLOC))
      loop
        select count(*)
        into V_CT_PESE
        from PSSA_VSND_FICHA_CADASTRAL 
        where PESE_SQ_PESSOA_SRVC_ENGENHARIA = reg1.PESE_SQ_PESSOA_SRVC_ENGENHARIA
        and FICA_SQ_FICHA_CADASTRAL = reg.FICA_SQ_FICHA_CADASTRAL
        and CLOC_SQ_CLSF_OCUPANTE != V_ID_CLOC;
        
        if (V_CT_PESE > 0) then
          update PSSA_VSND_FICHA_CADASTRAL set
            CLOC_SQ_CLSF_OCUPANTE = V_ID_CLOC
          where PESE_SQ_PESSOA_SRVC_ENGENHARIA = reg1.PESE_SQ_PESSOA_SRVC_ENGENHARIA
          and FICA_SQ_FICHA_CADASTRAL = reg.FICA_SQ_FICHA_CADASTRAL;
        else      
          select SQ_PSFC_SQ_PSSA_VSND_FCHA_CDTL.nextval
          into V_ID_PSFC
          from dual;
        
          insert into PSSA_VSND_FICHA_CADASTRAL
          (PSFC_SQ_PSSA_VSND_FICHA_CDTL
          ,PESE_SQ_PESSOA_SRVC_ENGENHARIA
          ,CLOC_SQ_CLSF_OCUPANTE
          ,FICA_SQ_FICHA_CADASTRAL
          ,FMWK_DT_ULTIMA_ATUALIZACAO)  values
          (V_ID_PSFC,
           reg1.PESE_SQ_PESSOA_SRVC_ENGENHARIA,
           V_ID_CLOC,
           reg.FICA_SQ_FICHA_CADASTRAL,
           sysdate);
        end if;      
      end loop;      
      ATUALIZAR_PLS_PROPRIETARIOS(reg.FICA_SQ_FICHA_CADASTRAL);
      
      PCK_SISGT_PENDENCIAS.GERAR_PENDENCIAS(REG.FICA_SQ_FICHA_CADASTRAL);
    end loop;      
    commit;
  EXCEPTION WHEN OTHERS THEN
    rollback;    
    raise_application_error(-20001, 'Erro na atualização de Proprietários.'||chr(13)||SQLERRM);
  end;
  
  procedure ATUALIZAR_PLS_PROPRIETARIOS (P_ID_FICHA IN NUMBER) AS
  begin
  
    delete from GRUPO_PSSA_PROCESSO_LIBERACAO
    where PSFC_SQ_PSSA_VSND_FICHA_CDTL in
      (select PSFC_SQ_PSSA_VSND_FICHA_CDTL
       from PSSA_VSND_FICHA_CADASTRAL
       where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA
       and PESE_SQ_PESSOA_SRVC_ENGENHARIA not in
        (select PESE_SQ_PESSOA_SRVC_ENGENHARIA 
         from PROPRIETARIO_IMOVEL
         where IMSE_SQ_IMOVEL_SRVC_ENGENHARIA =
          (select IMSE_SQ_IMOVEL_SRVC_ENGENHARIA
           from FICHA_CADASTRAL
           where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA)));
           
    delete from PSSA_VSND_FICHA_CADASTRAL
    where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA
    and PESE_SQ_PESSOA_SRVC_ENGENHARIA not in
      (select PESE_SQ_PESSOA_SRVC_ENGENHARIA 
       from PROPRIETARIO_IMOVEL
       where IMSE_SQ_IMOVEL_SRVC_ENGENHARIA =
        (select IMSE_SQ_IMOVEL_SRVC_ENGENHARIA
         from FICHA_CADASTRAL
         where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA));
  
    for reg in (select PRLI_SQ_PROCESSO_LIBERACAO 
                       from PROCESSO_LIBERACAO
                       where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA
                       and SIOB_SQ_SITUACAO_OBJETO = 1
                       and PRLI_IN_PROPRIETARIO = 'S')
    loop
      delete from GRUPO_PSSA_PROCESSO_LIBERACAO
      where PRLI_SQ_PROCESSO_LIBERACAO = reg.PRLI_SQ_PROCESSO_LIBERACAO;
      
      for reg1 in (select PSFC_SQ_PSSA_VSND_FICHA_CDTL
                   from PSSA_VSND_FICHA_CADASTRAL
                   where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA
                   and CLOC_SQ_CLSF_OCUPANTE = 2)
      loop
        insert into GRUPO_PSSA_PROCESSO_LIBERACAO
        ( GRPP_SQ_GRUPO_PSSA_PROCESSO
        , PSFC_SQ_PSSA_VSND_FICHA_CDTL
        , PRLI_SQ_PROCESSO_LIBERACAO
        , FMWK_DT_ULTIMA_ATUALIZACAO)
        (select   SQ_GRPP_SQ_GRUPO_PSSA_PROCESSO.nextval
                , reg1.PSFC_SQ_PSSA_VSND_FICHA_CDTL
                , reg.PRLI_SQ_PROCESSO_LIBERACAO
                , sysdate
        from dual);
      end loop;
    end loop;
    
  end;

  function COLUNAS_TABELA(P_NM_TABELA IN VARCHAR2) RETURN VARCHAR2 AS
    V_NM_COLUNAS VARCHAR2(900);
      I NUMBER := 1;
    BEGIN
      FOR REG IN (SELECT COLUMN_NAME FROM USER_TAB_COLUMNS WHERE TABLE_NAME = P_NM_TABELA)
      LOOP
        IF I = 1 THEN
          V_NM_COLUNAS := REG.COLUMN_NAME;
        ELSE
          V_NM_COLUNAS := V_NM_COLUNAS||', '||REG.COLUMN_NAME;
        END IF;
        I := I+1;
      END LOOP;
      
      RETURN V_NM_COLUNAS;
    END COLUNAS_TABELA;

  function COPIAR_DADOS (P_ID_ANTIGO            IN NUMBER, 
                                   P_NM_TABELA            IN VARCHAR2) return number AS
    V_ID_NOVO           NUMBER;
    V_NM_SEQUENCE       VARCHAR2(30);
    V_NM_COLUNA_PK      VARCHAR2(30);
    V_NM_COLUNAS        VARCHAR2(900);
    V_NM_COLUNAS_INSERT VARCHAR2(900);
    V_INSERT            VARCHAR2(2000);
  BEGIN
    select c1.column_name
    into V_NM_COLUNA_PK
    from user_cons_columns c1, user_constraints c2
    where c1.table_name = P_NM_TABElA
    and c2.table_name = P_NM_TABElA
    and c1.owner = 'SISGT_OWNER'
    and c2.owner = 'SISGT_OWNER'
    and c2.constraint_type = 'P'
    and c1.constraint_name = c2.constraint_name; 
    
    select object_name
    into V_NM_SEQUENCE
    from user_objects
    where object_type = 'SEQUENCE'
    and object_name like 'SQ_'||substr(V_NM_COLUNA_PK,0,6)||'%';
  
    execute immediate 'select '||V_NM_SEQUENCE||'.nextval from dual ' into V_ID_NOVO;
    
    V_NM_COLUNAS := COLUNAS_TABELA(P_NM_TABELA);
    V_NM_COLUNAS_INSERT := replace(replace(V_NM_COLUNAS, V_NM_COLUNA_PK, V_ID_NOVO),'FMWK_DT_ULTIMA_ATUALIZACAO','sysdate');
  
    V_INSERT := 'INSERT INTO '||P_NM_TABELA||' ('||V_NM_COLUNAS||') (SELECT '||V_NM_COLUNAS_INSERT||' FROM '||P_NM_TABELA||' WHERE '||V_NM_COLUNA_PK||' = '||P_ID_ANTIGO||')';
  
    execute immediate V_INSERT;
      
    --execute immediate 'commit';
      
    return v_id_novo;
  END COPIAR_DADOS;
  
  function COPIAR_DADOS(P_ID_ANTIGO IN NUMBER, 
                        P_NM_TABELA IN VARCHAR2, 
                        P_ID_NOVO_PAI IN NUMBER, 
                        P_NM_COLUNA_FK IN VARCHAR2) return number AS
  begin
    return COPIAR_DADOS_VERSIONAR(P_ID_ANTIGO,
                        P_NM_TABELA,
                        P_ID_NOVO_PAI,
                        P_NM_COLUNA_FK,
                        null,
                        null);
  end;
                        
  
  function COPIAR_DADOS_VERSIONAR (P_ID_ANTIGO            IN NUMBER, 
                                   P_NM_TABELA            IN VARCHAR2, 
                                   P_ID_NOVO_PAI          IN NUMBER, 
                                   P_NM_COLUNA_FK         IN VARCHAR2,
                                   P_NM_COLUNA_VERSAO     IN VARCHAR2,
                                   P_VALOR_COLUNA_VERSAO  IN NUMBER) return number AS
    V_ID_NOVO           NUMBER;
    V_NM_SEQUENCE       VARCHAR2(30);
    V_NM_COLUNA_PK      VARCHAR2(30);
    V_NM_COLUNAS        VARCHAR2(900);
    V_NM_COLUNAS_INSERT VARCHAR2(900);
    V_INSERT            VARCHAR2(2000);
  BEGIN
    select c1.column_name
    into V_NM_COLUNA_PK
    from user_cons_columns c1, user_constraints c2
    where c1.table_name = P_NM_TABElA
    and c2.table_name = P_NM_TABElA
    and c1.owner = 'SISGT_OWNER'
    and c2.owner = 'SISGT_OWNER'
    and c2.constraint_type = 'P'
    and c1.constraint_name = c2.constraint_name; 
    
    select object_name
    into V_NM_SEQUENCE
    from user_objects
    where object_type = 'SEQUENCE'
    and object_name like 'SQ_'||substr(V_NM_COLUNA_PK,0,6)||'%';
  
    execute immediate 'select '||V_NM_SEQUENCE||'.nextval from dual ' into V_ID_NOVO;
    
    if(P_NM_TABELA in ('DADO_ESPACIAL_AREA_INTERESSE', 'DADO_ESPACIAL_IMOVEL', 'DADO_ESPACIAL_SERVIDAO')) then
      insert into DADO_ESPACIAL
        ( DAES_SQ_DADO_ESPACIAL
        , ORCO_SQ_ORIGEM_COORDENADA
        , FUHO_SQ_FUSO_HORARIO
        , TISP_SQ_TIPO_SISTEMA_PROJECAO
        , TIGE_SQ_TIPO_GEOMETRIA
        , FMWK_DT_ULTIMA_ATUALIZACAO
        , DAES_IN_TIPO_DADO_ESPACIAL
        , DAES_MD_COORDENADA
        , DAES_MD_AREA_PERIMETRO)
      (select   V_ID_NOVO
              , ORCO_SQ_ORIGEM_COORDENADA
              , FUHO_SQ_FUSO_HORARIO
              , TISP_SQ_TIPO_SISTEMA_PROJECAO
              , TIGE_SQ_TIPO_GEOMETRIA
              , sysdate
              , DAES_IN_TIPO_DADO_ESPACIAL
              , DAES_MD_COORDENADA
              , DAES_MD_AREA_PERIMETRO
      from DADO_ESPACIAL
      where DAES_SQ_DADO_ESPACIAL = P_ID_ANTIGO);
    end if;
    
    if (P_NM_TABELA in ('REGISTRO_OCORRENCIA_PESSOA','REGISTRO_OCORRENCIA_NEGOCIACAO')) then
      insert into REGISTRO_OCORRENCIA
        ( REOC_SQ_REGISTRO_OCORRENCIA
        , CACO_SQ_CANAL_CONTATO
        , ESAO_SQ_ESTRATEGIA_ATND_OCRC
        , RERO_SQ_RSPL_RGST_OCORRENCIA
        , REOC_IN_TIPO_OCORRENCIA
        , REOC_IN_CONTATO_EFETUADO
        , REOC_DT_REGISTRO_OCORRENCIA
        , REOC_TX_OUTRA_ESTRATEGIA_ATND
        , REOC_TX_REGISTRO_OCORRENCIA
        , FMWK_DT_ULTIMA_ATUALIZACAO)
      (select V_ID_NOVO
        , CACO_SQ_CANAL_CONTATO
        , ESAO_SQ_ESTRATEGIA_ATND_OCRC
        , RERO_SQ_RSPL_RGST_OCORRENCIA
        , REOC_IN_TIPO_OCORRENCIA
        , REOC_IN_CONTATO_EFETUADO
        , REOC_DT_REGISTRO_OCORRENCIA
        , REOC_TX_OUTRA_ESTRATEGIA_ATND
        , REOC_TX_REGISTRO_OCORRENCIA
        , sysdate
       from REGISTRO_OCORRENCIA
       where REOC_SQ_REGISTRO_OCORRENCIA = P_ID_ANTIGO);
    end if;
      
    V_NM_COLUNAS := COLUNAS_TABELA(P_NM_TABELA);
    V_NM_COLUNAS_INSERT := replace(replace(V_NM_COLUNAS, V_NM_COLUNA_PK, V_ID_NOVO),'FMWK_DT_ULTIMA_ATUALIZACAO','sysdate');
  
    if P_ID_NOVO_PAI > 0 then
      V_NM_COLUNAS_INSERT := replace(V_NM_COLUNAS_INSERT, P_NM_COLUNA_FK, P_ID_NOVO_PAI);
    end if;
    
    if (P_VALOR_COLUNA_VERSAO > 0) then
      V_NM_COLUNAS_INSERT := replace(V_NM_COLUNAS_INSERT, P_NM_COLUNA_VERSAO, P_VALOR_COLUNA_VERSAO);
    end if;
  
    V_INSERT := 'INSERT INTO '||P_NM_TABELA||' ('||V_NM_COLUNAS||') (SELECT '||V_NM_COLUNAS_INSERT||' FROM '||P_NM_TABELA||' WHERE '||V_NM_COLUNA_PK||' = '||P_ID_ANTIGO||')';
  
    execute immediate V_INSERT;
      
    --execute immediate 'commit';
      
    return v_id_novo;
  END COPIAR_DADOS_VERSIONAR;

  function GERAR_CODIGO_REVISAO(P_CD_REVISAO IN VARCHAR2) RETURN VARCHAR2 AS
    V_PRIMEIRO number(2);
    V_SEGUNDO number(2);
  BEGIN
    if LPAD(P_CD_REVISAO,2,'0') = '00' then
      return 'A';
    else
      V_PRIMEIRO := ASCII(substr(LPAD(P_CD_REVISAO,2,'0'),2,1));
      V_SEGUNDO := ASCII(substr(LPAD(P_CD_REVISAO,2,'0'),1,1));
      
      if chr(V_PRIMEIRO) = 'Z' and chr(V_SEGUNDO) = '0'  then
        V_SEGUNDO := 64;
      end if;
      
      V_PRIMEIRO := V_PRIMEIRO + 1;
      
      if (chr(V_SEGUNDO) != '0') then
        if(V_PRIMEIRO>90) then
          V_PRIMEIRO := 65;        
          V_SEGUNDO := V_SEGUNDO + 1;
        end if;
        
        if (V_SEGUNDO>90) then
          return P_CD_REVISAO;
        end if;
        
        return chr(V_SEGUNDO)||chr(V_PRIMEIRO);
      end if;
      
      return chr(V_PRIMEIRO);
    end if;
  END GERAR_CODIGO_REVISAO;


  FUNCTION MOTIVO_REVISAO(P_DESCRICAO IN VARCHAR2) RETURN NUMBER AS
    V_ID_MORC   NUMBER(20);
    V_CT_MORC   NUMBER(5);
  BEGIN
    SELECT COUNT(*)
    INTO V_CT_MORC
    FROM MOTIVO_REVISAO_CANCELAMENTO
    WHERE MORC_NM_MOTIVO_REVS_CNCT = P_DESCRICAO;
    
    IF V_CT_MORC = 0 THEN
      select SQ_MORC_SQ_MOTIVO_REVS_CNCT.nextval
      into V_ID_MORC
      from dual;
      
      insert into MOTIVO_REVISAO_CANCELAMENTO
        (MORC_SQ_MOTIVO_REVS_CNCT
        ,MORC_NM_MOTIVO_REVS_CNCT
        ,MORC_IN_ATIVO
        ,FMWK_DT_ULTIMA_ATUALIZACAO
        ,MORC_IN_CANCELAMENTO_FICHA
        ,MORC_IN_CANCELAMENTO_PROCESSO
        ,MORC_IN_REVISAO_PROCESSO)
      values
        (V_ID_MORC
        ,P_DESCRICAO
        ,'S'
        ,sysdate
        ,'N'
        ,'N'
        ,'N');
        
        commit;
    else
      select MORC_SQ_MOTIVO_REVS_CNCT
      into V_ID_MORC
      from MOTIVO_REVISAO_CANCELAMENTO
      where MORC_NM_MOTIVO_REVS_CNCT = P_DESCRICAO;      
    end if;
    
    return V_ID_MORC;
  END MOTIVO_REVISAO;
  
  PROCEDURE INSERIR_HISTORICO_NEGOCIACAO(P_ID_PRLS       IN NUMBER,
                                         P_TX_HISTORICO  IN VARCHAR2) AS
  BEGIN
    INSERIR_HISTORICO_NEGOCIACAO(P_ID_PRLS, P_TX_HISTORICO, null);
  END;
  
  PROCEDURE INSERIR_HISTORICO_NEGOCIACAO(P_ID_PRLS       IN NUMBER,
                                         P_TX_HISTORICO  IN VARCHAR2,
                                         P_ID_USPS       IN NUMBER) AS

    CT_RERO       NUMBER(3);
    V_ID_RERO     NUMBER(20) := null;
    V_ID_REOC     NUMBER(20);
    CT_OCNE       NUMBER(3);
    V_ID_OCNE     NUMBER(20);
    V_NGDR_APRS_CMDR CHAR(1 BYTE);
  BEGIN
    if (P_ID_USPS is not null) then
      select count(*)
      into CT_RERO
      from RESPONSAVEL_RGST_OCORRENCIA
      where USPS_SQ_USUA_PRESTACAO_SERVICO = P_ID_USPS;
      
      if (CT_RERO = 0) then
        select SQ_RERO_SQ_RSPL_RGST_OCRC.nextval
        into V_ID_RERO
        from dual;
      
        insert into RESPONSAVEL_RGST_OCORRENCIA
          (RERO_SQ_RSPL_RGST_OCORRENCIA,
           USPS_SQ_USUA_PRESTACAO_SERVICO,
           FMWK_DT_ULTIMA_ATUALIZACAO)
        values
          (V_ID_RERO,
           P_ID_USPS,
           sysdate);
      else
        select max(RERO_SQ_RSPL_RGST_OCORRENCIA)
        into V_ID_RERO
        from RESPONSAVEL_RGST_OCORRENCIA
        where USPS_SQ_USUA_PRESTACAO_SERVICO = P_ID_USPS;
      end if;
    end if;  
  
    select SQ_REOC_SQ_REGISTRO_OCORRENCIA.nextval
    into V_ID_REOC
    from dual;
    
    insert into REGISTRO_OCORRENCIA
      (REOC_SQ_REGISTRO_OCORRENCIA
      ,RERO_SQ_RSPL_RGST_OCORRENCIA
      ,CACO_SQ_CANAL_CONTATO
      ,ESAO_SQ_ESTRATEGIA_ATND_OCRC
      ,REOC_IN_TIPO_OCORRENCIA
      ,REOC_IN_CONTATO_EFETUADO
      ,REOC_DT_REGISTRO_OCORRENCIA
      ,REOC_TX_REGISTRO_OCORRENCIA
      ,FMWK_DT_ULTIMA_ATUALIZACAO)
    values
      (V_ID_REOC
      ,V_ID_RERO
      ,12
      ,4
      ,'N'
      ,'N'
      ,sysdate
      ,P_TX_HISTORICO
      ,sysdate);
    
    select count(*)
    into CT_OCNE
    from OCORRENCIA_NEGOCIACAO
    where PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS;
    
    if (CT_OCNE = 0) then
      select SQ_OCNE_SQ_OCORRENCIA_NGCC.nextval
      into V_ID_OCNE
      from dual;
    
      insert into OCORRENCIA_NEGOCIACAO
        (OCNE_SQ_OCORRENCIA_NEGOCIACAO
        ,PRLS_SQ_PRCS_LBRC_SRVC_ENGR
        ,SIOC_SQ_SITUACAO_OCORRENCIA
        ,FMWK_DT_ULTIMA_ATUALIZACAO)
      values
        (V_ID_OCNE
        ,P_ID_PRLS
        ,1
        ,sysdate);
    else
      select max(OCNE_SQ_OCORRENCIA_NEGOCIACAO)
      into V_ID_OCNE
      from OCORRENCIA_NEGOCIACAO
      where PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS; 
    end if;
    
     BEGIN
       SELECT REON_IN_NGDR_APRS_CMDR
         INTO V_NGDR_APRS_CMDR
         FROM REGISTRO_OCORRENCIA_NEGOCIACAO REON
        INNER JOIN OCORRENCIA_NEGOCIACAO OCNE ON REON.OCNE_SQ_OCORRENCIA_NEGOCIACAO = OCNE.OCNE_SQ_OCORRENCIA_NEGOCIACAO
        WHERE OCNE.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS
          AND REON.REOC_SQ_REGISTRO_OCORRENCIA = ( SELECT MAX(REOC_SQ_REGISTRO_OCORRENCIA)
                                                     FROM REGISTRO_OCORRENCIA_NEGOCIACAO MREG
                                                    INNER JOIN OCORRENCIA_NEGOCIACAO MCOR ON MREG.OCNE_SQ_OCORRENCIA_NEGOCIACAO = MCOR.OCNE_SQ_OCORRENCIA_NEGOCIACAO
                                                    WHERE MCOR.PRLS_SQ_PRCS_LBRC_SRVC_ENGR = P_ID_PRLS );
    EXCEPTION WHEN NO_DATA_FOUND THEN
      V_NGDR_APRS_CMDR := NULL;
    END;
    
    insert into REGISTRO_OCORRENCIA_NEGOCIACAO
      (REOC_SQ_REGISTRO_OCORRENCIA
      ,OCNE_SQ_OCORRENCIA_NEGOCIACAO
      ,REON_IN_NGDR_APRS_CMDR
      ,REON_IN_NGDR_ACOMPANHADO
      ,REON_IN_GERADOR_CRISE
      ,REON_IN_ABERTO_NEGOCIACAO
      ,REON_IN_SATISFEITO_NGCC
      ,FMWK_DT_ULTIMA_ATUALIZACAO)
    values
      (V_ID_REOC
      ,V_ID_OCNE
      ,V_NGDR_APRS_CMDR
      ,null
      ,null
      ,null
      ,null
      ,sysdate);
  END;

END PCK_SISGT_REVISAO;