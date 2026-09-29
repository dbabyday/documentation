/*
Reverse Engineering Queries from Missing Index Recommendations

v1.1 - 2021-04-08

From Mastering Index Tuning: https://BrentOzar.com/go/masterindexes

This demo requires:

* Any supported version of SQL Server or Azure SQL DB
  (although the 10M row table creation can be pretty slow in Azure)
* Any Stack Overflow database: https://BrentOzar.com/go/querystack

This first RAISERROR is just to make sure you don't accidentally hit F5 and
run the entire script. You don't need to run this:
*/
RAISERROR(N'Oops! No, don''t just hit F5. Run these demos one at a time.', 20, 1) WITH LOG;
GO
 
 
/* Demo setup: */
USE StackOverflow;
GO
EXEC DropIndexes;
GO
/* Build a query that produces this: */
CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [dbo].[Users] ([DisplayName],[Location])


















/* Quiz 2: 2 queries at a time: */
CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [dbo].[Users] ([LastAccessDate],[WebsiteUrl])

CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [dbo].[Users] ([DownVotes],[WebsiteUrl])
















SELECT Id
  FROM dbo.Users
  WHERE LastAccessDate = GETDATE()
    AND WebsiteUrl = 'https://www.BrentOzar.com';

SELECT Id
  FROM dbo.Users
  WHERE DownVotes = 0
    AND WebsiteUrl = 'https://www.BrentOzar.com';
GO















/* Quiz 3: 3 queries at a time: */
SELECT VoteTypeId, COUNT(*) AS TotalVotes
  FROM dbo.Votes
  WHERE PostId = 12345
  GROUP BY VoteTypeId;

SELECT *
  FROM dbo.Votes
  WHERE PostId = 12345
  ORDER BY CreationDate;

SELECT *
  FROM dbo.Votes
  WHERE PostId = 12345
    AND VoteTypeId IN (2, 3);
GO 5

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