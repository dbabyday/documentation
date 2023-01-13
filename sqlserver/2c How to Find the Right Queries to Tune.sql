/*
Fundamentals of Query Tuning: Analyzing SQL Server's Performance

v1.0 - 2019-06-30

https://www.BrentOzar.com/go/queryfund


This demo requires:
* Any supported version of SQL Server
* Any Stack Overflow database: https://www.BrentOzar.com/go/querystack


By default, sp_BlitzCache finds your most resource-intensive queries by sorting
the plan cache by CPU. These two are the same thing:
*/
EXEC sp_BlitzCache;
GO
EXEC sp_BlitzCache @SortOrder = 'cpu';
GO


/* 
There are TONS of sort orders.

In a production environment, you'll see wildly different queries depending on
which way you sort your plan cache.

And you need to focus on the most important bottlenecks first - because you're
always going to have "bad" queries in the plan cache. The key is knowing where
to focus your tuning time.

To know that, we need to find our server's top wait type:
*/
EXEC sp_BlitzFirst @SinceStartup = 1;
GO


EXEC sp_BlitzFirst;
GO


EXEC sp_BlitzFirst @ExpertMode = 1;
GO



/*
Decoder ring for the 6 most common wait types:

CXPACKET/CXCONSUMER: queries going parallel to read a lot of data or do a lot of CPU work.
Sort by CPU and by READS.

LCK%: locking, so look for long-running queries. Sort by DURATION, and look for
the warning of "Long Running, Low CPU." That's probably a query being blocked.

PAGEIOLATCH: reading data pages that aren't cached in RAM. Sort by READS.

RESOURCE_SEMAPHORE: queries can't get enough workspace memory to start running.
Sort by MEMORY GRANT, although that isn't available in older versions of SQL.

SOS_SCHEDULER_YIELD: CPU pressure, so sort by CPU.

WRITELOG: writing to the transaction log for delete/update/insert (DUI) work.
Sort by WRITES.
*/

EXEC sp_BlitzCache @SortOrder = 'reads'

/*
Note that you can also sort by averages, too:
*/
EXEC sp_BlitzCache @SortOrder = 'avg reads'



/*
License: Creative Commons Attribution-ShareAlike 3.0 Unported (CC BY-SA 3.0)
More info: https://creativecommons.org/licenses/by-sa/3.0/

You are free to:
* Share - copy and redistribute the material in any medium or format
* Adapt - remix, transform, and build upon the material for any purpose, even 
  commercially

Under the following terms:
* Attribution - You must give appropriate credit, provide a link to the license,
  and indicate if changes were made.
* ShareAlike - If you remix, transform, or build upon the material, you must
  distribute your contributions under the same license as the original.
*/