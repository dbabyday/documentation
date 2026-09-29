/* Fundamentals of Vacuum
 * Module 6: Autovacuum's Problems Keeping Up with Blocking
 * 
 * v1.0 - 2024-11-25
 * https://smartpostgres.com/fundamentals/vacuum
 * 
 * This demo works on any version of Postgres,
 * and does not require any preexisting data.
 */


/* Make sure naptime is at the system default of 60s: */
select *
from pg_settings 
where name = 'autovacuum_naptime';

/* If not, set it back to 60s and restart the server: */
alter system set autovacuum_naptime = '60s';
SELECT pg_reload_conf();

/* Restart */

-- Make sure it took effect
select *
from pg_settings 
where name = 'autovacuum_naptime';




/* Autovacuum has two important default settings:
 * It uses 3 workers to process dead tuples.
 * They sleep for 60 seconds, then wake up and process again.
 * 
 * Those settings are fine under most circumstances.
 * 
 * But what if you've got a single table that's very active,
 * with lots of blocking happening on it all the time?
 * 
 * 
 * 
 * We'll use the same simple version of the Stack Overflow
 * Users table that we used in the last demo, but this time
 * we'll use just 1 table instead of 100, and we'll focus
 * all of the pgbench loads on that one table.
 * 
 * We're also going to create a couple of indexes on the
 * table so that inserts/updates/deletes have more work:
 */
DROP TABLE IF EXISTS public.users;
CREATE TABLE public.users (
    user_id SERIAL PRIMARY KEY,
    display_name VARCHAR(100) NOT NULL,
    last_access_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    views INTEGER default 0
);
create index last_access_date on public.users(last_access_date);
create index views on public.users(views);



-- Generate random names and insert 1000 rows
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
	        INSERT INTO public.users (display_name, last_access_date, views)
	        VALUES (random_display_name, CURRENT_TIMESTAMP, 0);
		END IF;
    END LOOP;
END $$;



-- Show that rows went in with random names:
select * from public.users limit 100;
select count(*) from public.users;



-- Check the starting table size:
select table_name, index_name, index_type, size_kb, dead_tuples, last_autovacuum
from check_indexes('public', 'users');





/* We're going to use pgbench to generate load.
 * The below is saved in 6-b-updating-users.sql:
 */


DO $$
DECLARE
    first_names TEXT[] := ARRAY[
        'John', 'Jane', 'Carlos', 'Maria', 'Liam', 'Emma', 'Omar', 'Aisha',
        'Wei', 'Yuki', 'Arjun', 'Priya', 'Hans', 'Greta', 'Ali', 'Fatima'
    ];
    i INT;
    random_first TEXT;
BEGIN
    random_first := first_names[ceil(random() * array_length(first_names, 1))];

    -- Insert into the table
	IF random_first IS NOT NULL THEN
	    UPDATE public.users
	    SET last_access_date = CURRENT_TIMESTAMP, views = views + 1
	    WHERE display_name LIKE random_first || ' %';
	END IF;

	PERFORM pg_sleep(1); -- wait a second
END $$;



/* Call it from pgbench by going into the folder where
 * the sql file is located, then run:
 * 
 * pgbench -c 50 -f 6-b-updating-users.sql -j 4 -n -t 30
 * 
 * While it runs, check the table and the number of views
 * should keep going up, indicating that rows are changing:
 */
select * from public.users order by views desc limit 100;

/* Note that object sizes and dead tuple counts are going up.
 * The rising dead tuple counts are an indication that
 * autovacuum can't keep up. If it was freeing the dead tuples,
 * we would have leftover space on the 8KB pages, but because
 * they don't, the table size will continue to bloat.
 */
select table_name, index_name, index_type, size_kb, dead_tuples, last_autovacuum, warning_summary, warning_details
from check_indexes('public', 'users');


/* Once the activity stops, then autovaccum can remove the
* dead tuples. Cancel pgbench, then as autovacuum kicks off,
* note that dead tuples goes back to 0.
*/
select table_name, index_name, index_type, size_kb, dead_tuples, last_autovacuum, warning_summary, warning_details
from check_indexes('public', 'users');





/* We can have autovacuum try to jump in more often,
 * sneaking in locks whenever it can.
 * 
 * By default, autovacuum naps for 60 seconds, which
 * means it'll only try 60x per hour on tables, and
 * if you've got serious blocking workloads, that
 * might not be enough.
 * 
 * We can reduce that naptime to let autovacuum
 * try more frequently. Here, I'm going to use an
 * extreme number of waking up every 1 second:
 */
alter system set autovacuum_naptime = '1s';
SELECT pg_reload_conf();

/* Restart the server */

-- Make sure it took effect
select *
from pg_settings 
where name = 'autovacuum_naptime';


/* Run the workload again, and while it runs, watch
 * dead_tuples:
 */
select table_name, index_name, index_type, size_kb, dead_tuples, last_autovacuum, warning_summary, warning_details
from check_indexes('public', 'users');




/* Another option is to set autovacuum to do more work
 * each time that it runs:
 */
ALTER TABLE public.users
SET (
    autovacuum_vacuum_cost_delay = 0,  -- Run autovacuum without a delay
    autovacuum_vacuum_cost_limit = 10000  -- Allow more work to be done per cycle
);
/* Documentation on those settings:
 * https://postgresqlco.nf/doc/en/param/autovacuum_vacuum_cost_delay/
 * https://postgresqlco.nf/doc/en/param/autovacuum_vacuum_cost_limit/
 * 
 * I personally don't have any experience with those settings, though,
 * so I see 'em as a footgun, at least for my experience level.
 */


/* However, if your locking/blocking is going on longer,
 * like 24/7, the longer autovacuum is delayed,
 * which means more dead tuples pile up, which means new tuples
 * (row versions) are forced to grow the size of the object,
 * because there's no empty space left to write new versions.
 * 
 * Autovacuum marks the dead tuples' space as available to
 * reuse, which stops object growth because new tuples (versions)
 * can be written to the dead tuple space.
 * 
 * Note that the table size does not go back to its original
 * tiny numbers, though. Shrinking the size of the table
 * isn't autovacuum's job. That would require a vacuum full
 * or a cluster.
 * 
 * The longer your workload goes with blocking,
 * the less likely autovacuum can keep up,
 * and the more likely you'll need to do a vacuum full
 * whenever autovacuum does fire off.
 * 
 * If we try to do manual vacuuming while the blocking
 * workload is happening, users will be angry. We may have
 * to schedule an outage to do a full vacuum.
 */


/* Clean up after ourselves: */
DROP TABLE IF EXISTS public.users;

alter system set autovacuum_naptime = '60s';
SELECT pg_reload_conf();

/* Restart */

-- Make sure it took effect
select *
from pg_settings 
where name = 'autovacuum_naptime';
