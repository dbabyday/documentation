# Fundamentals of Query Tuning

### Goals
1. Measure the work done when SQL Server executes the plan  
2. Revisit the plan to see if it was appropriate, given the data inside the database and our query  
3. Learn ways we can influence the plan (without forcing things)  

### Tips  
* Ctrl + l --> show estimated execution plan  



## Building a Query Plan
Compiling is single threaded  
* CompileCPU = CompileTime  

#### Reason For Early Termination  
* Time Out  
* Good Enough Plan Found  

#### Estimated Execution Plan
* Measurements are mostly useless

#### Actual Execution Plan
* Shows how accurate estimated rows are  
-> Okay range: **10x too high** - **10x too low**  

#### Order of tables in execution
* T-SQL is a **Declarative Language** - You usually declare the result set you're asking for,
but not how SQL Server assembles your results  
-> Not dependent on order you list tables in query  
-> Not even using CTEs force order of table execution  
-> Not even using subqueries force order of table execution  
* Ways to declare the way to process data  
-> Hints like FORCEORDER  
-> Which indexes you want to use  
-> Whether SQL Server should seek or scan those indexes  
-> **Warning:** the more you specify the more you miss out on optimizations, especially when things change like indexes, or new features




## How Parameters Affect Plan
Statistics help SQL Server decide order and type of operations to get data  
* Can get different execution plans for different filter values  
* Parameterization keeps the plan cached  
-> Drawback: if other parameters would do much better with a different plan, it still gets stuck with the cached plan  
-> If an "outlier" is used first, it might be a bad plan for most of the values that will be used  

#### These events (and others) can cause the cached plan to go away:
* Restarting the SQL Server
* DBCC FREEPROCCACHE
* Rebuilding indexes on tables in the query
* Updating statistics on tables in the query

#### Collect a set of parameters for tuning:
* Commonly called ones that users care a lot about
* Outliers with very small data sets
* Outliers with very large data sets
* Outliers where SQL Server estimates rows incorrectly
#### Armed with that, then you:
* Tune indexes or queries so that one plan works better for everyone, or
* Run the query with each set of parameters, getting its plan
* Measure how the different plans perform with different inputs

#### To get the set of common parameters, you can:
* Ask the users
* Query the tables (looking for outliers)
* Check the plan cache (but these are just the compiled parameters)  
-> sp_BlitzCache
* Run a Profiler trace or Extended Events session capturing them as they run

#### Parameter Sensitive Plan Optimization (2022)
* Different plans for small, medium, and large data filters
* Doesn't always work
* Good when it does work




## Improving Cardinality Estimation Accuracy

#### Ways to improve estimate's accuracy
* Update statistics  
-> Cardinality Estimation Based on Statistics  
-> with fullscan  
-> all rows (more accurate cardinality estimations), but takes a lot longer  
-> update stats only once a month or so, and do it with fullscan  
* Create an index  
-> also creates statistics with fullscan, so you get good numbers  
* OPTION RECOMPILE  
* Different compatibility levels  
-> 2019 has adaptive memory grants...gives you more memory, but adjusts with with more executions to right-size it, but has big fluctuations  
-> 2022 has better adaptive memory grant fluctions  
* Add a TOP  
-> uses less memory when sorting **100 or less** rows  

#### If the query is combined with a CTE or Subquery
* SQL Server may not know the value from the subquery that will affect the main query  
* Separate the query, and put the first value into a variable to use in the main query  
-> Does not change anything right away  
-> Because SQL Server builds the entire execution plan at the start  
* Add **OPTION (RECOMPILE)** to the main query  
-> Causes SQL Server to recompile the main query after it knows the value of the variable  
-> More complex the query is, and more often it runs, the more it impacts overall performance  
-> Good for queries that run **once a minute or less**  
* Or...make it two stored procedures  
-> the second stored proc compiles with the value passed in from the first  
* Or...dynamic sql  
-> use it with parameterization  
-> the dynamic sql query is seen as something separate when it executes, so it's plan is independent of the stored proc or parent query plan  




## Common T-SQL Anti-Patterns

* Might cause cardinality estimation problems
* But those problems may only cause plan changes for SOME parameters, and not others
* Or might be universally bad
* Might not be immediately obvious in the query plan
* Might change over time, like in newer versions of SQL Server and Azure SQL DB

