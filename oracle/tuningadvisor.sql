/*

15hkmst178u3r

*/

set 


-- 1. Create Tuning Task
DECLARE
  l_sql_tune_task_id  VARCHAR2(100);
BEGIN
  l_sql_tune_task_id := DBMS_SQLTUNE.create_tuning_task (
                          sql_id      => '&&sql_id',
                          scope       => DBMS_SQLTUNE.scope_comprehensive,
                          time_limit  => 500,
                          task_name   => 'JamesTuningTask_&&sql_id',
                          description => 'Tuning task1 for statement &&sql_id');
  DBMS_OUTPUT.put_line('l_sql_tune_task_id: ' || l_sql_tune_task_id);
END;
/


-- 2. Execute Tuning task
EXEC DBMS_SQLTUNE.execute_tuning_task(task_name => 'JamesTuningTask_&&sql_id');


-- 3. Get the Tuning advisor report
set long 65536
set longchunksize 65536
set linesize 200
select dbms_sqltune.report_tuning_task('JamesTuningTask_&&sql_id') from dual;


-- 4. Get list of tuning task present in database
-- SELECT TASK_NAME, STATUS FROM DBA_ADVISOR_LOG WHERE TASK_NAME like 'JamesTuningTask';


-- 5. Drop a tuning task
execute dbms_sqltune.drop_tuning_task('JamesTuningTask_&&sql_id');

