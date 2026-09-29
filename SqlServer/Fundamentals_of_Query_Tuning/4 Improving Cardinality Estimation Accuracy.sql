/*
Fundamentals of Query Tuning: Improving Cardinality Estimation Accuracy

v1.0 - 2019-06-30

https://www.BrentOzar.com/go/queryfund


This demo requires:
* Any supported version of SQL Server
* Any Stack Overflow database: https://www.BrentOzar.com/go/querystack

This first RAISERROR is just to make sure you don't accidentally hit F5 and
run the entire script. You don't need to run this:
*/
RAISERROR(N'Oops! No, don''t just hit F5. Run these demos one at a time.', 20, 1) WITH LOG;
GO


/* I'm using the 50GB medium Stack database: */
USE StackOverflow2013;
GO
/* And this stored procedure drops all nonclustered indexes: */
DropIndexes;
GO


/* Turn on actual execution plans: */
SELECT Location, COUNT(*)
  FROM dbo.Users
  GROUP BY Location
  ORDER BY COUNT(*) DESC
GO

/* 
Things to think about:

 * How were the row estimates for each operator?
 * When did they start to go wrong, and why?
 * What impact did this have on upstream operators?

What are some ways we could improve the estimate's accuracy?

 * Update statistics
 * Create an index
 * OPTION RECOMPILE
 * Different compatibility levels
 * Add a TOP
*/





/* 
Cardinality isn't just about row counts, either:
it's also about row CONTENTS.
*/
CREATE OR ALTER PROC dbo.usp_UsersInTopLocation_CTE AS
BEGIN
WITH TopLocation AS (SELECT TOP 1 Location
  FROM dbo.Users
  WHERE Location <> ''
  GROUP BY Location
  ORDER BY COUNT(*) DESC)
SELECT u.*
  FROM TopLocation
    INNER JOIN dbo.Users u ON TopLocation.Location = u.Location
  ORDER BY DisplayName;
END
GO

EXEC usp_UsersInTopLocation_CTE
GO



/* Is a subquery any different? */
CREATE OR ALTER PROC dbo.usp_UsersInTopLocation_Subquery AS
BEGIN
SELECT *
  FROM dbo.Users u
  WHERE Location = (SELECT TOP 1 Location
					  FROM dbo.Users
					  WHERE Location <> ''
					  GROUP BY Location
					  ORDER BY COUNT(*) DESC)
  ORDER BY DisplayName;
END
GO

EXEC usp_UsersInTopLocation_Subquery
GO




/*
What if we put the CTE's contents in a variable first?
*/
CREATE OR ALTER PROC dbo.usp_UsersInTopLocation AS
BEGIN
DECLARE @TopLocation NVARCHAR(100);

SELECT TOP 1 @TopLocation = Location
  FROM dbo.Users
  WHERE Location <> ''
  GROUP BY Location
  ORDER BY COUNT(*) DESC;

SELECT *
  FROM dbo.Users
  WHERE Location = @TopLocation
  ORDER BY DisplayName;
END
GO

EXEC usp_UsersInTopLocation
GO

/*
Things to think about:

 * Building a plan and executing a plan are two separate phases
 * The entire batch (proc) is compiled all at once
 * Sometimes, we need compilation to happen later
*/







/* Recompile at the statement level */
CREATE OR ALTER PROC dbo.usp_UsersInTopLocation AS
BEGIN
DECLARE @TopLocation NVARCHAR(100);

SELECT TOP 1 @TopLocation = Location
  FROM dbo.Users
  WHERE Location <> ''
  GROUP BY Location
  ORDER BY COUNT(*) DESC;

SELECT *
  FROM dbo.Users
  WHERE Location = @TopLocation
  ORDER BY DisplayName
  OPTION (RECOMPILE);
END
GO

EXEC usp_UsersInTopLocation
GO


/* Recompile at the proc level */
CREATE OR ALTER PROC dbo.usp_UsersInTopLocation WITH RECOMPILE AS
BEGIN
DECLARE @TopLocation NVARCHAR(100);

SELECT TOP 1 @TopLocation = Location
  FROM dbo.Users
  WHERE Location <> ''
  GROUP BY Location
  ORDER BY COUNT(*) DESC;

SELECT *
  FROM dbo.Users
  WHERE Location = @TopLocation
  ORDER BY DisplayName;
END
GO

EXEC usp_UsersInTopLocation
GO



/* 
To recap, cardinality is about:
 
 * How many rows an operator will put out
 * The CONTENTS of those rows, too

Start at the top right operator in each plan. When the estimates are >10x off,
we need to figure out how we can get that estimate to be more accurate, because
the rest of the upstream operators are probably screwed.




Now, it's your turn. Improve the estimates of this query:
*/
CREATE OR ALTER PROC [dbo].[usp_rpt_ControversialPosts] AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/466/most-controversial-posts-on-the-site */
set nocount on 

declare @VoteStats table (PostId int, up int, down int);

insert @VoteStats
select
    PostId, 
    up = sum(case when VoteTypeId = 2 then 1 else 0 end), 
    down = sum(case when VoteTypeId = 3 then 1 else 0 end)
from Votes
where VoteTypeId in (2,3)
group by PostId;

select top 500 p.Id as [Post Link] , v.up, v.down 
from @VoteStats v
join Posts p on PostId = p.Id
where v.down > (v.up * 0.5) and p.CommunityOwnedDate is null and p.ClosedDate is null
order by v.up desc;
END
GO





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