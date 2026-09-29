# Fundamentals of Index Tuning

## Indexes for Equality and Inequality Searches

#### WHERE clause
* Index on columns in WHERE clause
* Can include columns in SELECT to eliminate key lookups

#### Seek
* seek only means we jump to a value in the index's first column
* we may have scanned the rest of the table

#### Seek Predicates
* What SQL server seeked to

#### Predicate 
* AKA: Residual predicate, scan predicate
* SQL Server did not seek to these

#### Inequality Searches
* list equality fields first in your index
* beware of index seeks with <> searches - SQL Server may seek to value and read all rows before it, and seek to the value again and read all values after it

#### OR
* SQL Server can use multiple indexes...one for each part of the OR conditions, then combine the results

#### Testing Indexes
* Run query with index hints to used different indexes
>...FROM dbo.Users WITH (INDEX = IX_DisplayName_Location)

#### Field Order
* About selectivity, not necesarily equality
* Can depend on data distriution...if you are looking for a value that is the majority of the records, it doesn't make much difference, but if you are looking for a value that very few rows have, then it is very selective
* inequality can be more selective than equality depending on data distribution and the value you are using
* **ALL EQUALITY** - column order does not matter
* **With INEQUALITY** - order columns by how quick they reduce the amount of rows you scan
* _Usually_ start with WHERE columns first
* Commonly filtered-on fields go first to maximize the number of queries that can use the index

#### Testing It
* Craft a separate SELECT query for each filter in the WHERE clause, and test to see how selective it is




## Indexes for ORDER BY

#### Equality searches
* All WHERE clauses are equality
* Just add order by column to end of index, after the where columns

#### Inequality searches
* If you put the order by column after an inequality column, Logical reads will still be the same
* SQL Server will do a SORT operation after the index seek
* To eliminate the SORT, you must put the ORDER BY column after the EQUALITY columns
* **Depends on if you are trying to reduce logical reads or SORT operation**

#### TOP
* Using a TOP is like a filter to narrow down based on the ORDER BY column
* Might make sense to put the ORDER BY column first in the index (depends on the filters and data...where clause could still be more selective)
* SCAN here is a good thing...we want to read from the start/end of the index (but we are still not scanning the entire index)

**Decision** - Index for most important parameter values



## Indexes for JOINs

#### Break it down to separate queries for each table
* SQL server works like this...need to get rows from each table
* JOIN **ON** clause is a filter similar to a WHERE **IN** clause
* reduces search space

#### Foreign Keys
* Generally good idea to index foreign keys, or any common join columns, on both tables
* also helps with referential integrity checks

#### Mixing Filters and Joins
* Putting filters in JOIN or WHERE, doesn't matter ***in theory***

#### Lots of JOINs
* Order that SQL Server searches tables depends on multiple things
* How selective is the filter, **AND** how many pages have to be read to get those




## Missing Index Recommendations in Execution Plan

Quick, light-weight suggestions

#### Limitations
* The columns are not necessarily ordered correctly (ordered by column id...not by cardinality or selectivity) (it does group equality, then inequality columns, so that is a little better)
* Only shows first one (may not be the best or biggest impact)  
-> would need to look at XML to see others  
-> just use the index tuning strategies to analyze table
* Only looks at WHERE and JOINs (not GROUP BY or ORDER BY)
* Sometimes does **NOT** recommend any, even if there is a really good onec




