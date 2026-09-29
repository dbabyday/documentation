/*
Fundamentals of Query Tuning: Building a Plan

v1.2 - 2020-11-13

https://www.BrentOzar.com/go/queryfund


This demo requires:
* Any supported version of SQL Server
* Any Stack Overflow database: https://www.BrentOzar.com/go/querystack

This first RAISERROR is just to make sure you don't accidentally hit F5 and
run the entire script. You don't need to run this:
*/
RAISERROR(N'Oops! No, don''t just hit F5. Run these demos one at a time.', 20, 1) WITH LOG;
GO


/* When you pass in a query, SQL Server has to build a plan for it.
The more complex your query is, the longer it takes. 

Simple plans compile quickly with full optimization: */

DECLARE @TheRootOfAllEvil TABLE
  (Id INT PRIMARY KEY CLUSTERED);
WITH CTE1 AS (SELECT * FROM @TheRootOfAllEvil r1)
SELECT * FROM CTE1;
GO

/* Longer queries may not: */
DECLARE @TheRootOfAllEvil TABLE
  (Id INT PRIMARY KEY CLUSTERED);
WITH CTE1 AS (SELECT * FROM @TheRootOfAllEvil r1),
CTE2 AS (SELECT cA.* FROM CTE1 cA INNER JOIN CTE1 cB ON cA.Id = cB.Id),
CTE3 AS (SELECT cA.* FROM CTE2 cA INNER JOIN CTE2 cB ON cA.Id = cB.Id),
CTE4 AS (SELECT cA.* FROM CTE3 cA INNER JOIN CTE3 cB ON cA.Id = cB.Id),
CTE5 AS (SELECT cA.* FROM CTE4 cA INNER JOIN CTE4 cB ON cA.Id = cB.Id),
CTE6 AS (SELECT cA.* FROM CTE5 cA INNER JOIN CTE5 cB ON cA.Id = cB.Id),
CTE7 AS (SELECT cA.* FROM CTE6 cA INNER JOIN CTE6 cB ON cA.Id = cB.Id),
CTE8 AS (SELECT cA.* FROM CTE7 cA INNER JOIN CTE7 cB ON cA.Id = cB.Id)
SELECT * FROM CTE8;
GO


DECLARE @TheRootOfAllEvil TABLE
  (Id INT PRIMARY KEY CLUSTERED);
WITH CTE1 AS (SELECT * FROM @TheRootOfAllEvil r1),
CTE2 AS (SELECT cA.* FROM CTE1 cA INNER JOIN CTE1 cB ON cA.Id = cB.Id),
CTE3 AS (SELECT cA.* FROM CTE2 cA INNER JOIN CTE2 cB ON cA.Id = cB.Id),
CTE4 AS (SELECT cA.* FROM CTE3 cA INNER JOIN CTE3 cB ON cA.Id = cB.Id),
CTE5 AS (SELECT cA.* FROM CTE4 cA INNER JOIN CTE4 cB ON cA.Id = cB.Id),
CTE6 AS (SELECT cA.* FROM CTE5 cA INNER JOIN CTE5 cB ON cA.Id = cB.Id),
CTE7 AS (SELECT cA.* FROM CTE6 cA INNER JOIN CTE6 cB ON cA.Id = cB.Id),
CTE8 AS (SELECT cA.* FROM CTE7 cA INNER JOIN CTE7 cB ON cA.Id = cB.Id),
CTE9 AS (SELECT cA.* FROM CTE8 cA INNER JOIN CTE8 cB ON cA.Id = cB.Id)
SELECT * FROM CTE9;
GO

/* This takes several MINUTES just to compile: */
DECLARE @TheRootOfAllEvil TABLE
  (Id INT PRIMARY KEY CLUSTERED);
WITH CTE1 AS (SELECT * FROM @TheRootOfAllEvil r1),
CTE2 AS (SELECT cA.* FROM CTE1 cA INNER JOIN CTE1 cB ON cA.Id = cB.Id),
CTE3 AS (SELECT cA.* FROM CTE2 cA INNER JOIN CTE2 cB ON cA.Id = cB.Id),
CTE4 AS (SELECT cA.* FROM CTE3 cA INNER JOIN CTE3 cB ON cA.Id = cB.Id),
CTE5 AS (SELECT cA.* FROM CTE4 cA INNER JOIN CTE4 cB ON cA.Id = cB.Id),
CTE6 AS (SELECT cA.* FROM CTE5 cA INNER JOIN CTE5 cB ON cA.Id = cB.Id),
CTE7 AS (SELECT cA.* FROM CTE6 cA INNER JOIN CTE6 cB ON cA.Id = cB.Id),
CTE8 AS (SELECT cA.* FROM CTE7 cA INNER JOIN CTE7 cB ON cA.Id = cB.Id),
CTE9 AS (SELECT cA.* FROM CTE8 cA INNER JOIN CTE8 cB ON cA.Id = cB.Id),
CTE10 AS (SELECT cA.* FROM CTE9 cA INNER JOIN CTE9 cB ON cA.Id = cB.Id)
SELECT * FROM CTE10;
GO



/* Now let's use real queries. I'm using the 50GB medium Stack database: */
USE StackOverflow2013;
GO
/* And this stored procedure drops all nonclustered indexes: */
DropIndexes;
GO
/* It leaves clustered indexes in place though. */
SET STATISTICS IO ON;


