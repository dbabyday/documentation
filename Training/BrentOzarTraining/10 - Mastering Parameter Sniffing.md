# Mastering Parameter Sniffing

## Reaction for Emergencies
1. sp_BlitzCache
2. Save the bad plan, remove it from cache
3. Start working to make it less susceptible
	* Index Changes
	* Query Changes
	* System-level changes



## Reducing Impact of Parameter Sniffing


### Start by Query Tuning (not parameter sniffing solution)
* Maybe the plan is crappy
* Make the query more efficient can usually solve parameter sniffing
* Move on to parameter sniffing techniques after this


### With Index Tuning
* Can use cteRowsIWant to move a sort before a keylookup
	* Query sorts with a TOP()
	* Parameter sniffing issue makes keylookups okay for small result set, but bad for large
	* cte to get rows, sort them, then clustered index seeks replace keylookups
* Adding indexes can make parameter sniffing worse
	* Give SQL Server options to filter on different conditions
	* Different indexes good for different parameter values


### With Query Hints
* Index hint to force a plan with that one
	* Issue if the index gets renamed --> query fails
	* Usually not a good solution
* OPTION (OPTIMIZE FOR (@PARAMETER_NAME = VALUE))
	* Ignore value passed in for parameter, instead use the one listed in the hint
	* Risk: Data can change, and your values may not be good anymore
	* Use DYNAMIC SQL to insert hint into query (OPTION (RECOMPILE) for outlier values)
* OPTION (OPTIMIZE FOR UNKNOWN)
	* Uses average value
	* Can be good for equality searches
	* Bad for range searches
	* If using this a lot, consider turning off parameter sniffing at server level (bad for range searches)
* MAX_GRANT_PERCENT
	* SQL Server is always estimating large (25%) memory
	* Do not use with MIN_GRANT_PERCENT --> leads to cumulative memory exhaustion
* MAXDOP
	* If you're going to go parallel, use this number of threads
	* Overrides server level setting (can go higher)
	* 8 is a good starting to start with
	* Does not encourage a parallel plan
	* OPTION(USE HINT('ENABLE_PARALLEL_PLAN_PREFERENCE')) --> encourages parallel plan
* QUERY_OPTIMIZER_COMPATIBILITY_LEVEL_n
	* Query uses specified compatibility level
	* Not very practical...have to change all code needed, instead just tune query for now
* QUERYTRACEON
	* Use specific trace flag for query
	* OPTION (QUERYTRACEON 4199, QUERYTRACEON 4137)
	* https://github.com/ktaranov/sqlserver-kit/blob/master/SQL%20Server%20Trace%20Flag.md
	* Usually not a great idea in production, but may be good to see differences in dev/tuning
	* 8671: spend more time compiling plans, ignore "good enough plan found"
* RECOMPILE



### With Recompile Hints
#### OPTION (RECOMPILE)
* Put it inside the proc, on the query that needs it (reduce the compile impact of CPU)
* metrics are not saved in plan cache
* use sp_humanevents: 
	>EXECUTE dbo.sp_HumanEvents @event_type='recompilations', @seconds_sample=30;  
* Fine to use if query runs 1x a minute or less
* Partitioning makes compilation more complex and longer --> recompile takes longer






## Caching Multiple Plans with Branching

### Bad Branching Causes Sniffing, Good Branching Reduces It

#### WRONG Way: IF statement with queries in each part
* SQL Server creates execution plan for entire procedure on the first run, even the part that is not executed
* The parameter values on the first execution are used for all query estimates in the procedure

#### Dynamic SQL
* Cannot just use a dynamic sql string that is the same
	* That dynamic query will get its plan cached
* Need to change the query string in some Way
	* Can use an IF statement to add a comment depending on which type of value is passed in
	* The different comment will make the query "unique" and it gets its own plan cached

#### Child Stored Procedures
* Shell stored proc uses IF statement to call different child stored proc
	* Both child stored procs can have same text
	* Each stored proc gets its own plan cached, even if the query is the same
* Good when you want to structure the query differently
* If decision is based on a count, you can put those ID's into a temp table, and use that temp table in the child stored procs
	* Can use @@ROWCOUNT to get number of rows inserted into temp table

#### When TempTable "Random Recompile" Causes Issues
* Find the tipping point for different plans to pretty close accuracy
	* When temp table stats clear, the next run it will get stats that still work for the data sets
	* This tipping point changes, so we may run into issues again in the future
* Use OPTION (OPTIMIZIE FOR (@Variable=value))
	* Use values that you know get a good plan for that value range
	* Cardinality for that value can change, creating issues again in the future
* Use OPTION (OPTIMIZE for UNKNOWN)
	* Use this for one of the branches that it works best for
	* Changing cardinality for specific values don't affect this in the future
* Harcode list of values for a branch
	* More technical debt
	* Can work for specific cases
	* Need to be aware of when those values change



## Monitoring Sniffing Problems with the Plan Cache

### Spotting Variable Plans in the Cache
* Query has big differences in min and max worker_time, rows, duration, and/or logical reads
	* Indicates it is probably doing drastically different amounts of work
* Plan Generation number
	* if plan is invalidated (stats updates, index rebuild, ...)
	* high indicates it is likely susceptible to parameter sniffing
	* parameter sniffing issue is when new plan is regenerated and old is flushed out of cache
* Troubleshooting 
	* Log plan cache every 15 minutes using sp_BlitzFirst job
* 2019 - turn on last actual plans
	* see it in sp_BlitzCache

### Query Store
* Logs plan cache in the user database
	* includes queries executed with recompile hint
	* includes cancelled queries
* Pin plan to query
	* Force plan
	* May not work well for all parameters...can make parameter sniffing issue worse
	* Can use it if developers overuse recompile hint...Force Plan will override that
* Plan Cache Instability makes Query Store not usefull
	* Unparameterized queries


### Where to get plans and parameters
* Plan Cache --> sp_BlitzCache
* Log sp_BlitzCache every 15 minutes
* Query Store





## How SQL Server 2019 and 2022 Tries to Reduce the Blast Radius

### Memory Grant Feedback
* SQL Server will adjust memory grant based on how much has been used or spilled based on the last set of parameters used
* Large swings in amounts
* Suggested to turn this feature off
	> ALTER DATABASE SCOPED CONFIGURATION SET ROW_MODE_MEMORY_GRANT_FEEDBACK = OFF;  
	ALTER DATABASE SCOPED CONFIGURATION SET BATCH_MODE_MEMORY_GRANT_FEEDBACK = OFF;

### Adaptive Joins
* It IS important to understand what this IS NOT:
	* not a choice between an index seek + key lookup vs a table scan
	* not a choice between which table to process first (or next)
	* not a dynamic memory grant for the amount of rows that are moving through (and in fact, this operator has a new chance to spill to disk)
* Chooses Index Seek or Index Scan based on how many rows from first operation
	* Needs to wait for threshold of rows to be returned from first operator
	* Then chooses method for second table
* Don't always get adaptive Join
	* Only when cached with an outlier value
	* ==> parameter sniffing


### Automatic Tuning, aka Automatic Plan Regression
* Feature is okay
* Probably won't fix major parameter sniffing issue
* Query has to complete to have an impact
	* If user cancels due to long duration, it won't affect plan choice




## Recap

### Techniques
* Index tuning
* Query Hints
* Recompile
	* For queries running < 1 per minute
	* Always at statemetn level (never at stored proc level)
* Branching, Dynamic SQL

### Diagnosing
* Plan cache now
* Plan cahce over time


