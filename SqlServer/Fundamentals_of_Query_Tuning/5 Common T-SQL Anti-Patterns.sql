/*
Fundamentals of Query Tuning: Common T-SQL Anti-Patterns

v1.2 - 2021-02-03

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
SET STATISTICS IO, TIME ON;
GO
/* Create a few indexes to support our queries: */
CREATE INDEX IX_Location ON dbo.Users(Location);
CREATE INDEX IX_UserId ON dbo.Comments(UserId);
CREATE INDEX IX_CreationDate ON dbo.Comments(CreationDate);
GO
/* Start in compat level 2016: */
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 130;
GO


/* Multi-statement table-valued functions */
CREATE OR ALTER FUNCTION dbo.fn_GetUsers ( @Location NVARCHAR(200) )
RETURNS @Out TABLE ( UserId INT, DisplayName NVARCHAR(40), Reputation INT )
    WITH SCHEMABINDING
AS
    BEGIN
        INSERT  INTO @Out(UserId, DisplayName, Reputation)
        SELECT  Id, DisplayName, Reputation
        FROM    dbo.Users
        WHERE   Location = @Location;
		RETURN;
    END;
GO

SELECT * 
	FROM dbo.fn_GetUsers( N'India' )
	ORDER BY DisplayName;
GO
/* Read right to left, top to bottom.
The function has a few problems:
* Estimates aren't accurate
* The function itself is a black box:
	* The costs are wrong
	* The work it's doing is invisible

The problems get worse as more tables get involved
in your query - the estimation problems multiply: */

SELECT TOP 1000 c.*
  FROM dbo.fn_GetUsers ( N'India' ) u
  INNER JOIN dbo.Comments c ON u.UserId = c.UserId
	ORDER BY u.DisplayName, c.Score DESC;
GO


/* SQL Server 2017 introduced a fix: SQL Server runs
the function first to get the number of actual rows. */
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 140; /* 2017 */
GO
SELECT TOP 1000 c.*
  FROM dbo.fn_GetUsers ( N'India' ) u
  INNER JOIN dbo.Comments c ON u.UserId = c.UserId
	ORDER BY u.DisplayName, c.Score DESC;
GO

/* The moral of the story: Microsoft is learning
about estimation problems too, and in each new
version, they're improving estimates. Some T-SQL
anti-patterns are gradually getting fixed.

Let's focus on the ones that are still present
even in SQL Server 2019. */




/* Functions in the WHERE clause: */
SELECT *
  FROM dbo.Users
  WHERE Location = N'London, United Kingdom' /* No function */
  ORDER BY Reputation DESC;
GO

SELECT *
  FROM dbo.Users
  WHERE LTRIM(RTRIM(Location)) = N'London, United Kingdom'
  ORDER BY Reputation DESC;
GO
/* 
Are our estimates right?
Did we use the index?
Did we get an accurate memory grant? */


SELECT *
  FROM dbo.Users
  WHERE UPPER(Location) = N'London, United Kingdom'
  ORDER BY Reputation DESC;
GO
/* 
Are our estimates right?
Did we use the index appropriately?
Did we get an accurate memory grant? */



/* System functions on the incoming parameters: */
SELECT *
  FROM dbo.Users
  WHERE Location = LTRIM(RTRIM(N'London, United Kingdom'))
  ORDER BY Reputation DESC;
GO


/*
Different system functions behave differently,
especially in different places in the query.

There's no one truth about them all.

* Some overestimate, some under-estimate
* Some cause index scans, some don't
* Some are harmless, some are terribad

Generally speaking, avoid putting system functions
in the FROM/JOIN/WHERE/GROUP/etc unless you've
proven that the function placement is harmless in your
specific SQL Server version & compatibility level.
*/










/* 
Implicit conversions: when SQL Server needs to compare two things, but the
datatypes aren't the same. Sometimes SQL Server can convert them automatically:
*/
DECLARE @Location XML = N'London, United Kingdom';
SELECT *
  FROM dbo.Users
  WHERE Location = @Location;
