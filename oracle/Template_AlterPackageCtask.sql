set echo off feedback on define off lines 32767 pages 0 trimout on trimspool on

/* script out package in case a rollback is needed */
spool CTASK083954_20221004_1_rollback
column stmt format a32000
select dbms_metadata.get_ddl('PACKAGE','PKG_NON_EDI_BIZTALK_OUT','BIZTALK') stmt from dual;
spool off


/* check package status before altering */
set lines 300 pages 50
spool CTASK083954_20221004_1
column owner format a15
column object_name format a30

select   owner
       , object_name
       , object_type
       , status
       , last_ddl_time
from     dba_objects
where    owner='BIZTALK'
         and object_name='PKG_NON_EDI_BIZTALK_OUT'
order by object_type;



-- BIZTALK PACKAGES
alter session set events '10946 trace name context forever, level 65536';




/* CREATE OR REPLACE PACKAGE */











/* verify package and package body are valid */
select   owner
       , object_name
       , object_type
       , status
       , last_ddl_time
from     dba_objects
where    owner='BIZTALK'
         and object_name='PKG_NON_EDI_BIZTALK_OUT'
order by object_type;