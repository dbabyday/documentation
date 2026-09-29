/* Fundamentals of Vacuum
 * Module 5: Autovacuum's Problems Keeping Up with Many Active Tables
 * 
 * v1.0 - 2024-11-25
 * https://smartpostgres.com/fundamentals/vacuum
 * 
 * This demo works on any version of Postgres,
 * and does not require any preexisting data.
 */


/* Before doing this demo, make sure that our
 * autovacuum_max_workers is the default of 3:
 */
select *
from pg_settings 
where name = 'autovacuum_max_workers';

/* If it's not 3, set it back to 3, then restart the server: */
ALTER SYSTEM SET autovacuum_max_workers = 3;

/* Drop the 100 copy demo tables: */
DO $$
DECLARE
    i INT;
BEGIN
    FOR i IN 1..100 LOOP
        EXECUTE format($sql$
            DROP TABLE IF EXISTS users_copy_%s
        $sql$, i);
    END LOOP;
END $$;



/* Autovacuum has two important default settings:
 * It uses 3 workers to process dead tuples.
 * They sleep for 60 seconds, then wake up and process again.
 * 
 * Those settings are fine under most circumstances.
 * 
 * But what if you've got a lot more than 3 active tables,
 * and in a 60-second time span, they all have enough dead tuples
 * piled up to need vacuuming?
 * 
 * To simulate that, we'll create 100 tables and write a
 * workload to keep changing all of them. The table will be
 * like the Stack Overflow Users table, but simpler.
 */

-- Step 1: Create 100 tables
DO $$
DECLARE
    i INT;
BEGIN
    FOR i IN 1..100 LOOP
        EXECUTE format($sql$
            CREATE TABLE IF NOT EXISTS users_copy_%s (
			    user_id SERIAL PRIMARY KEY,
			    display_name VARCHAR(100) NOT NULL,
			    last_access_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
			    views INTEGER default 0
            )
        $sql$, i);
    END LOOP;
END $$;



-- Step 2: Populate users_copy_1 with 1000 rows of randomly generated names:
DO $$
DECLARE
    first_names TEXT[] := ARRAY[
        'John', 'Jane', 'Carlos', 'Maria', 'Liam', 'Emma', 'Omar', 'Aisha',
        'Wei', 'Yuki', 'Arjun', 'Priya', 'Hans', 'Greta', 'Ali', 'Fatima'
    ];
    middle_names TEXT[] := ARRAY[
        'James', 'Grace', 'Lee', 'Marie', 'Elijah', 'Sophia', 'Hassan', 'Ling',
        'Akira', 'Kumar', 'Anders', 'Nadia', 'Ahmed', 'Chen', 'Olga', 'Victor'
    ];
    last_names TEXT[] := ARRAY[
        'Smith', 'Johnson', 'Martinez', 'Garcia', 'Brown', 'Patel', 'Hernandez',
        'Yang', 'Kobayashi', 'Mehta', 'Andersen', 'Khan', 'Ivanov', 'Zhang', 'Dubois'
    ];
    i INT;
    random_first TEXT;
    random_middle TEXT;
    random_last TEXT;
    random_display_name TEXT;
BEGIN
    FOR i IN 1..1000 LOOP
        -- Generate random names
        -- Ensure random index is within bounds for each name part
        random_first := first_names[ceil(random() * array_length(first_names, 1))];
        random_middle := middle_names[ceil(random() * array_length(middle_names, 1))];
        random_last := last_names[ceil(random() * array_length(last_names, 1))];
        
        -- Concatenate into a display name
        random_display_name := random_first || ' ' || random_middle || ' ' || random_last;

        -- Insert into the table
		IF random_display_name IS NOT NULL THEN
	        INSERT INTO public.users_copy_1 (display_name, last_access_date, views)
	        VALUES (random_display_name, CURRENT_TIMESTAMP, 0);
		END IF;
    END LOOP;
END $$;



-- Verify that the table loaded 1000 rows
select count(*) from users_copy_1;



-- Populate the other 99 tables with those same 1000 rows:
DO $$
DECLARE
    i INT;
    sql_command TEXT;
BEGIN
    FOR i IN 2..100 LOOP
        -- Construct the SQL command
        sql_command := 'INSERT INTO users_copy_' || i::varchar || ' (display_name, last_access_date, views)
            SELECT display_name, last_access_date, views
            FROM users_copy_1';

        -- Log the SQL command for debugging
        --RAISE NOTICE 'Executing SQL: %', sql_command;

        -- Execute the SQL command
        EXECUTE sql_command;
    END LOOP;
END $$;





/* We could run a load test here in this demo file,
 * but to really simulate real world activity, let's
 * run a lot of queries from a lot of sessions at once.
 * 
 * To do that, we're going to use pgbench, a command line
 * utility that can fire off a lot of queries from a lot
 * of different sessions simultaneously.
 * 
 * To use pgbench on a Mac running Postgres.app, you'll need to
 * modify your path:
 * https://postgresapp.com/documentation/cli-tools.html
 * 
 * The below is saved in 5-b-updating-many-tables.sql:
 */