GO

/* Or try this: */
DECLARE @Location VARCHAR(100) = N'London, United Kingdom';
SELECT *
  FROM dbo.Users
  WHERE Location = @Location;
GO
/* Note - no warning in the plan.

Or this - note that I'm passing in a string, not a date:
*/
DECLARE @NotADate NVARCHAR(100) = N'2009-11-10';
SELECT *
  FROM dbo.Comments
  WHERE CreationDate = @NotADate;
GO


/* 
But if you pass in a higher-fidelity datatype than what's stored in the table:
*/
DECLARE @NotADate SQL_VARIANT = '2009-11-10';
SELECT *
  FROM dbo.Comments
  WHERE CreationDate = @NotADate;
GO

/* 
Things to think about:

 * SQL Server up-converts what's in the table to match the incoming data type
 * The CPU use goes up linearly with the number of rows/columns to be converted
 * We get a scan, not a seek
 * The estimates are usually way off, too

Granted, you probably never see people using SQL_VARIANT (and now you know why.)

Another example: comparing strings to numbers: */
SELECT *
	FROM dbo.Users
	WHERE Id = '26837';

/* No big deal. But try LIKE: */

SELECT *
	FROM dbo.Users
	WHERE Id LIKE '26837';

/* Because this also has to work: */

SELECT *
	FROM dbo.Users
	WHERE Id LIKE '26837%';

/* Read right to left, look at estimates,
and think about why they're off and what
you could do to fix 'em. */


/* The biggest offender is comparing VARCHAR
table contents to NVARCHAR parameters. Stack Overflow
doesn't ship with VARCHAR columns, so let's set one up:
*/
CREATE TABLE dbo.Users_Varchar (Id INT PRIMARY KEY CLUSTERED, DisplayName VARCHAR(40));
INSERT INTO dbo.Users_Varchar (Id, DisplayName)
  SELECT Id, DisplayName
  FROM dbo.Users;
GO
CREATE INDEX IX_DisplayName ON dbo.Users_Varchar(DisplayName);
GO

/* Will our query use the index if we pass in an NVARCHAR?
The N in front of a string mean's it's Unicode (NVARCHAR).*/
SELECT *
  FROM dbo.Users_Varchar
  WHERE DisplayName = N'Brent Ozar';
GO
/* Things to think about:
* Read right to left, top to bottom
* Is there a yellow bang? What does it say?

If we fix it, how does the plan get better? 
*/



/* This can hit you really hard on joins, so check the fields you join on: */
WITH ProblematicColumns AS  (
SELECT COLUMN_NAME
  FROM INFORMATION_SCHEMA.COLUMNS c1
  GROUP BY COLUMN_NAME
  HAVING COUNT(DISTINCT DATA_TYPE) > 1
)
SELECT c.*
  FROM ProblematicColumns pc
  INNER JOIN INFORMATION_SCHEMA.COLUMNS c ON pc.COLUMN_NAME = c.COLUMN_NAME
  ORDER BY c.COLUMN_NAME, c.DATA_TYPE;
GO




/* Comparing the contents of two columns in the same table: */
SELECT *
  FROM dbo.Users
  WHERE UpVotes + DownVotes > 1000000;
GO

SELECT u.DisplayName, u.Id, COUNT(*) AS NumberOfComments
  FROM dbo.Users u
  INNER JOIN dbo.Comments c ON u.Id = c.UserId
  WHERE u.DownVotes + u.UpVotes > 1000000
  GROUP BY u.DisplayName, u.Id;
GO

/*
Things to think about:

 * How are estimates vs actuals?
 * What's the effect?
 * Can you fix the estimate by putting in indexes?
 * Can you imagine a scenario where this query runs very, very slowly?
 * How might you rework this query, either to fix the estimate, AND/OR reduce
   the blast radius of that bad estimate?


This is really the start of a lifelong journey.
The more you learn about SQL Server, the more
you'll start to recognize queries that COMPILE,
but produce bad estimations or behaviors.
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