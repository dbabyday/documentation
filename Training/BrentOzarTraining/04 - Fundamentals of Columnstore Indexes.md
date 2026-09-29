# Fundamentals of Columnstore Indexes


## How Columnstore Data is Stored

**Good** - based on how fact tables were structured in 2008 data warehouses (with not much deletes/updates and large inserts)  
**Bad** - transactional data (deltes, updates, and small inserts)  

#### Each column is stored independently  
* Makes it extremely compressible  
* ...and groups of rows (1,000,000 rows or less)  
-> sorted by the initial load order of the table (if it was inserted ordered by id, that will be the sorting of the clustered columnstore index)  
->  other columns is like having an index on each row group  
-> can specify column to order by if you want  
* Good for **wide** tables, and you **don't know which columns** people are filtering on  
-> you don't have to read the whole 8k page of the entire rows that you do in row-stored tables  

#### Dictionary
* to turn strings into numbers  
* some overhead, but much smaller storage  



## Delete / Insert / Update

#### Delete
* scan column for value, identify tubal id (row id), mark row id as deleted  
-> columns all read only...  
* column store logical reads are lob logical reads  
* 0 memory grant for execution plan & much faster  
* deletes are not good for columnstore  
->makes selects slow because you have to read all the deleted data  
* we will need to clean these up  

#### Inserts
* put into a heap (delta store), not stored as columnstore  
* faster than row-stored insert, because there is no order, and no indexes  
* if doing a really large insert (like 1,000,000 rows) it will put in columnstore  

#### Updates
* mark old row as deleted and add a new row  
* new row is dumped in a heap  (delta store)  
-> its the fastest way to insert data  
* faster than row-stored updates  



## Select

#### Fast for the right type of queries  
* MAX()  
* compared to clustered row-stored indexes  
* row-store is faster than columnstore if indexed for those columns  
-> if you know the queries, this is good  
-> if you don't know the queries, columnstore is good  

#### Segement Elimintation  
set statistics io on  
-> Segment reads, segment skipped  
* If your query only involves some of the rowgroups (segments) it will skip the other segments  
* **Delta store (heap segment)**, has logical reads (all rows) every time because we don't know what's in there  
-> if your delta store is large, you will have a large amount of logical reads  

#### SELECT * Bad
* bad because we have to look through each column for the tubal id ==> lots of lob logical reads  
* the more columns we need, the more columnstores we have to go scan to match the tuple id and get the value  


## How Columnstore Data is Rebuilt

## Reorganize
>Alter Index Index_name on schema.table REORGANIZE;  
* May not do anything --> SQL Server still decides what ist's goingto do when reoganizing  

## Rebuild
* Fix the Delta Store  
* Rebuild each of the segments (removing deletes)  
* Takes a long time  
-> exand every row group to full size, then compress back down accross entire table  
* no longer sorted by any column  
-> when expand and compress the data, the rows become randomly shuffled  
-> sucks to not get segment elimination by a column  
* offline opperation (online=on is ignored)  


## CREATE CLUSTERED COLUMNSTORE INDEX with ORDER BY  
Rebuilds with the specified column sorted  

#### SQL 2022
* Can have some overlap due to parallel operation of index build  
* Use the column that you most often filter on (get segment elimination most often)  

#### 2019 & Prior (Manually)  
1. Drop columnstore index  
2. create clustered index (not a columnstore index)  
3. Create clustered columnstore index (use maxdop=1 to get best segment elimination)  
* takes a **long** time  
-> not practical for large tables  



## Benefits  
Can be good for some situations, but not many really fit well  
* Wide tables with lots of rows  
* numeric data (compresses easily; text data adds dicitonary space)  
* low inserts/updates/deletes  
* inserts in batches of 1 million +  

1. Batch mode execution  
-> 2019 gives you that on rowstore  
2.  Compression  
-> prune indexes on rowstore to reduce size, and can use page compression  
3. Segment elimination  
-> makes most sense in wide tables  
4. Rowgroup elimination  
-> but you only get it on one column  
-> reduces over time  

#### ColumnScore.com  
* helps decide if your table is a good fit for columstore  


## Types of Columnstore Indexes  
* Clustered Columnstore Index  
-> Store each column independently  
* Nonclustered columnstore index  
-> pick which columns you index  
-> like only the columns that are rarely/never updated  
-> Updates on other columns do not affect the nonclustered columnstore index  
-> Inserts/Deletes do  



## Partitioning with Columnstore  
## Construct with as few partitions as you can  
* As large as it can be, with size still allowing fast index maintenance  
* Do something like by year instead of by day or month  
* If you are **ALWAYS** filtering on the the partitioned column  
* Neend to implement partitioning and dynmaic sql to switch out partitions, drop and rebuild cci, and switch back  




## Other Notes
* Building columnstore indexes is CPU intensive  
-> minimum of 8 cores cpu and 64 GB memory  
* "Regular" rowstore indexes are best if you know the columns you filter by  
-> columnstore works well for when you do not knwo what users are going to use  

### Advantages review
1. Batch mode processing
2. Read less rows (row group & segment elimination)
3. Read less columns (especially from wide tables)
4. Compression

