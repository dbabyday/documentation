# Mastering Query Tuning

## How SQL Server Builds Query Plans

* **Query Optimizer** builds a query plan
    * like an Architect builds a blueprint
* **Query Processor** executes the plan
    * like a builder makes the house from the blueprints

#### Focus on:
* What to tell the Query Optimizer
* How the Query Optimizer builds the plans
* How the Query Processor executes the plans
* How to get the plan you really want

### Optimization Levels
* **TRIVIAL**
    * Query so simple it shouldn't need any time or effort to evaluate a plan
    * No parallelism
    * No missing index recommendations
    * Usually not your biggest problem, *execpt when you have a simple query that runs thousands of times per second and needs an index but one is not recommended*
* **FULL**
    1. Full, but exiting early for a good reason  
    2. Full, but exiting early for a bad reason (timeout)  
    3. Full, after extensive evaluations  
    * Rewriting join order, getting different data first
    * Consider different indexes, batch mode
    * Using objects you didn't ask for: indexed views, computed columns
    * Eliminating joins using foreign keys & constraints
    * Rewriting UNION, UNION ALL
    * --> these all use more CPU time (and can vary by a lot)

#### Estimated costs are like budgets
* Guess by optimizer soley for the purpose of designing better plans
* Not reported by the execution, even for actual plans

#### Estimated costs: almost useless
* Not good for: comparing which plan was actually better
* Good for: understanding why SQL Server chose one plan over another before exectuion started

#### Good Enough Plan Found
* Full, but terminated optimization early because we found a plan early that is expected to be good based on the query (not actual execution)

#### Timeout
* Full, but optimizer gave up because it is taking too long to build more exection plans
* If SQL Server under CPU load, it may call a timeout earlier because there is less CPU to use
* Memory pressure also affects timeouts if having to wait in memory


## When the Optimizer Gets an Early Estimate Wrong
#### Where to start
* Run the query and get the actual plan
* Read the plan right to left, top to bottom
* On each operator, check estimated vs actual rows
* If 10X high or low, find out why, fix it

#### 2 Kinds of Estimates
* "Early" (usually do these first)
    * Query has a filter (typically WHERE, but can be elsewhere)
    * SQL Server uses statistics to guess how many rows will match the filter
    * Usually executed first in exection plan
* "Late" (usually do these later)
    * Your query joins to other tables
    * There is no direct filter on those tables
    * What we're looking for is based off the early filters on other tables
    * A multiplier of the early estimeates (high=high here, low=low here)
    * Based on density vectors, averages
    * If early estimates are wrong, these are really wrong

#### Estimates come from statistics
* DBCC SHOW_STATISTICS('schema.table','index'), sys.dm_db_stats_histogram, sp_BlitzIndex
    * Not used very often, but can be used to show client what is going on
* Free YouTube class: BrentOzar.com/go/statsclass
* Stats have buckets for values or ranges of values
    * You get the average for that bucket
    * If you obfuscate value (with functions), you get an average from the density
