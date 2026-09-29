/*
Mastering Query Tuning - Lab 4 Setup

This script is from our Mastering Query Tuning class.
To learn more: https://www.BrentOzar.com/go/tuninglabs

Before running this setup script, restore the Stack Overflow database.
This script runs instantly - it's just creating stored procedures.




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
EXEC sys.sp_configure N'show advanced', 1;
GO
RECONFIGURE
GO
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 140
GO

CREATE OR ALTER PROC [dbo].[usp_MQT952] @StartDate DATETIME2, @EndDate DATETIME2 AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/952/top-500-answerers-on-the-site */

SELECT 
    Users.Id as [User Link],
    Count(Posts.Id) AS Answers,
    CAST(AVG(CAST(Score AS float)) as numeric(6,2)) AS [Average Answer Score]
FROM
    Posts
  INNER JOIN
    Users ON Users.Id = OwnerUserId
WHERE 
    PostTypeId = 2 and CommunityOwnedDate is null and ClosedDate is null
	AND Posts.CreationDate >= @StartDate AND Posts.CreationDate <= @EndDate
GROUP BY
    Users.Id, DisplayName
HAVING
    Count(Posts.Id) > 10
ORDER BY
    [Average Answer Score] DESC

END
GO

IF 'Question' <> (SELECT Type FROM dbo.PostTypes WHERE Id = 1)
	BEGIN
	DELETE dbo.PostTypes;
	SET IDENTITY_INSERT dbo.PostTypes ON;
	INSERT INTO dbo.PostTypes (Id, Type) VALUES
		(1, 'Question'),
		(2, 'Answer'),
		(3, 'Wiki'),
		(4, 'TagWikiExerpt'),
		(5, 'TagWiki'),
		(6, 'ModeratorNomination'),
		(7, 'WikiPlaceholder'),
		(8, 'PrivilegeWiki');
	SET IDENTITY_INSERT dbo.PostTypes OFF;
	END
GO


CREATE OR ALTER FUNCTION [dbo].[fn_UserHasVoted] ( @UserId INT, @PostId INT )
RETURNS BIT
    WITH RETURNS NULL ON NULL INPUT,
         SCHEMABINDING
AS
    BEGIN
        DECLARE @HasVoted BIT;
		IF EXISTS (SELECT Id
					FROM dbo.Votes
					WHERE UserId = @UserId
					  AND PostId = @PostId)
			SET @HasVoted = 1
		ELSE
			SET @HasVoted = 0;
        RETURN @HasVoted;
    END;
GO



CREATE OR ALTER PROC [dbo].[usp_FindRecentInterestingPostsForUser]
	@UserId INT,
	@SinceDate DATETIME = NULL AS
BEGIN
SET NOCOUNT ON
/* If they didn't pass in a date, find the last vote they cast, and use 7 days before that */
IF @SinceDate IS NULL
	SELECT @SinceDate = DATEADD(DD, -7, CreationDate)
		FROM dbo.Votes v
		WHERE v.UserId = @UserId
		ORDER BY CreationDate DESC;

SELECT TOP 10000 p.*
FROM dbo.Posts p
WHERE PostTypeId = 1 /* Question */
  AND dbo.fn_UserHasVoted(@UserId, p.Id) = 0 /* Only want to show posts they haven't voted on yet */
  AND p.CreationDate >= @SinceDate
ORDER BY p.CreationDate DESC; /* Show the newest stuff first */
END
GO


CREATE OR ALTER   FUNCTION [dbo].[AcceptedAnswerPercentageRate] ( @UserId INT )
RETURNS FLOAT
    WITH RETURNS NULL ON NULL INPUT
AS
    BEGIN
		/* Source: http://data.stackexchange.com/stackoverflow/query/949/what-is-my-accepted-answer-percentage-rate */

		DECLARE @Percent FLOAT;
		IF EXISTS (SELECT * FROM Posts WHERE OwnerUserId = @UserId AND PostTypeId = 2)
			SELECT @Percent = 
				(CAST(Count(a.Id) AS float) / (SELECT Count(*) FROM Posts WHERE OwnerUserId = @UserId AND PostTypeId = 2) * 100)
			FROM
				Posts q
			  INNER JOIN
				Posts a ON q.AcceptedAnswerId = a.Id
			WHERE
				a.OwnerUserId = @UserId
			  AND
				a.PostTypeId = 2;
		ELSE
			SET @Percent = 0
		RETURN @Percent;
    END;
GO


CREATE OR ALTER PROC dbo.usp_UsersByAcceptedAnswerPercentageRate @StartDate DATETIME, @EndDate DATETIME AS
BEGIN
WITH Activity AS (
		SELECT DISTINCT UserId FROM dbo.Comments WHERE CreationDate BETWEEN @StartDate AND @EndDate
		UNION
		SELECT DISTINCT UserId FROM dbo.Votes WHERE CreationDate BETWEEN @StartDate AND @EndDate
		UNION
		SELECT DISTINCT OwnerUserId FROM dbo.Posts WHERE CreationDate BETWEEN @StartDate AND @EndDate
		UNION
		SELECT DISTINCT UserId FROM dbo.Badges WHERE Date BETWEEN @StartDate AND @EndDate)
SELECT TOP 100 *
  FROM dbo.Users u
	INNER JOIN Activity a ON u.Id = a.UserId /* Only people who left comments or voted in this date range */
  ORDER BY dbo.AcceptedAnswerPercentageRate(Id) DESC;
END
GO



CREATE OR ALTER PROC dbo.usp_Q59985 @DisplayName NVARCHAR(40), @StartDate NVARCHAR(40), @EndDate NVARCHAR(40) AS
BEGIN

