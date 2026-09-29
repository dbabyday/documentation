/*
Mastering Server Tuning - Lab 3 Setup

This script is from our Mastering Server Tuning class.
To learn more: https://www.BrentOzar.com/go/tuninglabs

Before running this setup script, restore the Stack Overflow database.
This script runs in 1-2 minutes depending on server hardware - it's changing
indexes as well as creating stored procs and changing server settings.




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
GO
USE StackOverflow;
GO

CREATE OR ALTER PROC dbo.usp_ServerLab3_Setup AS
BEGIN
	EXEC sys.sp_configure N'cost threshold', N'5'
	EXEC sys.sp_configure N'max degree of parallelism', N'0'
	EXEC sys.sp_configure N'max server memory (MB)', N'16000'
	RECONFIGURE WITH OVERRIDE;
	IF NOT EXISTS(SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Comments' AND COLUMN_NAME = 'IsDeleted')
		ALTER TABLE dbo.Comments
		  ADD IsDeleted BIT NOT NULL DEFAULT 0;
	IF NOT EXISTS(SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Comments' AND COLUMN_NAME = 'IsPrivate')
		ALTER TABLE dbo.Comments
		  ADD IsPrivate BIT NOT NULL DEFAULT 0;
	IF NOT EXISTS(SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Posts' AND COLUMN_NAME = 'IsDeleted')
		ALTER TABLE dbo.Posts
		  ADD IsDeleted BIT NOT NULL DEFAULT 0;
	IF NOT EXISTS(SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Posts' AND COLUMN_NAME = 'IsPrivate')
		ALTER TABLE dbo.Posts
		  ADD IsPrivate BIT NOT NULL DEFAULT 0;
	IF NOT EXISTS(SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'IsDeleted')
		ALTER TABLE dbo.Users
		  ADD IsDeleted BIT NOT NULL DEFAULT 0;
	IF NOT EXISTS(SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'IsPrivate')
		ALTER TABLE dbo.Users
		  ADD IsPrivate BIT NOT NULL DEFAULT 0;
	IF NOT EXISTS(SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Votes' AND COLUMN_NAME = 'IsDeleted')
		ALTER TABLE dbo.Votes
		  ADD IsDeleted BIT NOT NULL DEFAULT 0;
	IF NOT EXISTS(SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Votes' AND COLUMN_NAME = 'IsPrivate')
		ALTER TABLE dbo.Votes
		  ADD IsPrivate BIT NOT NULL DEFAULT 0;
	IF EXISTS(SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Users') AND name = 'IX_LastAccessDate_DisplayName_Reputation')
		DROP INDEX IX_LastAccessDate_DisplayName_Reputation ON dbo.Users;
	IF EXISTS(SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Users') AND name = '_dta_index_Users_5_149575571__K7_K10_K1_5')
		DROP INDEX _dta_index_Users_5_149575571__K7_K10_K1_5 ON dbo.Users;
	ALTER TABLE dbo.Users
	  ALTER COLUMN Location VARCHAR(100);
END
GO



EXEC usp_ServerLab3_Setup;
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER VIEW [dbo].[vwComments] AS 
	SELECT Id, CreationDate, PostId, Score, Text, UserId, IsDeleted, IsPrivate
	FROM dbo.Comments
	WHERE IsDeleted = 0
	  AND IsPrivate = 0; /* No longer showing items marked private as of the 2019 release */
GO

CREATE OR ALTER VIEW [dbo].[vwPosts] AS 
SELECT [Id]
      ,[AcceptedAnswerId]
      ,[AnswerCount]
      ,[Body]
      ,[ClosedDate]
      ,[CommentCount]
      ,[CommunityOwnedDate]
      ,[CreationDate]
      ,[FavoriteCount]
      ,[LastActivityDate]
      ,[LastEditDate]
      ,[LastEditorDisplayName]
      ,[LastEditorUserId]
      ,[OwnerUserId]
      ,[ParentId]
      ,[PostTypeId]
      ,[Score]
      ,[Tags]
      ,[Title]
      ,[ViewCount]
	  ,[IsDeleted]
	  ,[IsPrivate]
  FROM [dbo].[Posts]
	WHERE IsDeleted = 0
	  AND IsPrivate = 0; /* No longer showing items marked private as of the 2019 release */
GO

CREATE OR ALTER VIEW [dbo].[vwUsers] AS 
	SELECT [Id]
		  ,[AboutMe]
		  ,[Age]
		  ,[CreationDate]
		  ,[DisplayName]
		  ,[DownVotes]
		  ,[EmailHash]
		  ,[LastAccessDate]
		  ,[Location]
		  ,[Reputation]
		  ,[UpVotes]
		  ,[Views]
		  ,[WebsiteUrl]
		  ,[AccountId]
		  ,[IsDeleted]
		  ,[IsPrivate]
	FROM dbo.Users
	WHERE IsDeleted = 0
	  AND IsPrivate = 0; /* No longer showing items marked private as of the 2019 release */
