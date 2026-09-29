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
