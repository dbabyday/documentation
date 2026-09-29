/*
Mastering Index Tuning - Heaps vs Clustered Indexes
Last updated: 2020-04-01

This script is from our Mastering Index Tuning class.
To learn more: https://www.BrentOzar.com/go/masterindexes
*/


USE [StackOverflow]
GO
DropIndexes;
SET STATISTICS IO ON; /* and turn on actual execution plans */
GO


/* How many reads does it take to scan the clustered index? */
SELECT COUNT(*) FROM dbo.Users WITH (INDEX = 1);
GO

CREATE INDEX IX_LastAccessDate_Id ON dbo.Users(LastAccessDate, Id);
GO
/* Here's what an index seek + key lookup looks like when we have a
   clustered index. Note the number of reads. */
SELECT *
  FROM dbo.Users
  WHERE LastAccessDate >= '2013/11/10'
    AND LastAccessDate <  '2013/11/11';
GO


/* Drop the clustered index: */
ALTER TABLE [dbo].[Users] DROP CONSTRAINT [PK_Users_Id] WITH ( ONLINE = OFF )
GO
/* But we still have the nonclustered index! */
SELECT *
  FROM dbo.Users
  WHERE LastAccessDate >= '2013/11/10'
    AND LastAccessDate <  '2013/11/11';
GO




/* How many reads does it take to scan the heap? */
SELECT COUNT(*) FROM dbo.Users WITH (INDEX = 0);
GO





/* Look at the forwarded_fetch_count column: */
SELECT * FROM sys.dm_db_index_operational_stats(DB_ID(), OBJECT_ID('dbo.Users'), 0, 0);
GO




/* See how a lot of the data is NULL?
   And take note of the number of logical reads... */
SELECT *
  FROM dbo.Users
  WHERE LastAccessDate >= '2013/11/10'
    AND LastAccessDate <  '2013/11/11';
GO


/* What if we went back and populated that? */
UPDATE dbo.Users
  SET AboutMe = 'Wow, I am really starting to like this site, so I will fill out my profile.',
      Age = 18,
	  Location = 'University of Alaska Fairbanks: University Park Building, University Avenue, Fairbanks, AK, United S',
	  WebsiteUrl = 'https://www.linkedin.com/profile/view?id=26971423&authType=NAME_SEARCH&authToken=qvpL&locale=en_US&srchid=969545191417678255996&srchindex=1&srchtotal=452&trk=vsrp_people_res_name&trkInfo=VSRPsearchId%'
  WHERE Id = 2977185;
GO

/* Now, check your logical reads: */
SELECT *
  FROM dbo.Users
  WHERE LastAccessDate >= '2013/11/10'
    AND LastAccessDate <  '2013/11/11';
GO


/* Look at the forwarded_fetch_count column: */
SELECT forwarded_fetch_count 
FROM sys.dm_db_index_operational_stats(DB_ID(), OBJECT_ID('dbo.Users'), 0, 0);
GO


/* The more users who update their data, the worse this becomes. What if everyone did? */
UPDATE dbo.Users
  SET AboutMe = 'Wow, I am really starting to like this site, so I will fill out my profile.',
      Age = 18,
	  Location = 'University of Alaska Fairbanks: University Park Building, University Avenue, Fairbanks, AK, United S',
	  WebsiteUrl = 'https://www.linkedin.com/profile/view?id=26971423&authType=NAME_SEARCH&authToken=qvpL&locale=en_US&srchid=969545191417678255996&srchindex=1&srchtotal=452&trk=vsrp_people_res_name&trkInfo=VSRPsearchId%'
  WHERE LastAccessDate >= '2013/11/10'
    AND LastAccessDate <  '2013/11/11';
GO



/* Now, check your logical reads: */
SELECT *
  FROM dbo.Users
  WHERE LastAccessDate >= '2013/11/10'
    AND LastAccessDate <  '2013/11/11';
GO



/* Look at the forwarded_fetch_count column: */
SELECT forwarded_fetch_count 
FROM sys.dm_db_index_operational_stats(DB_ID(), OBJECT_ID('dbo.Users'), 0, 0);
GO


/* To fix it, you can rebuild the table, which builds a new copy w/o forwarded pointers: */
ALTER TABLE dbo.Users REBUILD;
GO
/* But that's slow because:
  * It's logged
  * It takes the table offline on Standard Edition
  * It also has to rebuild all the nonclustered indexes because the File/Page/Slot number is changing

Or, put a clustered key on it, which fixes this problem permanently. */



/* The next problem: deletes don't actually delete.
Let's delete everyone who hasn't set their location: */
DropIndexes;
GO
DELETE dbo.Users WHERE Location IS NULL;
GO

SELECT COUNT(*) FROM dbo.Users;


/* Only one user is important anyway: */
DELETE dbo.Users WHERE Id <> 26837;
GO
SELECT COUNT(*) FROM dbo.Users;


/* Turn off actual plans: */
sp_BlitzIndex @TableName = 'Users';



/* Add the clustered primary key back in: */
ALTER TABLE [dbo].[Users] ADD  CONSTRAINT [PK_Users_Id] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (ONLINE = OFF);
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