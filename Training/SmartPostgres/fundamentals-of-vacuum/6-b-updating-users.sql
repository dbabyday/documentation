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