# How I Use the First Responder Kit

Health Check - Top down</br>
Emergency (know the server well) - Bottom up</br>
* Server-wide health check: sp_Blitz
* Performance check: sp_BlitzFirst
* Find the queries causing the waits: sp_BlitzCache
* Check indexes that'd help queries: sp_BlitzIndex
* Analyzing deadlocks: sp_BlitzLock
* Which queries running now: sp_BlitzWho, sp_WhoIsActive




## sp_Blitz
>sp_Blitz @CheckServerInfo=1;
* @CheckServerInfo=1 -> additional info about the server

#### Output
* Prioritized list
* 1-49 critical (get fired for loosing data)
* Server Info (@CheckServerInfo=1)

#### Saving Results
>execute sp_Blitz  
@OutputDatabaseName=N'CentralAdmin'  
, @OutputSchemaName=N'dbo'  
, @OutputTableName=N'sp_BlitzResults';  
* Log to table once a month to show progress over time

#### format for easy sharing (online forum questions)
>execute sp_Blitz @OutputType='markdown'





## sp_BlitzFirst
>execute sp_BlitzFirst  
@ExpertMode=1  
, @Seconds=60  

* @ExpertMode=1  
-> 1st result set: what is running right now  
-> 2nd result set: prioritized result set  
-> Wait stats  
-> Storage access  
-> Perfmon counters

#### First look at a server
>execute sp_BlitzFirst  @SinceStartup=1, @OutputType='Top10';
* @SinceStartup=1  
-> Wait and Perfmon stats since last restart
* @OutputType='Top10'  
-> reduce result set for easy look/screen shots

#### Wait stats cheat sheet
* **CXPACKET/CXCONSUMER/LATCH_EX** - queries going parallel to read a lot of data or do a lot of CPU work. Sort by CPU and by READS.
* **LCK%** - locking, so look for long-running queries. Sort by DURATION, and look for the warning of "Long Running, Low CPU." That's probably a query being blocked.
* **PAGEIOLATCH** - reading data pages that aren't cached in RAM. Sort by READS.
* **RESOURCE_SEMAPHORE** - queries can't get enough workspace memory to start running. Sort by MEMORY GRANT, although that isn't available in older versions of SQL.
* **SOS_SCHEDULER_YIELD** - CPU pressure, so sort by CPU.  
*-> Check MAXDOP, and consider lowering CTFP  
-> sp_BlitzCache @SortOrder='cpu'  
-> Watch for anti-patterns in Mastering Server Tuning  
-> SOS_SCHEDULER_YIELD module  
-> set statistics time on (forget about logical reads)*
* **WRITELOG** - writing to the transaction log for delete/update/insert (DUI) work. Sort by WRITES.  
* If wait time to clock time is about 1:1, you can probably ignore it
* ASYNC_NETWORK_IO  
sp_BlitzWho   
GO 20  
-> see which sessions are waiting on ASYNC_NETWORK_IO  
usually app server far away, or underpowered app server

#### Saving Results
>execute sp_BlitzFirst  
@OutputDatabaseName = 'CentralAdmin'  
, @OutputSchemaName = 'dbo'  
, @OutputTableName = 'BlitzFirst'  
, @OutputTableNameFileStats = 'BlitzFirst_FileStats'  
, @OutputTableNamePerfmonStats = 'BlitzFirst_PerfmonStats'  
, @OutputTableNameWaitStats = 'BlitzFirst_WaitStats'  
, @OutputTableNameBlitzCache = 'BlitzCache'  
, @OutputTableNameBlitzWho = 'BlitzWho';
* run as agent job
* creates the tables automatically
* creats views for deltas
* default retention is 7 days (@OutputTableRetentionDays)

#### Get results from a given time
>execute sp_BlitzFirst  
@OutputDatabaseName = 'CentralAdmin'  
, @OutputSchemaName = 'dbo'  
, @OutputTableName = 'BlitzFirst'  
, @OutputTableNameFileStats = 'BlitzFirst_FileStats'  
, @OutputTableNamePerfmonStats = 'BlitzFirst_PerfmonStats'  
, @OutputTableNameWaitStats = 'BlitzFirst_WaitStats'  
, @OutputTableNameBlitzCache = 'BlitzCache'  
, @OutputTableNameBlitzWho = 'BlitzWho'  
, @AsOf='2024-02-28 14:30';




## sp_BlitzCache
>sp_BlitzCache @SortOrder='cpu'  

#### Result sets  
1. top 10 most resource intensive queries  
2. prioritized list of problems in the 1st result set  
**priority 1 warnings** in the 2nd result set = you cannot believe anything in this script or any monitoring tool.

#### Steps
1. Check for priority 1 warnings in result set 2
2. Check result set 1 for how many queries have high impact (example if sorting on cpu, look for queries with "Total CPU" that are magnitudes higher than the rest)
3. Look at "Query Type" to see if the query is in a function or query also on the list (nested statements are cumulative)
4. Warnings - use these when looking at the query plan
5. 2nd result set gives info about those warnings
6. Look at query plan