* **Early Estimation Errors**
    1. WHERE clause that is not easy to understand
        * system funcitons (string, math, esp date math)
        * User-defined functions (scalar, TVFs)
        * Fetching data from configuration tables
    2. Data size grew to where 201 buckets wasn't enough
        * Can't fix it, can only limit bad effects
        * ex: run a query to get those first results, then run the main with recompile
    3. Statistics done with really low sampling rates
        * Ruled out obfuscated WHERE clause...
        * Check histogram for estimate
        * Check number of rows that actually exist
        * Consider updating statistics with fullscan
        * Check out PERSIST_SAMPLE_PERCENT = ON
    4. Statistics out of date
        * SQL Server automatically updates stats when about 20% of the data changes
        * Use regular stats update jobs (Ola Hallengren's)
        * Monthly or weekly is usually good enough
        * With fullscan if you can


## When the Optimizer Gets an Late Estimate Wrong
* Number of executions x estimated number of rows per execution
    * Estmiated number of rows comes from density vector x number of rows in table
    * Just a guess

#### Goes Wrong
* Makes a bad Early Estimate
    * Fix root cause...Always work right to left, top to bottom
    * Fix by Mitigate effects: break query into two parts
* Early estimate is accurate, but second table has outliners that match (way less or more than average number of rows)
    * Query the data to find outliners
        >SELECT TOP(100) 
              u.Location  
            , (SUM(1) / COUNT(DISTINCT u.Id)) AS PostsPerUser  
            , COUNT(DISTINCT u.Id) AS Residents  
            , SUM(1) AS TotalPosts  
        FROM dbo.Users u  
        JOIN dbo.Posts p ON u.Id = p.OwnerUserId  
        GROUP BY u.Location  
        ORDER BY (SUM(1) / COUNT(DISTINCT u.Id)) DESC;  
    * No fix when we hit an outlier for late estimate

#### Break Query into Two Parts
1. Read plan right to left, top to bottom
2. Find place whre estimates vs actuals suddenly went 10X higher or lower
3. Break query into two parts  
    * Phase 1 runs, insert into temp table  
    * Phase 2 runs, SQL Server builds stats on the temp table, understands how many rows came out of Phase 1  
* Can still hit the issue with only 201 buckets statistics problem
* Can push Phase 2 to later in the plan
    * Put all the results into a temp table
    * Select from the the temp table to do your sort (ORDER BY, TOP, ...)
    * Gets rid of memory grant issue
* **CATCH**
    * Temp tables are reused across sessions (strcture and statistics)
    * You can inherit someone else's stats, even if you drop the temp tables
    * Think of it like OPTION(RANDOM RECOMPILE)
* If you only get one set of values from first part, usually best to put them into variables and use the variables in the second part with OPTION(RECOMPILE) or a child stored proc

####  When All Estimates are Close, but Still Slow
* 3 possible fixes  
    * Add or tune indexes so there is less work to do
    * Reorder operations in the query
    * Add hardware

#### If You Have lots of separate statements and first estimates are close
* Try combining statements together with a CTE
* This lets SQL Server reorder its operations and may look at a different table first




## How SQL Server 2017, 2019, and 2022 Try to Fix Queries Automatically

### Batch Mode Execution
* Reduces CPU and elapsed time
* 2017 for columnstore, 2019 for rowstore
* Plans - Have to hover mouse over operator to see execution mode

### TVF Ineterleaved Executions
* Multi-Statement Table-Valued Functions
    * Hard to see in they query plan, stats IO
    * Can run row-by-row
    * Estimates are hard-coded (100 or 1)
        * 2017 can fix by running the MSTVF first, then passing the row esxtimates to the rest of the plan
        * Still avoid: Know number of rows, but not contents...it just sucks less

### Scalar Function Inlining
* Internal SQL Server change of scalar functions to run and return as set based
* Lots of exceptions
* Can be very CPU intensive

### Adaptive Memory Grants
* SQL Server watches how much memory is used, and adjusts the plan
    * As parameters change and memory requirements change a lot, you get BIG swings in memory grants and spills
* Only works if your query needs the same amount of memory every time
    * Grant feedback is disabled for parameter-sensitive plans
* Issues
    * No proactive warning when it's happening
    * Minimal instrumentation
    * Monitoring tools don't cover it
    * Resets constantly on index rebuilds, stats updates, failovers, restarts
* On by default in compat 150 (2019)
* To turn off
    > ALTER DATABASE SCOPED CONFIGURATION SET BATCH_MODE_MEMORY_GRANT_FEEDBACK = OFF;  
    ALTER DATABASE SCOPED CONFIGURATION SET ROW_MODE_MEMORY_GRANT_FEEDBACK = OFF;  
* Getting better in 2022

### Adaptive Joins
* Joining between 2 tables
    * When the driver table returns just a few rows, then it makes sense to do nested loops: one operation per row that it finds.
    * When the driver table returns a lot of rows, then it makes sense to do a hash join: scan the other table and check all the rows.
    * Both operations are shown, but only one will be executed
        * Essentially 2 execution plans cached in one
    * Adaptive join has to buffer and wait to see how many rows are coming before deciding
* Hard to get in the execution plan
    * Great when they are there
* Issue: Uses memory, and can be highly affected by adaptive memory grants (should disable adaptive memory grants)

### Automatic Tuning
"Automatic Plan Regression"
* How it works
    * Turn on Query store
    * Get a good query plan
    * Have something go wrong and get a bad query plan
    * After a while SQL Server will realize it's a bad plan, and try to revert to the good plan stored in Query Store...if it's faster, keep it permanently
* Doesn't help when...
    * Never had a good plan
    * Query store was not enabled with good plan
    * Query changes
    * No one good plan for all parameters

### Things to turn off
Can make things much worse
* Scalar Function Inlining
* Memory grant feedback (a little better in 2022)

### Paramter-Sensitive Plan Optimization (PSPO)
* Tries to reduce parameter sniffing issues
* Looks at a few equality search parameters
* Checks 201-bucket histogram for outliers
* Compiles a plan for outlier parameter only, and knows other parameters may need their own plans
* Doesn't fix:
    * Multi-parameter searches (like start and end dates)
    * Correlations between parameters
    * The 201-bucket problem
    * The local variable problem
* Big Problem: PSPO breaks all plan cache monitoring
    * Can't tell which queries came from which stored procs
    * Breaks sp_BlitzCache and all monitoring apps
* Don't use it for now




### Refresher: Using sp_BlitzCache for Query Tuning
* Profiler problems
    * Must be started in advance
    * Can have huge performance overhead
    * Doesn't aggregate data together (hides death-by-a-thousand-cuts scenario)
* Newer tools
    * Extended Events
    * Query Store
    * Lightweight Profiling
    * All have to be configured in advance
    * All can have ugly performance impacts
* Use Plan Cache instead (sp_BlitzCache)
    * SQL Server already caches plans for queries
    * It's on by default
    * No additional overhead
    * Drawbacks
        * Not every query is cached
        * It clears out over time
        * Stored in XML (hard to query)

#### Result sets
1. Top 10 worst queries
    * Warnings
    * Query Plans
    * Cached Execution Parameter
2. Details of the warnings found in the top set
    * Priority 1 Finding = plan cache instability/amnesia...cannot trust the results in the top set as being long term, only really recent
* Look at the warnings, and use those when looking at the plan

#### Plan
* Estimates not actuals stored in plan cache
    * 2019 has a switch to store **last** actual plan (and sp_BlitzCache will show you this) - still is cached parameter values, not last values
    > ALTER DATABASE SCOPED CONFIGURATION SET LAST_QUERY_PLAN_STATS = ON;  
    * perfoance hit of some sort

#### Sort Order by Wait Type
* Run sp_BlitzFirst @SinceStartup=1;
* If your top wait type is ..., then use sp_BlitzCache = @SortOrder = ...
    * CXPACKET -> cpu, reads
    * SOS_SCHEDULER_YIELD -> cpu
    * THREADPOOL -> cpu
    * LCK_** -> duration
    * RESOURCE_SEMAPHORE -> memory grant
    * PAGEIOLATCH_** -> reads
    * WRITELOG -> writes
* @StoredProcName = 
    * sp_BlitzCache @SortOrder='reads', @StoredProcName='myProcName'
    * Get all the statements for the proc you want to tune
    * Look at the statement that the highest value for what you're looking for (reads/cpu/...), not estimated cost

### Other ways to analyze queries
* Logging sp_BlitzWho, sp_WhoIsActive to table
* Extended Events with Erik Darling's sp_HumanEvents
* Query Store - Erin Stellato's blog posts and Plural Sight training
* 2019's new default lightweight profiling, air_quote_actual plans

### T-SQL Tuning Speed Hacks
* 2019+: ALTER DATABASE SCOPED CONFIGURATION SET LAST_QUERY_PLAN_STATS=ON;  
    * Each time th equery runs, the last actual plan is saved in dmv (shown in sp_BlitzCache too)
    * Drawback: higher CPU (10%)
    * Some things are missing (exact pages of spills, cpu time, wait stats, unballanced parallelism)
* Query Store
    * See history, show changes your tuning made
    * Newer features require it to be on
    * Erin Stellato's free 1-hour SQLBits video on youtube
* Compat Level
    * Latest compat level if you take time to tune queries
    * Newest features/tools
    * Legacy Cardinality Estimation - remove this query by query with hint as you tune
    * check sys.database_scoped_configurations where is_value_default<>1 to see what is turned off


## Rewrites: Changing Parameters, Results, and Refactoring

### Tuning for SELECT * and Lots of Rows
* IF EXISTS (SELECT *...
    * SELECT * does not matter
    * Not returning any columns, just checking if there is a row that matches
* Small number of rows = No problem
    * A small number of key lookups is great
    * Under 100 = not worried
* Thousands of rows
    * Tolerable
    * SELECT * isn't really the problem (developers always want more columns than what is just in the index, even if its not *)
    * "Why do you need so many rows returned?" - the real question to talk to developers about
* **Variable Number of Rows**
    * This one is the big issue (select * or listing columns with more than on the index)
    * Parameter sniffing issues: cache plan with key lookups for smaller number of rows, then forced to do key lookups for a really large number of rows
    * Don't have great options:
        * Make a really wide nonclustered index
        * Change clustered index to match your searches (data warehouse technique)
        * Create a narrow nonclustered index and pray
        * Use recompile hints, branching procs, or other tricks designed to get you multiple plans for different data sizes
* Cases you can tune
    1.  **Lots of rows, but developers are flexible on how many can be displayed on each page**
        * ROW Tuning with CTE Pagination
            * Use CTE that gets IDs for a PageNumber and PageSize using OFFSET to get a limited number of results when joined to main table
            * Can rerun proc with next page number if you want more (next set) of results
        > -- Example  
        CREATE OR ALTER PROC dbo.usp_UsersByLastAccessDate  
              @StartDate DATETIME  
            , @EndDAte   DATETIME  
            , PageNumber INT=1  
            , PageSize   INT=10000  
        AS  
        BEGIN  
            WITH RowsIWant AS(  
                SELECT Id, uR.DisplayName -- Include the sort columns
                FROM dbo.Users uR  
                WHERE uR.LastAccessDate >= @StartDate  
                  AND uR.LastAccessDate < @EndDate  
                ORDER BY uR.DisplayName  
                OFFSET((@PageNumber - 1) * @PageSize) ROW  
                FETCH NEXT (@PageSize) ROWS ONLY  
            )  
            SELECT u.*  
            FROM RowsIWant r  
            INNER JOIN dbo.Users u on r.Id = u.Id  
            ORDER BY r.DisplayName;  -- Use the CTE's sort columns  
        END;  
        GO  
    2. **Tuning key lookups around bad estimates**
        * SQL Server thinks it is going to get a lot of records, so it wants to do a clustered index scan instead of key lookups for the smaller number of actual rows that come back  
        * Statistics don't show how columns relate to each other, so when filtering on multiple columns, it doesn't know how many meet all the filters
        * Separate into phases
            1. Filtering, should only use indexes, only return ID columns to do joins later
                * Test with CTE and Temp Table to see which works better
            2. Join results to main table on IDs
                * "key lookups" (but they're really going to be clustered index seeks here)
    3. **Nulcear Option**
        * Force error when someone executes SELECT *, so no one can do it
        > ALTER TABLE dbo.Users ADD IToldYouToStopSelectingStar AS 1/0;  


### Why User-Defined Functions Suck, and How to Fix 'Em
* Developers use functions for scaleable and reuseable code
    * Good in a most places, but NOT SQL Server
    * SQL is set-based, and calculating row by row is painful
* Bad functions:
    * Scalar user-defined functions
    * Multi-statement table-valued functions
    * Functions in table definitions
* Not-so-bad functions:
    * SQL Server 2019's Froid technology
    * Inline table-valued functions
    * CTE and OUTER APPLY

#### Scalar User-Defined Functions
* Runs once per row
* "Black boxes"
    * Not shown in STATISTICS IO
    * Just "Computer Scalar" in Query Plan...really bad hard coded cost estimates
    * Cost isn't added to the total query cost
* Inhibits parallelism
* Use sp_BlitzCache to find them
    * High CPU for query
    * See almost all the CPU time for the function
* No benefits

#### Multi-statement table-valued user-defined functions (MSTVSs)
* Use table variables to store data
    * single threaded -> guarantees at least a serial zone in the plan
* Takes several times longer than a scalar UDF
* Some info in execution plan, but misleading
* Some info in STATISTICS IO but misleading
    * hard-coded 1 logical read per execution
* Slightly better in 2017

#### Scalar Functions in Table Definitions
* Computed Columns
* Check Constraints
* All queries against the table are serial

#### 2019 Can Inline some Scalar Functions
* Lots of Limitations
    * Can't call dtime-dependent functions like GETDATE()
    * The UDF can't have table variable or TVPs
    * The UDF can't be referenced in a GROUP BY or ORDER BY
    * The UDF can't be used in a computed column, check constraint, or partitioned funciton
* Check the is_inlineable column in sys.sql_modules
* No parallelism
* No missing index requests




## Dynamic SQL

### Fixing Multi-Parameter Queries with Dynamic SQL
* Create different execution plans for different sets of parameters
* 
* Parametrize the dynamic SQL...allow SQL Server to reuse they query's plan

#### Pro Tips
* include a comment with where it comes from, like the sp name
    * Makes it easier to troubleshoot it when you see it in the plan cache
* Use DECLARE @crlf = NCHAR(13) + NCHAR(10);
    * Query text is nicely formatted when you're troubleshooting
* Do not create dynamic comments...they will change the query, and SQL Server will not reuse the execution plan and cause procedure cache instability
* Use parameters in the stored proc to allow you to print out the dynamic sql so you can troubleshoot it
    * , @Debug_PrintQuery TINYINT = 0
    * , @Debug_ExecuteQuery TINYINT = 1

#### SQL Injection
* NEVER put the users input into the SQL string
* Use IF/CASE statements to check input options and build the sql string with your code (not the user's)


Mastering Server Tuning 3-1 Plan Caching and Parameterization




## Advanced Rewrites to Fix Scalability Problems

### Balancing Parallelism Threads
* Operator (right before Gather Streams operator) properties > rows > look at how many rows per thread
* Can separate part of query into a temp table to get better stats so SQL Server balances accross threads
* rare problem

### Parallelism Doing More Work
* First part of query has lots of results
* SQL Server thinks it will need to do lots of reads for the second part, so it starts the second part early (in parallel)
* In actuality, not a whole lot of reads need to be done in the second part, so if SQL Server waited until the first part was finished it would do less reads in the second part
* Fixes  
    * Can use OPTION (MAXDOP 1) to force single-threaded  
    * Separate with temp table  
    * OPTION (FORCESEEK) - not a big fan of this one, but can be a good solution in some scenarios  

### Index Spool (Eager Spool)
* Other spools are fine...Eager Spool is an issue
* copy of data written in tempdb
* only single threaded
* **Fix** - good old indexing  
    * Put seek predicates in key columns  
    * Put output list in included columns  
    * *Bonus:* fix the sort  


### Avoid Deadlocks by Modfiying T-sql
#### Concurency Challenges
* Locking
* Blocking
* Deadlocks
#### Fixes
* Index Tuning
* **Tune T-SQL code**
* Use right isolation Levels
* Do NOT use NOLOCK
    * You can see data that was never committed
    * You can see rows twice
    * You can skip rows altogether
    * Your query can fail with an error: Could not continue scan with NOLOCK due to data movement
#### Tune T-SQL Code
* Work through tables in the same order in both transactions
    * The second one will be blocked before it can take a lock to block the first
* Touch a table as few times as practical
    * Get all the locks you need as quickly as possible
    * If you need to do two separate updates to a table, try to write the first query to lock both rows even though you only update 1 of them right always
#### sp_BlitzLock
* Helps you spot Deadlocks


### Use Batches To Do a Lot of Work Without Blocking
* Doing everything in one transaction
    * Good: eas to code, done quickly
    * Bad: Lock escalation means no one else cna work
* Small Batches
    * Good: lets others work alongside you
    * Bad: harder to code, takes longer to Run
* Avoid ~ 5000 row lock escalation threshold
* Design batching code to run on the clustered indexes
* Use the fast-ordered-delete technique of CTEs or views so SQL Server understands how many rows will be involved
    * https://www.brentozar.com/archive/2018/04/how-to-delete-just-some-rows-from-a-really-big-table/




# Bookmark
## Working on usp_Q6627
## 00:00