/* Create a few indexes to support our queries: */
CREATE INDEX IX_Location ON dbo.Users(Location);
CREATE INDEX IX_UserId ON dbo.Comments(UserId);
CREATE INDEX IX_CreationDate ON dbo.Comments(CreationDate);
GO
/* 
Here's the query we want to tune:
Show me the comments from a date range, from people who live in one area. 
*/
SELECT u.DisplayName, u.Id AS UserId, c.Id AS CommentId, c.Score, c.Text
  FROM dbo.Users u
  INNER JOIN dbo.Comments c ON u.Id = c.UserId
  WHERE u.Location = 'Helsinki, Finland'
    AND c.CreationDate BETWEEN '2013-08-01' AND '2013-08-30'
  ORDER BY c.Score DESC;
GO
/*
With those indexes above in mind, what are some of our possible plans?
In plain English, how could SQL Server choose to build these results?
(Look at the table definitions in Object Explorer to help get started.)
*/




/*
Let's see what SQL Server chooses to do. Get the estimated plan. In SSMS:
 * Click Query, Display Estimated Plan or
 * Control-L
*/
SELECT u.DisplayName, u.Id AS UserId, c.Id AS CommentId, c.Score, c.Text
  FROM dbo.Users u
  INNER JOIN dbo.Comments c ON u.Id = c.UserId
  WHERE u.Location = 'Helsinki, Finland'
    AND c.CreationDate BETWEEN '2013-08-01' AND '2013-08-30'
  ORDER BY c.Score DESC;
GO

/*
Things to think about:

 * Which table does SQL Server choose to process first?
 * How does it plan to access that table?
 * How many rows does it expect to find?
 * Where does that estimate come from?

 * Which table does it choose to process second?
 * How does it plan to access that one?
 * How many rows does it expect to find?
 * Where does that estimate come from?

 * Near the end, it does a sort (after it's found the data)
 * How many rows does it expect to sort?
 * How does that influence the memory grant?

 * Is the query going parallel?
 * Which parts go parallel, and how?

Now, run the query with actual execution plans turned on. In SSMS:
 * Click Query, Include Actual Plan or
 * Hit Control-M to turn on actual plans
*/
SELECT u.DisplayName, u.Id AS UserId, c.Id AS CommentId, c.Score, c.Text
  FROM dbo.Users u
  INNER JOIN dbo.Comments c ON u.Id = c.UserId
  WHERE u.Location = 'Helsinki, Finland'
    AND c.CreationDate BETWEEN '2013-08-01' AND '2013-08-30'
  ORDER BY c.Score DESC;
GO


/*
Things to think about:

 * What new "actual" data is available on each operator's tooltip?
 * How did our estimates vs actuals compare for each operator?
 * How did our memory estimate do?

 * Did the query go parallel? How parallel?
 * How many times was each operation done?





 * Is SQL Server's table processing order determined by our query's order?
 * What if we rewrite our query to put Comments first?
*/
SELECT u.DisplayName, u.Id AS UserId, c.Id AS CommentId, c.Score, c.Text
  FROM dbo.Comments c
  INNER JOIN dbo.Users u ON u.Id = c.UserId
  WHERE c.CreationDate BETWEEN '2013-08-01' AND '2013-08-30'
    AND u.Location = 'Helsinki, Finland'
  ORDER BY c.Score DESC;
GO

/* Compare the two plans with Compare Showplan */



/* Or try a CTE: */
WITH CommentsFiltered AS (SELECT Id, Score, Text, UserId
                            FROM dbo.Comments
                            WHERE CreationDate BETWEEN '2013-08-01' AND '2013-08-30'
)
SELECT u.DisplayName, u.Id AS UserId, c.Id AS CommentId, c.Score, c.Text
FROM CommentsFiltered c
  INNER JOIN dbo.Users u ON u.Id = c.UserId
  WHERE u.Location = 'Helsinki, Finland'
  ORDER BY c.Score DESC;
GO


/* Or try subqueries: */
SELECT u.DisplayName, u.Id AS UserId, c.Id AS CommentId, c.Score, c.Text

FROM (SELECT * FROM dbo.Comments
                WHERE CreationDate BETWEEN '2013-08-01' AND '2013-08-30') c

  INNER JOIN (SELECT * FROM dbo.Users u WHERE u.Location = 'Helsinki, Finland') u

        ON u.Id = c.UserId

  ORDER BY c.Score DESC;
GO


/*
T-SQL is a declarative language.

You usually declare the result set you're asking for,
but not how SQL Server assembles your results.

You CAN declare the way you want the data to be processed by specifying:
 * Hints like FORCEORDER
 * Which indexes you want to use
 * Whether SQL Server should seek or scan those indexes

But the more you specify, the more you miss out on cool optimizations,
especially in future versions where SQL Server keeps learning new tricks, or
when your database administrator (or you) add better indexes.

Back on your plan, right-click on the SELECT operator, and click Properties.

 * Compile CPU, Memory, Time
 * Optimization Level = Full means SQL Server put some thought into this

In a perfect world, SQL Server spends CPU & time analyzing what your query is
trying to do, and tries to build an execution plan quickly, making a tradeoff
between:

 * Time spent building an execution plan
 * Time executing the plan (and getting you your results)

But interestingly, SQL Server doesn't know whether you're going to run this
query just once, or millions of times. It does the best job it can, quickly,
and then moves on to its next task. It doesn't go back and refine that plan.

Our goals today are to:

 * Measure the work done when SQL Server executes the plan
 * Revisit the plan to see if it was appropriate, given the data inside the
   database and our query
 * Learn ways we can influence the plan (without forcing things)

*/




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