#### Functions in the FROM & below (WHERE, JOIN, GROUP BY, etc)
* Even on the right side, it can make estimates way worse  
* System functions (processing strings, dates, security, etc)
* User-defined functions (scalars, table-valued functions)
* CLR functions (plus the newer Java, R, Python type stuff)  
* Generally speaking, avoid putting any functions in the FROM/JOIN/WHERE/GROUP/etc unless you've proven that the function placement is harmless in your specific SQL Server version & compatibility level.

#### Implicit conversions
* We get a scan, not a seek
* The estimates are usually way off, too
* SQL Server up-converts what's in the table to match the incoming data type
* CPU use goes up linearly with the number of rows/columns to be converted
* This can get really bad when on join columns  

#### Comparing the contents of 2 columns on 1 table
* SQL Server has tons of those hard-coded estimates,
but the worst offenders are:  
-> Comparing or doing math on 2 columns in the same table  
-> Or even 2 columns in DIFFERENT tables

#### Table variables
* Cardinality estimation is just 1 row (no stats on object) 
-> Because of that, it underestimated memory, and the sort spilled to disk  
-> Single threaded (doesn't use parallelism because it is estimating 1 row)  
**FIXES**  
-> OPTION RECOMPILE on query selecting from table variable, it will get accurate estimates  
-> SQL 2019 compat level (checks for row estimates, but can cause parameter sniffing problems)  
* Variables ignore transactions  
-> If you do DML on records in tbl variable, they will happen whether you commit or rollback  





## Execution Plans Are Lying Liars

* **The costs** - everywhere you see a percentage, it's an estimated cost, not the actual cost, even when you're looking at the actual plans. The top query's 100% cost is meaningless.  
* **Scalar function operators** don't show their actual CPU and IO time/cost (hardcoded for 0)  
-> cost is hardcoded at 0 - does not show actual CPU or IO time/cost (could be the biggest part, but you don't see it)  
-> executions hardcoded at 1 - but it really runs for every row  
* **The missing index request** - it's only showing the first one, and it's awful. It's suggesting we need to cover the Comments.Text field, which will double the size of the table.
* **The arrow sizes** - in estimated plans, they're based off the estimated rows that will be output by the operator. In actual plans, they're based off the number of rows READ by the operator.
* **The type conversion warning** - says it will affect cardinality estimate, but it simply can't. The CreationDate isn't used for anything but output.
* **The wait stats** - note the query runtime compared to the wait times.
* **Contents of functions** - in this case, fnGetPostType is querying the PostTypes table, but you don't even see that table in the plan, the stats IO, or waits.
* **The SELECT tooltip's "Degree of Parallelism"** implies 0, aka unlimited, but this query was single-threaded.  
-> user defined functions anywhere means the plan cannot go parallel...look at properties > NonparallelPlanReason  






## Recap

#### Query Execution has 2 Phases
1. Building the Plan  
-> Based off the parameters we start with  
-> Compiled for the hwole batch, all at once  
-> Plan quality can vary based on time available  
-> Your window: compilation CPU, time, timeouts  
2. Executing the Plan  
-> Based off the parameters in the cached plan  
-> Not revisited when problems happen  

#### Focus on Repeatable Metrics
* Common  
-> **Logical Reads** - set statistics io on  
-> **CPU Time** - set statistics time on  
* Less Common  
-> TempDB spills  
-> Memory grants  

#### Most Important Gauge
* Compare estimated rows to actual rows  
* Start at top right and work across/down
* Find the spot where variance is > 10x  
* Fixes  
-> Change T-SQL to be more easily understood  
-> Break a large query into parts, use temp tables  
-> Recompile, dynamic SQL, child stored procedures  

#### Parameters  
* Find the right parameters to tune  
-> query data to find outliers  





## How to Find the Right Queries to Tune
> execute sp_BlitzFirst @SinceStartup=1;  
* Tells you how long it has been up, and what it has waited most on  
* Let's you know what to look for and what to sort sp_BlitzCache  

> execute sp_BlitzCache @SortOrder='cpu';  
1. Look for Priority 1 warnings --> means you cannot trust the output...address these first  
2. Check for top couple of queries before the metric drops down significantly  
3. Look at warnings for the plan, and use the further descriptions about them in the second result set  












