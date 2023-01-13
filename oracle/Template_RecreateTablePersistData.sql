
/*

	Note: This table needs data persisted. This script is set up to 
		1. create a backup table with the data from the original table
		2. drop the original table
		3. create the new table
		4. insert the data from the backup table into the new table
		5. drop the backup table

	It is advised to run these steps individually to ensure the data is backed up 
	and re-inserted successfully before the tables are dropped.

*/


/* Do not run the entire script at once */
WHENEVER SQLERROR EXIT
prompt WARNING: Do not run this script all together. You should manually execute one section at a time.;
prompt Exiting script now, without executing any commands.;
select 1/0 from dual;



/* 1. Backup the data */
create table <TABLE_NAME>_BAK as 
select * from PRODDTA.<TABLE_NAME>;

-- make sure the row counts match
select 'PRODDTA.<TABLE_NAME>' tbl, count(*) from PRODDTA.<TABLE_NAME>
union all
select '<TABLE_NAME>_BAK' tbl, count(*) from <TABLE_NAME>_BAK;



/* 2. Drop original table */
drop table PRODDTA.<TABLE_NAME>;



/* 3. Create new table */





/* 4. Insert data from backup table */
insert into PRODDTA.<TABLE_NAME> (
	COL1,COL2,COL3...
)
select COL1,COL2,COL3...
from   <TABLE_NAME>_BAK;

-- make sure the row counts match
select 'PRODDTA.<TABLE_NAME>' tbl, count(*) from PRODDTA.<TABLE_NAME>
union all
select '<TABLE_NAME>_BAK' tbl, count(*) from <TABLE_NAME>_BAK;

commit;



/* 5. drop backup table */
drop table <TABLE_NAME>_BAK;
