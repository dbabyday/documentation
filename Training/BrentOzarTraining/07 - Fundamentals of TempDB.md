# Fundamentals of TempDB



## General size guideline to start with  
* 25% of total combined sizes of databases on the server  
* Could need less or more  



## Version Store

* Be aware of large data change transactions -> all that data has to be written in tempdb version store  
* Cleans up version store slowly in the background, not immediately truncating unneaded data  
* RCSI, SI, Triggers 

#### Monitor version store size
> SELECT DB_NAME(database_id) AS database_name,  
  reserved_space_kb / 1024.0 AS version_store_mb  
FROM sys.dm_tran_version_store_space_usage  
WHERE reserved_space_kb > 0  
ORDER BY 2 DESC;  
  
> /* for each database */  
SELECT db.name, db.is_read_committed_snapshot_on AS rcsi_on,  
	db.snapshot_isolation_state_desc AS snapshot_isolation,  
	COALESCE(vs.reserved_space_kb, 0) / 1024.0 AS version_store_mb  
FROM sys.databases db  
LEFT OUTER JOIN sys.dm_tran_version_store_space_usage vs ON db.database_id = vs.database_id  
ORDER BY vs.reserved_space_kb DESC, db.name;  



## Temp Tables

#### Like Real Tables
* The table has stats just like a real table
* The table has an actual size just like a real table

#### Different than Real Tables
* They get special names behind the scenes
* They're only accessible per-session: one session shouldn't be able to read someone else's data

#### Optimizations
* Temp tables have 2 cool optimizations that help queries run faster, especially when we have a lot of queries that keep creating/dropping temp tables:
	1. Their structure can be reused across sessions
	2. Their statistics can be reused, too
* Even if you explicitly drop a temp table, you still get these optimizations.
* However, if you modify a temp table after it's created, you lose these optimizations, but you GAIN more accurate statistics (at the expense of slower temp table creation, stats updates, and higher CPU for recompilations.)
* It's up to you to figure out which one you want:
	* Temp table reuse, or
	* New temp tables each time



## Tables Variables

#### Estimated number of rows is alwasy 1

#### They don't get statistics, so:
* Bad news: estimates are usually off, but
* Good news: they don't recompile as contents change

#### If the number of rows we're getting out of the table variable don't really matter because:
* They're low (like under 100), or
* We're not doing anything with the rows after we get them, like we're not sorting them or joining them to any other objects
* Then table variables have a cool advantage:
	* They don't have stats
	* But that also means they don't trigger recompiles

#### SQL Server 2019
* Added an estimate for how many rows to be read (but only the first time the query runs)
* Estimated number of rows out is a hard-coded percent (not an accurate estimate)
* No stats
* The problem is now like parameter sniffing

#### Difference

* With temp table stats reuse:
	* You could inherit someone else's table stats
	* You could inherit their estimates, too
	* Those estimates could change as the temp table's contents changed as queries run
* With table variables:
	* You WILL inherit the total number of rows in in the object from the compiled plan
	* There are no column stats (data distribution) to inherit, so these are just consistently wrong
	* This has less to do with temp tables, and more like conventional parameter sniffing problems

#### Table variables are okay if:
* Your query brings back a few rows, and
* The contents (data distribution) of those rows don't matter at all, and
* You're not doing anything with the data (like you're not sorting it or joining it to other tables)
* You need to prevent recompilations
* You don't care if you inherit someone else's plan (because all the data is tiny anyway no matter what parameters people use)
#### But be aware that:
* Even though they don't show up in all_objects, they still take up space in TempDB.
* Starting in SQL Server 2019, the first params for a proc will cause the plan to be built with an understanding of the number of rows in the table variable (but not an understanding of the data distribution, because there are no stats)




## Temp Tables and Table Variables at Scale

#### SQL Server was not designed for constant creation/dropping of objects

* Contention on system pages (PFS/SGAM/GAM pages)
* Fix: create more tempdb data files = more system pages
    * not about the actual files, just need more system pages
    * data files need to be same size...larger file gets more activity

