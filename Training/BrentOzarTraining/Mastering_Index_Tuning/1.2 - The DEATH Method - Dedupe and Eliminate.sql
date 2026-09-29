/*
Mastering Index Tuning - The D.E.A.T.H. Method
Last updated: 2019-06-14

This script is from our Mastering Index Tuning class.
To learn more: https://www.BrentOzar.com/go/masterindexes

Before running this setup script, restore the Stack Overflow database.
Don't run this all at once: it's about interactively stepping through a few
statements and understanding the plans they produce.

Requirements:
* Any SQL Server version or Azure SQL DB
* Stack Overflow database of any size: https://BrentOzar.com/go/querystack
 


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


/* Create a few indexes: */
CREATE INDEX IX_LastAccessDate ON dbo.Users(LastAccessDate);
CREATE INDEX IX_Age ON dbo.Users(Age) INCLUDE (LastAccessDate);
CREATE INDEX IX_DisplayName ON dbo.Users(DisplayName) INCLUDE (LastAccessDate);
CREATE INDEX IX_DownVotes ON dbo.Users(DownVotes) INCLUDE (LastAccessDate);
CREATE INDEX IX_Location ON dbo.Users(Location) INCLUDE (LastAccessDate);
CREATE INDEX IX_Reputation ON dbo.Users(Reputation) INCLUDE (LastAccessDate);
GO



/* Get the estimated plans for these - don't actually run 'em: */
DELETE dbo.Users WHERE Reputation = 1000000;



DELETE dbo.Users WHERE Reputation = 1;


UPDATE dbo.Users
    SET LastAccessDate = GETDATE()
    WHERE DisplayName = 'Brent Ozar';
GO


/* Just one index on Reputation, nothing else: */
EXEC DropIndexes;
GO
CREATE INDEX IX_Reputation ON dbo.Users(Reputation);
GO


/* All our indexes, but WITHOUT the LastAccessDate include: */
EXEC DropIndexes;
GO
CREATE INDEX IX_Age ON dbo.Users(Age);
CREATE INDEX IX_DisplayName ON dbo.Users(DisplayName);
CREATE INDEX IX_DownVotes ON dbo.Users(DownVotes);
CREATE INDEX IX_Location ON dbo.Users(Location);
CREATE INDEX IX_Reputation ON dbo.Users(Reputation);
GO


CREATE INDEX IX_LastAccessDate ON dbo.Users(LastAccessDate);
GO