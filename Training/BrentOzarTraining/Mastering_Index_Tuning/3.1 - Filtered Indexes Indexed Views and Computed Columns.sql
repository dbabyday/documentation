/*
Artisanal Indexes: Filtered Indexes, Indexed Views, and Computed Columns
v1.3 - 2023-11-28

This script is from our SQL Server performance tuning classes.
To learn more: https://www.BrentOzar.com/go/tuninglabs

This first RAISERROR is just to make sure you don't accidentally hit F5 and
run the entire script. You don't need to run this:
*/
RAISERROR(N'Oops! No, don''t just hit F5. Run these demos one at a time.', 20, 1) WITH LOG;
GO


USE StackOverflow;
GO
/* Set the compat level to be the same as master: */
DECLARE @StringToExec NVARCHAR(4000);
SELECT @StringToExec = N'ALTER DATABASE CURRENT SET compatibility_level = '
	+ CAST(compatibility_level AS NVARCHAR(5)) + N';' 
	FROM sys.databases WHERE name = 'master';
EXEC(@StringToExec);
GO

DropIndexes @TableName = 'Users' /* Source: https://www.brentozar.com/archive/2017/08/drop-indexes-fast/ */
GO
SET STATISTICS IO ON;




/* 
===============================================================================
=== PART 1: FILTERED INDEXES
===============================================================================
*/




/* 
We're going to add an IsDeleted field to the StackOverflow.dbo.Users table
that doesn't ship with the data dump, but it's the kind of thing you often see
out in real life in the field:
*/
ALTER TABLE dbo.Users
   ADD IsDeleted BIT NOT NULL DEFAULT 0,
       IsEmployee BIT NOT NULL DEFAULT 0
GO

/* Populate some of the employees: */
UPDATE dbo.Users
    SET IsEmployee = 1
    WHERE Id IN (1, 2, 3, 4, 13249, 23354, 115866, 130213, 146719);
GO
/* And update a random ~1% of the people: */
UPDATE dbo.Users
    SET IsDeleted = 1
    WHERE Id % 100 = 0;
GO


/* Now run a typical query: */
SET STATISTICS IO ON;

SELECT *
  FROM dbo.Users
  WHERE IsDeleted = 0
    AND DisplayName LIKE 'Br%'
  ORDER BY Reputation;
GO

CREATE INDEX IsDeleted_DisplayName ON dbo.Users (IsDeleted, DisplayName)
	INCLUDE (Reputation);
CREATE INDEX DisplayName_IsDeleted ON dbo.Users (DisplayName, IsDeleted)
	INCLUDE (Reputation);
GO
SELECT *
  FROM dbo.Users
  WHERE IsDeleted = 0
    AND DisplayName LIKE 'Br%'
  ORDER BY Reputation;
GO


CREATE INDEX DisplayName_Reputation_Filtered ON dbo.Users (DisplayName, Reputation)
    WHERE IsDeleted = 0;
GO
SELECT *
  FROM dbo.Users
  WHERE IsDeleted = 0
    AND DisplayName LIKE 'Br%'
  ORDER BY Reputation;
GO

sp_BlitzIndex @TableName = 'Users';
GO


SELECT *
  FROM dbo.Users
  WHERE IsEmployee = 1
  ORDER BY DisplayName;
GO

CREATE INDEX IX_IsEmployee_DisplayName ON dbo.Users(IsEmployee, DisplayName);
GO
SELECT *
  FROM dbo.Users
  WHERE IsEmployee = 1
  ORDER BY DisplayName;
GO


sp_BlitzIndex @TableName = 'Users';
GO

DropIndexes @TableName = 'Users';
GO
CREATE INDEX IX_DisplayName_Filtered_Employees ON dbo.Users(DisplayName)
	INCLUDE ([Id], [AboutMe], [Age], [CreationDate], [DownVotes], 
		[EmailHash], [LastAccessDate], [Location], [Reputation], 
		[UpVotes], [Views], [WebsiteUrl], [AccountId])
  WHERE IsEmployee = 1;
GO
SELECT *
  FROM dbo.Users
  WHERE IsEmployee = 1
  ORDER BY DisplayName;
GO


