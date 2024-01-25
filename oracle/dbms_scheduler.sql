



/*
-- http://blog.data-alchemy.org/tips/oracle-scheduler-disable/#:~:text=Disable%20DBMS%20Scheduler%20You%20can%20disable%20the%20Scheduler,dbms_scheduler.set_scheduler_attribute%20%28%27SCHEDULER_DISABLED%27%2C%20%27TRUE%27%29%3B%20PL%20%2FSQL%20procedure%20successfully%20completed.

-- check if the scheduler is enabled
select value from dba_scheduler_global_attribute where attribute_name = 'SCHEDULER_DISABLED';

-- enable scheduler
exec dbms_scheduler.set_scheduler_attribute ( 'SCHEDULER_DISABLED', 'FALSE');

-- disable scheduler
exec dbms_scheduler.set_scheduler_attribute ( 'SCHEDULER_DISABLED', 'TRUE' );


*/




insert into proddta.a (x,y) select systimestamp, trunc(dbms_random.value(1,10)) from dual;


delete from proddta.a where y<(select trunc(dbms_random.value(1,10)) from dual);


delete from proddta.a where y>(select trunc(dbms_random.value(1,10)) from dual);


update proddta.a set y=(select trunc(dbms_random.value(1,10)) where y=(select trunc(dbms_random.value(1,10));




begin
	-- create a program the execute the procedure
	dbms_scheduler.create_program (
		  program_name   => 'PRODDTA.P_F5541043_LOT2_UPD_PROG'
		, program_type   => 'STORED_PROCEDURE'
		, program_action => 'PRODDTA.P_F5541043_LOT2_UPD'
		, enabled        => TRUE
	);

	-- create a schedule
	dbms_scheduler.create_schedule (
		  schedule_name   => 'PRODDTA.P_F5541043_LOT2_UPD_SCHED'
		, start_date      => to_timestamp('2023-11-22 15:30:00','YYYY-MM-DD HH24:MI:SS')
		, repeat_interval => 'FREQ=MINUTELY; INTERVAL=5'
		, comments        => 'Every 5 minutes'
	);

	-- create a job to run the program on the schedule
	dbms_scheduler.create_job (
		  job_name      => 'PRODDTA.P_F5541043_LOT2_UPD_JOB'
		, program_name  => 'PRODDTA.P_F5541043_LOT2_UPD_PROG'
		, schedule_name => 'PRODDTA.P_F5541043_LOT2_UPD_SCHED'
		, enabled       => TRUE
	);
end;
/



-- enable the job
exec dbms_scheduler.enable('CA.ARCHIVE_EXTENTS_JOB');

-- disable the job
exec dbms_scheduler.disable('CA.ARCHIVE_EXTENTS_JOB');





select * from dba_scheduler_job_run_details where job_name='a_update_JOB';

select * from dba_scheduler_job_log where job_name='a_update_JOB';

-- find enabled jobs
col job_name for a70
col enabled for a7
select owner||'.'||job_name job_name, enabled from dba_scheduler_jobs where enabled='TRUE' order by 1;



-- disable job
exec dbms_scheduler.disable('PRODDTA.a_update_JOB');

-- drop job
exec dbms_scheduler.drop_job('PRODDTA.P_F5541043_LOT2_UPD_JOB');
exec dbms_scheduler.drop_schedule('PRODDTA.P_F5541043_LOT2_UPD_SCHED');
exec dbms_scheduler.drop_program('PRODDTA.P_F5541043_LOT2_UPD_PROG');



VIEW_NAME
---------------------------------------
DBA_SCHEDULER_CHAINS
DBA_SCHEDULER_CHAIN_RULES
DBA_SCHEDULER_CHAIN_STEPS
DBA_SCHEDULER_CREDENTIALS
DBA_SCHEDULER_DB_DESTS
DBA_SCHEDULER_DESTS
DBA_SCHEDULER_EXTERNAL_DESTS
DBA_SCHEDULER_FILE_WATCHERS
DBA_SCHEDULER_GLOBAL_ATTRIBUTE
DBA_SCHEDULER_GROUPS
DBA_SCHEDULER_GROUP_MEMBERS
DBA_SCHEDULER_INCOMPATS
DBA_SCHEDULER_INCOMPAT_MEMBER
DBA_SCHEDULER_JOBS
DBA_SCHEDULER_JOB_ARGS
DBA_SCHEDULER_JOB_CLASSES
DBA_SCHEDULER_JOB_DESTS
DBA_SCHEDULER_JOB_LOG
DBA_SCHEDULER_JOB_ROLES
DBA_SCHEDULER_JOB_RUN_DETAILS
DBA_SCHEDULER_NOTIFICATIONS
DBA_SCHEDULER_PROGRAMS
DBA_SCHEDULER_PROGRAM_ARGS
DBA_SCHEDULER_REMOTE_DATABASES
DBA_SCHEDULER_REMOTE_JOBSTATE
DBA_SCHEDULER_RESOURCES
DBA_SCHEDULER_RSC_CONSTRAINTS
DBA_SCHEDULER_RUNNING_CHAINS
DBA_SCHEDULER_RUNNING_JOBS
DBA_SCHEDULER_SCHEDULES
DBA_SCHEDULER_WINDOWS
DBA_SCHEDULER_WINDOW_DETAILS
DBA_SCHEDULER_WINDOW_GROUPS
DBA_SCHEDULER_WINDOW_LOG
DBA_SCHEDULER_WINGROUP_MEMBERS




-- execute the PDU stored procedure to update any necessary records right now
EXECUTE PRODDTA.MTRL_PO_NEXT_STATUS_UPDATE_PROG;

-- update the schedule's end date
BEGIN
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'PRODDTA.P_F5541043_LOT2_UPD_SCHED'
     ,attribute => 'END_DATE'
     ,value     => TO_TIMESTAMP('2024-01-13 00:00:00','YYYY-MM-DD HH24:MI:SS'));
END;
/

-- create a job to run the program on the schedule
begin
	dbms_scheduler.create_job (
		job_name      => 'PRODDTA.MTRL_PO_NEXT_STATUS_UPDATE_JOB',
		program_name  => 'PRODDTA.MTRL_PO_NEXT_STATUS_UPDATE_PROG',
		schedule_name => 'PRODDTA.MTRL_PO_NEXT_STATUS_UPDATE_EVERY_2_HOURS');
end;
/



