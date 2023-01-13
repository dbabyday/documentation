

-- add an hour
select to_char(sysdate,'MM/DD/YYYY HH:MI:SS')
     , to_char(sysdate + 1/24,'MM/DD/YYYY HH:MI:SS')
     , systimestamp
     , systimestamp + numtodsinterval(1,'hour')
from dual;


-- add a day
select sysdate + 1 as add_day
     , systimestamp  +  numtodsinterval(1, 'day')
from dual;


-- add a week
select sysdate + 7 as add_day
     , systimestamp  +  numtodsinterval(7, 'day')
from dual;


-- add a month
select add_months(sysdate, 1) add_month
     , cast(add_months(systimestamp,1) as timestamp with time zone)
from dual;


-- add a year
select add_months(sysdate, 12) add_month
     , cast(add_months(systimestamp,12) as timestamp with time zone)
from dual;


-- duration
select extract(day from diff)*24 + extract(hour from diff)
into   elapsed_mins
from   (select to_timestamp('2021-10-08 14:00:00','YYYY-MM-DD HH24:MI:SS')-to_timestamp('2021-10-11 07:00:00','YYYY-MM-DD HH24:MI:SS') diff from dual);








select 
       extract(day    from (to_timestamp('2021-10-08 07:42:12','YYYY-MM-DD HH24:MI:SS')-to_timestamp('2021-10-08 06:24:58','YYYY-MM-DD HH24:MI:SS'))) lag_days
     , extract(hour   from (to_timestamp('2021-10-08 07:42:12','YYYY-MM-DD HH24:MI:SS')-to_timestamp('2021-10-08 06:24:58','YYYY-MM-DD HH24:MI:SS'))) lag_hours
     , extract(minute from (to_timestamp('2021-10-08 07:42:12','YYYY-MM-DD HH24:MI:SS')-to_timestamp('2021-10-08 06:24:58','YYYY-MM-DD HH24:MI:SS'))) lag_minutes
     , extract(second from (to_timestamp('2021-10-08 07:42:12','YYYY-MM-DD HH24:MI:SS')-to_timestamp('2021-10-08 06:24:58','YYYY-MM-DD HH24:MI:SS'))) lag_seconds
from dual;


select	  source_entry_time
	, target_entry_time
	, to_char(extract(day from (target_entry_time-source_entry_time)))||' days '||
		lpad(to_char(extract(hour from (target_entry_time-source_entry_time))),2,'0')||':'||
		lpad(to_char(extract(minute from (target_entry_time-source_entry_time))),2,'0')||':'||
		lpad(to_char(round(extract(second from (target_entry_time-source_entry_time)),0)),2,'0') lag_time
	-- , extract(day from (target_entry_time-source_entry_time))*24*60*60 +
	-- 	extract(hour from (target_entry_time-source_entry_time))*60*60 +
	-- 	extract(minute from (target_entry_time-source_entry_time))*60 +
	-- 	round(extract(second from (target_entry_time-source_entry_time)),0) lag_in_seconds
	, extract(day from (target_entry_time-source_entry_time))*24*60 +
		extract(hour from (target_entry_time-source_entry_time))*60 +
		extract(minute from (target_entry_time-source_entry_time)) +
		round(extract(second from (target_entry_time-source_entry_time))/60,0) lag_in_minutes
from	  ca.repl_canary_a
where     extract(day from (target_entry_time-source_entry_time))*24*60 +
		extract(hour from (target_entry_time-source_entry_time))*60 +
		extract(minute from (target_entry_time-source_entry_time)) +
		round(extract(second from (target_entry_time-source_entry_time))/60,0) > 0
order by  source_entry_time;






column replication_stream format a18

select	  'A' replication_stream
	, extract(day from (diff))*24*60 +
		extract(hour from (diff))*60 +
		extract(minute from (diff)) lag_in_minutes
from	  (select systimestamp - max(source_entry_time) diff from ca.repl_canary_a)
union all
select	'C' replication_stream
	, extract(day from (diff))*24*60 +
		extract(hour from (diff))*60 +
		extract(minute from (diff)) lag_in_minutes
from	  (select systimestamp - max(source_entry_time) diff from ca.repl_canary_c)
order by  1;

hist 36 run
hist 42 run




23722  31 Jan 2022 00:00    
23723  31 Jan 2022 01:00    awrrpt_jdepd03_0000_0100.html
23724  31 Jan 2022 02:00    awrrpt_jdepd03_0100_0200.html
23725  31 Jan 2022 03:00    awrrpt_jdepd03_0200_0300.html
23726  31 Jan 2022 04:00    awrrpt_jdepd03_0300_0400.html
23727  31 Jan 2022 05:00    awrrpt_jdepd03_0400_0500.html
23728  31 Jan 2022 06:00    awrrpt_jdepd03_0500_0600.html
23729  31 Jan 2022 07:00    awrrpt_jdepd03_0600_0700.html
23730  31 Jan 2022 08:00    awrrpt_jdepd03_0700_0800.html
23731  31 Jan 2022 09:00    awrrpt_jdepd03_0800_0900.html
23732  31 Jan 2022 10:01    awrrpt_jdepd03_0900_1000.html
23733  31 Jan 2022 11:00    awrrpt_jdepd03_1000_1100.html