#### sp_BlitzCache @SortOrder='cpu', @MinutesBack=60
* Only show me the queries that ran in the past 60 minutes  
Metrics are from since startup

#### Sort orders
* cpu, reads, writes, duration, memory grant, unused grant
* avg cpu, avg duration, ... (looking for queries that do not run often, but suck when they do)

#### sp_BlitzCache @SortOrder='cpu', @ExportToExcel=1
1. Excel friendly format result set, without XML fields
2. Regular result set, with XML fields




## sp_BlitzIndex
>sp_BlitzIndex  
sp_BlitzIndex @GetAllDatabases=1  
* @Mode  
**0** - default  
**4** - default, but with more (wide tables, identity close to running out of numbers, ...)  
**2** - Inventory (all indexes that exist)  
**3** - Missing index inventory  
**1** - Summary (number of objects, space, ...)  

#### Process
1. Look at results to get general idea of what kind of work is needed
2. Use the More Info column to get detailed info on the specific table
3. Drop unused indexes
4. Look at lock column for blocking
5. Page IO Latch Wait Count/Time - shows which objects are not beign cached in memory

#### Result Sets from table level
>execute sp_BlitzIndex @DatabaseName=N'StackOverflow', @SchemaName=N'dbo', @TableName=N'Users';
1. Info about indexes that already exist
2. Missing Index Requests  - Info about indexes SQL Server wishes it had
3. Statistics (don't really use)
4. Columns on the table (don't really use)

#### DEATH Method
* Dedupe
* Eliminate unused
* Add missing indexes
* Tune indexes for specific queries
* Heaps usually need clustered indexes

#### Saving Results  
Reference data if sql server reboots
>execute sp_BlitzIndex  
@GetAllDatabases=1  
, @Mode=3
, @OutputDatabaseName=N'CentralAdmin'  
, @OutputSchemaName=N'dbo'  
, @OutputTableName=N'BlitzIndex_Results';  

#### Other helpful parameters
* @BringThePain=1 -- doesn't hurt anything, just can take a long time to run, will get a prompt to include if needed  
* sp_BlitzIndex @GetAllDatabases=1, @Mode=2, @SortOrder='size'; --'rows'  



## sp_BlitzLock
>sp_BlitzLock  

#### Result Sets
1. All the deadlocks that have happened, queries involved, if victim, ...  
-> Look for serializable and/or exclusive locks  
-> Shows login name, app, ...  
-> Deadlock priority  
-> Deadlock graph - click on it, save it, name it "*.xdl", and then open it
2. Details
3. Summary - **where to go first**  
-> Look for the one table that has been involved in the most deadlocks  
-> If there is code, look at the query that was involved in the most deadlocks  
-> Tune just that query/table (enough indexes to select quickly, but not too many to lock all the indexes for updates)  

#### Saving Results  
Save to table every coule of hours if default system_health session does not have enough history
>execute sp_BlitzLock  
@OutputDatabaseName=N'CentralAdmin'  
, @OutputSchemaName=N'dbo'  
, @OutputTableName=N'BlitzLock';  



## sp_BlitzWho & sp_WhoIsActive
* sp_WhoIsActive  
-> perforamce tuned to an inch of its life  
-> doesn't show as much data  
* sp_BlitzWho  
-> more functionality, more built in  
-> use when not in the middle of an emergency

>execute sp_WhoIsActive;  
-- in an emergency no parameters to get quick info

>execute sp_BlitzWho;  
-- get cached parameters  
-- wait_info: now, and top session waits overall  
**execute sp_BlitzWho @ShowSleepingSpids=1, @ExpertMode=1;**  
-- tempdb_allocations_mb  
-- memory query plans have used  

#### Saving Results  
Save to table every coule of hours if default system_health session does not have enough history
>execute sp_BlitzWho  
@OutputDatabaseName=N'CentralAdmin'  
, @OutputSchemaName=N'dbo'  
, @OutputTableName=N'BlitzWho';  
* Can create an "Emergency Only" job to run this every minute. When someone calls with an issue, have them enable the job, then you can disable it when you're done.




## sp_BlitzBackups
>sp_BlitzBackups
* In the past 2 weeks, what is the point that we would have lost the most data?
* How long did they take? Because I want to know how long a restore will take.

#### Result Sets
1. Databases, RPO & RTO data, size, throughput speed, ...
2. First/Last dates, sizes, speeds, ...
3. Warnings




## Consultant Toolkit
* DBAs/Developers should log data to tables, but consultants should get excel reports
* First Responder Kit output into an excel spreadsheet with accompanying plans




## Recap
1. Server-wide health check with sp_Blitz
2. Performance check - Log sp_BlitzFirst every 15 minutes
3. Find queries causing your top wiats - sp_BlitzCache with @SortOrder parameter
4. Index tuning with sp_BlitzIndex @GetAllDatabases=1

### Report
* Priority 1-50 sp_Blitz findings
* Prioritized list of top wait types
* List of top 3-4 queries causing those waits
* Rough idea of what tables need index help first





