create or replace
PACKAGE BODY PCK_SISGT_DIAGRAMA_UNIFILAR AS  
  FUNCTION F_DIAGRAMA_UNIFILAR_OBRA (P_ID_OBRA IN NUMBER)
    RETURN TEMP_PRLS_REC
    PIPELINED
    IS
      V_PRLS_REC PRLS_REC;   
      
      
      
    BEGIN
      FOR REG IN (select prls.prls_sq_prcs_lbrc_srvc_engr,
                         prli.prli_sq_processo_liberacao,
                         prli.prli_nr_processo_liberacao,
                         prli.prli_cd_revisao_prcs_liberacao,
                         siob.siob_sq_situacao_objeto,
                         siob.siob_nm_situacao_objeto,
                         mowo.siwo_sq_situacao_workflow,
                         mowo.siwo_nm_situacao_workflow,
                         sine.sine_sq_situacao_negociacao,
                         sine.sine_nm_situacao_negociacao,
                         sili.sili_sq_situacao_liberacao,
                         sili.sili_nm_situacao_liberacao,
                         siaj.siaj_sq_sitc_acao_judicial,
                         siaj.siaj_nm_sitc_acao_judicial,
                         fica.fica_sq_ficha_cadastral,
                         fica.fica_nr_ficha_cadastral,
                         arin.arin_sq_area_interesse,
                         arin.arin_md_extensao,
                         arin.arin_nr_kilometro_inicial,
                         arin.arin_nr_kilometro_final
                  from processo_liberacao_srvc_engr prls     
                  inner join processo_liberacao prli on prls.prli_sq_processo_liberacao = prli.prli_sq_processo_liberacao
                  inner join ficha_cadastral fica on prli.fica_sq_ficha_cadastral = fica.fica_sq_ficha_cadastral
                  inner join situacao_objeto siob on siob.siob_sq_situacao_objeto = prli.siob_sq_situacao_objeto
                  inner join (SELECT PRLI_SQ_PROCESSO_LIBERACAO, SITW.SIWO_SQ_SITUACAO_WORKFLOW, SITW.SIWO_NM_SITUACAO_WORKFLOW
                              FROM MOVIMENTO_WORKFLOW MOWO
                              INNER JOIN SITUACAO_WORKFLOW SITW ON MOWO.SIWO_SQ_SITUACAO_WORKFLOW = SITW.SIWO_SQ_SITUACAO_WORKFLOW
                              INNER JOIN (  SELECT MAX(MOWO_SQ_MOVIMENTO_WORKFLOW) MOWO_SQ_MOVIMENTO_WORKFLOW
                                            FROM MOVIMENTO_WORKFLOW
                                            GROUP BY PRLI_SQ_PROCESSO_LIBERACAO
                                          ) MOWO_MAX ON MOWO.MOWO_SQ_MOVIMENTO_WORKFLOW = MOWO_MAX.MOWO_SQ_MOVIMENTO_WORKFLOW
                  ) mowo on MOWO.PRLI_SQ_PROCESSO_LIBERACAO = PRLI.PRLI_SQ_PROCESSO_LIBERACAO
                  inner join situacao_negociacao sine on sine.sine_sq_situacao_negociacao = prls.sine_sq_situacao_negociacao
                  inner join situacao_liberacao sili on sili.sili_sq_situacao_liberacao = prls.sili_sq_situacao_liberacao
                  inner join situacao_acao_judicial siaj on siaj.siaj_sq_sitc_acao_judicial = prls.siaj_sq_sitc_acao_judicial
                  inner join area_interesse arin on arin.prli_sq_processo_liberacao = prli.prli_sq_processo_liberacao
                  inner join servico_engenharia seen on seen.seen_sq_servico_engenharia = prls.seen_sq_servico_engenharia                  
                  where (prli.siob_sq_situacao_objeto = 3 or 
                  (prli.siob_sq_situacao_objeto = 2 and prli.prli_in_revisao = 'S'))
                  and prli.prli_in_proprietario = 'S'                  
                  and prls.prls_sq_prcs_lbrc_srvc_destino is null
                  and seen.obra_sq_obra = P_ID_OBRA
      ) LOOP
        V_PRLS_REC.ID_PL_VINC := NULL;
        V_PRLS_REC.NR_PL_TERRA_NUA_VINC := NULL;
        V_PRLS_REC.CD_REVISAO_PL_TN_VINC := NULL;
        V_PRLS_REC.ID_SIOB_VINC := NULL;
        V_PRLS_REC.NM_SIOB_VINC := NULL;
        V_PRLS_REC.ID_SIWO_VINC := NULL;
        V_PRLS_REC.NM_SIWO_VINC := NULL;
        V_PRLS_REC.ID_SINE_VINC := NULL;
        V_PRLS_REC.NM_SINE_VINC := NULL;
        V_PRLS_REC.ID_SILI_VINC := NULL;
        V_PRLS_REC.NM_SILI_VINC := NULL;
        V_PRLS_REC.ID_SIAJ_VINC := NULL;
        V_PRLS_REC.NM_SIAJ_VINC := NULL;
        
        V_PRLS_REC.ID_FICHA := REG.FICA_SQ_FICHA_CADASTRAL;
        V_PRLS_REC.NR_FICHA := REG.FICA_NR_FICHA_CADASTRAL;
        V_PRLS_REC.ID_PL_TERRA_NUA := REG.PRLS_SQ_PRCS_LBRC_SRVC_ENGR;
        V_PRLS_REC.NR_PL_TERRA_NUA := REG.prli_nr_processo_liberacao;
        V_PRLS_REC.CD_REVISAO_PL_TN := REG.prli_cd_revisao_prcs_liberacao;
        V_PRLS_REC.ID_SIOB := REG.SIOB_SQ_SITUACAO_OBJETO;
        V_PRLS_REC.NM_SIOB := REG.SIOB_NM_SITUACAO_OBJETO;
        V_PRLS_REC.ID_SIWO := REG.SIWO_SQ_SITUACAO_WORKFLOW;
        V_PRLS_REC.NM_SIWO := REG.SIWO_NM_SITUACAO_WORKFLOW;
        V_PRLS_REC.ID_SINE := REG.SINE_SQ_SITUACAO_NEGOCIACAO;
        V_PRLS_REC.NM_SINE := REG.SINE_NM_SITUACAO_NEGOCIACAO;
        V_PRLS_REC.ID_SILI := REG.SILI_SQ_SITUACAO_LIBERACAO;
        V_PRLS_REC.NM_SILI := REG.SILI_NM_SITUACAO_LIBERACAO;
        V_PRLS_REC.ID_SIAJ := REG.SIAJ_SQ_SITC_ACAO_JUDICIAL;
        V_PRLS_REC.NM_SIAJ := REG.SIAJ_NM_SITC_ACAO_JUDICIAL;
        
        V_PRLS_REC.ID_ARIN := REG.ARIN_SQ_AREA_INTERESSE;
        V_PRLS_REC.KM_INICIAL := REG.ARIN_NR_KILOMETRO_INICIAL;
        V_PRLS_REC.KM_FINAL := REG.ARIN_NR_KILOMETRO_FINAL;
        V_PRLS_REC.MD_EXTENSAO := REG.ARIN_MD_EXTENSAO;
        
        FOR REG2 IN (select prls.prls_sq_prcs_lbrc_srvc_engr,
                       prli.prli_sq_processo_liberacao,
                       prli.prli_nr_processo_liberacao,
                       prli.prli_cd_revisao_prcs_liberacao,
                       siob.siob_sq_situacao_objeto,
                       siob.siob_nm_situacao_objeto,
                       mowo.siwo_sq_situacao_workflow,
                       mowo.siwo_nm_situacao_workflow,
                       sine.sine_sq_situacao_negociacao,
                       sine.sine_nm_situacao_negociacao,
                       sili.sili_sq_situacao_liberacao,
                       sili.sili_nm_situacao_liberacao,
                       siaj.siaj_sq_sitc_acao_judicial,
                       siaj.siaj_nm_sitc_acao_judicial                         
                from processo_liberacao_srvc_engr prls     
                inner join processo_liberacao prli on prls.prli_sq_processo_liberacao = prli.prli_sq_processo_liberacao  
                inner join ficha_cadastral fica on fica.fica_sq_ficha_cadastral = prli.fica_sq_ficha_cadastral
                inner join situacao_objeto siob on siob.siob_sq_situacao_objeto = prli.siob_sq_situacao_objeto
                inner join (SELECT PRLI_SQ_PROCESSO_LIBERACAO, SITW.SIWO_SQ_SITUACAO_WORKFLOW, SITW.SIWO_NM_SITUACAO_WORKFLOW
                            FROM MOVIMENTO_WORKFLOW MOWO
                            INNER JOIN SITUACAO_WORKFLOW SITW ON MOWO.SIWO_SQ_SITUACAO_WORKFLOW = SITW.SIWO_SQ_SITUACAO_WORKFLOW
                            INNER JOIN (  SELECT MAX(MOWO_SQ_MOVIMENTO_WORKFLOW) MOWO_SQ_MOVIMENTO_WORKFLOW
                                          FROM MOVIMENTO_WORKFLOW
                                          GROUP BY PRLI_SQ_PROCESSO_LIBERACAO
                                        ) MOWO_MAX ON MOWO.MOWO_SQ_MOVIMENTO_WORKFLOW = MOWO_MAX.MOWO_SQ_MOVIMENTO_WORKFLOW
                ) mowo on MOWO.PRLI_SQ_PROCESSO_LIBERACAO = PRLI.PRLI_SQ_PROCESSO_LIBERACAO
                inner join situacao_negociacao sine on sine.sine_sq_situacao_negociacao = prls.sine_sq_situacao_negociacao
                inner join situacao_liberacao sili on sili.sili_sq_situacao_liberacao = prls.sili_sq_situacao_liberacao
                inner join situacao_acao_judicial siaj on siaj.siaj_sq_sitc_acao_judicial = prls.siaj_sq_sitc_acao_judicial                  
                where (prli.siob_sq_situacao_objeto = 3 or 
                  (prli.siob_sq_situacao_objeto = 2 and prli.prli_in_revisao = 'S'))
                and prli.prli_sq_prcs_lbrc_vinculado = REG.PRLI_SQ_PROCESSO_LIBERACAO
                and prls.prls_sq_prcs_lbrc_srvc_destino is null)
          LOOP
            V_PRLS_REC.ID_PL_VINC := REG2.PRLI_SQ_PROCESSO_LIBERACAO;
            V_PRLS_REC.NR_PL_TERRA_NUA_VINC := REG2.PRLI_NR_PROCESSO_LIBERACAO;
            V_PRLS_REC.CD_REVISAO_PL_TN_VINC := REG2.PRLI_CD_REVISAO_PRCS_LIBERACAO;
            V_PRLS_REC.ID_SIOB_VINC := REG2.SIOB_SQ_SITUACAO_OBJETO;
            V_PRLS_REC.NM_SIOB_VINC := REG2.SIOB_NM_SITUACAO_OBJETO;
            V_PRLS_REC.ID_SIWO_VINC := REG2.SIWO_SQ_SITUACAO_WORKFLOW;
            V_PRLS_REC.NM_SIWO_VINC := REG2.SIWO_NM_SITUACAO_WORKFLOW;
            V_PRLS_REC.ID_SINE_VINC := REG2.SINE_SQ_SITUACAO_NEGOCIACAO;
            V_PRLS_REC.NM_SINE_VINC := REG2.SINE_NM_SITUACAO_NEGOCIACAO;
            V_PRLS_REC.ID_SILI_VINC := REG2.SILI_SQ_SITUACAO_LIBERACAO;
            V_PRLS_REC.NM_SILI_VINC := REG2.SILI_NM_SITUACAO_LIBERACAO;
            V_PRLS_REC.ID_SIAJ_VINC := REG2.SIAJ_SQ_SITC_ACAO_JUDICIAL;
            V_PRLS_REC.NM_SIAJ_VINC := REG2.SIAJ_NM_SITC_ACAO_JUDICIAL;
            
            PIPE ROW(V_PRLS_REC);
          END LOOP;
          
         if V_PRLS_REC.ID_PL_VINC is null then 
          PIPE ROW(V_PRLS_REC);
        end if;
     END LOOP;
     RETURN;
   END;
   
   FUNCTION F_DIAGRAMA_UNIFILAR_SERVICO (P_ID_SEEN IN NUMBER)
    RETURN TEMP_PRLS_REC
    PIPELINED
    IS
      V_PRLS_REC PRLS_REC;   
      
      
      
    BEGIN
      FOR REG IN (select prls.prls_sq_prcs_lbrc_srvc_engr,
                         prli.prli_sq_processo_liberacao,
                         prli.prli_nr_processo_liberacao,
                         prli.prli_cd_revisao_prcs_liberacao,
                         siob.siob_sq_situacao_objeto,
                         siob.siob_nm_situacao_objeto,
                         mowo.siwo_sq_situacao_workflow,
                         mowo.siwo_nm_situacao_workflow,
                         sine.sine_sq_situacao_negociacao,
                         sine.sine_nm_situacao_negociacao,
                         sili.sili_sq_situacao_liberacao,
                         sili.sili_nm_situacao_liberacao,
                         siaj.siaj_sq_sitc_acao_judicial,
                         siaj.siaj_nm_sitc_acao_judicial,
                         fica.fica_sq_ficha_cadastral,
                         fica.fica_nr_ficha_cadastral,
                         arin.arin_sq_area_interesse,
                         arin.arin_md_extensao,
                         arin.arin_nr_kilometro_inicial,
                         arin.arin_nr_kilometro_final
                  from processo_liberacao_srvc_engr prls     
                  inner join processo_liberacao prli on prls.prli_sq_processo_liberacao = prli.prli_sq_processo_liberacao
                  inner join ficha_cadastral fica on prli.fica_sq_ficha_cadastral = fica.fica_sq_ficha_cadastral
                  inner join situacao_objeto siob on siob.siob_sq_situacao_objeto = prli.siob_sq_situacao_objeto
                  inner join (SELECT PRLI_SQ_PROCESSO_LIBERACAO, SITW.SIWO_SQ_SITUACAO_WORKFLOW, SITW.SIWO_NM_SITUACAO_WORKFLOW
                              FROM MOVIMENTO_WORKFLOW MOWO
                              INNER JOIN SITUACAO_WORKFLOW SITW ON MOWO.SIWO_SQ_SITUACAO_WORKFLOW = SITW.SIWO_SQ_SITUACAO_WORKFLOW
                              INNER JOIN (  SELECT MAX(MOWO_SQ_MOVIMENTO_WORKFLOW) MOWO_SQ_MOVIMENTO_WORKFLOW
                                            FROM MOVIMENTO_WORKFLOW
                                            GROUP BY PRLI_SQ_PROCESSO_LIBERACAO
                                          ) MOWO_MAX ON MOWO.MOWO_SQ_MOVIMENTO_WORKFLOW = MOWO_MAX.MOWO_SQ_MOVIMENTO_WORKFLOW
                  ) mowo on MOWO.PRLI_SQ_PROCESSO_LIBERACAO = PRLI.PRLI_SQ_PROCESSO_LIBERACAO
                  inner join situacao_negociacao sine on sine.sine_sq_situacao_negociacao = prls.sine_sq_situacao_negociacao
                  inner join situacao_liberacao sili on sili.sili_sq_situacao_liberacao = prls.sili_sq_situacao_liberacao
                  inner join situacao_acao_judicial siaj on siaj.siaj_sq_sitc_acao_judicial = prls.siaj_sq_sitc_acao_judicial
                  inner join area_interesse arin on arin.prli_sq_processo_liberacao = prli.prli_sq_processo_liberacao
                  inner join servico_engenharia seen on seen.seen_sq_servico_engenharia = prls.seen_sq_servico_engenharia                  
                  where (prli.siob_sq_situacao_objeto = 3 or 
                  (prli.siob_sq_situacao_objeto = 2 and prli.prli_in_revisao = 'S' and 
                    not exists (select 'x' from processo_liberacao_srvc_engr prls_max, processo_liberacao prli_max, ficha_cadastral fica_max
                                where prls_max.prli_sq_processo_liberacao = prli_max.prli_sq_processo_liberacao
                                and fica_max.fica_sq_ficha_cadastral = prli_max.fica_sq_ficha_cadastral
                                and prli_max.prli_nr_processo_liberacao = prli.prli_nr_processo_liberacao
                                and fica_max.fica_nr_ficha_cadastral = fica.fica_nr_ficha_cadastral
                                and prli_max.prli_sq_processo_liberacao > prli.prli_sq_processo_liberacao)))
                  and prli.prli_in_proprietario = 'S'   
                  and prls.prls_sq_prcs_lbrc_srvc_destino is null
                  and seen.seen_sq_servico_engenharia = P_ID_SEEN
      ) LOOP
        V_PRLS_REC.ID_PL_VINC := NULL;
        V_PRLS_REC.NR_PL_TERRA_NUA_VINC := NULL;
        V_PRLS_REC.CD_REVISAO_PL_TN_VINC := NULL;
        V_PRLS_REC.ID_SIOB_VINC := NULL;
        V_PRLS_REC.NM_SIOB_VINC := NULL;
        V_PRLS_REC.ID_SIWO_VINC := NULL;
        V_PRLS_REC.NM_SIWO_VINC := NULL;
        V_PRLS_REC.ID_SINE_VINC := NULL;
        V_PRLS_REC.NM_SINE_VINC := NULL;
        V_PRLS_REC.ID_SILI_VINC := NULL;
        V_PRLS_REC.NM_SILI_VINC := NULL;
        V_PRLS_REC.ID_SIAJ_VINC := NULL;
        V_PRLS_REC.NM_SIAJ_VINC := NULL;
        
        V_PRLS_REC.ID_FICHA := REG.FICA_SQ_FICHA_CADASTRAL;
        V_PRLS_REC.NR_FICHA := REG.FICA_NR_FICHA_CADASTRAL;
        V_PRLS_REC.ID_PL_TERRA_NUA := REG.PRLS_SQ_PRCS_LBRC_SRVC_ENGR;
        V_PRLS_REC.NR_PL_TERRA_NUA := REG.prli_nr_processo_liberacao;
        V_PRLS_REC.CD_REVISAO_PL_TN := REG.prli_cd_revisao_prcs_liberacao;
        V_PRLS_REC.ID_SIOB := REG.SIOB_SQ_SITUACAO_OBJETO;
        V_PRLS_REC.NM_SIOB := REG.SIOB_NM_SITUACAO_OBJETO;
        V_PRLS_REC.ID_SIWO := REG.SIWO_SQ_SITUACAO_WORKFLOW;
        V_PRLS_REC.NM_SIWO := REG.SIWO_NM_SITUACAO_WORKFLOW;
        V_PRLS_REC.ID_SINE := REG.SINE_SQ_SITUACAO_NEGOCIACAO;
        V_PRLS_REC.NM_SINE := REG.SINE_NM_SITUACAO_NEGOCIACAO;
        V_PRLS_REC.ID_SILI := REG.SILI_SQ_SITUACAO_LIBERACAO;
        V_PRLS_REC.NM_SILI := REG.SILI_NM_SITUACAO_LIBERACAO;
        V_PRLS_REC.ID_SIAJ := REG.SIAJ_SQ_SITC_ACAO_JUDICIAL;
        V_PRLS_REC.NM_SIAJ := REG.SIAJ_NM_SITC_ACAO_JUDICIAL;
        
        V_PRLS_REC.ID_ARIN := REG.ARIN_SQ_AREA_INTERESSE;
        V_PRLS_REC.KM_INICIAL := REG.ARIN_NR_KILOMETRO_INICIAL;
        V_PRLS_REC.KM_FINAL := REG.ARIN_NR_KILOMETRO_FINAL;
        V_PRLS_REC.MD_EXTENSAO := REG.ARIN_MD_EXTENSAO;
        
        FOR REG2 IN (select prls.prls_sq_prcs_lbrc_srvc_engr,
                       prli.prli_sq_processo_liberacao,
                       prli.prli_nr_processo_liberacao,
                       prli.prli_cd_revisao_prcs_liberacao,
                       siob.siob_sq_situacao_objeto,
                       siob.siob_nm_situacao_objeto,
                       mowo.siwo_sq_situacao_workflow,
                       mowo.siwo_nm_situacao_workflow,
                       sine.sine_sq_situacao_negociacao,
                       sine.sine_nm_situacao_negociacao,
                       sili.sili_sq_situacao_liberacao,
                       sili.sili_nm_situacao_liberacao,
                       siaj.siaj_sq_sitc_acao_judicial,
                       siaj.siaj_nm_sitc_acao_judicial                         
                from processo_liberacao_srvc_engr prls     
                inner join processo_liberacao prli on prls.prli_sq_processo_liberacao = prli.prli_sq_processo_liberacao   
                inner join ficha_cadastral fica on fica.fica_sq_ficha_cadastral = prli.fica_sq_ficha_cadastral
                inner join situacao_objeto siob on siob.siob_sq_situacao_objeto = prli.siob_sq_situacao_objeto
                inner join (SELECT PRLI_SQ_PROCESSO_LIBERACAO, SITW.SIWO_SQ_SITUACAO_WORKFLOW, SITW.SIWO_NM_SITUACAO_WORKFLOW
                            FROM MOVIMENTO_WORKFLOW MOWO
                            INNER JOIN SITUACAO_WORKFLOW SITW ON MOWO.SIWO_SQ_SITUACAO_WORKFLOW = SITW.SIWO_SQ_SITUACAO_WORKFLOW
                            INNER JOIN (  SELECT MAX(MOWO_SQ_MOVIMENTO_WORKFLOW) MOWO_SQ_MOVIMENTO_WORKFLOW
                                          FROM MOVIMENTO_WORKFLOW
                                          GROUP BY PRLI_SQ_PROCESSO_LIBERACAO
                                        ) MOWO_MAX ON MOWO.MOWO_SQ_MOVIMENTO_WORKFLOW = MOWO_MAX.MOWO_SQ_MOVIMENTO_WORKFLOW
                ) mowo on MOWO.PRLI_SQ_PROCESSO_LIBERACAO = PRLI.PRLI_SQ_PROCESSO_LIBERACAO
                inner join situacao_negociacao sine on sine.sine_sq_situacao_negociacao = prls.sine_sq_situacao_negociacao
                inner join situacao_liberacao sili on sili.sili_sq_situacao_liberacao = prls.sili_sq_situacao_liberacao
                inner join situacao_acao_judicial siaj on siaj.siaj_sq_sitc_acao_judicial = prls.siaj_sq_sitc_acao_judicial                  
                where (prli.siob_sq_situacao_objeto = 3 or 
                  (prli.siob_sq_situacao_objeto = 2 and prli.prli_in_revisao = 'S' and 
                    not exists (select 'x' from processo_liberacao_srvc_engr prls_max, processo_liberacao prli_max, ficha_cadastral fica_max
                                where prls_max.prli_sq_processo_liberacao = prli_max.prli_sq_processo_liberacao
                                and fica_max.fica_sq_ficha_cadastral = prli_max.fica_sq_ficha_cadastral
                                and prli_max.prli_nr_processo_liberacao = prli.prli_nr_processo_liberacao
                                and fica_max.fica_nr_ficha_cadastral = fica.fica_nr_ficha_cadastral
                                and prli_max.prli_sq_processo_liberacao > prli.prli_sq_processo_liberacao)))
                and prli.prli_sq_prcs_lbrc_vinculado = REG.PRLI_SQ_PROCESSO_LIBERACAO
                and prls.prls_sq_prcs_lbrc_srvc_destino is null)
          LOOP
            V_PRLS_REC.ID_PL_VINC := REG2.PRLI_SQ_PROCESSO_LIBERACAO;
            V_PRLS_REC.NR_PL_TERRA_NUA_VINC := REG2.PRLI_NR_PROCESSO_LIBERACAO;
            V_PRLS_REC.CD_REVISAO_PL_TN_VINC := REG2.PRLI_CD_REVISAO_PRCS_LIBERACAO;
            V_PRLS_REC.ID_SIOB_VINC := REG2.SIOB_SQ_SITUACAO_OBJETO;
            V_PRLS_REC.NM_SIOB_VINC := REG2.SIOB_NM_SITUACAO_OBJETO;
            V_PRLS_REC.ID_SIWO_VINC := REG2.SIWO_SQ_SITUACAO_WORKFLOW;
            V_PRLS_REC.NM_SIWO_VINC := REG2.SIWO_NM_SITUACAO_WORKFLOW;
            V_PRLS_REC.ID_SINE_VINC := REG2.SINE_SQ_SITUACAO_NEGOCIACAO;
            V_PRLS_REC.NM_SINE_VINC := REG2.SINE_NM_SITUACAO_NEGOCIACAO;
            V_PRLS_REC.ID_SILI_VINC := REG2.SILI_SQ_SITUACAO_LIBERACAO;
            V_PRLS_REC.NM_SILI_VINC := REG2.SILI_NM_SITUACAO_LIBERACAO;
            V_PRLS_REC.ID_SIAJ_VINC := REG2.SIAJ_SQ_SITC_ACAO_JUDICIAL;
            V_PRLS_REC.NM_SIAJ_VINC := REG2.SIAJ_NM_SITC_ACAO_JUDICIAL;
            
            PIPE ROW(V_PRLS_REC);
          END LOOP;
          
         if V_PRLS_REC.ID_PL_VINC is null then 
          PIPE ROW(V_PRLS_REC);
        end if;
     END LOOP;
     RETURN;
   END;
END PCK_SISGT_DIAGRAMA_UNIFILAR;