/* Source: http://data.stackexchange.com/stackoverflow/query/59985/weighted-activity-gauge-for-scifi  (but modified) */
SELECT TOP 100
  pt.Type as PostType, 
  p.Id as [Post Link],
  p.CreationDate,
  p.Score,
  isnull(p.ViewCount, p2.ViewCount) as [View Count],
  3 - p.PostTypeId as Weight --+ 
  -- Comment out the case if answers should have weight 1, 
  -- regardless of if they are the accepted answer.
  --  CASE
  --    WHEN p2.AcceptedAnswerId = p.Id 
  --    THEN 2
  --    ELSE 0
  --  END AS Weight
FROM Posts p
LEFT JOIN PostTypes pt
ON p.PostTypeId = pt.Id
LEFT JOIN Posts p2
ON p.ParentId = p2.Id
WHERE (p.Tags in ('<sql-server>','<oracle>','<mysql>') 
		OR p2.Tags in ('<sql-server>','<oracle>','<mysql>')
      )
AND p.OwnerUserId = (SELECT TOP 1 Id FROM Users WHERE DisplayName = @DisplayName)
AND p.CreationDate BETWEEN convert(Date, @StartDate) and convert(Date, @EndDate)
ORDER BY 6 DESC;
END
GO



CREATE OR ALTER PROC dbo.mqt_Lab4_Level1 @StartDate DATETIME, @EndDate DATETIME AS
BEGIN
/*
Our users asked to see who had the most accepted answers during date range.
Anybody can post an answer to a question, but only one answer can be marked
as "Accepted" - and everybody wants to be accepted, right?

Here's the report that our team wrote:

First, we want to find everyone who was active in a given date range.

The Users table has a LastActivityDate, but that only stores the most recent
date. We specifically need to see history for this. So we start with a CTE
that queries the different tables where users might have had activity, and we
build a list of all the users who created something during our date range.

Then, for those active users, we get the top 100 ordered by accepted answer
percentage rate.

Run the query with parameters like this:

EXEC mqt_Lab4_Level1 '2017/01/01', '2017/01/02'

You can experiment with shorter and longer date ranges - but maybe just start
with one day at first. Then, review the plan and the query to tune it.

Set yourself a timer for 10 minutes. If you're still stumped, look at
mqt_Lab4_Level1_Clue.
*/

WITH Activity AS (
		SELECT DISTINCT UserId FROM dbo.Comments WHERE CreationDate BETWEEN @StartDate AND @EndDate
		UNION
		SELECT DISTINCT UserId FROM dbo.Votes WHERE CreationDate BETWEEN @StartDate AND @EndDate
		UNION
		SELECT DISTINCT OwnerUserId FROM dbo.Posts WHERE CreationDate BETWEEN @StartDate AND @EndDate
		UNION
		SELECT DISTINCT UserId FROM dbo.Badges WHERE Date BETWEEN @StartDate AND @EndDate)
SELECT TOP 100 *
  FROM dbo.Users u
	INNER JOIN Activity a ON u.Id = a.UserId /* Only people who left comments or voted in this date range */
  ORDER BY dbo.AcceptedAnswerPercentageRate(Id) DESC;
END
GO


CREATE OR ALTER PROC dbo.mqt_Lab4_Level1_Clue AS
BEGIN
PRINT 'Stumped, eh? Turn off actual execution plans, and try this:'
PRINT 'DBCC FREEPROCCACHE'
PRINT 'Then run the query for just one day, and then check sp_BlitzCache.'
PRINT 'Look at what queries are running the most often, and try to figure out why.'
END
GO




CREATE OR ALTER PROC [dbo].[usp_QueryLab4] WITH RECOMPILE AS
BEGIN
/* Hi! You can ignore this stored procedure.
   This is used to run different random stored procs as part of your class.
   Don't change this in order to "tune" things.
*/
SET NOCOUNT ON

DECLARE @Id1 INT = CAST(RAND() * 10000000 AS INT) + 1;

IF @Id1 % 11 = 10
	EXEC usp_Q59985 'Brent Ozar', '2017/01/01', '2017/01/10'
ELSE IF @Id1 % 11 = 9
	EXEC usp_UsersByAcceptedAnswerPercentageRate @StartDate = '2017/08/02', @EndDate = '2017/08/03'
ELSE IF @Id1 % 11 = 8
	EXEC usp_MQT952 @StartDate = '2016/11/10', @EndDate = '2016/11/11';
ELSE IF @Id1 % 11 = 7
	EXEC usp_MQT952 @StartDate = '2016/01/01', @EndDate = '2017/01/01';
ELSE IF @Id1 % 11 = 6
	EXEC usp_FindRecentInterestingPostsForUser 26837, '2017/08/25'
ELSE IF @Id1 % 11 = 5
	EXEC usp_FindRecentInterestingPostsForUser 26837, '2017/08/21'
ELSE IF @Id1 % 11 = 4
	EXEC usp_FindRecentInterestingPostsForUser 22656, '2017/08/21'
ELSE IF @Id1 % 11 = 3
	EXEC usp_FindRecentInterestingPostsForUser 22656, '2017/01/14'
ELSE IF @Id1 % 11 = 2
	EXEC usp_FindRecentInterestingPostsForUser 5205141
ELSE
	EXEC usp_UsersByAcceptedAnswerPercentageRate @StartDate = '2017/08/01', @EndDate = '2017/08/02'

WHILE @@TRANCOUNT > 0
	BEGIN
	COMMIT
	END
END
GO