create or replace
PACKAGE BODY PCK_SISGT_PENDENCIAS AS

  PROCEDURE AREA_COORDENADA_AREA_IMOVEL(P_ID_FICHA IN NUMBER) AS
    ct_daes            number; 
    vl_area_coordenada number := 0;
    vl_area_imovel     number;
    ds_mensagem        varchar2(100) := 'Área total do imóvel [vl_imovel]m² diferente da Área encontrada nas coordenadas [vl_coordenada]m²';
    in_justificavel    varchar2(1) := 'N';
    in_impeditiva      varchar2(1) := 'N';
  BEGIN
    select nvl(imve_md_area_total,0)
    into vl_area_imovel
    from  ficha_cadastral fica,    
          imovel_servico_engenharia imse,
          imovel_versionado imve, 
          dado_espacial_imovel daei,
          dado_espacial daes
    where fica.fica_sq_ficha_cadastral = P_ID_FICHA
    and imse.imse_sq_imovel_srvc_engenharia = fica.imse_sq_imovel_srvc_engenharia
    and imve.imve_sq_imovel_versionado = imse.imve_sq_imovel_versionado
    and daei.imve_sq_imovel_versionado = imve.imve_sq_imovel_versionado
    and daes.daes_sq_dado_espacial = daei.daes_sq_dado_espacial_imovel
    and daes.orco_sq_origem_coordenada = 2;
    
    select COUNT(daes.daes_sq_dado_espacial)
    into CT_DAES
    from  ficha_cadastral fica,    
          imovel_servico_engenharia imse,
          imovel_versionado imve, 
          dado_espacial_imovel daei,
          dado_espacial daes
    where fica.fica_sq_ficha_cadastral = P_ID_FICHA
    and imse.imse_sq_imovel_srvc_engenharia = fica.imse_sq_imovel_srvc_engenharia
    and imve.imve_sq_imovel_versionado = imse.imve_sq_imovel_versionado
    and daei.imve_sq_imovel_versionado = imve.imve_sq_imovel_versionado
    and daes.daes_sq_dado_espacial = daei.daes_sq_dado_espacial_imovel
    and daes.orco_sq_origem_coordenada = 2;
    
    if(CT_DAES > 0) then
      select sum(nvl(SDO_GEOM.SDO_AREA(DAES_MD_COORDENADA, 0.005),0))
      into vl_area_coordenada
      from  ficha_cadastral fica,    
            imovel_servico_engenharia imse,
            imovel_versionado imve, 
            dado_espacial_imovel daei,
            dado_espacial daes
      where fica.fica_sq_ficha_cadastral = P_ID_FICHA
      and imse.imse_sq_imovel_srvc_engenharia = fica.imse_sq_imovel_srvc_engenharia
      and imve.imve_sq_imovel_versionado = imse.imve_sq_imovel_versionado
      and daei.imve_sq_imovel_versionado = imve.imve_sq_imovel_versionado
      and daes.daes_sq_dado_espacial = daei.daes_sq_dado_espacial_imovel
      and daes.orco_sq_origem_coordenada = 2;
    end if;
    
    ds_mensagem := replace(replace(ds_mensagem,'[vl_imovel]',trim(to_char(vl_area_imovel,'9G999G999G999G990D00'))),'[vl_coordenada]',trim(to_char(vl_area_coordenada,'9G999G999G999G990D00')));
    
    if CRIAR_PENDENCIA(p_id_ficha, ds_mensagem)  = 1 then
      if (vl_area_coordenada <> vl_area_imovel) then        
        INSERIR_PENDENCIA(P_ID_FICHA, 'Ficha de Cadastro', DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);        
      end if;
    end if;
  exception
    when no_data_found then
      /* caso seja uma ficha de interferencia ou não possua coordenadas*/
      null;
  END AREA_COORDENADA_AREA_IMOVEL;

  PROCEDURE AREA_INTERESSE_MAIOR_IMOVEL(P_ID_FICHA IN NUMBER) AS
    vl_area_interesse number;
    vl_area_imovel    number;
    ds_mensagem       varchar2(100) := 'Soma das áreas de interesse [vl_area_interesse] maior que a Área Total do imóvel [vl_imovel]';
    in_justificavel   varchar2(1) := 'N';
    in_impeditiva     varchar2(1) := 'S';
  BEGIN    
    select sum(nvl(arin.arin_md_area_nova,0))+sum(nvl(arin.arin_md_area_existente,0)), nvl(imve_md_area_total,0)
    into vl_area_interesse, vl_area_imovel
    from  ficha_cadastral fica,    
          imovel_servico_engenharia imse,
          imovel_versionado imve,
          area_interesse arin,
          processo_liberacao prli
    where fica.fica_sq_ficha_cadastral = P_ID_FICHA
    and prli.fica_sq_ficha_cadastral = fica.fica_sq_ficha_cadastral
    and arin.prli_sq_processo_liberacao = prli.prli_sq_processo_liberacao
    and imse.imse_sq_imovel_srvc_engenharia = fica.imse_sq_imovel_srvc_engenharia
    and imve.imve_sq_imovel_versionado = imse.imve_sq_imovel_versionado  
    and prli.siob_sq_situacao_objeto != 2
    group by nvl(imve_md_area_total,0);
    
    ds_mensagem := replace(replace(ds_mensagem,'[vl_area_interesse]',trim(to_char(vl_area_interesse,'9G999G999G999G990D00'))),'[vl_imovel]',trim(to_char(vl_area_imovel,'9G999G999G999G990D00')));
     
    if CRIAR_PENDENCIA(p_id_ficha, ds_mensagem)  = 1 then 
      if (vl_area_interesse > vl_area_imovel) then        
        INSERIR_PENDENCIA(P_ID_FICHA, 'Ficha de Cadastro', DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);        
      end if;
    end if;
  exception
    when no_data_found then
      /* caso seja uma ficha de interferencia */
      null;
  END AREA_INTERESSE_MAIOR_IMOVEL;

  PROCEDURE AREA_INTERESSE_NAO_INFORMADA(P_ID_FICHA IN NUMBER) AS
    vl_area_interesse number;
    id_tipo_ficha     number(1);
    ds_mensagem       varchar2(100) := 'Área de interesse não informada ou igual a 0';
    in_justificavel   varchar2(1) := 'N';
    in_impeditiva     varchar2(1) := 'S';
  BEGIN
    if CRIAR_PENDENCIA(p_id_ficha, ds_mensagem)  = 1 then
      select  nvl(sum(arin.arin_md_area_nova),0)+nvl(sum(arin.arin_md_area_existente),0), 
              fica.tifc_sq_tipo_ficha_cadastral
      into vl_area_interesse, id_tipo_ficha
      from  ficha_cadastral fica,    
            area_interesse arin,
            processo_liberacao prli
      where fica.fica_sq_ficha_cadastral = P_ID_FICHA      
      and prli.fica_sq_ficha_cadastral = fica.fica_sq_ficha_cadastral
      and arin.prli_sq_processo_liberacao(+) = prli.prli_sq_processo_liberacao 
      and prli.siob_sq_situacao_objeto != 2
      group by fica.tifc_sq_tipo_ficha_cadastral;
      
      /*Para fichas Simplificadas a pendência não é impeditiva*/
      if(id_tipo_ficha = 2) then
        in_impeditiva := 'N';
      end if;
      
      if (vl_area_interesse = 0) then      
        INSERIR_PENDENCIA(P_ID_FICHA, 'Ficha de Cadastro', DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);        
      end if;
    end if;
  exception
    when no_data_found then      
      null;
  END AREA_INTERESSE_NAO_INFORMADA;

  PROCEDURE AREA_INTERESSE_SERVIDAO_90(P_ID_FICHA IN NUMBER) AS
    vl_area_interesse number;
    vl_area_imovel    number;
    ds_mensagem       varchar2(100) := 'Área de Interesse para Servidão com percentual igual ou maior a 90% da área total do imóvel';
    in_justificavel   varchar2(1) := 'N';
    in_impeditiva     varchar2(1) := 'N';
  BEGIN
    if CRIAR_PENDENCIA(p_id_ficha, ds_mensagem)  = 1 then
      select sum(nvl(arin.arin_md_area_nova,0))+sum(nvl(arin.arin_md_area_existente,0)), nvl(imve_md_area_total,0)
      into vl_area_interesse, vl_area_imovel
      from  ficha_cadastral fica,    
            imovel_servico_engenharia imse,
            imovel_versionado imve,
            area_interesse arin,
            processo_liberacao prli
      where fica.fica_sq_ficha_cadastral = P_ID_FICHA
      and prli.fica_sq_ficha_cadastral = fica.fica_sq_ficha_cadastral
      and arin.prli_sq_processo_liberacao = prli.prli_sq_processo_liberacao
      and imse.imse_sq_imovel_srvc_engenharia = fica.imse_sq_imovel_srvc_engenharia
      and imve.imve_sq_imovel_versionado = imse.imve_sq_imovel_versionado      
      and obca_sq_objetivo_cadastro = 1
      and prli.siob_sq_situacao_objeto != 2
      group by nvl(imve_md_area_total,0);
      
      if vl_area_imovel > 0 then
        if ((vl_area_interesse/vl_area_imovel)*100 >= 90) then      
          INSERIR_PENDENCIA(P_ID_FICHA, 'Ficha de Cadastro', DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);        
        end if;
      end if;
    end if;
  exception
    when no_data_found then
      /* caso seja uma ficha de interferencia ou não tenha área para servidão*/
      null;
  END AREA_INTERESSE_SERVIDAO_90;
  
  PROCEDURE SERVIDAO_MAIOR_IMOVEL(P_ID_FICHA IN NUMBER) AS
    vl_area_servidao  number;
    vl_area_imovel    number;
    ds_mensagem       varchar2(100) := 'Área da Servidão [vl_servidao]m² maior que a Área Total do imóvel [vl_imovel]m²';
    in_justificavel   varchar2(1) := 'N';
    in_impeditiva     varchar2(1) := 'N';
  BEGIN    
    select sum(nvl(serv_md_area,0)), nvl(imve_md_area_total,0)
    into vl_area_servidao, vl_area_imovel
    from  ficha_cadastral fica, 
          imovel_servico_engenharia imse,
          imovel_versionado imve,
          servidao serv
    where fica.fica_sq_ficha_cadastral = P_ID_FICHA
    and imse.imse_sq_imovel_srvc_engenharia = fica.imse_sq_imovel_srvc_engenharia
    and imve.imve_sq_imovel_versionado = imse.imve_sq_imovel_versionado
    and serv.imve_sq_imovel_versionado = imve.imve_sq_imovel_versionado
    group by nvl(imve_md_area_total,0);
    
    ds_mensagem := replace(replace(ds_mensagem,'[vl_servidao]',trim(to_char(vl_area_servidao,'9G999G999G999G990D00'))),'[vl_imovel]',trim(to_char(vl_area_imovel,'9G999G999G999G990D00')));
     
    if CRIAR_PENDENCIA(p_id_ficha, ds_mensagem)  = 1 then 
      if (vl_area_servidao > vl_area_imovel) then        
        INSERIR_PENDENCIA(P_ID_FICHA, 'Imóvel', DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);        
      end if;
    end if;
  exception
    when no_data_found then
      /* caso seja uma ficha de interferencia */
      null;
  END SERVIDAO_MAIOR_IMOVEL;
  
  PROCEDURE IMOVEL_PROP_IRREGULAR(P_ID_FICHA IN NUMBER) AS
    ds_mensagem         varchar2(100) := 'Imóvel possui proprietário(s) irregular(es).';
    in_justificavel     varchar2(1) := 'N';
    in_impeditiva       varchar2(1) := 'N';
    ct_prop_irregular   number(3);
    ct_proprietarios    number(3);
  BEGIN
    if CRIAR_PENDENCIA(p_id_ficha, ds_mensagem) = 1 then
      select count(*)
      into CT_PROP_IRREGULAR
      from PROPRIETARIO_IMOVEL
      where PRIM_IN_SITUACAO_REGULAR = 'N'
      and IMSE_SQ_IMOVEL_SRVC_ENGENHARIA = (select IMSE_SQ_IMOVEL_SRVC_ENGENHARIA 
                                            from FICHA_CADASTRAL
                                            where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA);
                                            
      select count(*)
      into CT_PROPRIETARIOS
      from PROPRIETARIO_IMOVEL
      where IMSE_SQ_IMOVEL_SRVC_ENGENHARIA = (select IMSE_SQ_IMOVEL_SRVC_ENGENHARIA 
                                              from FICHA_CADASTRAL
                                              where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA);
                                              
      if CT_PROP_IRREGULAR > 0 then
        if CT_PROP_IRREGULAR = CT_PROPRIETARIOS then
          DS_MENSAGEM := 'Imovel possui todo(s) o(s) proprietários irregular(es).';
          IN_JUSTIFICAVEL := 'S';
          IN_IMPEDITIVA := 'S';
        end if;
        
        INSERIR_PENDENCIA(P_ID_FICHA, 'Imóvel', DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA); 
      end if;
    end if;
   exception
    when no_data_found then
      /* caso seja uma ficha de interferencia */
      null;
  END IMOVEL_PROP_IRREGULAR;
  
  PROCEDURE IMOVEL_NAO_REGULARIZADO(P_ID_FICHA IN NUMBER) AS
    v_sq_situacao_legal number(20);
    ds_mensagem         varchar2(100) := 'Imóvel com situação legal Não Regularizada.';
    in_justificavel     varchar2(1) := 'N';
    in_impeditiva       varchar2(1) := 'N';
  BEGIN
    if CRIAR_PENDENCIA(p_id_ficha, ds_mensagem)  = 1 then
      select SILE_SQ_SITUACAO_LEGAL
      into V_SQ_SITUACAO_LEGAL
      from  IMOVEL_VERSIONADO IMVE,
            IMOVEL_SERVICO_ENGENHARIA IMSE,
            FICHA_CADASTRAL FICA
      where IMVE.IMVE_SQ_IMOVEL_VERSIONADO = IMSE.IMVE_SQ_IMOVEL_VERSIONADO
      and IMSE.IMSE_SQ_IMOVEL_SRVC_ENGENHARIA = FICA.IMSE_SQ_IMOVEL_SRVC_ENGENHARIA
      and FICA.FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA;
      
      if (V_SQ_SITUACAO_LEGAL = 1) then
        INSERIR_PENDENCIA(P_ID_FICHA, 'Imóvel', DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA); 
      end if;
    end if;   
  exception
    when no_data_found then
      /* caso seja uma ficha de interferencia */
      null;
  END IMOVEL_NAO_REGULARIZADO;
  
  PROCEDURE IMOVEL_SEM_COORDENADAS(P_ID_FICHA IN NUMBER) AS
    id_imovel number;
    ct_dado_espacial number;
    ds_mensagem varchar2(100) := 'Imóvel cadastrado sem coordenadas';
    in_justificavel varchar2(1) := 'N';
    in_impeditiva   varchar2(1) := 'N';
  BEGIN
    if CRIAR_PENDENCIA(p_id_ficha, ds_mensagem)  = 1 then
      select imve_sq_imovel_versionado
      into id_imovel
      from  ficha_cadastral fica,
            imovel_servico_engenharia imse
      where imse.imse_sq_imovel_srvc_engenharia = fica.imse_sq_imovel_srvc_engenharia
      and fica.imse_sq_imovel_srvc_engenharia is not null
      and fica.fica_sq_ficha_cadastral = P_ID_FICHA;
      
      if id_imovel is not null then
        select count(*)
        into ct_dado_espacial
        from  dado_espacial_imovel daei
        where daei.imve_sq_imovel_versionado = id_imovel;
      
        if ct_dado_espacial= 0 then
          INSERIR_PENDENCIA(P_ID_FICHA, 'Imóvel', DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);        
        end if;
      end if;
    end if; 
  exception
    when no_data_found then
      /* caso seja uma ficha de interferencia */
      null;
  END IMOVEL_SEM_COORDENADAS;

  PROCEDURE IMOVEL_SEM_IMAGEM(P_ID_FICHA IN NUMBER) AS
    id_imovel       number;
    ct_arquivo      number;
    ds_mensagem     varchar2(100) := 'Imóvel cadastrado sem foto';
    in_justificavel varchar2(1) := 'N';
    in_impeditiva   varchar2(1) := 'N';
  BEGIN
    if CRIAR_PENDENCIA(p_id_ficha, ds_mensagem)  = 1 then
      select imse.imve_sq_imovel_versionado
      into id_imovel
      from ficha_cadastral fica,
            imovel_servico_engenharia imse
      where imse.imse_sq_imovel_srvc_engenharia = fica.imse_sq_imovel_srvc_engenharia
      and fica.imse_sq_imovel_srvc_engenharia is not null
      and fica.fica_sq_ficha_cadastral = P_ID_FICHA;
      
      if id_imovel is not null then
        select count(*)
        into ct_arquivo       
        from arquivo_imovel arim, documento docu
        where arim.docu_sq_documento = docu.docu_sq_documento
        and arim.imve_sq_imovel_versionado = id_imovel
        and docu.tido_sq_tipo_documento = 1; /*Alterar o Tipo Documento*/
      
        if ct_arquivo = 0 then
          INSERIR_PENDENCIA(P_ID_FICHA, 'Imóvel', DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);        
        end if;
      end if;
    end if; 
  exception
    when no_data_found then
      /* caso seja uma ficha de interferencia */
      null;
  END IMOVEL_SEM_IMAGEM;

  PROCEDURE IMOVEL_SEM_RGI(P_ID_FICHA IN NUMBER) AS
    id_imovel       number;
    ct_arquivo      number;
    ds_mensagem     varchar2(100) := 'Imóvel cadastrado sem documento anexo';
    in_justificavel varchar2(1) := 'S';
    in_impeditiva   varchar2(1) := 'S';
  BEGIN
    if CRIAR_PENDENCIA(p_id_ficha, ds_mensagem)  = 1 then
      select imse.imve_sq_imovel_versionado
      into id_imovel
      from ficha_cadastral fica,
            imovel_servico_engenharia imse
      where imse.imse_sq_imovel_srvc_engenharia = fica.imse_sq_imovel_srvc_engenharia
      and fica.imse_sq_imovel_srvc_engenharia is not null
      and fica.fica_sq_ficha_cadastral = P_ID_FICHA;
      
      if id_imovel is not null then
    
        select count(*)
        into ct_arquivo
        from arquivo_imovel arim, documento docu
        where arim.docu_sq_documento = docu.docu_sq_documento
        and arim.imve_sq_imovel_versionado = id_imovel
        and docu.tido_sq_tipo_documento = 27; /*Alterar o Tipo Documento*/
      
        if ct_arquivo = 0 then
          INSERIR_PENDENCIA(P_ID_FICHA, 'Imóvel', DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);        
        end if;
      end if;
    end if;
  exception
    when no_data_found then
      /* caso seja uma ficha de interferencia */
      null;
  END IMOVEL_SEM_RGI;
  
  PROCEDURE INTERF_NAO_REGULARIZADA(P_ID_FICHA IN NUMBER) AS
    v_sq_situacao_legal number(20);
    ds_mensagem         varchar2(100) := 'Interferência com situação legal Não Regularizada.';
    in_justificavel     varchar2(1) := 'N';
    in_impeditiva       varchar2(1) := 'N';
  BEGIN
    if CRIAR_PENDENCIA(p_id_ficha, ds_mensagem)  = 1 then
      select SILE_SQ_SITUACAO_LEGAL
      into V_SQ_SITUACAO_LEGAL
      from  INTERFERENCIA INTE,
            INTERFERENCIA_SRVC_ENGENHARIA INSE,
            FICHA_CADASTRAL FICA
      where INTE.INTE_SQ_INTERFERENCIA = inse.inte_sq_interferencia
      and inse.inse_sq_intf_srvc_engr = fica.inse_sq_intf_srvc_engr
      and FICA.FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA;
      
      if (V_SQ_SITUACAO_LEGAL = 1) then
        INSERIR_PENDENCIA(P_ID_FICHA, 'Interferência', DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA); 
      end if;
    end if;   
  exception
    when no_data_found then
      /* caso seja uma ficha de interferencia */
      null;
  END INTERF_NAO_REGULARIZADA;
  
  PROCEDURE INTERFERENCIA_FC_VINCULADA(P_ID_FICHA IN NUMBER) AS
    ds_mensagem     varchar2(100) := 'Ficha de Interferência Dentro do Imóvel sem Ficha Vinculada';
    in_justificavel varchar2(1) := 'N';
    in_impeditiva   varchar2(1) := 'S';
    
    V_ID_TIPO_FICHA       number(20);
    V_ID_FICHA_VINCULADA  number(20);
  BEGIN
    if CRIAR_PENDENCIA(p_id_ficha, ds_mensagem) = 1 then
      select  TIFC_SQ_TIPO_FICHA_CADASTRAL, 
              FICA_SQ_FICHA_CDTL_VINCULADA
      into  V_ID_TIPO_FICHA,
            V_ID_FICHA_VINCULADA
      from FICHA_CADASTRAL
      where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA;
      
      if (V_ID_TIPO_FICHA = 3 and V_ID_FICHA_VINCULADA is null) then
        INSERIR_PENDENCIA(P_ID_FICHA, 'Ficha Cadastral', ds_mensagem, in_justificavel, in_impeditiva);
      end if;
    end if;
  END INTERFERENCIA_FC_VINCULADA;
  
  PROCEDURE CONSTRUCAO_NAO_EDIFICANTE(P_ID_FICHA IN NUMBER) AS
    ds_origem         varchar2(100) := 'SISTEMA';
    ds_mensagem       varchar2(100) := 'Construção em área Não Edificante, mas FC não possui área deste tipo';
    ds_pls            varchar2(100);
    ct_construcao     number(5);
    ct_area_interesse number(5);
    in_justificavel   varchar2(1) := 'N';
    in_impeditiva     varchar2(1) := 'S';
  BEGIN
    if CRIAR_PENDENCIA(p_id_ficha, ds_mensagem)  = 1 then
      select count(*)
      into CT_CONSTRUCAO
      from CONSTRUCAO
      where CONS_IN_AREA_NAO_EDIFICANTE = 'S'
      and PRLI_SQ_PROCESSO_LIBERACAO IN 
        ( select PRLI_SQ_PROCESSO_LIBERACAO 
          from PROCESSO_LIBERACAO
          where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA);
          
      select count(*)
      into CT_AREA_INTERESSE
      from AREA_INTERESSE ARIN, TIPO_DESTINACAO_AREA TIDA
      where TIDA.TIDA_SQ_TIPO_DESTINACAO_AREA = ARIN.TIDA_SQ_TIPO_DESTINACAO_AREA
      and TIDA.TIDA_IN_TIPO_INSTALACAO = 3
      and PRLI_SQ_PROCESSO_LIBERACAO IN 
        ( select PRLI_SQ_PROCESSO_LIBERACAO 
          from PROCESSO_LIBERACAO 
          where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA);
      
      if CT_CONSTRUCAO > 0 and CT_AREA_INTERESSE = 0 then
        -- monta os PLs
        for reg1 in 
          (select distinct lpad(prli_nr_processo_liberacao,3,'0')||'-'||lpad(prli_cd_revisao_prcs_liberacao,2,'0') numero_processo
           from PROCESSO_LIBERACAO PRLI,                 
                CONSTRUCAO CONS
           where PRLI.FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA
           and CONS.PRLI_SQ_PROCESSO_LIBERACAO = PRLI.PRLI_SQ_PROCESSO_LIBERACAO
           and CONS.CONS_IN_AREA_NAO_EDIFICANTE = 'S'
           order by lpad(prli_nr_processo_liberacao,3,'0')||'-'||lpad(prli_cd_revisao_prcs_liberacao,2,'0'))
        loop
          ds_pls := ds_pls||reg1.numero_processo||', ';
        end loop;
        /* retira a última vírgula*/
        ds_pls := substr(ds_pls, 1, length(ds_pls)-2);          
        INSERIR_PENDENCIA(P_ID_FICHA, ds_origem, ds_pls, DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);      
      end if;      
    end if;
  exception
    when no_data_found then      
      null;
  END CONSTRUCAO_NAO_EDIFICANTE;
  
  PROCEDURE EQUIPAMENTO_NAO_EDIFICANTE(P_ID_FICHA IN NUMBER) AS
    ds_origem         varchar2(100) := 'SISTEMA';
    ds_mensagem       varchar2(100) := 'Equipamento em área Não Edificante, mas FC não possui área deste tipo';
    ds_pls            varchar2(100);
    ct_equipamento    number(5);
    ct_area_interesse number(5);
    in_justificavel   varchar2(1) := 'N';
    in_impeditiva     varchar2(1) := 'S';
  BEGIN
    if CRIAR_PENDENCIA(p_id_ficha, ds_mensagem)  = 1 then
      select count(*)
      into CT_EQUIPAMENTO
      from EQUIPAMENTO
      where EQUI_IN_AREA_NAO_EDIFICANTE = 'S'
      and PRLI_SQ_PROCESSO_LIBERACAO IN 
        ( select PRLI_SQ_PROCESSO_LIBERACAO 
          from PROCESSO_LIBERACAO 
          where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA);
          
      select count(*)
      into CT_AREA_INTERESSE
      from AREA_INTERESSE ARIN, TIPO_DESTINACAO_AREA TIDA
      where TIDA.TIDA_SQ_TIPO_DESTINACAO_AREA = ARIN.TIDA_SQ_TIPO_DESTINACAO_AREA
      and TIDA.TIDA_IN_TIPO_INSTALACAO = 3
      and PRLI_SQ_PROCESSO_LIBERACAO IN 
        ( select PRLI_SQ_PROCESSO_LIBERACAO 
          from PROCESSO_LIBERACAO 
          where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA);
      
      if CT_EQUIPAMENTO > 0 and CT_AREA_INTERESSE = 0 then
        -- monta os PLs
        for reg1 in 
          (select distinct lpad(prli_nr_processo_liberacao,3,'0')||'-'||lpad(prli_cd_revisao_prcs_liberacao,2,'0') numero_processo
           from PROCESSO_LIBERACAO PRLI,                 
                EQUIPAMENTO EQUI
           where PRLI.FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA
           and EQUI.PRLI_SQ_PROCESSO_LIBERACAO = PRLI.PRLI_SQ_PROCESSO_LIBERACAO
           and EQUI.EQUI_IN_AREA_NAO_EDIFICANTE = 'S'
           order by lpad(prli_nr_processo_liberacao,3,'0')||'-'||lpad(prli_cd_revisao_prcs_liberacao,2,'0'))
        loop
          ds_pls := ds_pls||reg1.numero_processo||', ';
        end loop;
        /* retira a última vírgula*/
        ds_pls := substr(ds_pls, 1, length(ds_pls)-2);          
        INSERIR_PENDENCIA(P_ID_FICHA, ds_origem, ds_pls, DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);      
      end if;      
    end if;
  exception
    when no_data_found then      
      null;
  END EQUIPAMENTO_NAO_EDIFICANTE;
  
  PROCEDURE COBERTURA_NAO_EDIFICANTE(P_ID_FICHA IN NUMBER) AS
    ds_origem         varchar2(100) := 'SISTEMA';
    ds_mensagem       varchar2(100) := 'Cobertura Vegetal Mineral em área Não Edificante, mas FC não possui área deste tipo';
    ds_pls            varchar2(100);
    ct_cobertura      number(5);
    ct_area_interesse number(5);
    in_justificavel   varchar2(1) := 'N';
    in_impeditiva     varchar2(1) := 'S';
  BEGIN
    if CRIAR_PENDENCIA(p_id_ficha, ds_mensagem)  = 1 then
      select count(*)
      into CT_COBERTURA
      from COBERTURA_VEGETAL_MINERAL
      where COVM_IN_AREA_NAO_EDIFICANTE = 'S'
      and PRLI_SQ_PROCESSO_LIBERACAO IN 
        ( select PRLI_SQ_PROCESSO_LIBERACAO 
          from PROCESSO_LIBERACAO 
          where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA);
          
      select count(*)
      into CT_AREA_INTERESSE
      from AREA_INTERESSE ARIN, TIPO_DESTINACAO_AREA TIDA
      where TIDA.TIDA_SQ_TIPO_DESTINACAO_AREA = ARIN.TIDA_SQ_TIPO_DESTINACAO_AREA
      and TIDA.TIDA_IN_TIPO_INSTALACAO = 3
      and PRLI_SQ_PROCESSO_LIBERACAO IN 
        ( select PRLI_SQ_PROCESSO_LIBERACAO 
          from PROCESSO_LIBERACAO 
          where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA);
      
      if CT_COBERTURA > 0 and CT_AREA_INTERESSE = 0 then
        -- monta os PLs
        for reg1 in 
          (select distinct lpad(prli_nr_processo_liberacao,3,'0')||'-'||lpad(prli_cd_revisao_prcs_liberacao,2,'0') numero_processo
           from PROCESSO_LIBERACAO PRLI,                 
                COBERTURA_VEGETAL_MINERAL COVM
           where PRLI.FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA
           and COVM.PRLI_SQ_PROCESSO_LIBERACAO = PRLI.PRLI_SQ_PROCESSO_LIBERACAO
           and COVM.COVM_IN_AREA_NAO_EDIFICANTE = 'S'
           order by lpad(prli_nr_processo_liberacao,3,'0')||'-'||lpad(prli_cd_revisao_prcs_liberacao,2,'0'))
        loop
          ds_pls := ds_pls||reg1.numero_processo||', ';
        end loop;
        /* retira a última vírgula*/
        ds_pls := substr(ds_pls, 1, length(ds_pls)-2);          
        INSERIR_PENDENCIA(P_ID_FICHA, ds_origem, ds_pls, DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);      
      end if;      
    end if;
  exception
    when no_data_found then      
      null;
  END COBERTURA_NAO_EDIFICANTE;
  
  PROCEDURE FICHA_SEM_INSTALACAO(P_ID_FICHA IN NUMBER) AS
    ct_instalacao   number;
    ds_mensagem     varchar2(100) := 'Ficha sem instalação';
    in_justificavel varchar2(1) := 'S';
    in_impeditiva   varchar2(1) := 'S';
  BEGIN
    if CRIAR_PENDENCIA(p_id_ficha, ds_mensagem)  = 1 then
      select count(*)
      into ct_instalacao
      from  intc_obra_srvc_ficha_cadastral          
      where fica_sq_ficha_cadastral = P_ID_FICHA;
      
      if ct_instalacao = 0 then
        INSERIR_PENDENCIA(P_ID_FICHA, 'Ficha de Cadastro', DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);        
      end if;
    end if;
  END FICHA_SEM_INSTALACAO;
  
  PROCEDURE FICHA_SIMPLIFICADA(P_ID_FICHA IN NUMBER) AS
    v_tipo_ficha    number;
    ds_mensagem     varchar2(100) := 'Ficha Simplificada';
    in_justificavel varchar2(1) := 'S';
    in_impeditiva   varchar2(1) := 'S';
  BEGIN
    if CRIAR_PENDENCIA(p_id_ficha, ds_mensagem)  = 1 then
      select TIFC_SQ_TIPO_FICHA_CADASTRAL
      into V_TIPO_FICHA
      from  FICHA_CADASTRAL
      where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA;
      
      if V_TIPO_FICHA = 2 then /*Ficha Por Imóvel Simplificada*/
        INSERIR_PENDENCIA(P_ID_FICHA, 'Ficha de Cadastro', DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);        
      end if;
    end if;
  END FICHA_SIMPLIFICADA;
  
  PROCEDURE AUSENTE_SEM_IMAGEM(P_ID_FICHA IN NUMBER) IS
    t_pessoas        TABLE_T_PESE_NOME;
    ds_origem        varchar2(100);
    ds_secao         varchar2(255);
    ds_mensagem      varchar2(100) := 'Pessoa ausente sem documento anexo';
    in_justificavel  varchar2(1) := 'S';
    in_impeditiva    varchar2(1) := 'S';
  BEGIN    
    t_pessoas := CONDICAO_PESSOA_SEM_ARQUIVO(P_ID_FICHA, 'F', 3, 1);
    /*Atualizar o tipo documento*/
    
    if t_pessoas is null or t_pessoas.count=0 then
      return;
    end if;
    
    for i in t_pessoas.FIRST..t_pessoas.LAST loop
      ds_origem := t_pessoas(i).nome_pessoa;
      ds_secao := SELECIONAR_PLS(P_ID_FICHA, t_pessoas(i).id_pessoa_srvc_engenharia);
      
      if ds_secao is not null then
        if CRIAR_PENDENCIA(p_id_ficha, ds_origem, ds_secao, ds_mensagem)  = 1 then  
          INSERIR_PENDENCIA(P_ID_FICHA, ds_origem, ds_secao, DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);
        end if;
      end if;
    end loop;
      

  END AUSENTE_SEM_IMAGEM;

  PROCEDURE CONJUGE_SEM_IMAGEM(P_ID_FICHA IN NUMBER) AS   
    ds_origem       varchar2(100);
    ds_secao        varchar2(255);
    ds_mensagem     varchar2(100) := 'Pessoa casada sem documento anexo';
    in_justificavel varchar2(1) := 'S';
    in_impeditiva   varchar2(1) := 'S';
  BEGIN
    for reg in 
      (select peve.peve_nm_pessoa, pese.pese_sq_pessoa_srvc_engenharia      
      from  PSSA_VSND_FICHA_CADASTRAL pvfc, 
          pessoa_servico_engenharia pese,
          pessoa_versionada peve,
          pessoa_fisica pefi,
          relacionamento_pessoa repe
      where pvfc.pese_sq_pessoa_srvc_engenharia = pese.pese_sq_pessoa_srvc_engenharia
      and   peve.peve_sq_pessoa_versionada = pese.peve_sq_pessoa_versionada
      and   pefi.peve_sq_pessoa_versionada = peve.peve_sq_pessoa_versionada
      and  ( (repe.peve_sq_pessoa_vrnd_origem = peve.peve_sq_pessoa_versionada and repe.tire_sq_tipo_rlcm_origem = 1)
            or (repe.peve_sq_pessoa_vrnd_destino = peve.peve_sq_pessoa_versionada and repe.tire_sq_tipo_rlcm_destino = 1))
      and   pvfc.fica_sq_ficha_cadastral = P_ID_FICHA
      and   peve.peve_in_tipo_pessoa = 'F'
      and   pefi.esci_sq_estado_civil = 2
      and   not exists 
        (select 'x' 
        from arquivo_relacionamento arre, documento docu
        where arre.docu_sq_documento = docu.docu_sq_documento
        and docu.tido_sq_tipo_documento = 13
        and arre.repe_sq_relacionamento_pessoa = repe.repe_sq_relacionamento_pessoa))
    loop
      ds_origem := reg.peve_nm_pessoa;
      ds_secao := SELECIONAR_PLS(P_ID_FICHA, reg.pese_sq_pessoa_srvc_engenharia);
      
      if ds_secao is not null then
        if CRIAR_PENDENCIA(p_id_ficha, ds_origem, ds_secao, ds_mensagem)  = 1 then  
          INSERIR_PENDENCIA(P_ID_FICHA, ds_origem, ds_secao, DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);      
        end if;
      end if;
    end loop;    
  END CONJUGE_SEM_IMAGEM;

  PROCEDURE CPFCNPJ_SEM_IMAGEM(P_ID_FICHA IN NUMBER) AS    
    ds_origem       varchar2(100);
    ds_secao        varchar2(255);
    ds_mensagem     varchar2(100) := 'CPF/CNPJ informado sem imagem anexa';
    in_justificavel varchar2(1) := 'S';
    in_impeditiva   varchar2(1) := 'S';
    ct_arquivo      number := 0;
  BEGIN
    for reg in 
      (select peve.peve_nm_pessoa, pese.pese_sq_pessoa_srvc_engenharia, pese.peve_sq_pessoa_versionada
      from  PSSA_VSND_FICHA_CADASTRAL pvfc, 
            pessoa_servico_engenharia pese,
            pessoa_versionada peve
      where pvfc.pese_sq_pessoa_srvc_engenharia = pese.pese_sq_pessoa_srvc_engenharia
      and   pese.peve_sq_pessoa_versionada = peve.peve_sq_pessoa_versionada
      and   pvfc.fica_sq_ficha_cadastral = P_ID_FICHA)
    loop
      
      begin
        
        select count(*)
        into ct_arquivo
        from arquivo_pessoa arpe, documento docu, pessoa_versionada peve
        where arpe.docu_sq_documento = docu.docu_sq_documento
        and arpe.peve_sq_pessoa_versionada = reg.peve_sq_pessoa_versionada
        and peve.peve_sq_pessoa_versionada = arpe.peve_sq_pessoa_versionada
        and ((peve.peve_in_tipo_pessoa = 'F' and docu.tido_sq_tipo_documento = 5)
        or(peve.peve_in_tipo_pessoa = 'J' and docu.tido_sq_tipo_documento = 33))
        and peve.peve_sq_pessoa_versionada = reg.peve_sq_pessoa_versionada;
        
        if (ct_arquivo >= 1) then
          
          delete from pendencia_ficha_cadastral
          where pefc_sq_pendencia_ficha_cdtl in 
          ( select pefc_sq_pendencia_ficha_cdtl
            from pendencia_ficha_cadastral 
            where fica_sq_ficha_cadastral = P_ID_FICHA
            and pefc_ds_justificativa is null
            and pefc_tx_pendencia = DS_MENSAGEM
            and ((pefc_ds_origem = ds_origem) or (ds_origem is null))
            and ((pefc_ds_secao = ds_secao) or (ds_secao is null)));
          commit;
          
        else
        
          ds_origem := reg.peve_nm_pessoa;
          ds_secao := SELECIONAR_PLS(P_ID_FICHA, reg.pese_sq_pessoa_srvc_engenharia);
          
          if ds_secao is not null then
            if CRIAR_PENDENCIA(p_id_ficha, ds_origem, ds_secao, ds_mensagem)  = 1 then  
              INSERIR_PENDENCIA(P_ID_FICHA, ds_origem, ds_secao, DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);      
            end if;        
          end if;
        
        end if;
      
      exception
      when no_data_found then      
        null;
      end;
      
    end loop;  
  END CPFCNPJ_SEM_IMAGEM;

  PROCEDURE ESPOLIO_SEM_IMAGEM(P_ID_FICHA IN NUMBER) AS
    t_arquivo_cope  TABLE_T_PESE_NOME;
    t_arquivo_repe  TABLE_T_PESE_NOME;
    ct_pese         number(1);
    ds_origem       varchar2(100);
    ds_secao        varchar2(255);
    ds_mensagem     varchar2(100) := 'Pessoa espólio sem documento anexo';
    in_justificavel varchar2(1) := 'S';
    in_impeditiva   varchar2(1) := 'S';
  BEGIN    
    t_arquivo_cope := CONDICAO_PESSOA_SEM_ARQUIVO(P_ID_FICHA, 'F', 4, 1);
  
    t_arquivo_repe := RELACIONAMENTO_SEM_ARQUIVO(P_ID_FICHA, 'F', 10, 1); 
   
    if (t_arquivo_cope is null or t_arquivo_cope.count=0) 
      and (t_arquivo_repe is null or t_arquivo_repe.count=0) 
    then
      return;
    end if;
    
    if(t_arquivo_cope.count>0) then
      for i in t_arquivo_cope.FIRST..t_arquivo_cope.LAST loop
        ds_origem := t_arquivo_cope(i).nome_pessoa;
        ds_secao := SELECIONAR_PLS(P_ID_FICHA, t_arquivo_cope(i).id_pessoa_srvc_engenharia);
        
        if ds_secao is not null then
          if CRIAR_PENDENCIA(p_id_ficha, ds_origem, ds_secao, ds_mensagem)  = 1 then  
            INSERIR_PENDENCIA(P_ID_FICHA, ds_origem, ds_secao, DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);
          end if;
        end if;
      end loop;
    end if;
    
    if (t_arquivo_repe.count>0) then
      for i in t_arquivo_repe.FIRST..t_arquivo_repe.LAST loop
        ds_origem := t_arquivo_repe(i).nome_pessoa;
        ds_secao := SELECIONAR_PLS(P_ID_FICHA, t_arquivo_repe(i).id_pessoa_srvc_engenharia);
        
        if ds_secao is not null then
          if CRIAR_PENDENCIA(p_id_ficha, ds_origem, ds_secao, ds_mensagem)  = 1 then  
            INSERIR_PENDENCIA(P_ID_FICHA, ds_origem, ds_secao, DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);
          end if;
        end if;
      end loop;
    end if;  
  END ESPOLIO_SEM_IMAGEM;  

  PROCEDURE HERDEIRO_SEM_IMAGEM(P_ID_FICHA IN NUMBER) AS
    ds_origem       varchar2(100);
    ds_secao        varchar2(255);
    t_pessoas       TABLE_T_PESE_NOME;
    ds_mensagem     varchar2(100) := 'Pessoa herdeiro sem documento anexo';
    in_justificavel varchar2(1) := 'S';
    in_impeditiva   varchar2(1) := 'S';
  BEGIN
        
    t_pessoas := RELACIONAMENTO_SEM_ARQUIVO(P_ID_FICHA, 'F', 11, 1);
    /*Atualizar o Tipo Documento*/
    
    if t_pessoas is null or t_pessoas.count=0 then
      return;
    end if;
    
    for i in t_pessoas.FIRST..t_pessoas.LAST loop
      ds_origem := t_pessoas(i).nome_pessoa;
      ds_secao := SELECIONAR_PLS(P_ID_FICHA, t_pessoas(i).id_pessoa_srvc_engenharia);
      
      if ds_secao is not null then
        if CRIAR_PENDENCIA(p_id_ficha, ds_origem, ds_secao, ds_mensagem)  = 1 then  
          INSERIR_PENDENCIA(P_ID_FICHA, ds_origem, ds_secao, DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);
        end if;
      end if;
    end loop;
    
  END HERDEIRO_SEM_IMAGEM;

  PROCEDURE IDENTIFICACAO_SEM_IMAGEM(P_ID_FICHA IN NUMBER) AS
    ds_origem       varchar2(100);
    ds_secao        varchar2(255);
    ds_mensagem     varchar2(100) := 'Documento de Identificação informado sem imagem anexa';
    in_justificavel varchar2(1) := 'S';
    in_impeditiva   varchar2(1) := 'S';
  BEGIN
    for reg in
      (select peve.peve_nm_pessoa, pese.pese_sq_pessoa_srvc_engenharia      
      from  PSSA_VSND_FICHA_CADASTRAL pvfc, 
          pessoa_servico_engenharia pese,
          pessoa_versionada peve,
          identificacao_pessoa_fisica idpf
      where pvfc.pese_sq_pessoa_srvc_engenharia = pese.pese_sq_pessoa_srvc_engenharia
      and   pese.peve_sq_pessoa_versionada = peve.peve_sq_pessoa_versionada
      and   idpf.peve_sq_pessoa_versionada = peve.peve_sq_pessoa_versionada
      and   pvfc.fica_sq_ficha_cadastral = P_ID_FICHA
      and   peve.peve_in_tipo_pessoa = 'F'
      and   idpf.idpf_nr_doct_identificacao is not null
      and   not exists 
        (select 'x' 
        from arquivo_pessoa arpe, documento docu
        where arpe.docu_sq_documento = docu.docu_sq_documento
        and arpe.peve_sq_pessoa_versionada = peve.peve_sq_pessoa_versionada
        and docu.tido_sq_tipo_documento = idpf.tido_sq_tipo_documento))
    loop
      ds_origem := reg.peve_nm_pessoa;
      ds_secao := SELECIONAR_PLS(P_ID_FICHA, reg.pese_sq_pessoa_srvc_engenharia);
      
      if ds_secao is not null then
        if CRIAR_PENDENCIA(p_id_ficha, ds_origem, ds_secao, ds_mensagem)  = 1 then  
          INSERIR_PENDENCIA(P_ID_FICHA, ds_origem, ds_secao, DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);      
        end if;
      end if;
    end loop;    
  END IDENTIFICACAO_SEM_IMAGEM;

  PROCEDURE IMAGEM_SEM_CPFCNPJ(P_ID_FICHA IN NUMBER) AS  
    ds_origem       varchar2(100);
    ds_secao        varchar2(255);
    ds_mensagem     varchar2(100) := 'Imagem anexa sem CPF/CNPJ informado';
    in_justificavel varchar2(1) := 'S';
    in_impeditiva   varchar2(1) := 'S';
  BEGIN
    for reg in 
      (select peve_nm_pessoa, pese_sq_pessoa_srvc_engenharia      
        from
        (select peve.peve_sq_pessoa_versionada, peve.peve_nm_pessoa, pese.pese_sq_pessoa_srvc_engenharia,
          case when peve.peve_in_tipo_pessoa = 'F' then
              (select PEFI_CD_CPF from 
              pessoa_fisica pefi
              where pefi.peve_sq_pessoa_versionada = peve.peve_sq_pessoa_versionada)
            when peve.peve_in_tipo_pessoa = 'J' then
              (select peju_cd_cnpj
              from pessoa_juridica peju
              where peju.peve_sq_pessoa_versionada = peve.peve_sq_pessoa_versionada)
            end peve_cd_cpfcnpj
          from  PSSA_VSND_FICHA_CADASTRAL pvfc, 
              pessoa_servico_engenharia pese,
              pessoa_versionada peve      
          where pvfc.pese_sq_pessoa_srvc_engenharia = pese.pese_sq_pessoa_srvc_engenharia
          and   pese.peve_sq_pessoa_versionada = peve.peve_sq_pessoa_versionada
          and   pvfc.fica_sq_ficha_cadastral = P_ID_FICHA  
          and not exists 
            (select 'x' 
            from arquivo_pessoa arpe, documento docu
            where arpe.docu_sq_documento = docu.docu_sq_documento
            and arpe.peve_sq_pessoa_versionada = peve.peve_sq_pessoa_versionada
            and ((peve.peve_in_tipo_pessoa = 'F' and docu.tido_sq_tipo_documento = 5)
            or(peve.peve_in_tipo_pessoa = 'J' and docu.tido_sq_tipo_documento = 33))))
        where peve_cd_cpfcnpj is null)
    loop
      ds_origem := reg.peve_nm_pessoa;
      
      ds_secao := SELECIONAR_PLS(P_ID_FICHA, REG.PESE_SQ_PESSOA_SRVC_ENGENHARIA);
      
      if ds_secao is not null then
        if CRIAR_PENDENCIA(p_id_ficha, ds_origem, ds_secao, ds_mensagem)  = 1 then
          INSERIR_PENDENCIA(P_ID_FICHA, DS_ORIGEM, DS_SECAO, DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);  
        end if;
      end if;
    end loop;    
  END IMAGEM_SEM_CPFCNPJ;

  PROCEDURE IMAGEM_SEM_IDENTIFICACAO(P_ID_FICHA IN NUMBER) AS
    ds_origem       varchar2(100);
    ds_secao        varchar2(255);
    ds_mensagem     varchar2(100) := 'Imagem anexa sem Documento de Identificação informado';
    in_justificavel varchar2(1) := 'S';
    in_impeditiva   varchar2(1) := 'S';
  BEGIN
    for reg in
      (select peve.peve_nm_pessoa, pese.pese_sq_pessoa_srvc_engenharia      
      from  PSSA_VSND_FICHA_CADASTRAL pvfc
      inner join pessoa_servico_engenharia pese on pese.pese_sq_pessoa_srvc_engenharia = pvfc.pese_sq_pessoa_srvc_engenharia 
      inner join pessoa_versionada peve on peve.peve_sq_pessoa_versionada = pese.peve_sq_pessoa_versionada
      left join identificacao_pessoa_fisica idpf on idpf.peve_sq_pessoa_versionada = peve.peve_sq_pessoa_versionada
      where pvfc.fica_sq_ficha_cadastral = P_ID_FICHA
      and   peve.peve_in_tipo_pessoa = 'F'
      and   idpf.idpf_nr_doct_identificacao is null
      and  exists 
        (select 'x' 
        from arquivo_pessoa arpe, documento docu
        where arpe.docu_sq_documento = docu.docu_sq_documento
        and arpe.peve_sq_pessoa_versionada = peve.peve_sq_pessoa_versionada
        and docu.tido_sq_tipo_documento = idpf.tido_sq_tipo_documento))
    loop
      ds_origem := reg.peve_nm_pessoa;
      ds_secao := SELECIONAR_PLS(P_ID_FICHA, reg.pese_sq_pessoa_srvc_engenharia);
      
      if ds_secao is not null then
        if CRIAR_PENDENCIA(p_id_ficha, ds_origem, ds_secao, ds_mensagem)  = 1 then  
          INSERIR_PENDENCIA(P_ID_FICHA, ds_origem, ds_secao, DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);      
        end if;
      end if;
    end loop;      
  END IMAGEM_SEM_IDENTIFICACAO;  

  PROCEDURE INCAPAZ_SEM_IMAGEM(P_ID_FICHA IN NUMBER) AS
    ds_origem        varchar2(100);
    ds_secao         varchar2(255);
    t_pessoas        TABLE_T_PESE_NOME;
    ds_mensagem      varchar2(100) := 'Pessoa incapaz sem documento anexo';
    in_justificavel  varchar2(1) := 'S';
    in_impeditiva    varchar2(1) := 'S';
  BEGIN
    t_pessoas := CONDICAO_PESSOA_SEM_ARQUIVO(P_ID_FICHA, 'F', 2, 1);
    /*Atualizar o tipo documento*/
    
    if t_pessoas is null or t_pessoas.count=0 then
      return;
    end if;
       
    for i in t_pessoas.FIRST..t_pessoas.LAST loop
      ds_origem := t_pessoas(i).nome_pessoa;
      ds_secao := SELECIONAR_PLS(P_ID_FICHA, t_pessoas(i).id_pessoa_srvc_engenharia);
      
      if ds_secao is not null then
        if CRIAR_PENDENCIA(p_id_ficha, ds_origem, ds_secao, ds_mensagem)  = 1 then  
          INSERIR_PENDENCIA(P_ID_FICHA, ds_origem, ds_secao, DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);
        end if;
      end if;
    end loop;
  END INCAPAZ_SEM_IMAGEM;

  PROCEDURE INSOLVENTE_SEM_IMAGEM(P_ID_FICHA IN NUMBER) AS
    ds_origem        varchar2(100);
    ds_secao         varchar2(255);
    t_pessoas        TABLE_T_PESE_NOME;
    ds_mensagem      varchar2(100) := 'Pessoa insolvente sem documento anexo';
    in_justificavel  varchar2(1) := 'S';
    in_impeditiva    varchar2(1) := 'S';
  BEGIN
    t_pessoas := CONDICAO_PESSOA_SEM_ARQUIVO(P_ID_FICHA, 'F', 5, 1);
    /*Atualizar o tipo documento*/
    
    if t_pessoas is null or t_pessoas.count=0 then
      return;
    end if;
        
    for i in t_pessoas.FIRST..t_pessoas.LAST loop
      ds_origem := t_pessoas(i).nome_pessoa;
      ds_secao := SELECIONAR_PLS(P_ID_FICHA, t_pessoas(i).id_pessoa_srvc_engenharia);
    
      if ds_secao is not null then
        if CRIAR_PENDENCIA(p_id_ficha, ds_origem, ds_secao, ds_mensagem)  = 1 then  
          INSERIR_PENDENCIA(P_ID_FICHA, ds_origem, ds_secao, DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);
        end if;
      end if;
    end loop;
  END INSOLVENTE_SEM_IMAGEM;

  PROCEDURE MASSA_FALIDA_SEM_IMAGEM(P_ID_FICHA IN NUMBER) AS
    ds_origem        varchar2(100);
    ds_secao         varchar2(255);
    t_pessoas        TABLE_T_PESE_NOME;
    ds_mensagem      varchar2(100) := 'Pessoa Jurídica massa falida sem documento anexo';
    in_justificavel  varchar2(1) := 'S';
    in_impeditiva    varchar2(1) := 'S';
  BEGIN
   t_pessoas := CONDICAO_PESSOA_SEM_ARQUIVO(P_ID_FICHA, 'J', 7, 1);
   /*Atualizar o tipo documento*/
   
   if t_pessoas is null or t_pessoas.count=0 then
      return;
    end if;
        
   for i in t_pessoas.FIRST..t_pessoas.LAST loop
      ds_origem := t_pessoas(i).nome_pessoa;
      ds_secao := SELECIONAR_PLS(P_ID_FICHA, t_pessoas(i).id_pessoa_srvc_engenharia);
      
      if ds_secao is not null then
        if CRIAR_PENDENCIA(p_id_ficha, ds_origem, ds_secao, ds_mensagem)  = 1 then  
          INSERIR_PENDENCIA(P_ID_FICHA, ds_origem, ds_secao, DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);
        end if;
      end if;
    end loop;
  END MASSA_FALIDA_SEM_IMAGEM;

  PROCEDURE PROCURADOR_SEM_IMAGEM(P_ID_FICHA IN NUMBER) AS
    ds_origem       varchar2(100);
    ds_secao        varchar2(255);
    t_pessoas       TABLE_T_PESE_NOME;
    ds_mensagem     varchar2(100) := 'Pessoa procurador sem documento anexo';
    in_justificavel varchar2(1) := 'S';
    in_impeditiva   varchar2(1) := 'S';
  BEGIN
    t_pessoas := CONDICAO_PESSOA_SEM_ARQUIVO(P_ID_FICHA, 'F', 7, 1);
   /*Atualizar o tipo documento*/
   
   if t_pessoas is null or t_pessoas.count=0 then
      return;
    end if;
        
   for i in t_pessoas.FIRST..t_pessoas.LAST loop
      ds_origem := t_pessoas(i).nome_pessoa;
      ds_secao := SELECIONAR_PLS(P_ID_FICHA, t_pessoas(i).id_pessoa_srvc_engenharia);
    
      if ds_secao is not null then
        if CRIAR_PENDENCIA(p_id_ficha, ds_origem, ds_secao, ds_mensagem)  = 1 then  
          INSERIR_PENDENCIA(P_ID_FICHA, ds_origem, ds_secao, DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);
        end if;
      end if;
    end loop;    
  END PROCURADOR_SEM_IMAGEM;

  PROCEDURE SOCIO_SEM_IMAGEM(P_ID_FICHA IN NUMBER) AS
    ds_origem       varchar2(100);
    ds_secao        varchar2(255);
    t_pessoas       TABLE_T_PESE_NOME;
    ds_mensagem     varchar2(100) := 'Pessoa sócio de empresa sem documento anexo';
    in_justificavel varchar2(1) := 'S';
    in_impeditiva   varchar2(1) := 'S';
  BEGIN    
    t_pessoas := RELACIONAMENTO_SEM_ARQUIVO(P_ID_FICHA, 'F', 14, 45);
    
    if t_pessoas is null or t_pessoas.count=0 then
      return;
    end if;
        
    for i in t_pessoas.FIRST..t_pessoas.LAST loop
      ds_origem := t_pessoas(i).nome_pessoa;
      ds_secao := SELECIONAR_PLS(P_ID_FICHA, t_pessoas(i).id_pessoa_srvc_engenharia);
    
      if ds_secao is not null then
        if CRIAR_PENDENCIA(p_id_ficha, ds_origem, ds_secao, ds_mensagem)  = 1 then  
          INSERIR_PENDENCIA(P_ID_FICHA, ds_origem, ds_secao, DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);
        end if;
      end if;
    end loop;    
  END SOCIO_SEM_IMAGEM;

  PROCEDURE TUTOR_SEM_IMAGEM(P_ID_FICHA IN NUMBER) AS
    ds_origem       varchar2(100);
    ds_secao        varchar2(255);
    t_pessoas       TABLE_T_PESE_NOME;
    ds_mensagem     varchar2(100) := 'Pessoa tutor/curador sem documento anexo';
    in_justificavel varchar2(1) := 'S';
    in_impeditiva   varchar2(1) := 'S';
  BEGIN
    t_pessoas := RELACIONAMENTO_SEM_ARQUIVO(P_ID_FICHA, 'F', 3, 1);
    /*Atualizar o Tipo Documento*/
   
    if t_pessoas is null or t_pessoas.count=0 then
      return;
    end if;
            
    for reg in (select * from table(t_pessoas)) loop
      ds_origem := reg.nome_pessoa;
      ds_secao := SELECIONAR_PLS(P_ID_FICHA, reg.id_pessoa_srvc_engenharia);
    
      if ds_secao is not null then
        if CRIAR_PENDENCIA(p_id_ficha, ds_origem, ds_secao, ds_mensagem)  = 1 then  
          INSERIR_PENDENCIA(P_ID_FICHA, ds_origem, ds_secao, DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);
        end if;
      end if;
    end loop;
  END TUTOR_SEM_IMAGEM;

  PROCEDURE UNIAO_ESTAVEL_SEM_IMAGEM(P_ID_FICHA IN NUMBER) AS
    ds_origem       varchar2(100);
    ds_secao        varchar2(255);
    ds_mensagem     varchar2(100) := 'Pessoa em união estável sem documento anexo';
    in_justificavel varchar2(1) := 'S';
    in_impeditiva   varchar2(1) := 'S';
  BEGIN
    for reg in 
      (select peve.peve_nm_pessoa, pese.pese_sq_pessoa_srvc_engenharia      
      from  PSSA_VSND_FICHA_CADASTRAL pvfc, 
          pessoa_servico_engenharia pese,
          pessoa_versionada peve,
          pessoa_fisica pefi,
          relacionamento_pessoa repe
      where pvfc.pese_sq_pessoa_srvc_engenharia = pese.pese_sq_pessoa_srvc_engenharia
      and   peve.peve_sq_pessoa_versionada = pese.peve_sq_pessoa_versionada
      and   pefi.peve_sq_pessoa_versionada = peve.peve_sq_pessoa_versionada
      and  ( (repe.peve_sq_pessoa_vrnd_origem = peve.peve_sq_pessoa_versionada and repe.tire_sq_tipo_rlcm_origem = 2)
            or (repe.peve_sq_pessoa_vrnd_destino = peve.peve_sq_pessoa_versionada and repe.tire_sq_tipo_rlcm_destino = 2))
      and   pvfc.fica_sq_ficha_cadastral = P_ID_FICHA
      and   peve.peve_in_tipo_pessoa = 'F'
      and   pefi.esci_sq_estado_civil = 5
      and   not exists 
        (select 'x' 
        from arquivo_relacionamento arre, documento docu
        where arre.docu_sq_documento = docu.docu_sq_documento
        and docu.tido_sq_tipo_documento = 12
        and arre.repe_sq_relacionamento_pessoa = repe.repe_sq_relacionamento_pessoa))
    loop
      ds_origem := reg.peve_nm_pessoa;
      ds_secao := SELECIONAR_PLS(P_ID_FICHA, reg.pese_sq_pessoa_srvc_engenharia);
      
      if ds_secao is not null then
        if CRIAR_PENDENCIA(p_id_ficha, ds_origem, ds_secao, ds_mensagem)  = 1 then  
          INSERIR_PENDENCIA(P_ID_FICHA, ds_origem, ds_secao, DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);      
        end if;
      end if;
    end loop;    
  END UNIAO_ESTAVEL_SEM_IMAGEM;
  
  PROCEDURE PESSOA_SEM_PL(P_ID_FICHA in number) as
    ds_origem       varchar2(100);
    ds_secao        varchar2(255) := 'Pessoa Física/Jurídica';
    ds_mensagem     varchar2(100) := 'Pessoa sem Processo de Liberação';
    in_justificavel varchar2(1) := 'N';
    in_impeditiva   varchar2(1) := 'N';
  BEGIN
    for reg in 
      (select peve.peve_nm_pessoa
       from pssa_vsnd_ficha_cadastral pvfc,
            pessoa_servico_engenharia pese,
            pessoa_versionada peve
       where pvfc.fica_sq_ficha_cadastral = P_ID_FICHA              
       and pese.pese_sq_pessoa_srvc_engenharia = pvfc.pese_sq_pessoa_srvc_engenharia
       and peve.peve_sq_pessoa_versionada = pese.peve_sq_pessoa_versionada
       and not exists
        (select 'x' from 
          grupo_pssa_processo_liberacao gppl,
          processo_liberacao prli
        where prli.fica_sq_ficha_cadastral = pvfc.fica_sq_ficha_cadastral
        and gppl.prli_sq_processo_liberacao = prli.prli_sq_processo_liberacao
        and gppl.psfc_sq_pssa_vsnd_ficha_cdtl = pvfc.psfc_sq_pssa_vsnd_ficha_cdtl))
    loop
      ds_origem := reg.peve_nm_pessoa;
      
      if CRIAR_PENDENCIA(p_id_ficha, ds_origem, ds_secao, ds_mensagem)  = 1 then  
         INSERIR_PENDENCIA(P_ID_FICHA, ds_origem, ds_secao, DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);      
      end if;
    end loop;
  exception
    when no_data_found then
      /* Todas as pessoas vinculadas possuem processo de liberação */
      null;
  END PESSOA_SEM_PL;
  
  PROCEDURE GERAR_PENDENCIAS(P_ID_FICHA IN NUMBER) AS
    V_ID_SITUACAO NUMBER(20);
    V_ORIGEM_MIGRACAO VARCHAR2(100) := 'ORIGEM MIGRAÇÃO CADPROP WEB';
  BEGIN
    select SIOB_SQ_SITUACAO_OBJETO
    into V_ID_SITUACAO
    from FICHA_CADASTRAL
    where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA;
    
    if V_ID_SITUACAO = 1 then
      delete from pendencia_ficha_cadastral
      where fica_sq_ficha_cadastral =  P_ID_FICHA
      and pefc_ds_justificativa is null
      and pefc_ds_origem != V_ORIGEM_MIGRACAO;    
  
      -- CPF/CNPJ informado sem imagem anexa
      CPFCNPJ_SEM_IMAGEM(P_ID_FICHA);
      
      -- Imagem anexa sem CPF/CNPJ informado
      IMAGEM_SEM_CPFCNPJ(P_ID_FICHA);
      
      -- Documento de Identificação informado sem imagem anexa
      IDENTIFICACAO_SEM_IMAGEM(P_ID_FICHA);
      
      -- Imagem anexa sem Documento de Identificação informado
      IMAGEM_SEM_IDENTIFICACAO(P_ID_FICHA);
      
      -- Pessoa em União estável sem documento anexo
      UNIAO_ESTAVEL_SEM_IMAGEM(P_ID_FICHA);
      
      -- Pessoa Espólio sem documento anexo
      ESPOLIO_SEM_IMAGEM(P_ID_FICHA);
      
      -- Pessoa em Incapaz sem documento anexo
      INCAPAZ_SEM_IMAGEM(P_ID_FICHA);
      
      -- Pessoa Insolvente sem documento anexo
      INSOLVENTE_SEM_IMAGEM(P_ID_FICHA);
      
      -- Pessoa Ausente sem documento anexo
      AUSENTE_SEM_IMAGEM(P_ID_FICHA);
      
      -- Pessoa Massa Falida sem documento anexo
      MASSA_FALIDA_SEM_IMAGEM(P_ID_FICHA);
      
      -- Pessoa casada sem documento anexo
      CONJUGE_SEM_IMAGEM(P_ID_FICHA);
      
      -- Pessoa Herdeiro sem documento anexo
      HERDEIRO_SEM_IMAGEM(P_ID_FICHA);
      
      -- Pessoa Procurador sem documento anexo
      PROCURADOR_SEM_IMAGEM(P_ID_FICHA);
      
      -- Pessoa Procurador sem documento anexo
      TUTOR_SEM_IMAGEM(P_ID_FICHA);
      
      -- Pessoa Sócio de Empresa sem documento anexo
      SOCIO_SEM_IMAGEM(P_ID_FICHA);
      
      -- Imóvel com Proprietário(s) Irregular(es)
      IMOVEL_PROP_IRREGULAR(P_ID_FICHA);
      
      -- Imóvel com Situação Irregular
      IMOVEL_NAO_REGULARIZADO(P_ID_FICHA);
        
      --Imóvel sem Coordenadas
      IMOVEL_SEM_COORDENADAS(P_ID_FICHA);
      
      --Imóvel sem RGI
      IMOVEL_SEM_RGI(P_ID_FICHA);
      
      --Imóvel sem foto
      IMOVEL_SEM_IMAGEM(P_ID_FICHA);
      
      -- Área Total da Servidão maior que Área Total do Imóvel
      SERVIDAO_MAIOR_IMOVEL(P_ID_FICHA);
      
      -- Área total do Imóvel diferente da área das coordenadas
      AREA_COORDENADA_AREA_IMOVEL(P_ID_FICHA);
      
      -- Soma das Áreas de Interesse maior que Área Total do Imóvel
      AREA_INTERESSE_MAIOR_IMOVEL(P_ID_FICHA);
      
      -- Área de interesse não informada ou igual a zero
      AREA_INTERESSE_NAO_INFORMADA(P_ID_FICHA);
    
      -- Área de interesse para Servidão com percentual igual ou maior a 90% da área total do imóvel
      AREA_INTERESSE_SERVIDAO_90(P_ID_FICHA);
      
      -- Interferência com Situação Legal não Regular
      INTERF_NAO_REGULARIZADA(P_ID_FICHA);
      
      -- Ficha de Interferência Dentro do Imóvel sem Ficha Vinculada
      INTERFERENCIA_FC_VINCULADA(P_ID_FICHA);
      
      -- Ficha Simplificada
      FICHA_SIMPLIFICADA(P_ID_FICHA);
      
      -- Ficha sem instalação
      FICHA_SEM_INSTALACAO(P_ID_FICHA);
      
      -- Pessoa não vinculada a nenhum PL
      PESSOA_SEM_PL(P_ID_FICHA);
      
      -- Construção em área Não Edificante quando FC não possui área deste tipo
      CONSTRUCAO_NAO_EDIFICANTE(P_ID_FICHA);
      
      -- Equipamento em área Não Edificante quando FC não possui área deste tipo
      EQUIPAMENTO_NAO_EDIFICANTE(P_ID_FICHA);
      
      -- Cobertura Vegetal Mineral em área Não Edificante quando FC não possui área deste tipo
      COBERTURA_NAO_EDIFICANTE(P_ID_FICHA);
      
      -- PL de Terra Nua Vinculado com status de Cancelado
      PL_VINCULADO_CANCELADO(P_ID_FICHA);
      
      commit;
    end if;
  exception
    when others then
      rollback;     
      raise_application_error(-20001, 'Erro na Geração das Pendências.'||chr(13)||SQLERRM);
  END GERAR_PENDENCIAS;

  PROCEDURE INSERIR_PENDENCIA(P_ID_FICHA IN NUMBER, P_DS_SECAO IN VARCHAR2, P_DS_MENSAGEM IN VARCHAR2, P_IN_JUSTIFICAVEL IN VARCHAR2, P_IN_IMPEDITIVA IN VARCHAR2) AS
  BEGIN
    INSERIR_PENDENCIA(P_ID_FICHA, NULL, P_DS_SECAO, P_DS_MENSAGEM, P_IN_JUSTIFICAVEL, P_IN_IMPEDITIVA);
  END INSERIR_PENDENCIA;

  PROCEDURE INSERIR_PENDENCIA(P_ID_FICHA IN NUMBER, P_DS_ORIGEM IN VARCHAR2, P_DS_SECAO IN VARCHAR2, P_DS_MENSAGEM IN VARCHAR2, P_IN_JUSTIFICAVEL IN VARCHAR2, P_IN_IMPEDITIVA IN VARCHAR2) AS
    CT_PENDENCIA number(5);
  BEGIN
    select count(*)
    into CT_PENDENCIA
    from PENDENCIA_FICHA_CADASTRAL
    where FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA
    and PEFC_DS_ORIGEM = nvl(P_DS_ORIGEM,'SISTEMA')
    and PEFC_DS_SECAO = P_DS_SECAO
    and PEFC_TX_PENDENCIA = P_DS_MENSAGEM;
    
    if CT_PENDENCIA = 0 then
  
      insert into pendencia_ficha_cadastral
      ( PEFC_SQ_PENDENCIA_FICHA_CDTL,
        FICA_SQ_FICHA_CADASTRAL,
        PEFC_TX_PENDENCIA,
        PEFC_DS_ORIGEM,
        PEFC_DS_SECAO,
        PEFC_IN_JUSTIFICAVEL,
        PEFC_IN_IMPEDITIVA,
        PEFC_IN_JUSTIFICATIVA_ACEITA,
        FMWK_DT_ULTIMA_ATUALIZACAO)
      (select SQ_PEFC_SQ_PENDENCIA_FCHA_CDTL.nextval,
              P_ID_FICHA,
              P_DS_MENSAGEM,
              nvl(P_DS_ORIGEM,'SISTEMA'),
              P_DS_SECAO,
              P_IN_JUSTIFICAVEL,
              P_IN_IMPEDITIVA,
              'N',
              sysdate
       from dual);
    end if;
  END INSERIR_PENDENCIA;

  FUNCTION CONDICAO_PESSOA_SEM_ARQUIVO
  ( P_ID_FICHA        IN NUMBER, 
    P_TIPO_PESSOA     IN VARCHAR2,
    P_CONDICAO_PESSOA IN NUMBER,
    P_TIPO_DOCUMENTO  IN NUMBER
  ) RETURN TABLE_T_PESE_NOME AS    
   
    t_pessoas TABLE_T_PESE_NOME := TABLE_T_PESE_NOME();
    v_pese_nome T_PESE_NOME ;
    i number := 1;
    V_CT_TABLE    NUMBER(5);
  BEGIN
    select COUNT(pese.pese_sq_pessoa_srvc_engenharia)
    into V_CT_TABLE
      from  PSSA_VSND_FICHA_CADASTRAL pvfc, 
            pessoa_servico_engenharia pese,
            pessoa_versionada peve,
            dado_complementar_cndc_pessoa dacp
      where pvfc.pese_sq_pessoa_srvc_engenharia = pese.pese_sq_pessoa_srvc_engenharia
      and   peve.peve_sq_pessoa_versionada = pese.peve_sq_pessoa_versionada
      and   dacp.dacp_sq_clmr_cndc_pessoa = peve.dacp_sq_clmr_cndc_pessoa
      and   pvfc.fica_sq_ficha_cadastral = P_ID_FICHA
      and   peve.peve_in_tipo_pessoa = P_TIPO_PESSOA
      and   dacp.cope_sq_condicao_pessoa = P_CONDICAO_PESSOA      
      and   not exists 
        (select 'x' 
        from arquivo_pessoa arpe, documento docu
        where arpe.docu_sq_documento = docu.docu_sq_documento
        and arpe.peve_sq_pessoa_versionada = peve.peve_sq_pessoa_versionada
        and docu.tido_sq_tipo_documento = P_TIPO_DOCUMENTO);
  
    for reg in (
      select peve.peve_nm_pessoa, pese.pese_sq_pessoa_srvc_engenharia   
      from  PSSA_VSND_FICHA_CADASTRAL pvfc, 
            pessoa_servico_engenharia pese,
            pessoa_versionada peve,
            dado_complementar_cndc_pessoa dacp
      where pvfc.pese_sq_pessoa_srvc_engenharia = pese.pese_sq_pessoa_srvc_engenharia
      and   peve.peve_sq_pessoa_versionada = pese.peve_sq_pessoa_versionada
      and   dacp.dacp_sq_clmr_cndc_pessoa = peve.dacp_sq_clmr_cndc_pessoa
      and   pvfc.fica_sq_ficha_cadastral = P_ID_FICHA
      and   peve.peve_in_tipo_pessoa = P_TIPO_PESSOA
      and   dacp.cope_sq_condicao_pessoa = P_CONDICAO_PESSOA      
      and   not exists 
        (select 'x' 
        from arquivo_pessoa arpe, documento docu
        where arpe.docu_sq_documento = docu.docu_sq_documento
        and arpe.peve_sq_pessoa_versionada = peve.peve_sq_pessoa_versionada
        and docu.tido_sq_tipo_documento = P_TIPO_DOCUMENTO))
    loop 
      v_pese_nome := t_pese_nome(reg.peve_nm_pessoa, reg.pese_sq_pessoa_srvc_engenharia);
      
      if(i=1) then
        t_pessoas.extend(V_CT_TABLE);
      end if;
      t_pessoas(i) := v_pese_nome;
      i := i+1;
    end loop;
    
    return t_pessoas;
  END CONDICAO_PESSOA_SEM_ARQUIVO;
  
  FUNCTION RELACIONAMENTO_SEM_ARQUIVO
  ( P_ID_FICHA             IN NUMBER, 
    P_TIPO_PESSOA          IN VARCHAR2,
    P_TIPO_RELACIONAMENTO  IN NUMBER,
    P_TIPO_DOCUMENTO       IN NUMBER
  ) RETURN TABLE_T_PESE_NOME AS
  
    t_pessoas TABLE_T_PESE_NOME  := TABLE_T_PESE_NOME();
    v_pese_nome T_PESE_NOME;
    i number := 1;
    V_CT_TABLE  number(5);
  BEGIN 
    select COUNT(pese.pese_sq_pessoa_srvc_engenharia)
    into V_CT_TABLE
      from  PSSA_VSND_FICHA_CADASTRAL pvfc, 
          pessoa_servico_engenharia pese,
          pessoa_versionada peve,        
          relacionamento_pessoa repe
      where pvfc.pese_sq_pessoa_srvc_engenharia = pese.pese_sq_pessoa_srvc_engenharia
      and   peve.peve_sq_pessoa_versionada = pese.peve_sq_pessoa_versionada    
      and  ( (repe.peve_sq_pessoa_vrnd_origem = peve.peve_sq_pessoa_versionada and repe.tire_sq_tipo_rlcm_origem = P_TIPO_RELACIONAMENTO)
            or (repe.peve_sq_pessoa_vrnd_destino = peve.peve_sq_pessoa_versionada and repe.tire_sq_tipo_rlcm_destino = P_TIPO_RELACIONAMENTO))
      and   pvfc.fica_sq_ficha_cadastral = P_ID_FICHA
      and   peve.peve_in_tipo_pessoa = P_TIPO_PESSOA       
      and   not exists 
        (select 'x' 
        from arquivo_relacionamento arre, documento docu
        where arre.docu_sq_documento = docu.docu_sq_documento
        and docu.tido_sq_tipo_documento = P_TIPO_DOCUMENTO 
        and arre.repe_sq_relacionamento_pessoa = repe.repe_sq_relacionamento_pessoa);
  
    for reg in 
      (select peve.peve_nm_pessoa, pese.pese_sq_pessoa_srvc_engenharia
      from  PSSA_VSND_FICHA_CADASTRAL pvfc, 
          pessoa_servico_engenharia pese,
          pessoa_versionada peve,        
          relacionamento_pessoa repe
      where pvfc.pese_sq_pessoa_srvc_engenharia = pese.pese_sq_pessoa_srvc_engenharia
      and   peve.peve_sq_pessoa_versionada = pese.peve_sq_pessoa_versionada    
      and  ( (repe.peve_sq_pessoa_vrnd_origem = peve.peve_sq_pessoa_versionada and repe.tire_sq_tipo_rlcm_origem = P_TIPO_RELACIONAMENTO)
            or (repe.peve_sq_pessoa_vrnd_destino = peve.peve_sq_pessoa_versionada and repe.tire_sq_tipo_rlcm_destino = P_TIPO_RELACIONAMENTO))
      and   pvfc.fica_sq_ficha_cadastral = P_ID_FICHA
      and   peve.peve_in_tipo_pessoa = P_TIPO_PESSOA       
      and   not exists 
        (select 'x' 
        from arquivo_relacionamento arre, documento docu
        where arre.docu_sq_documento = docu.docu_sq_documento
        and docu.tido_sq_tipo_documento = P_TIPO_DOCUMENTO 
        and arre.repe_sq_relacionamento_pessoa = repe.repe_sq_relacionamento_pessoa)) 
    loop    
      v_pese_nome := t_pese_nome(reg.peve_nm_pessoa, reg.pese_sq_pessoa_srvc_engenharia);
      
      if(i=1) then
        t_pessoas.extend(V_CT_TABLE);
      end if;
      
      t_pessoas(i) := v_pese_nome;
      i := i+1;
    
    end loop;
      
    return t_pessoas;
  END RELACIONAMENTO_SEM_ARQUIVO;

  FUNCTION CRIAR_PENDENCIA
  ( P_ID_FICHA IN NUMBER, P_MENSAGEM IN VARCHAR2
  ) RETURN NUMBER AS
    CT_PENDENCIA NUMBER;
  BEGIN
    RETURN CRIAR_PENDENCIA(P_ID_FICHA, NULL, NULL, P_MENSAGEM);    
  END CRIAR_PENDENCIA;

  FUNCTION CRIAR_PENDENCIA(P_ID_FICHA IN NUMBER, P_ORIGEM IN VARCHAR2, P_SECAO IN VARCHAR2, P_MENSAGEM IN VARCHAR2) RETURN NUMBER AS
    CT_PENDENCIA NUMBER;
  BEGIN
    select count(*)
    into ct_pendencia
    from pendencia_ficha_cadastral 
    where fica_sq_ficha_cadastral = P_ID_FICHA
    and pefc_ds_justificativa is not null
    and pefc_tx_pendencia = p_mensagem
    and ((pefc_ds_origem = P_ORIGEM) or (P_ORIGEM is null))
    and ((pefc_ds_secao = P_SECAO) or (P_SECAO is null));
    
    if ct_pendencia = 0 then
      delete from pendencia_ficha_cadastral
      where pefc_sq_pendencia_ficha_cdtl in 
        ( select pefc_sq_pendencia_ficha_cdtl
          from pendencia_ficha_cadastral 
          where fica_sq_ficha_cadastral = P_ID_FICHA
          and pefc_ds_justificativa is null
          and pefc_tx_pendencia = p_mensagem
          and ((pefc_ds_origem = P_ORIGEM) or (P_ORIGEM is null))
          and ((pefc_ds_secao = P_SECAO) or (P_SECAO is null)));
      commit;
      return 1;
    else
      return 0;
    end if;
  END CRIAR_PENDENCIA;
  
  FUNCTION SELECIONAR_PLS
  (P_ID_FICHA IN NUMBER,
   P_ID_PESE  IN NUMBER
  ) RETURN VARCHAR2 AS
    ds_pls varchar2(255) := 'PL(s) ';
  BEGIN    
    for reg1 in 
      (select distinct lpad(prli_nr_processo_liberacao,3,'0')||'-'||prli_cd_revisao_prcs_liberacao numero_processo
       from processo_liberacao prli, 
            grupo_pssa_processo_liberacao gppl,
            pssa_vsnd_ficha_cadastral pvfc
       where prli.fica_sq_ficha_cadastral = P_ID_FICHA
       and pvfc.fica_sq_ficha_cadastral = prli.fica_sq_ficha_cadastral
       and gppl.prli_sq_processo_liberacao = prli.prli_sq_processo_liberacao
       and gppl.psfc_sq_pssa_vsnd_ficha_cdtl = pvfc.psfc_sq_pssa_vsnd_ficha_cdtl
       and pvfc.pese_sq_pessoa_srvc_engenharia = P_ID_PESE
       and prli.siob_sq_situacao_objeto != 2
       order by lpad(prli_nr_processo_liberacao,3,'0')||'-'||prli_cd_revisao_prcs_liberacao)
    loop
      ds_pls := ds_pls||reg1.numero_processo||', ';
    end loop;
    
    if ds_pls = 'PL(s) ' then
      return null;
    else
      /* retira a última vírgula*/
      return substr(ds_pls, 1, length(ds_pls)-2);          
    end if;
  END SELECIONAR_PLS;
  
  PROCEDURE PL_VINCULADO_CANCELADO(P_ID_FICHA IN NUMBER) AS
    ds_origem         varchar2(100) := 'SISTEMA';
    ds_mensagem       varchar2(100) := 'PL de Terra Nua vinculado, possui status cancelado.';
    ds_pls            varchar2(100) := '';
    in_justificavel   varchar2(1)   := 'N';
    in_impeditiva     varchar2(1)   := 'S';
    ct_pls            number        := 0;
  BEGIN
    if CRIAR_PENDENCIA(p_id_ficha, ds_mensagem)  = 1 then
      
      select COUNT(PLRI.PRLI_SQ_PROCESSO_LIBERACAO)
        into ct_pls
        FROM PROCESSO_LIBERACAO PLRI
       INNER JOIN PROCESSO_LIBERACAO PRLV ON PLRI.PRLI_SQ_PRCS_LBRC_VINCULADO = PRLV.PRLI_SQ_PROCESSO_LIBERACAO
       WHERE PRLV.SIOB_SQ_SITUACAO_OBJETO = 2
         AND PLRI.FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA;
      
      if( ct_pls > 0 ) then
        for reg1 in 
            (select distinct lpad(PLRI.prli_nr_processo_liberacao,3,'0')||'-'||lpad(PLRI.prli_cd_revisao_prcs_liberacao,2,'0') numero_processo
               FROM PROCESSO_LIBERACAO PLRI
              INNER JOIN PROCESSO_LIBERACAO PRLV ON PLRI.PRLI_SQ_PRCS_LBRC_VINCULADO = PRLV.PRLI_SQ_PROCESSO_LIBERACAO
              WHERE PLRI.SIOB_SQ_SITUACAO_OBJETO <> 2
                AND PRLV.SIOB_SQ_SITUACAO_OBJETO = 2
                AND PLRI.FICA_SQ_FICHA_CADASTRAL = P_ID_FICHA
           order by lpad(PLRI.prli_nr_processo_liberacao,3,'0')||'-'||lpad(PLRI.prli_cd_revisao_prcs_liberacao,2,'0'))
          loop
            ds_pls := ds_pls||reg1.numero_processo||', ';
          end loop;
        
        /* retira a última vírgula*/
        ds_pls := substr(ds_pls, 1, length(ds_pls)-2);
          
        INSERIR_PENDENCIA(P_ID_FICHA, ds_origem, ds_pls, DS_MENSAGEM, IN_JUSTIFICAVEL, IN_IMPEDITIVA);
      end if;
    end if;
  exception
    when no_data_found then      
      null;
  END PL_VINCULADO_CANCELADO;
END PCK_SISGT_PENDENCIAS;