sp_BlitzIndex @TableName = 'Users';
GO






/* 
===============================================================================
=== PART 2: INDEXED VIEWS
===============================================================================
*/

/* 
Say we need to quickly find which non-deleted 
users have the most comments, and speed is critical:
*/
SELECT TOP 100 u.Id, u.DisplayName, u.Location, u.AboutMe, SUM(1) AS CommentCount
  FROM dbo.Users u
  INNER JOIN dbo.Comments c ON u.Id = c.UserId
  WHERE u.IsDeleted = 0
  GROUP BY u.Id, u.DisplayName, u.Location, u.AboutMe
  ORDER BY SUM(1) DESC;
GO


/* Note that we do already have in index on Comments.UserId: */
sp_BlitzIndex @TableName = 'Comments'
GO

CREATE OR ALTER VIEW dbo.vwCommentsByUser WITH SCHEMABINDING AS
    SELECT UserId, 
        SUM(1) AS CommentCount,
        COUNT_BIG(*) AS MeanOldSQLServerMakesMeDoThis
    FROM dbo.Comments
    GROUP BY UserId;
GO
CREATE UNIQUE CLUSTERED INDEX CL_UserId ON dbo.vwCommentsByUser(UserId);
GO




SELECT TOP 100 u.Id, u.DisplayName, u.Location, u.AboutMe, SUM(1) AS CommentCount
  FROM dbo.Users u
  INNER JOIN dbo.Comments c ON u.Id = c.UserId
  WHERE u.IsDeleted = 0
  GROUP BY u.Id, u.DisplayName, u.Location, u.AboutMe
  ORDER BY SUM(1) DESC;
GO


/* Not fast enough? You can even put indexes
on top of indexed views: */
CREATE INDEX CommentCount ON dbo.vwCommentsByUser(CommentCount);

/* And get time down even faster: */
SELECT TOP 100 u.Id, u.DisplayName, u.Location, u.AboutMe, SUM(1) AS CommentCount
  FROM dbo.Users u
  INNER JOIN dbo.Comments c ON u.Id = c.UserId
  WHERE u.IsDeleted = 0
  GROUP BY u.Id, u.DisplayName, u.Location, u.AboutMe
  ORDER BY SUM(1) DESC;
GO


/* Keep in mind that more indexes, more columns, more problems: */
sp_BlitzIndex @TableName = 'vwCommentsByUser'
GO



/* 
===============================================================================
=== PART 3: COMPUTED COLUMNS
===============================================================================
*/

/* Say we have an index on DisplayName: */
CREATE INDEX IX_DisplayName ON dbo.Users(DisplayName);

/* But we have a legacy app that does LTRIM/RTRIM: */
SELECT *
	FROM dbo.Users
	WHERE LTRIM(RTRIM(DisplayName)) = N'Brent Ozar';

/* It *COULD* use the index, but it refuses to: */
SELECT *
	FROM dbo.Users WITH (INDEX = IX_DisplayName)
	WHERE LTRIM(RTRIM(DisplayName)) = N'Brent Ozar';

/* We have 3 problems:
1. Our estimates are way off, so
2. We're ignoring nonclustered indexes, and
3. We can't get index seeks

We can fix one of them: */
ALTER TABLE dbo.Users
	ADD DisplayNameTrimmed AS LTRIM(RTRIM(DisplayName));

/* Not persisted, runs instantly. 

Try the query again: */
SELECT *
	FROM dbo.Users
	WHERE LTRIM(RTRIM(DisplayName)) = N'Brent Ozar';

/* We fixed the estimates, AND it uses the index!
But we don't get an index seek. We can, though: */
CREATE INDEX DisplayName_Trimmed
	ON dbo.Users(DisplayNameTrimmed);

SELECT *
	FROM dbo.Users
	WHERE LTRIM(RTRIM(DisplayName)) = N'Brent Ozar';

/* Even without changing our query to point to the new column!

But the functions have to match, in order, or else: */
SELECT *
	FROM dbo.Users
	WHERE RTRIM(LTRIM(DisplayName)) = N'Brent Ozar';

SELECT *
	FROM dbo.Users
	WHERE TRIM(DisplayName) = N'Brent Ozar';


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