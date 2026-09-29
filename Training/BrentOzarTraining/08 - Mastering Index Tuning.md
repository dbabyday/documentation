# Mastering Index Tuning

## DEATH Method  
* Dedupe  
* Eliminate  
* Add  
* Tune for specific queries  
* Heaps  

#### General Guideline to Start  
* Aim for 5 indexes or less  
* Aim for 5 columns or less on each index  
* **More** can be fine when:  
    * Read-only (or read-biased) tables  
    * Very, very good hardware (12-16+ CPU cores, 64GB RAM, 2TB SSD)  
      Aim for ~ 10 well-tuned indexes per table  
    * When DUI speed does not matter  
* **Less** may be required when:  
    * Ingestion speed is critical  
    * Read speed does not matter  
* Too many and not enough can cause slow performance and blocking  



## Reads and Writes Numbers are Wrong
#### sys.dm_db_index_usage_stats - "usage stats"
* "Execution Plan" DMV
* Shows # of times an operator appeared in a query plan that was run (not if it was used or how often accessed)
    * Reads: seeks, scans, lookups
    * Updates: inserts, updates, deletes  
* If an operator was executed multiple times, or 0 times, we still see one and only one here (think key lookups for 0 or many rows from an index seek)  
* Reset by system restart

#### sys.dm_db_index_opearational_stats - "op stats"
* Shows # of times an operator was accessed
* Lock waits
* Data only persisted while the object's metadata is in memory
    * No good way to know when it was last cleared
    * Can be reset by memory pressure



## Steps D and E: Dedupe and Eliminate
* Do these once at the same time  
* Easier to Eliminate unused indexes first, then dedupe indexes with same keys

#### Eliminate
* Drop indexes with 0 reads

#### Deduplication
* Identical indexes: eliminate all but one of them
* Borderline identical
    * Identify the key superset (key order matters)
    * Combine the included columns
    * Review to see if it is a monster (we are aiming for the 5/5 rule)
    * Create the new index
    * Drop the rest

#### How to use sp_BlitzIndex to D/E
1. sp_BlitzIndex @GetAllDatabases=1 (figure out what database to tune)
2. sp_BlitzIndex in the database to tune (figure out what table to focus on)  
3. Run command in More Info column for the table to tune
* Drop indexes that have 0 reads (assuming uptime has included a full workload)  
* Drop narrower indexes that have duplicate keys  
* Check indexes that start with the same couple of columns to see how many rows each combination might have.  
    * If it is unique or really small, then you could eliminate one of the indexes and live with key lookups, or put the other columns as includeds.  
    >SELECT TOP(10) OwnerUserId, PostTypeId, COUNT(1) AS recs  
    FROM dbo.Posts  
    GROUP BY OwnerUserId, PostTypeId  
    ORDER BY COUNT(1) DESC;   



## The T Step: Tuning Indexes for Specific Queries
#### Column Order  
* Equality searches...any order is fine  
* Order matters for: Inequality (<, >, <>, IS NOT NULL, IN, etc.), ORDER BY, JOINs  
* Missing Index Requests: Order is by column id, not by selectivity  

#### An Index for Multiple Queries
* Which one runs most often?
* Does one need to be faster?
* Guidelines  
    * Fields use most often go first
    * Selectivity matters  
    * Fields in WHERE clause go first
* How to get the workload
    * Read plan cache with **sp_BlitzCache @SortOrder='reads'**

#### Recap
1. sp_BlitzCache @SortOrder='reads'
2. Look at index recommendations, but build your own
3. Generally, equality fields first, then inequallity fields
4. ORDER BY, JOINs can come into play too
5. Build as few queries as practical to satisfy queries

#### Foreign Keys and Check Constraints
* Only help when:
    * Querying for data that cannot exist
    * Stopping bad data from entering
    * ...that's about it

#### Indexes for a query that joins tables
1. Write it as separate queries, one for each table, with all the filters for that table (WHERE and JOIN filters)
2. SQL Server will filter the table that can be filtered down the fastest...write an index for this one first
3. Include the join column in the WHERE clause for your query to look at the second table




## The A Step: Adding Indexes with Clippy and the DMVs

#### Adding Indexes with Recommendations
* Use recommendations to rapidly go from 0 ~5 indexes
* Do NOT try finding which query plans are involved (unless 2019+)
* Too many columns? Try without th eincludes first
* Selectivity - try to guess what the query filters 
* Be careful with INCLUDE columns
    * Avoid large data types
    * Avoid columns that get updated a lot...leads to blocking issues on the index

#### Avoiding Key Lookups and Residual Predicates
* Key lookup cost estimations are from spinning disk  
    * Was 150 IO/sec, now on SSD 150K-1M IO/sec  
    * Plan operation cost can be WAY overestimated
