-- Move SQL Plan Baseline to other Instance
-- https://expertoracle.com/2016/05/17/move-sql-baseline-to-other-instance/


--STEP 1) create a staging table
BEGIN
  DBMS_SPM.CREATE_STGTAB_BASELINE(table_name => 'stage');
END;
/


-- STEP 2) Pack the SQL plan baselines
DECLARE
	my_plans number;
BEGIN
	my_plans := DBMS_SPM.PACK_STGTAB_BASELINE(
		table_name => 'stage',
		enabled => 'yes',
		SQL_HANDLE => 'SQL_e55ac78551b6f3a2'
	);
END;
/


-- STEP 3) Export the staging table
expdp tables=jlutsey.stage directory=tmp_oracle dumpfile=stage.dmp logfile=stage.log compression=all


-- STEP 4) Transfer the flat file to the target system.


-- STEP 5) Import the staging table
impdp dumpfile=stage.dmp directory=tmp_oracle logfile=stage_imp.log


-- STEP 6 ) Unpack the SQL plan baselines
DECLARE
	l_plans_unpacked  PLS_INTEGER;
BEGIN
	l_plans_unpacked := DBMS_SPM.UNPACK_STGTAB_BASELINE(
		table_name      => 'STAGE',
		table_owner     => 'JLUTSEY',
		creator         => 'JLUTSEY'
	);
DBMS_OUTPUT.put_line('Plans Unpacked: ' || l_plans_unpacked);
END;
/


-- STEP 7) VERIFY
select * from dba_sql_plan_baselines;


