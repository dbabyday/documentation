/*
Mastering Index Tuning - Foreign Keys and Check Constraints
Last updated: 2020-11-04

This script is from our Mastering Index Tuning class.
To learn more: https://www.BrentOzar.com/go/masterindexes

Before running this setup script, restore the Stack Overflow database.
Don't run this all at once: it's about interactively stepping through a few
statements and understanding the plans they produce.

Requirements:
* Any SQL Server version or Azure SQL DB
* Stack Overflow database of any size: https://BrentOzar.com/go/querystack
 

This first RAISERROR is just to make sure you don't accidentally hit F5 and
run the entire script. You don't need to run this:
*/
RAISERROR(N'Oops! No, don''t just hit F5. Run these demos one at a time.', 20, 1) WITH LOG;
GO


USE StackOverflow;
GO

IF DB_NAME() <> 'StackOverflow'
  RAISERROR(N'Oops! For some reason the StackOverflow database does not exist here.', 20, 1) WITH LOG;
GO

/* Foreign key demos */
SELECT p.PostTypeId, COUNT(*) AS Posts
  FROM dbo.PostTypes pt
  INNER JOIN dbo.Posts p ON pt.Id = p.PostTypeId
  GROUP BY p.PostTypeId
  ORDER BY COUNT(*) DESC;
GO


ALTER TABLE dbo.Posts
ADD CONSTRAINT fk_Posts_PostTypeId 
	FOREIGN KEY (PostTypeId) 
REFERENCES dbo.PostTypes(Id);
GO

SELECT pt.Id, pt.Type, COUNT(*) AS Posts
  FROM dbo.PostTypes pt
  INNER JOIN dbo.Posts p ON pt.Id = p.PostTypeId
  GROUP BY pt.Id, pt.Type
  ORDER BY COUNT(*) DESC;
GO


ALTER TABLE dbo.Posts
ADD CONSTRAINT fk_Posts_OwnerUserId 
	FOREIGN KEY (OwnerUserId) 
REFERENCES dbo.Users(Id);
GO

SELECT p.*
  FROM dbo.Posts p
  LEFT OUTER JOIN dbo.Users u ON p.OwnerUserId = u.Id
  WHERE u.Id IS NULL;
GO

ALTER TABLE dbo.Posts WITH NOCHECK
ADD CONSTRAINT fk_Posts_OwnerUserId 
	FOREIGN KEY (OwnerUserId) 
REFERENCES dbo.Users(Id)
GO

EXEC sp_Blitz;

ALTER TABLE dbo.Posts
DROP CONSTRAINT fk_Posts_OwnerUserId;
GO



ALTER TABLE dbo.Posts WITH NOCHECK
ADD CONSTRAINT fk_Posts_OwnerUserId 
	FOREIGN KEY (OwnerUserId) 
REFERENCES dbo.Users(Id)
ON DELETE CASCADE;
GO


DELETE dbo.Users WHERE Id = 26837;


ALTER TABLE dbo.Posts
DROP CONSTRAINT fk_Posts_PostTypeId;
GO
ALTER TABLE dbo.Posts
DROP CONSTRAINT fk_Posts_OwnerUserId;
GO




/* Constraint demos */



/* Say we have a CompanyCode column in Users: */
EXEC sp_rename 'dbo.Users.Age', 'CompanyCode'
GO
/* And say everyone has the same CompanyCode:
 (this will take a minute) */
UPDATE dbo.Users SET CompanyCode = 100;

/* And all of our queries always ask for that CompanyCode: */
SELECT *
	FROM dbo.Users
	WHERE CompanyCode = 100
	AND DisplayName = N'Brent Ozar';

/* Then every missing index request will start with that,
even though it's basically useless: all the columns match.

Will a check constraint fix it? */
ALTER TABLE dbo.Users
	ADD CONSTRAINT CompanyCodeIsAlways100
	CHECK (CompanyCode = 100);

/* And then try your query again: */
SELECT *
	FROM dbo.Users
	WHERE CompanyCode = 100
	AND DisplayName = N'Brent Ozar';

/* Add an index just on DisplayName: */
CREATE INDEX DisplayName ON dbo.Users(DisplayName);

/* And then try your query again, and check the key lookup predicates: */
SELECT *
	FROM dbo.Users
	WHERE CompanyCode = 100
	AND DisplayName = N'Brent Ozar';

/* SQL Server will eliminate this, at least: */
SELECT * FROM dbo.Users WHERE CompanyCode <> 100;


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