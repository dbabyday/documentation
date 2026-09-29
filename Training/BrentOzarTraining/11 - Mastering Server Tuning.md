# Mastering Server Tuning

## How to Measure a SQL Server's Performance
1. Size
2. Batch Requests/sec
3. Wait Time Ratio

### Database Size
*how much weight are we carrying*
* 1 - 150 GB: easy to handle on Standard Edition
* 150 - 500 GB: easy to hanlde with Enterprise Edition
* Over 500 GB: matters if it is active data and how accessed (OLTP vs Analytical)
* Over 1TB OLTP data: starts to get very challenging
* Very uncomfortable: 100 TB, 10-12K databases per server

#### Chart size over time to show impaact of data growth


### Batch Requests/sec
*how fast is SQL Server*
* 0 - 1,000: easy to handle with commodity hardware
* 1,000 - 5,000: one bad change to a query can knovk over a commodity server
* 5,000 - 25,000: if you're growing, you should be making a scale-out or caching plan
* Over 25,000 - doable, but needs attention

#### Data Warehouses are Different
* Measure in how fast to scanning TB of data
* Better performance in cloud like structure


### Wait Time Ratio
*how hard is SQL Server working*

#### How SQL Server Schedules CPU
Query runs on CPU thread until...  
1. It finishes
2. Has been running for 4 miliseconds
3. Waits on something else  

...then it goes back into queue waiting for CPU

#### Wait types
* Resources
    * CPU, memory, storage, network, latches, locks
* Preemtive - *Stuff outside of SQL Server*
    * COM, OLEDB, CLR (linked servers)
* System Tasks
    * Lazywriter, trace, full text search

#### sys.dm_os_wait_stats

#### Wait Times Change
* Increase
    * More batch requests/sec
    * Queries were tuned (badly)
    * Storage got slower
    * Hardware is shared
* Decrease
    * Less batch requests/sec
    * Queries were tuned
    * Indexes were tuned
    * Memory was added

#### Wait Time Per Core Per Second
* 0 - Your server isn't doning anything
* 1 second of waits - You're not doing much
* Multiple seconds per core - now we're waiting, and should be tuning

#### sp_BlitzFirst
* Like a dashboard
    * Batch Requests perSec
    * Wait Time per Core per Sec
    * Database Size Total
    * Wait Stats listed
    * Warnings
    * What some of the reasons it might be slow
* Useful Parameters
    >@SinceStartup = 1  
    @ExpertMode = 1  
    @Seconds = 60  




## How to Fix PAGEIOLATCH Waits

#### PAGEIOLATCH waits mean reading data pages from a data file.
* See this a lot when not enough memory to keep all the needed data cached
    * Have to go read it from storage

#### 4 most common ways of tuning it, in order, are:
1. Tune indexes
    > sp_BlitzIndex @GetAllDatabases = 1;
2. Tune queries
    > sp_BlitzCache @SortOrder = 'reads';
