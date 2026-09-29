/*
Mastering Index Tuning - Lab 4
Last updated: 2023-11-28

This script is from our Mastering Index Tuning class.
To learn more: https://www.BrentOzar.com/go/tuninglabs

Before running this setup script, restore the Stack Overflow database.
This script takes ~5 minutes with 4 cores, 32GB RAM, and SSD storage.




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


USE StackOverflow;
GO

IF DB_NAME() <> 'StackOverflow'
  RAISERROR(N'Oops! For some reason the StackOverflow database does not exist here.', 20, 1) WITH LOG;
GO

/* Set the compat level to be the same as master: */
DECLARE @StringToExec NVARCHAR(4000);
SELECT @StringToExec = N'ALTER DATABASE CURRENT SET compatibility_level = '
	+ CAST(compatibility_level AS NVARCHAR(5)) + N';' 
	FROM sys.databases WHERE name = 'master';
EXEC(@StringToExec);
GO


CREATE OR ALTER PROC dbo.usp_LogUserVisit @Id INT AS
BEGIN
UPDATE dbo.Users
	SET LastAccessDate = GETUTCDATE()
	WHERE Id = @Id;
END
GO

CREATE OR ALTER PROC dbo.usp_LogPostView @PostId INT, @UserId INT = NULL AS
BEGIN
BEGIN TRAN
	UPDATE dbo.Posts
		SET ViewCount = ViewCount + 1, LastActivityDate = GETUTCDATE()
		WHERE Id = @PostId;

	/* If the post is a question, and it has achieved 1,000 views, give the owner a badge */
	IF 1000 >= (SELECT ViewCount FROM dbo.Posts WHERE Id = @PostId AND PostTypeId = 1)
		AND NOT EXISTS (SELECT * 
							FROM dbo.Posts p
							INNER JOIN dbo.Users u ON p.OwnerUserId = u.Id
							INNER JOIN dbo.Badges b ON u.Id = b.UserId AND b.Name = 'Popular Question'
							WHERE p.Id = @PostId)
		BEGIN
		INSERT INTO dbo.Badges(Name, UserId, Date)
			SELECT 'Popular Question', OwnerUserId, GETUTCDATE()
			FROM dbo.Posts p
			INNER JOIN dbo.Users u ON p.OwnerUserId = u.Id
			WHERE p.Id = @PostId;
		END 

	/* If the post is an answer, and it has achieved 1,000 views, give the owner a badge */
	IF 1000 >= (SELECT ViewCount FROM dbo.Posts WHERE Id = @PostId AND PostTypeId = 2)
		AND NOT EXISTS (SELECT * 
							FROM dbo.Posts p
							INNER JOIN dbo.Users u ON p.OwnerUserId = u.Id
							INNER JOIN dbo.Badges b ON u.Id = b.UserId AND b.Name = 'Popular Answer'
							WHERE p.Id = @PostId)
		BEGIN
		INSERT INTO dbo.Badges(Name, UserId, Date)
			SELECT 'Popular Answer', OwnerUserId, GETUTCDATE()
			FROM dbo.Posts p
			INNER JOIN dbo.Users u ON p.OwnerUserId = u.Id
			WHERE p.Id = @PostId;
		END 

	IF @UserId IS NOT NULL
		UPDATE dbo.Users
			SET LastAccessDate = GETUTCDATE()
			WHERE Id = @UserId;

COMMIT
END
GO

CREATE OR ALTER PROC dbo.usp_LogVote @PostId INT, @UserId INT, @VoteTypeId INT AS
BEGIN
BEGIN TRAN
	INSERT INTO dbo.Votes(PostId, UserId, VoteTypeId, CreationDate)
	SELECT @PostId, @UserId, @VoteTypeId, GETDATE()
		FROM dbo.Posts p
		  LEFT OUTER JOIN dbo.Votes v ON p.Id = v.PostId
									AND v.VoteTypeId = @VoteTypeId
									AND v.UserId = @UserId /* Not allowed to vote twice */
		WHERE p.Id = @PostId			/* Make sure it's a valid post */
		  AND p.ClosedDate IS NULL		/* Not allowed to vote on closed posts */
		  AND p.OwnerUserId <> @UserId	/* Not allowed to vote on your own posts */
		  AND v.Id IS NULL				/* Not allowed to vote twice */
		  AND EXISTS (SELECT * FROM dbo.VoteTypes vt WHERE vt.Id = @VoteTypeId) /* Only accept current vote types */

	IF @VoteTypeId = 2 /* UpVote */
		BEGIN
		UPDATE dbo.Posts	
			SET Score = Score + 1
			WHERE Id = @PostId;
		END

	IF @VoteTypeId = 3 /* DownVote */
		BEGIN
		UPDATE dbo.Posts	
			SET Score = Score - 1
			WHERE Id = @PostId;
		UPDATE dbo.Users
			SET Reputation = Reputation - 1 /* Downvoting costs you a reputation point */
			WHERE Id = @UserId;
		END

	UPDATE dbo.Users
		SET LastAccessDate = GETUTCDATE()
		WHERE Id = @UserId;

	UPDATE dbo.Posts
		SET LastActivityDate = GETUTCDATE()
		WHERE Id = @PostId;

COMMIT
END
GO

