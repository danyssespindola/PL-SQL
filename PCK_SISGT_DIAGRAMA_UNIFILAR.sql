create or replace
PACKAGE PCK_SISGT_DIAGRAMA_UNIFILAR
    IS
    
      TYPE prls_rec IS RECORD
      (ID_FICHA number(20),
       NR_FICHA CHAR(16),
       ID_PL_TERRA_NUA number(20),
       NR_PL_TERRA_NUA number(3),
       CD_REVISAO_PL_TN varchar2(2),
       ID_SIOB number(20),
       NM_SIOB varchar2(70),
       ID_SIWO number(20),
       NM_SIWO varchar2(70),
       ID_SINE number(20),
       NM_SINE varchar2(70),
       ID_SILI number(20),
       NM_SILI varchar2(70),
       ID_SIAJ number(20),
       NM_SIAJ varchar2(70),
       ID_ARIN NUMBER(20),
       KM_INICIAL NUMBER(7,3),
       KM_FINAL NUMBER(7,3),
       MD_EXTENSAO NUMBER(9,2),
       ID_PL_VINC number(20),
       NR_PL_TERRA_NUA_VINC number(3),
       CD_REVISAO_PL_TN_VINC varchar2(2),
       ID_SIOB_VINC number(20),
       NM_SIOB_VINC varchar2(70),
       ID_SIWO_VINC number(20),
       NM_SIWO_VINC varchar2(70),
       ID_SINE_VINC number(20),
       NM_SINE_VINC varchar2(70),
       ID_SILI_VINC number(20),
       NM_SILI_VINC varchar2(70),
       ID_SIAJ_VINC number(20),
       NM_SIAJ_VINC varchar2(70));
 
  TYPE TEMP_PRLS_REC IS TABLE OF PRLS_REC;
  
  FUNCTION F_DIAGRAMA_UNIFILAR_OBRA (P_ID_OBRA IN NUMBER) RETURN TEMP_PRLS_REC PIPELINED;
  FUNCTION F_DIAGRAMA_UNIFILAR_SERVICO (P_ID_SEEN IN NUMBER) RETURN TEMP_PRLS_REC PIPELINED;
  
 END;