3. Add more memory
4. Make storage faster
    * Crystal Disk Mark: BrentOzar.com/go/cdm
    * Download Crystal Disk Mark Standard Edition
    * Save it to share
    * Settings accross the top
        * 1 = number of tests (1 = quick test, 9 = many tests)
        * 1 GiB = test file size (1GiB = quick test, 64Gib = in-depth test that won't just get cached)
        * S: = drive letter or folder you want to test


## How to Fix SOS_SCHEDULER_YIELD Waits
*SQL Operating System (SOS) runs a query from a worker thread on the scheduler thread for 4 miliseconds, then yields the scheduler thread to another worker thread. While that first worker thread is waiting for more time on the scheduer thread, it is in SOS_SCHEDULER_YIELD wait.*


### Look at Average Wait Time in ms
* Each query yields CPU every 4 ms
* Compare that to the average time it is waiting each time it yields
* If avg is 4, the query is taking twice as long as just doing the work nonstop
* Box might not be stressed most of the time, but bursts of high activity will show high on average SOS_SCHEDULER_YIELD wait Times


### Causes
* Other processes on the same server using CPU
    * Check Ring Buffers (sp_BlitzFirst)
    * Check Task Manager by CPU usage
* Queries using a lot of CPU
    * sp_BlitzCache @SortOrder = 'cpu'  -- look for:
        * String processing ('LIKE '%STRING%')
        * Row-based processing (cursors, functions)
        * Sorting/grouping (but index for that, not reads)
        * Heaps with forwarded fetches (rebuild, add clustered index)
        * Implicit conversions 
* Not enough CPU power in the server
    * Faster clock speed CPUs (get 29%-45% more CPU cycles with same number of CPUs)
    * Resources for instance families
        * AWS: https://ec2instnaces.info
        * Azure VMs: https://azure-instances.info
        * Google Computing Engine: https://cloud.google.com/compute/docs/instances/specify-min-cpu-platform
* Queries compiling over and over




How to Fix Misleading Waits

## What CXPACKET and CXCONSUMER Means and How to Fix It

#### Queries go parallel because they:
* Need to read a lot of pages (PAGEIOLATCH, LATCH_EX)
* Need to do a lot of CPU work (SOS_SCHEDULER_YIELD)

#### When you see parallelism wiats
1. Make sure CTFP & MAXDOP have sane defaults
    * CTFP Default to 50 (30-100 is fine for starting point)
    * Changing CTFP clears plan cache
2. Look past parallelism wiats, check you next top wait
3. Tune those queries/insdexes, then they won't need to go so far parallel, and parllel waits will drop away
4. Revisit Mastering Query Tuning
    * Fix unballanced parallelism at query level

#### Parallelism in Execution Plan
* To see cost of serial plan, run with OPTION(MAXDOP 1) hint
* If plan shows parallelsim, you ahve to look at properties to see how many of the threads were actually doing work
    * Actual Logical Reads, ACtual Number of Rows, ...
    * The thread that finds rows, has to do all the downstream work for those rows

#### Workflow
1. Set CTFP & MAXDOP per industry best practicves
2. *Let those bake in for a few days*
3. Index tuning to reduce times when queryies go parallel to scan lots of data and sort it (D.E.A.)
4. *Let those bake in for a few days*
5. Look for queries still doing a lot of work, then tune them (T.)
6. *Let those bake in for a few days*
7. If parallelism is still big problem (10X wait time ratio), start looking for specific queries with parallelism issue


#### Degree of Parallelism Feedback (2022+)
* DOP_FEEDBACK - database-scoped config option
* Query runs repeatedly with parallelism plan
* And parallelism wiats are a problem
* DOP will decrease each time it runs
* Makes sense for servers with lots of CPUs and high MAXDOP
* Not great because CX% measurements are inaccurate, so it is hard to make good decisions based on them



## Plan Caching and Parameterization

#### Plan Reuse
* should result in lower CPU, more memory, and easier troubleshooting
* Microsoft guideline: 85% of queries should use cached plans
    * Compilations/sec high (over 15%)


#### Queries that do not get plan reuse
* Literal values
* Parameter lengths
* SaaS apps
    * Store each client in its own database
    * Same query in different databases get their own plan

#### Issues
* More memory taken by plans
* Less memory available to cache data
* Much harder to do plan cache analysis
* Higher CPU consumption due to compliations

#### Find Issue
* Query plan cache hsitory
    * if only a couple hours for most plans
    * Query redundant queries
    * Or - review recent queries and look for patterns
    > sp_BlitzCache @SortOrder='recent compilations', @Top=50, @SkipAnalysis=1; 


#### Fix for Literal Values
* Forced Parameterization
    * Doesn't fix everything
    * You will see more parameter sniffing Issues 
* NOT a fix: Optimize for Adhoc

#### Fix for Parameter Lenghts
* Have to fix the code

#### Fix for SaaS apps
* No fix
* Have to monitor from the app side insetad of SQL Server plan cache





## What LCK% Means and How to Fix It

### Fixes for Concurrency Issues
1. Index Tuning
    * Enough to make queries fast
    * Not so many that they slow down DUIs (they hold locks for longer)
2. Tune transactional code
3. Use right isolation level for your applications


#### Implement Optimistic Locking
* RCSI
    * changes default isolation for entire database
    * Good when you have widespread blocking issues
    * Caution: you can get different results, so it is best if you can test your whole code base
* Snapshot Isolation
    * Allows each query to specify to use snapshot isolation
    * Good when you can't test all code base, and you have a handful of queries causing blocking issues
* Overhead with both
    * Increased TempDB size
        * Start at 25% of total db size
        * Not good fit if you have batch loads > 30 minutes (fix batch loads to avoid transactions first)
    * May slow down TempDB
        * First monitor/fix that TempDB storage is averaging 100ms or faster for writes
        * Use local, mirrored SSD
* Monitoring
    * Free Space in tempdb
    * Version Store Size
    * Longes Running Transaction Time
* Troubleshooting version store
    * Why is versions store growing
        * sp_WhoIUsActive or sp_BlitzWho to find open transactions
    * Which db is using version store space
        * sys.dm_tran_version_store_space_usage
    * Why can't SQL Server clean out version store
        * https://learn.microsoft.com/en-us/archive/blogs/sqlserverstorageengine/managing-tempdb-in-sql-server-tempdb-basics-version-store-growth-and-removing-stale-row-versions
* Put version store in user database
    * 2019 Accelerated Database Recovery can put version store in user database files
    * enables near-instant rollbacks because original versions of rows are already in the data file
    * Drawbacks
        * data files can grow quickily
        * Differential backups can grow too
        * User db storage under more workload
        * Monitoring an dtroubleshooting are not well-defined yet

#### Real Readable Replicas
* Create 2 connection strings
    * Primary - for write queries
    * Secondary - for read-only queries
    * SQL Server does not separate them on its own, developers have to choose which one to connect to
* Options
    1. Log shipped secondaries (cheap, daily snapshot of data, restore with standby and leave in readable state)
    2. Transactional replication (nearly up to date data, absolutely require diferent indexes)
    3. Alwasy On Availability Groups (nearly up-to-date data, need to offload backups or CHECKDB)


How to Fix LCK% Waits
What LCK% Means and How to Fix It
20:37





## How to Fix Poison Waits

### THREADPOOL
* High SOS_SCHEDULER_YIELD from normal queries
* Add blocking from abnormal query
* Combined results in THREADPOOL
    * Available threads are used up...all are waiting on blocking before they can finish their CPU work
    * SQL Server acts "frozen"...You get connection timeouts, even though CPU is not high

#### How to troubleshoot
* DAC (Dedicated Admin Connection)
    * ADMIN:GCC-SQL-PD-001
* Fix the Emergency
    * Log sp_BlitzWho for future analysis
    * Find lead blocker
    * Have user end transaction, or kill session if you need to
        * rollbacks are single threaded...be careful because killing a session can take longer than the transaction ran for
* Fix the problem long term
    * Increase CPU cores (expensive, still have blocking)
    * Number of worker threads (512 default, increasing it can lesson problem, but doesn't let queries finish any faster)
    * MAXDOP 1 kinda fixes it (use it for short-term banaid)
    * Reduce number of simultaneous queries
    * Reduce cost of the query
        * Index tuning: sp_BlitzIndex
        * Query tuning sp_BlitzCache @SortOrder = 'reads'
    * Reduce locking of lead blocker
        * make transaction shorter and/or faster
        * change isolation level (RCSI?)


### RESOURCE_SEMAPHORE
SQL Server runs out of "query workspace memory", and sessions have to wait for memory to become available before starting query  

#### Query Workspace Memory
* Memory for sorts, joins, query execution
    * Execution plan reports in KB
* Can be up to 25% of SQL Server memory
* Steals from plan cache and buffer cache

#### Fixes
1. Tuning queries and/or indexes
    * Find queriers running when this wait starts
    * Look for the ones that have large memory grants
    * sp_BlitzCache @SortOrder = 'memory grant'   (note that queries are probably being removed from cache all the time)
2. Tame problem with Resource Governer
3. Adding more memory





## Hardware-Sounding Waits

### WRITELOG
* look for Avg ms Per Wait 
    * not a problem if it is low
    * if hundres+ ms, then people will notice
* Fixes:
    * Don't store files in the database
        * just adds a lot of overhead to transaction log
    * Delayed Durability
        * tell user the transaction is committed right away
        * dangerous...you can loose data with shutdown, failover, restart...
    * ONe database involved: Use dedicated pair of mirrored solid state drives
    * Multiple databases involved: Stripe across many drives in a RAID 10 solid state

### HADR_SYNC_COMMIT
* Always On Availability Groups in synchronous commit mode
* Only affects data modification (not selects)
* Fixes:
    * Switch to async
    * Check waits on the sync secondaries (may be disk-bottlenecked)
    * Check network latency between Replicas
    * Separate non-ciritical data (staging tables, scratch space) into separate, non-sync AG databases

### ASYNC_NETWORK_ID
* Slow client machines, or underpowered app server VMs
* Appplication processing data row-by-row instead of just getting it all from SQL Server first
* Slow network connections, especially WANs or VPNs
* **Not a database problem**
* Fixes:
    * Run sp_WhiIsActive repeatedly and look for ASYNC_NETOWRK_IO in the wait_info
        * Find the program name, and check the app code it is running







## Triage Prcoess

### Levels of Problems
1. The server is down, not responding to queries
2. The server is going to go down in minutes if we can't fix the problem quickly
3. The entire server is in bad shape, but will survive today whether we fix the problem or not
4. Some parts of some applications are unusually slow
5. Bob's report is running unusually slow
6. Bob's report is running just like it did yesterday: slow

### Your goal is to fill this out fast.
The symptoms are __________.  
I believe the root cause is __________.  
If we don't take actions now, the effect will be __________.  
I recommend that we:  
* Take action __________ now to fix it, or
* Take action __________ to investigate further, or
* Put this in __________'s queue

### Triage tools, in order:
1. Your monitoring software
2. sp_WhoIsActive
3. sp_BlitzFirst
4. sp_BlitzCache
5. sp_BlitzIndex
6. sp_Blitz
* Allow others to run these
    * Grant permissions to the procs rather than the users (http://www.brentozar.com/askbrent/)


#### Your monitoring software
* Let's you know when there is an emergency
* Compare historical measurements

#### sp_WhoIsACtive
* No rows: nothing is going on...maybe connection issue
* Queries running for hours
* Queries running for minutes
* Blocking
* TempDB full (tempdb allocations column)
* Round 2, get more info  
    >EXEC sp_WhoIsActive @get_locks=1, @get_plans=1  
    * Check what level we are at, fill out sheet 
        * level 1 or 2

#### sp_BlitzFirst
* Snapshot of server's bottlenecks
> EXEC sp_BlitzFirst @ExpertMode=1;  
* Check what levle we are at, fill out sheet
    * rules out level 3

#### sp_BlitzCache
* Top 10 most resource-intensive queries in plan cache
* Includes all databases
* Look for queries you recognize, unusual resource use, 1 query using > 50% resource, unusual parameters
* Fill out your sheet, and act
    * Free plan from cache now
    * Put in developer's queue to make more consistent plan

#### sp_BlitzIndex
* Work with users/developer/analysts on what is slow
* Look at indexes for those
* Not urgent fix for level 6

#### sp_Blitz
* Always good to run this to find any issues that could get you fired