CREATE OR ALTER PROC dbo.usp_ReportVotesByDate @StartDate DATETIME, @EndDate DATETIME AS
BEGIN
SELECT TOP 500 p.Title, vt.Name, COUNT(DISTINCT v.Id) AS Votes
  FROM dbo.Posts p
    INNER JOIN dbo.Votes v ON p.Id = v.PostId
	INNER JOIN dbo.VoteTypes vt ON v.VoteTypeId = vt.Id
	INNER JOIN dbo.Users u ON v.UserId = u.Id
  WHERE v.CreationDate BETWEEN @StartDate AND @EndDate
  GROUP BY p.Title, vt.Name
  ORDER BY COUNT(DISTINCT v.Id) DESC;
END
GO


CREATE OR ALTER PROC dbo.usp_IndexLab4_Setup AS
BEGIN
SELECT *
  INTO dbo.Users_New
  FROM dbo.Users;
DROP TABLE dbo.Users;
EXEC sp_rename 'dbo.Users_New', 'Users', 'OBJECT';

SET IDENTITY_INSERT dbo.Users ON;
INSERT INTO [dbo].[Users]
           ([AboutMe]
           ,[Age]
           ,[CreationDate]
           ,[DisplayName]
           ,[DownVotes]
           ,[EmailHash]
		   ,[Id]
           ,[LastAccessDate]
           ,[Location]
           ,[Reputation]
           ,[UpVotes]
           ,[Views]
           ,[WebsiteUrl]
           ,[AccountId])
SELECT [AboutMe]
           ,[Age]
           ,[CreationDate]
           ,[DisplayName]
           ,[DownVotes]
           ,[EmailHash]
		   ,[Id]
           ,[LastAccessDate]
           ,[Location]
           ,[Reputation]
           ,[UpVotes]
           ,[Views]
           ,[WebsiteUrl]
           ,[AccountId]
FROM dbo.Users
WHERE DisplayName LIKE '%duplic%';
SET IDENTITY_INSERT dbo.Users OFF;

EXEC DropIndexes @SchemaName = 'dbo', @TableName = 'Posts', @ExceptIndexNames = 'IX_OwnerUserId_Includes,IX_LastActivityDate_Includes,IX_Score,IX_ViewCount_Score_LastActivityDate';
EXEC DropIndexes @SchemaName = 'dbo', @TableName = 'Badges';

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Posts]') AND name = N'IX_OwnerUserId_Includes')
	CREATE INDEX IX_OwnerUserId_Includes ON dbo.Posts(OwnerUserId) INCLUDE (Score, ViewCount, LastActivityDate);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Posts]') AND name = N'IX_LastActivityDate_Includes')
	CREATE INDEX IX_LastActivityDate_Includes ON dbo.Posts(LastActivityDate) INCLUDE (Score, ViewCount);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Posts]') AND name = N'IX_Score')
	CREATE INDEX IX_Score ON dbo.Posts(Score) INCLUDE (LastActivityDate, ViewCount);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Posts]') AND name = N'IX_ViewCount_Score_LastActivityDate')
	CREATE INDEX IX_ViewCount_Score_LastActivityDate ON dbo.Posts(ViewCount, Score, LastActivityDate);
END
GO


CREATE OR ALTER PROC [dbo].[usp_IndexLab4] WITH RECOMPILE AS
BEGIN
/* Hi! You can ignore this stored procedure.
   This is used to run different random stored procs as part of your class.
   Don't change this in order to "tune" things.
*/
SET NOCOUNT ON

DECLARE @Id1 INT = CAST(RAND() * 10000000 AS INT) + 1,
		@Id2 INT = CAST(RAND() * 10000000 AS INT) + 1,
		@StartDate DATETIME = DATEADD(DAY, -1, GETUTCDATE()),
		@EndDate DATETIME = GETUTCDATE();

IF @Id1 % 13 = 11 AND @@SPID % 5 = 0
	EXEC usp_ReportVotesByDate @StartDate = @StartDate, @EndDate = @EndDate;
ELSE IF @Id1 % 13 = 10
	EXEC dbo.usp_LogPostView @PostId = 38549, @UserId = 22656
ELSE IF @Id1 % 13 = 9
	EXEC dbo.usp_LogPostView @PostId = 38549, @UserId = NULL /* Anonymous visitor */
ELSE IF @Id1 % 13 = 8
	EXEC dbo.usp_LogVote @PostId = 38549, @UserId = 22656, @VoteTypeId = 3
ELSE IF @Id1 % 13 = 7
	EXEC usp_LogUserVisit @Id = 22656;
ELSE IF @Id1 % 13 = 6
	EXEC dbo.usp_LogVote @PostId = @Id1, @UserId = @Id2, @VoteTypeId = 3
ELSE IF @Id1 % 13 = 5
	EXEC dbo.usp_LogVote @PostId = @Id1, @UserId = @Id2, @VoteTypeId = 2
ELSE IF @Id1 % 13 = 4
	EXEC dbo.usp_LogPostView @PostId = @Id1, @UserId = @Id2
ELSE IF @Id1 % 13 = 3
	EXEC dbo.usp_LogPostView @PostId = @Id1, @UserId = NULL /* Anonymous visitor */
ELSE IF @Id1 % 13 = 2
	EXEC usp_LogUserVisit @Id = @Id1;
ELSE
	EXEC dbo.usp_LogVote @PostId = 38549, @UserId = 22656, @VoteTypeId = 2

WHILE @@TRANCOUNT > 0
	BEGIN
	COMMIT
	END
END
GO

EXEC usp_IndexLab4_Setup
GO