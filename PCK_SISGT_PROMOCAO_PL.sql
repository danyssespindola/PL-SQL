create or replace
PACKAGE BODY PCK_SISGT_PROMOCAO_PL AS

  PROCEDURE PROMOVER(P_ID_PRLI IN NUMBER) AS
    V_ID_FICHA                NUMBER(20);
    V_ID_SERVICO              NUMBER(20);
  BEGIN
    select FICA_SQ_FICHA_CADASTRAL
      into V_ID_FICHA
      from PROCESSO_LIBERACAO
      where PRLI_SQ_PROCESSO_LIBERACAO = P_ID_PRLI;
  
    select distinct SEEN_SQ_SERVICO_ENGENHARIA
    into V_ID_SERVICO
    from PROCESSO_LIBERACAO_SRVC_ENGR
    where PRLS_SQ_PRCS_LBRC_SRVC_DESTINO is null
    and PRLI_SQ_PROCESSO_LIBERACAO IN 
      (select PRLI_SQ_PROCESSO_LIBERACAO 
       from PROCESSO_LIBERACAO PRLI, FICHA_CADASTRAL FICA
       where PRLI.FICA_SQ_FICHA_CADASTRAL = FICA.FICA_SQ_FICHA_CADASTRAL
       and FICA.FICA_NR_FICHA_CADASTRAL = 
        (select FICA_NR_FICHA_CADASTRAL 
         from FICHA_CADASTRAL 
         where FICA_SQ_FICHA_CADASTRAL = V_ID_FICHA));  
      
    PROMOVER(NULL, V_ID_SERVICO, P_ID_PRLI);
  EXCEPTION WHEN NO_DATA_FOUND THEN
    NULL;
  END;

  PROCEDURE PROMOVER(P_ID_USUARIO             IN NUMBER, 
                     P_ID_SERVICO             IN NUMBER,
                     P_ID_PROCESSO_LIBERACAO  IN NUMBER) AS

    V_ID_FICHA                NUMBER(20);
    V_ID_SIOB_FICHA           NUMBER(20);
    V_ID_SIOB_PRLI            NUMBER(20);
    V_NR_PROCESSO             NUMBER(3);
    V_CD_REVISAO_PROCESSO     VARCHAR2(2);
    V_ID_SERVICO              NUMBER(20);
    CT_PL_PROMOVIDO           NUMBER(2);
    V_ID_PRCS_LBRC_SRVC_ENGR  NUMBER(20);
    V_NM_TABELA               VARCHAR2(30) := 'PROCESSO_LIBERACAO_SRVC_ENGR';
    V_ID_PRLS_ANTIGO          NUMBER(20);
  BEGIN
    select PRLI_NR_PROCESSO_LIBERACAO, PRLI_CD_REVISAO_PRCS_LIBERACAO, SIOB_SQ_SITUACAO_OBJETO
    into V_NR_PROCESSO, V_CD_REVISAO_PROCESSO, V_ID_SIOB_PRLI
    from PROCESSO_LIBERACAO
    where PRLI_SQ_PROCESSO_LIBERACAO = P_ID_PROCESSO_LIBERACAO;
  
    if (V_ID_SIOB_PRLI = 3) then
      select FICA_SQ_FICHA_CADASTRAL, SIOB_SQ_SITUACAO_OBJETO
      into V_ID_FICHA, V_ID_SIOB_FICHA
      from PROCESSO_LIBERACAO
      where PRLI_SQ_PROCESSO_LIBERACAO = P_ID_PROCESSO_LIBERACAO;
      
      begin
        select distinct SEEN_SQ_SERVICO_ENGENHARIA
        into V_ID_SERVICO
        from PROCESSO_LIBERACAO_SRVC_ENGR
        where PRLS_SQ_PRCS_LBRC_SRVC_DESTINO is null
        and PRLI_SQ_PROCESSO_LIBERACAO IN 
          (select PRLI_SQ_PROCESSO_LIBERACAO 
           from PROCESSO_LIBERACAO PRLI, FICHA_CADASTRAL FICA
           where PRLI.FICA_SQ_FICHA_CADASTRAL = FICA.FICA_SQ_FICHA_CADASTRAL
           and FICA.FICA_NR_FICHA_CADASTRAL = 
            (select FICA_NR_FICHA_CADASTRAL 
             from FICHA_CADASTRAL 
             where FICA_SQ_FICHA_CADASTRAL = V_ID_FICHA));        
          
        /* Algum PL da Ficha já foi promovido, então todos serão promovidos para o mesmo servico */
        
        /* Seleciona o PL a ser promovido e as suas revisões anteriores canceladas */
        for reg in (select PRLI_SQ_PROCESSO_LIBERACAO, SIOB_SQ_SITUACAO_OBJETO
                    from PROCESSO_LIBERACAO PRLI
                    where PRLI_IN_REVISAO = 'N'
                    and 
                      ((PRLI.PRLI_NR_PROCESSO_LIBERACAO = V_NR_PROCESSO
                        and /*PRLI.PRLI_CD_REVISAO_PRCS_LIBERACAO < V_CD_REVISAO_PROCESSO
                        and*/ SIOB_SQ_SITUACAO_OBJETO = 2)
                      or (PRLI.PRLI_SQ_PROCESSO_LIBERACAO = P_ID_PROCESSO_LIBERACAO))
                    and PRLI_SQ_PROCESSO_LIBERACAO IN 
                      (select PRLI_SQ_PROCESSO_LIBERACAO 
                       from PROCESSO_LIBERACAO PRLI, FICHA_CADASTRAL FICA
                       where PRLI.FICA_SQ_FICHA_CADASTRAL = FICA.FICA_SQ_FICHA_CADASTRAL
                       and FICA.FICA_NR_FICHA_CADASTRAL = 
                        (select FICA_NR_FICHA_CADASTRAL 
                         from FICHA_CADASTRAL 
                         where FICA_SQ_FICHA_CADASTRAL = V_ID_FICHA))
                    and exists (select 'x' from AVALIACAO_SEPAV_TOTAL AVST 
                                where AVST.PRLI_SQ_PROCESSO_LIBERACAO = PRLI.PRLI_SQ_PROCESSO_LIBERACAO)
                    order by 1)
        loop        
          select count(*)
          into CT_PL_PROMOVIDO
          from PROCESSO_LIBERACAO_SRVC_ENGR
          where SEEN_SQ_SERVICO_ENGENHARIA = V_ID_SERVICO
          and PRLI_SQ_PROCESSO_LIBERACAO = REG.PRLI_SQ_PROCESSO_LIBERACAO;
          
          if (CT_PL_PROMOVIDO = 0) then
            /* Promove automaticamente*/
            select SQ_PRLS_SQ_PRCS_LBRC_SRVC_ENGR.nextval
            into V_ID_PRCS_LBRC_SRVC_ENGR
            from dual;
            
            insert into PROCESSO_LIBERACAO_SRVC_ENGR
              (PRLS_SQ_PRCS_LBRC_SRVC_ENGR,
               PRLI_SQ_PROCESSO_LIBERACAO,
               SEEN_SQ_SERVICO_ENGENHARIA,
               PRLS_IN_ATIVO,
               TINE_SQ_TIPO_NEGOCIACAO,
               FMWK_DT_ULTIMA_ATUALIZACAO)
            values
              (V_ID_PRCS_LBRC_SRVC_ENGR,
               REG.PRLI_SQ_PROCESSO_LIBERACAO,
               V_ID_SERVICO,
               'S',
               GET_TIPO_NEGOCIACAO(REG.PRLI_SQ_PROCESSO_LIBERACAO),
               sysdate);
            
            /* Coloca o PL no Status Workflow LIBERADO */
            insert into MOVIMENTO_WORKFLOW
              ( MOWO_SQ_MOVIMENTO_WORKFLOW
              , PRLI_SQ_PROCESSO_LIBERACAO
              , SIOB_SQ_SITC_FICHA_CADASTRAL
              , SIOB_SQ_SITC_PRCS_LIBERACAO
              , SIWO_SQ_SITUACAO_WORKFLOW
              , USUA_SQ_USUARIO_MOVIMENTO
              , FMWK_DT_ULTIMA_ATUALIZACAO)
            (select SQ_MOWO_SQ_MOVIMENTO_WORKFLOW.nextval,
                    REG.PRLI_SQ_PROCESSO_LIBERACAO,
                    V_ID_SIOB_FICHA,
                    REG.SIOB_SQ_SITUACAO_OBJETO,
                    9,
                    P_ID_USUARIO,
                    sysdate
              from dual);
            
            PCK_SISGT_STATUS_NEG_FINAL.VERIFICAR_STATUS(V_ID_PRCS_LBRC_SRVC_ENGR, P_ID_USUARIO);
            
            /* Verifica se existe uma versão anterior do mesmo PL já Promovida, de versão anterior à selecionada */
            begin
              select max(PRLS_SQ_PRCS_LBRC_SRVC_ENGR)
              into V_ID_PRLS_ANTIGO
              from PROCESSO_LIBERACAO_SRVC_ENGR PRLS,
                   PROCESSO_LIBERACAO PRLI
              where PRLS.PRLI_SQ_PROCESSO_LIBERACAO = PRLI.PRLI_SQ_PROCESSO_LIBERACAO
              and PRLI.PRLI_SQ_PROCESSO_LIBERACAO IN 
                (select PRLI_SQ_PROCESSO_LIBERACAO 
                 from PROCESSO_LIBERACAO PRLI, FICHA_CADASTRAL FICA
                 where PRLI.FICA_SQ_FICHA_CADASTRAL = FICA.FICA_SQ_FICHA_CADASTRAL
                 and FICA.FICA_NR_FICHA_CADASTRAL = 
                  (select FICA_NR_FICHA_CADASTRAL 
                   from FICHA_CADASTRAL 
                   where FICA_SQ_FICHA_CADASTRAL = V_ID_FICHA))
              and PRLI.PRLI_NR_PROCESSO_LIBERACAO = V_NR_PROCESSO
              and PRLI.PRLI_SQ_PROCESSO_LIBERACAO < REG.PRLI_SQ_PROCESSO_LIBERACAO
              and PRLS.SEEN_SQ_SERVICO_ENGENHARIA = V_ID_SERVICO
              and PRLI.PRLI_IN_REVISAO = 'S';
              
              if (V_ID_PRLS_ANTIGO is not null) then
                /* Copia os Dados Dependentes */ 
                PCK_SISGT_TRANSFERENCIA.ATUALIZAR_DEPENDENCIAS_PRLS(V_ID_PRLS_ANTIGO,V_ID_PRCS_LBRC_SRVC_ENGR,V_NM_TABELA,NULL,NULL); 
              
                if (REG.SIOB_SQ_SITUACAO_OBJETO = 3) then
                  update PROCESSO_LIBERACAO_SRVC_ENGR set
                    PRLS_IN_ATIVO = 'N'
                  where PRLS_SQ_PRCS_LBRC_SRVC_ENGR = V_ID_PRLS_ANTIGO; 
                  
                 PCK_SISGT_STATUS_NEG_FINAL.VERIFICAR_STATUS(V_ID_PRLS_ANTIGO, P_ID_USUARIO);   
                end if;
              end if;
            exception when NO_DATA_FOUND then
              null;
            end;
          end if;        
        end loop;
      exception when no_data_found then
        /* Não poderá fazer a promoção automática */
        select SQ_PRLS_SQ_PRCS_LBRC_SRVC_ENGR.nextval
        into V_ID_PRCS_LBRC_SRVC_ENGR
        from dual;
        
        insert into PROCESSO_LIBERACAO_SRVC_ENGR
              (PRLS_SQ_PRCS_LBRC_SRVC_ENGR,
               PRLI_SQ_PROCESSO_LIBERACAO,
               SEEN_SQ_SERVICO_ENGENHARIA,
               PRLS_IN_ATIVO,
               TINE_SQ_TIPO_NEGOCIACAO,
               FMWK_DT_ULTIMA_ATUALIZACAO)
            values
              (V_ID_PRCS_LBRC_SRVC_ENGR,
               P_ID_PROCESSO_LIBERACAO,
               P_ID_SERVICO,
               'S',
               GET_TIPO_NEGOCIACAO(P_ID_PROCESSO_LIBERACAO),
               sysdate);
            
          /* Coloca o PL no Status Workflow LIBERADO */
          insert into MOVIMENTO_WORKFLOW
            ( MOWO_SQ_MOVIMENTO_WORKFLOW
            , PRLI_SQ_PROCESSO_LIBERACAO
            , SIOB_SQ_SITC_FICHA_CADASTRAL
            , SIOB_SQ_SITC_PRCS_LIBERACAO
            , SIWO_SQ_SITUACAO_WORKFLOW
            , USUA_SQ_USUARIO_MOVIMENTO           
            , FMWK_DT_ULTIMA_ATUALIZACAO)
          (select SQ_MOWO_SQ_MOVIMENTO_WORKFLOW.nextval,
                  P_ID_PROCESSO_LIBERACAO,
                  V_ID_SIOB_FICHA,
                  (select SIOB_SQ_SITUACAO_OBJETO from PROCESSO_LIBERACAO where PRLI_SQ_PROCESSO_LIBERACAO = P_ID_PROCESSO_LIBERACAO), 
                  9, /*Liberado */
                  P_ID_USUARIO,
                  sysdate
            from dual);
        
        PCK_SISGT_STATUS_NEG_FINAL.VERIFICAR_STATUS(V_ID_PRCS_LBRC_SRVC_ENGR, P_ID_USUARIO);  
      end; 
      commit;
    end if;
  END PROMOVER;
  
  FUNCTION GET_TIPO_NEGOCIACAO(P_PROCESSO IN NUMBER) RETURN NUMBER AS
    V_ID_OBCA             NUMBER(20);
    V_ID_FICHA            NUMBER(20);
    V_IN_PROPRIETARIO     VARCHAR2(1);
    V_ID_TIPO_FICHA       NUMBER(20);
    V_VL_TERRA_NUA        NUMBER(20);
    V_VL_CONSTRUCAO       NUMBER(20);
    V_VL_EQUIPAMENTO      NUMBER(20);
    V_VL_VEGETACAO        NUMBER(20);
    V_VL_ATIVIDADE_ECON   NUMBER(20);
    
    V_IN_PROP_PETROBRAS   VARCHAR2(1);
    V_ID_NATUREZA         NUMBER(20);
    
    V_ID_TIPO_NEGOG       NUMBER(20);
  BEGIN
    select NVL(PRLI.OBCA_SQ_OBJETIVO_CADASTRO, PRLV.OBCA_SQ_OBJETIVO_CADASTRO), 
           PRLI.FICA_SQ_FICHA_CADASTRAL,
           PRLI.PRLI_IN_PROPRIETARIO
    into V_ID_OBCA, V_ID_FICHA, V_IN_PROPRIETARIO
    from PROCESSO_LIBERACAO PRLI
    left join PROCESSO_LIBERACAO PRLV on PRLV.PRLI_SQ_PROCESSO_LIBERACAO = PRLI.PRLI_SQ_PRCS_LBRC_VINCULADO
    where PRLI.PRLI_SQ_PROCESSO_LIBERACAO = P_PROCESSO;
    
    select  AVST_VL_DANO_DIRT_TERRA_NUA,
            AVST_VL_DANO_DIRT_CONSTRUCAO,
            AVST_VL_DANO_DIRT_EQUIPAMENTO,
            AVST_VL_DANO_DIRT_VEGETACAO,            
            AVST_VL_DANO_DIRT_ATVD_ECNC
    into  V_VL_TERRA_NUA,
          V_VL_CONSTRUCAO,
          V_VL_EQUIPAMENTO,
          V_VL_VEGETACAO,
          V_VL_ATIVIDADE_ECON
    from AVALIACAO_SEPAV_TOTAL
    where PRLI_SQ_PROCESSO_LIBERACAO = P_PROCESSO;
    
    select TIFC_SQ_TIPO_FICHA_CADASTRAL
    into V_ID_TIPO_FICHA
    from FICHA_CADASTRAL
    where FICA_SQ_FICHA_CADASTRAL = V_ID_FICHA;
    
    -- 4 - Interferência
    if (V_ID_TIPO_FICHA in (3,4)) then
      return 4;
    else
      select IMVE_IN_PROPRIEDADE_PETROBRAS, NAIM_SQ_NATUREZA_IMOVEL
      into V_IN_PROP_PETROBRAS, V_ID_NATUREZA
      from  FICHA_CADASTRAL FICA,
            IMOVEL_SERVICO_ENGENHARIA IMSE,
            IMOVEL_VERSIONADO IMVE
      where FICA.IMSE_SQ_IMOVEL_SRVC_ENGENHARIA = IMSE.IMSE_SQ_IMOVEL_SRVC_ENGENHARIA
      and IMSE.IMVE_SQ_IMOVEL_VERSIONADO = IMVE.IMVE_SQ_IMOVEL_VERSIONADO
      and FICA.FICA_SQ_FICHA_CADASTRAL = V_ID_FICHA;
      
      -- 2 - Imóvel Petrobrás
      if V_IN_PROP_PETROBRAS = 'S' then
        return 2;
      end if;
      
      -- 3 - Área Pública
      if V_ID_NATUREZA in (1,2,3) then
        return 3;
      end if;
    end if;
    
    -- 5 - Aquisição
    if V_ID_OBCA = 2 and V_VL_TERRA_NUA > 0 then
      return 5;
    end if;

    -- 6 - Servidão
    if V_ID_OBCA = 1 and V_VL_TERRA_NUA > 0 then
      return 6;
    end if;
    
    -- 1 - Somente Dano Direto
    if V_ID_OBCA in (1,2) then
      if (V_VL_CONSTRUCAO >0 or V_VL_EQUIPAMENTO >0 or V_VL_VEGETACAO >0 or V_VL_ATIVIDADE_ECON >0)
      then
        if V_IN_PROPRIETARIO = 'S' and V_VL_TERRA_NUA = 0 then
          return 1;
        end if;
        
        if V_IN_PROPRIETARIO = 'N' then
          return 1;
        end if;
      end if;
    end if;
    
    if V_ID_OBCA not in (1,2) then
      if V_IN_PROPRIETARIO = 'N' and 
        (V_VL_CONSTRUCAO >0 or V_VL_EQUIPAMENTO >0 or V_VL_VEGETACAO >0 or V_VL_ATIVIDADE_ECON >0)
      then
        return 1;
      end if;
    end if;
    
    -- 7 - Contratos
    if V_ID_OBCA in (4,7,9,10,11,12) and
      (V_VL_TERRA_NUA=0 and V_VL_CONSTRUCAO=0 and V_VL_EQUIPAMENTO=0 and V_VL_VEGETACAO=0 and V_VL_ATIVIDADE_ECON=0)
    then
      return 7;
    end if;
    
    -- 8 - Outros
    if (V_VL_TERRA_NUA=0 and V_VL_CONSTRUCAO=0 and V_VL_EQUIPAMENTO=0 and V_VL_VEGETACAO=0 and V_VL_ATIVIDADE_ECON=0)
      or V_ID_OBCA in (3,6,13,14)
    then
      return 8;
    end if;
    
    return 8;
  END GET_TIPO_NEGOCIACAO;

END PCK_SISGT_PROMOCAO_PL;