GO

CREATE OR ALTER VIEW [dbo].[vwVotes] AS 
	SELECT Id, PostId, UserId, BountyAmount, VoteTypeId, CreationDate, IsDeleted, IsPrivate
	FROM dbo.Votes
	WHERE IsDeleted = 0
	  AND IsPrivate = 0; /* No longer showing items marked private as of the 2019 release */
GO




CREATE OR ALTER PROC dbo.usp_SearchPostsByLocation @Location NVARCHAR(100) AS
BEGIN
/* Find the most recent posts from an area */
SELECT TOP 200 p.Title, p.Id, p.CreationDate
  FROM dbo.vwPosts p
  INNER JOIN dbo.vwUsers u ON p.OwnerUserId = u.Id
  WHERE u.Location = @Location
    AND u.IsDeleted = 0
	AND u.IsPrivate = 0
	AND p.IsDeleted = 0
	AND p.IsPrivate = 0
  ORDER BY p.CreationDate DESC
END
GO

CREATE OR ALTER PROC [dbo].[usp_AcceptedAnswersByUser]
	@UserId INT AS
BEGIN
SET NOCOUNT ON
SELECT pQ.Title, pQ.Id, pA.Title, pA.Body, c.CreationDate, u.DisplayName, c.Text
FROM dbo.vwPosts pA
  INNER JOIN dbo.vwPosts pQ ON pA.ParentId = pQ.Id
			AND pA.Id = pQ.AcceptedAnswerId
  LEFT OUTER JOIN dbo.vwComments c ON pA.Id = c.PostId
			AND c.UserId <> @UserId
  LEFT OUTER JOIN dbo.Users u ON c.UserId = u.Id
WHERE pA.OwnerUserId = @UserId
ORDER BY pQ.CreationDate, c.CreationDate
END
GO

CREATE OR ALTER PROC [dbo].[usp_Q166045] @UserId1 INT = 22656, @UserId2 INT = 88656 AS
BEGIN
/* Find questions that are commented on by two specific users, and see who had the higher-rated comment */

/* Adapted from: https://data.stackexchange.com/stackoverflow/query/166045/questions-that-have-been-answered-by-both-jon-skeet-and-eric-lippert */
select p1.Title, cBest.*
from vwPosts p1
inner join vwComments cBest ON p1.Id = cBest.PostId AND cBest.UserId IN(@UserId1, @UserId2)
left outer join vwComments cBetter ON p1.Id = cBetter.PostId AND cBest.Id <> cBetter.Id AND cBetter.UserId IN(@UserId1, @UserId2) AND cBetter.Score > cBest.Score
where p1.PostTypeId = 1 AND
      p1.Id in
      (select c1.PostId
       from vwComments c1
       where c1.UserId = @UserId1
       intersect
       select c2.PostId
       from vwComments c2
       where c2.UserId = @UserId2)
and cBetter.Id IS NULL
order by p1.Score desc;
END
GO

CREATE OR ALTER PROC [dbo].[usp_Q947] @UserId INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/947/my-comment-score-distribution */

SELECT 
    Count(*) AS CommentCount,
    Score
FROM 
    vwComments
WHERE 
    UserId = @UserId
GROUP BY 
    Score
ORDER BY 
    Score DESC
END
GO

CREATE OR ALTER PROC [dbo].[usp_Q949] @UserId INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/949/what-is-my-accepted-answer-percentage-rate */

SELECT 
    (CAST(Count(a.Id) AS float) / (1 + (SELECT Count(*) FROM Posts WHERE OwnerUserId = @UserId AND PostTypeId = 2) * 100)) AS AcceptedPercentage
FROM
    vwPosts q
  INNER JOIN
    vwPosts a ON q.AcceptedAnswerId = a.Id
WHERE
    a.OwnerUserId = @UserId
  AND
    a.PostTypeId = 2

END
GO


CREATE OR ALTER PROC dbo.usp_ReportCommentsByLocation @Location NVARCHAR(100), @StartDate NVARCHAR(100), @EndDate NVARCHAR(100) AS
BEGIN
SELECT DISTINCT u.Location, u.DisplayName, 
	pQ.Title AS QuestionTitle,
	pA.Title AS AnswerTitle,
	c.CreationDate AS CommentDate,
	c.Text AS CommentText
FROM dbo.vwPosts pQ
  INNER JOIN dbo.vwPosts pA ON pQ.Id = pA.ParentId
  INNER JOIN dbo.vwComments c ON pA.Id = c.PostId  /* Only looking for comments on answers */
  INNER JOIN dbo.vwUsers u ON c.UserId = u.Id
WHERE u.Location LIKE (@Location + N'%')
  AND CAST(c.CreationDate AS DATE) BETWEEN @StartDate AND @EndDate
ORDER BY c.CreationDate, u.Location, u.DisplayName
END
GO