#### How to configure TempDB

* Start with 4-8 equally sized data files
* Start with about 25% of total data size on the server
* Leave autogrowth on
* Don't shrink them

#### If you still have contention
* You are running thousands of queries per second, AND pagelatch are your highest waits
* Switch temp tables to table variables
* This is a rare, edge case scenario to use table variables
    * You'll still get pagelatch waits, but less total wait time
* In 2019, you can use MEMORY_OTPIMIZED TEMPDB_METADATA=ON
    * get similar pagelatch wait time reduction, but with still using temp tables
    * does cause memory pressure (it is an in memory oltp feature)
    * probably better to switch to table variables



## How Memory-Optimized Table Variables Help TempDB

#### Drawbacks
* We have to enable In-Memory OLTP on the db
* We have to create a table type ahead of time
* They only use memory, not disk (which means they add memory pressure)

#### Good news
* There are no page latch waits
* There are XTP (Extreme Transaction Processing) waits (aka In-Memory OLTP, aka Hekaton)
* There are no compilations
* It does show up in the plan cache (but not memory used)
* This does alleviate the pressure from TempDB

#### Verdict
* If you can't fix GAM/SGAM/PFS contention or recompilations any other way, and
* If it's caused by queries using a relatively small amount of data, and
* If estimates don't matter (because like table variables, these don't have statistics), and
* It's a relatively small number of procs (because you have to create user-defined table types ahead of time for them, plus edit the procs to point to the new table types), and
* You're on Enterprise Edition (because you need Resource Governor)




## How Execution Plans Use TempDB

* If we use more memory than was granted, it spill to tempdb  

* This TempDB consumer is particularly hard to predict: it's different on a query-by-query basis, and changes with SQL Server versions.
* Microsoft's trying to make it better with adaptive memory grants, but 2019, it's worse instead of better. 2022 compat level is much better.
* To look for queries causing spills, run: sp_BlitzCache @SortOrder = 'spills'
* In their plans, look for:
	* Sorts
	* Hash matches
	* Adaptive joins




## Other TempDB Consumers

#### Cursors
* Kind of like a temp table - store a static copy of the data  

#### Index builds
* SORT_IN_TEMPDB=ON  
* TempDB caches stuff in memory rather than writing it to disk (so you don't always see it use physical file space/writes)  

#### Read only databases
* read-only mode, AG secondaries, db mirroring, db snapshots, etc...
* Statistics are stored in tempdb



## Provision and Monitor TempDB

## Size Guideline
* Start with 25% of total data size on the entire server  

## Where to store
* SSD (tempdb is latency-sensative)
	* bare metal --> local ssd
	* Cloud VM --> ephemeral storage (cloud term for local ssd)
	* Convential VM --> probably on the SAN (VM admins probably won't let you use local SSD, and it makes sense)  
		* Should TempDB be on its own dedicated volume?
			* Can SAN replication be disabled for one volume? then yes.
			* Use a "vent-valve file" on a separate volume that has lots of room to grow.  
			  Create a 1MB file on a large volume  
			  Enable autogrow in a big increment  
			  Set up alerts for when that file grows  
			  Proportional fill menas we won't use this file a lot (the bigger files on our dedicated volume will be used most)  

## How many files
* SQL Server was not designed for constant create/drop of objects  
	* PFS - Page Free Space pages
	* SGAM - Shared Global Allocation Map pages
	* Latches protect these pages in memory (lightweight locks)
* Start with 4-8 equally sized data files and 1 log file  
* Take total available space if on dedicated volume  
	*  If on shared volume, use 25% for TempDB



## Monitoring

#### Monitor what percentage of TempDB is used  

#### Alert when "high enough"
* 80% is too late - you won't have time to react...leave time to take action  
* 10% is a good starting point for alert  

#### What to monitor
* Does it have enough capacity?
	* If not, what is using the space?
* Are the pages in memory fast enough (are we fighting over PFS/SGAM)?
	* If not, do we need more files?
* Are the pages on disk fast enough?