* If estimations are way off, it can still be a big deal
* Scanning an index + keylookups are better than scanning the table
    * ...as long as the logical reads for the index scan + key lookups are less than the logical reads to scan the table
* **Residual Predicates** (AKA: leftover predicate, scan predicate)  
    * Fix if it eliminates a lot of the key lookups we need to do
    * They make estimates inacurate for what we end up neededing after all the filtering
    * Can put them in INCLUDEs or KEYs
    * May still be a residual predicate, but our goal is to dramatically reduce the number of key lookups




## The H Step: Heaps Usually Need Clustered Indexes

* Heaps have file#, page#, and **slot#** for each row to uniquly identify
    * RID Lookup instead of key lookup

#### Benefits of Heaps
* 67% less reads for key looups (only matters if your biggest problem is key lookups)
* 1% less reads for tablew scans (really small benefit)
* Possibly faster load times (depends on your ETL)
* ...nobody cares about any of these

#### Use Cases
* Staging tables 
    * shove data in quickly
    * truncate every night
    * scan it back out once
* scan-only tables like a true data warehouse
    * don't know the user queries, so you can't index well...best to not index and let it be scanned every time

#### Drawbacks
* Forwarded fetches --> more logical reads
    * When updates cause rows to move to a different page...leaves a forwarding pointer in original location  
    * Workarounds: ALTER TABLE...REBUILD, TRUNCATE TABLE, add clustered index
* Deletes do not deallocate all empty pages
    * Optimized for loading data...so it keeps some storage allocated
    * Workarounds: ALTER TABLE...REBUILD, TRUNCATE TABLE, add clustered index

#### Choosing a Clustered Index
* Static
    * Row stays in same palce
    * If this changes, you have to update all the non-clustered indexes each time
* Unique
    * If not, SQL Server add a hidden uniquifier
* Narrow
    * The wider it is, the wider all your non-clustered indexes are
    * Affects space in memory and on disk
    * Affects IO
* Ever-Increasing
    * Avoids it from getting fragmented quickly
    * Creates hot-spot at end of last page (this will be in RAM because it is getting all the inserts). If it is random, you spread out the inserts, but you likely have to read each of those pages into memory.





## Tuning Indexes to Avoid Blocking

#### Concurrency challenges
* **Locking:** Lefty takes out a lock
* **Blocking:** Righty needs a lock, but Lefty has it
    * SQL Server will let Righty wait forever, and they symptom is LCK* wiats
* **Deadlocks:** Left has locks, but needs some held by Righty. Righty has locks, but needs some held by Lefty
    * SQL Server solves this one by killing somebody, and the symptom is dead bodies everywhere

#### Ways to fix blocking and deadlocks
1. Have enough indexes to make your queries fast, but not so many that they slow down DUIs (making them hold more locks for longer times)
2. Keep batches and transactions short
3. Use the right isolation level for your app's needs

#### Tools
* D.E.A.T.H. Method
    * D.E.A. with sp_BlitzIndex: look for "Agressive Index" warnings (this index has a lot of blocking)
    * T. with sp_BlitzCache @SortOrder='duration': look for "Long Running, Low CPU" warnings
    * H. because heaps can be locking hell
* Finding Deadlocks with sp_BlitzLock
* Finding Queries Live with sp_BlitzWho, sp_WhoIsActive





## Artisanal, Hand-Crafted, Specialized Index Types