DO $$
DECLARE
    i INT;
    sql_command TEXT;
    first_names TEXT[] := ARRAY[
        'John', 'Jane', 'Carlos', 'Maria', 'Liam', 'Emma', 'Omar', 'Aisha',
        'Wei', 'Yuki', 'Arjun', 'Priya', 'Hans', 'Greta', 'Ali', 'Fatima'
    ];
    random_first TEXT;
BEGIN

   FOR i IN 1..100 LOOP
		random_first := first_names[ceil(random() * array_length(first_names, 1))];

        -- Construct the SQL command
        sql_command := 'UPDATE users_copy_' || (FLOOR(RANDOM() * 100 + 1)::INT)::varchar || ' SET last_access_date = CURRENT_TIMESTAMP, views = views + 1
	    	WHERE display_name LIKE ''' || random_first || ' %'';';

        -- Log the SQL command for debugging
        --RAISE NOTICE 'Executing SQL: %', sql_command;

        -- Execute the SQL command
        EXECUTE sql_command;
    END LOOP;
END $$;





/* Call it from pgbench by going into the folder where
 * the sql file is located, then run:
 * 
 * pgbench -c 50 -f 5-b-updating-many-tables.sql -j 4 -n -t 30
 * 
 * Those parameters:
 * -f is the file we want to run
 * -j 4 means use 4 threads (basically CPU cores) to run the workload
 * -c 50 means run 50 clients, like simulating 50 web or app servers
 * -5 30 means each client will run the file 30 times (transactions)
 * -n means don't vacuum before kicking off
 *
 * 
 * Verify that the workload is running: 
 */
select * from pg_stat_activity;



/* 
 * While it runs, check the table and the number of views
 * should keep going up, indicating that rows are changing:
 */

select table_name, size_kb, dead_tuples, last_autovacuum, warning_summary, warning_details
from check_indexes('public', null)
where dead_tuples is not null
  and index_type = 'ordinary table'
order by dead_tuples desc limit 100;


/* Note that:
 * size_kb is going up
 * dead_tuples is going up
 * last_autovacuum is present in some tables, but not others
 * Warnings about vacuum happening now, autovacuum not keeping up
 * 
 *
 * After teaching, cancel pgbench, 
 * watch auto vacuum gradually catch up:
*/
select * from pg_stat_activity;


select table_name, size_kb, dead_tuples, last_autovacuum, warning_summary, warning_details
from check_indexes('public', null)
where dead_tuples is not null
  and index_type = 'ordinary table'
order by dead_tuples desc limit 100;




/* We can help autovacuum catch up more quickly by
 * configuring it to have more workers, which can
 * process more tables simultaneously, at the risk
 * of using more CPU, memory, and IO throughput.
 * 
 * https://postgresqlco.nf/doc/en/param/autovacuum_max_workers/
 * 
 * The default is 3. Let's check ours:
 */
select *
from pg_settings 
where name = 'autovacuum_max_workers';


ALTER SYSTEM SET autovacuum_max_workers = 10;
/* If you're using AWS RDS, here's how to set it:
 * https://docs.aws.amazon.com/prescriptive-guidance/latest/tuning-postgresql-parameters/autovacuum-max-workers.html
 * 
 * If you're on Postgres 17 or higher, alter system may
 * be disabled, and you may have to edit configuration files
 * outside of your server, like in a default container used
 * for provisioning high availability:
 * https://www.dbi-services.com/blog/postgresql-17-add-allow_alter_system-guc/
*/



/* Restart our Postgres server, and check again: */
select *
from pg_settings 
where name = 'autovacuum_max_workers';



/* After autovacuum has caught up, try the workload again.
 * pgbench -c 50 -f 5-b-updating-many-tables.sql -j 4 -n -t 30
 * 
 * If you want to see if we're catching up,
 * although note that you might have dead tuples
 * without hitting the autovacuum threshold.
 */
select * from pg_stat_activity;
select * from pg_stat_progress_vacuum;

select table_name, size_kb, dead_tuples, last_autovacuum, warning_summary, warning_details
from check_indexes('public', null)
where dead_tuples is not null
  and index_type = 'ordinary table'
order by dead_tuples desc limit 100;



/* Drop the 100 copy demo tables: */
DO $$
DECLARE
    i INT;
BEGIN
    FOR i IN 1..100 LOOP
        EXECUTE format($sql$
            DROP TABLE IF EXISTS users_copy_%s
        $sql$, i);
    END LOOP;
END $$;


/* Recap: if your check_indexes reports that autovacuum
 * isn't keeping up across a lot of tables, and this scenario
 * rings a bell with you, you probably want to gradually 
 * increase the number of autovacuum workers over the span
 * of days.
 * 
 * Just go slowly: the more autovacuum workers you add,
 * the more CPU overhead you're adding.
 */