CREATE OR ALTER PROC dbo.usp_SupportSearch
	@DisplayName NVARCHAR(40), @Location NVARCHAR(100),
	@HasPostedSince DATETIME, @HasCommentedSince DATETIME AS
BEGIN

DECLARE @StringToExec NVARCHAR(4000);
SET @StringToExec = N'SELECT * FROM dbo.vwUsers u
	WHERE DisplayName LIKE ''' + @DisplayName + '''
	AND Location LIKE ''' + @Location + '''
	AND EXISTS (SELECT * FROM dbo.vwPosts WHERE OwnerUserId = u.Id AND CreationDate > ''' + CAST(@HasPostedSince AS NVARCHAR(100)) + ''')
	AND EXISTS (SELECT * FROM dbo.vwComments WHERE UserId = u.Id AND CreationDate > ''' + CAST(@HasCommentedSince AS NVARCHAR(100)) + ''')';

PRINT @StringToExec;
EXEC(@StringToExec);
END
GO

CREATE OR ALTER PROC [dbo].[usp_ServerLab3_Clue] AS
BEGIN
PRINT 'When you take samples with sp_BlitzFirst, you should be seeing:'
PRINT '  * Parallelism waits - so you could try raising Cost Threshold, but'
PRINT '    then remember to look past those for the next high wait, which is...'
PRINT '  * CPU waits - so you would look at sp_BlitzCache @SortOrder = ''cpu'''
PRINT '    for the high resource-consuming queries, but...'
PRINT '  ';
PRINT 'sp_BlitzFirst is also warning you about high compilations per sec,'
PRINT 'and sp_BlitzCache will be warning you about an unstable plan cache.'
PRINT ' ';
PRINT 'Check to see if there are unparameterized queries flooding the cache'
PRINT 'that all look different, but are really the same. If so, could you:'
PRINT '  * Tune them to go faster, and'
PRINT '  * Make them easier to group together to see their overall impact'
END;
GO


CREATE OR ALTER PROC [dbo].[usp_ServerLab3] WITH RECOMPILE AS
BEGIN
/* Hi! You can ignore this stored procedure.
   This is used to run different random stored procs as part of your class.
   Don't change this in order to "tune" things.
*/
SET NOCOUNT ON

DECLARE @Id1 INT = CAST(RAND() * 10000000 AS INT) + 1;
DECLARE @Id2 INT = CAST(RAND() * 10000000 AS INT) + 1;
DECLARE @Id3 INT = CAST(RAND() * 10000000 AS INT) + 1;
DECLARE @DisplayName NVARCHAR(40), @Location NVARCHAR(100), @Date1 DATETIME, @Date2 DATETIME;

IF @@SPID % 2 = 0 /* Half of the sessions run this all the time: */
    BEGIN
    SELECT TOP 1 @DisplayName = DisplayName, @Location = Location, @Date1 = CreationDate, @Date2 = CreationDate
        FROM dbo.Users WITH (NOLOCK)
        WHERE Id >= @Id1
        ORDER BY Id OPTION (RECOMPILE);

	EXEC usp_SupportSearch @DisplayName = @DisplayName, @Location = @Location,
	@HasPostedSince = @Date1, @HasCommentedSince = @Date2;
    END

ELSE IF @Id1 % 50 = 11
    EXEC usp_AcceptedAnswersByUser 22656
ELSE IF @Id1 % 50 = 10
    EXEC usp_ReportCommentsByLocation 'Chicago', '2017/01/14', '2017/01/20'
ELSE IF @Id1 % 50 = 9
	EXEC dbo.usp_Q947 22656;
ELSE IF @Id1 % 50 = 8
	EXEC dbo.usp_Q947 @Id1;
ELSE IF @Id1 % 50 = 7
	EXEC dbo.usp_Q949 22656;
ELSE IF @Id1 % 50 = 6
	EXEC dbo.usp_Q949 @Id1;
ELSE IF @Id1 % 50 = 5
    EXEC [usp_Q166045] 22656, 88656
ELSE IF @Id1 % 50 = 4
    EXEC [usp_Q166045] 88656, 22656
ELSE IF @Id1 % 50 = 3
	EXEC usp_AcceptedAnswersByUser @Id1
ELSE IF @Id1 % 50 = 2
    EXEC usp_SearchPostsByLocation 'New York NY';
ELSE IF @Id1 % 50 = 1
    EXEC usp_SearchPostsByLocation 'Bangalore, Karnataka, India';
ELSE
    BEGIN
    SELECT TOP 1 @DisplayName = DisplayName, @Location = Location, @Date1 = CreationDate, @Date2 = CreationDate
        FROM dbo.Users WITH (NOLOCK)
        WHERE Id >= @Id1
        ORDER BY Id OPTION (RECOMPILE);

	EXEC usp_SupportSearch @DisplayName = @DisplayName, @Location = @Location,
	@HasPostedSince = @Date1, @HasCommentedSince = @Date2;
    END

WHILE @@TRANCOUNT > 0
	BEGIN
	COMMIT
	END
END
GO