#### Rarely Used, but can Benefit Edge Cases
1. App frequently queries a small subset of rows: **Filtered Indexes**
2. App frequently queries aggregations: **Indexed Views**
3. App frequently queries computations (and the app can't jus tinsert the computed value): **Indexed Computed Columns**

#### Potential Issue with Some Artisanal Indexes: Different SET Options
* Can't be used for reads
* Inserts will fail
* If these options are not set to these required values
    * ANSI_NULLS = ON
    * ANSI_PADDING = ON
    * ANSI_WARNINGS = ON
    * ARITHABORT = ON
    * CONCAT_NULL_YIELDS_NULL = ON
    * NUMERIC_ROUNDABORT = OFF
    * QUOTED_IDENTIFIER = ON
* Monitor connections before creating these indexes (capture every 5 or so minutes)
>SELECT *  
FROM sys.dm_exec_sessions  
WHERE is_user_process = 1 AND (  
    ansi_nulls = 0  
    OR ansi_padding = 0  
    OR ansi_warnings = 0  
    OR arithabort = 0  
    OR concat_null_yields_null = 0  
    OR quoted_identifier = 0 );  

### Filtered Index
* Only effective if the WHERE clause is selective  
    * Like, 5%
* Avoid index overhead for all the rows that are not in the index (most of the table)...only maintaining the small number of rows in the index
* May have to use index hint to get SQL Server to use it  
* Benefit: Index will be small due to small number of rows, so you can include lots (all) of table columns and still have a very small index  
* Parameterized queries do not use them
    * Need a plan that works no matter what the parameter value is, not just the value that matches the index filter
* MERGE might fail...might not update filtered index  
    * lots of other MERGE issues

### Indexed Views
* Written to disk
* Good if doing a lot of aggregation
>CREATE VIEW...WITH SCHEMABINDING AS...  
--does not let base tables be changed in a way that would break the view
> CREATE UNIQUE CLUSTERED INDEX...ON myViewName(columnName);  
-- this materialized the view...writes it to disk
* Can run a query against table, and if it matches with the view, SQL Server should use the view instead, but in reality it usually does not work
    * May have to change query to view instead of table
    * Use **WITH (NOEXPAND)** hint to force SQL Server to use the index on the view
* **Downside:** adds overhead to DUIs
    * Good for tables that do not change that much
    * Want to make view on as few tables and few columns as you can  
* Limitations
    * No self joins, outer joins, or subqueries
    * No OVER clause (ranking/windowing functions)
    * No OUTER or CROSS APPLY
    * **GROUPING:** must contain a COUNT_BIG column; no HAVING, MIN, MAX, TOP, or ORDER BY
    * The clustered index on the view must be unique
    * Lots more rules: BrentOzar.com/go/viewrules
* Indexed View Corruption
    * You can still get data back, but it is wrong
    * Must run DBCC CHECKDBCC with EXTENDED_LOGICAL_CHECKS for compatibility level 110 and higher

### Computed Columns
* Add a columnn to the table that is computed from an existing column
* Example Query: WHERE LTRIM(RTRIM(DisplayName)) = 'Brent Ozar'
> ALTER TABLE dbo.Users ADD DisplayNameTrimmed AS LTRIM(RTRIM(DisplayName));  
* Adds statistics for column and can scan index on base column
* Or, create index on new column to get a seek
* **Limitations**
    * Formulas must match EXACTLY




## Tips
#### Index Creation Options
* ONLINE = ON  -> makes creation slower
* SORT_IN_TEMPDB = ON -> only makes sense when TempDB is on much faster storage than the user database
* MAXDOP = 0 -> Unlimited CPU to go faster; can pick a number if you have a big server to use more CPU but not all of it
* DATA_COMPRESSION = ROW,PAGE,NONE
    * Only works for on row data, not MAX, XML, JSON, other
    * Not a big difference with on or off
    * columnstore indexes work better for compression

#### Fill Factor
* Default: 100% (or 0% is the same thing)
* Page splits
    * "Bad" - row is updated with bigger data and splits row on to multiple pages
    * "Good" - adding new, empty pages for new rows (not really a split)
    * Do not alter fill factor to "fix" page splits, use Extended Events to monitor bad page splits on a per-object basis, and determine if you should adjust it for that one index.
* Actions
    * 100% - leave it
    * 80-99% - nothing, focus on bigger battles
    * 51-79% - "you're wasting X% of memory, space, and taking longer for backups, restores, checkdb, index rebuilds, and other maintenance"
    * 1-50% - "I'm going to set fill factor back to a sane number. Want to start with 80%, 90%, or **100%**?"

#### Fragmentation
* Internal vs External Framgmentation
    * SQL Server does not monitor for the important one, internal
    * External - are the pages in order...we don't care, it doesn't matter now with SSD and shared storage...its all random anyway
* If rebuilding indexes more than once a week, time to start backing off from that schedule

#### Presence of Indexes Can Change Plans
* **No nonclustered indexes** -> more likely to get trivial optimization
* **Presence of any index on table** -> can trip trivial plan over to full optimization, even if index is not used
* **Presence of any columnstore index** -> can trigger batch mode in 2016-17
* **A computed column using a user-defined function on a table** -> causes any query that touches that table to go serial (including CHECKDB) even if the query does not touch that column

#### Columnstore Indexes Work Well With:
* Tables with 100M+ rows, 100GB+, dozens of columns
* Loaded in batches (like 100K+ rows)
* Not many updates/deletes
* SQL Server 2016 or newer, 64GB+ RAM
* Data is highly repetative (compressible)
* Columnscore.come

#### In-Memory OLTP (not a fan)
* DBCC CHECKDB skips these files
* Coruption is only found when it fails to come online during startup or you get a critical failure
* Just go buy the extra RAM instead, and see if it fixes your problem...add 2x RAM for the size of the tables you are thinking about Hekaton for
