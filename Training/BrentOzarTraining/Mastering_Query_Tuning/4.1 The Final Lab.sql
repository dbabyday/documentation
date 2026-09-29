/*
Mastering Query Tuning - Lab 5 Setup

This script is from our Mastering Query Tuning class.
To learn more: https://www.BrentOzar.com/go/tuninglabs

Before running this setup script, restore the Stack Overflow database.
This script runs instantly - it's just creating stored procedures and
changing indexes. Did I say changing? I meant dropping. Whatevs.




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

CREATE OR ALTER PROC [dbo].[usp_MQT6925] @UserId INT = NULL, @CreationDate VARCHAR(50) = NULL, @Reputation INT = NULL AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/6925/newer-users-with-more-reputation-than-me */

IF @UserId IS NOT NULL
	SELECT u.Id as [User Link], u.Reputation, u.Reputation - me.Reputation as Difference
	FROM dbo.Users me 
	INNER JOIN dbo.Users u 
		ON u.CreationDate > me.CreationDate
		AND u.Reputation > me.Reputation
	WHERE me.Id = @UserId
ELSE
	SELECT u.Id as [User Link], u.Reputation, u.Reputation as Difference
	FROM dbo.Users u 
	WHERE u.CreationDate > @CreationDate
		AND u.Reputation > @Reputation


END
GO


CREATE OR ALTER PROC [dbo].[usp_MQT6856] @MinReputation INT = 1, @Upvotes INT = 100 AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/6856/high-standards-top-100-users-that-rarely-upvote */

select top 100
  Id as [User Link],
  round((100.0 * (Reputation/10)) / (UpVotes+1), 2) as [Ratio %],
  Reputation as Rep, 
  UpVotes as [+ Votes],
  DownVotes [- Votes]
from Users
where Reputation > @MinReputation
  and UpVotes > @Upvotes
order by [Ratio %] desc

END
GO



CREATE OR ALTER PROC [dbo].[usp_Q6627] AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/6627/top-50-most-prolific-editors */

-- Top 50 Most Prolific Editors
-- Shows the top 50 post editors, where the user was the most recent editor
-- (meaning the results are conservative compared to the actual number of edits).

SELECT TOP 50
    Id AS [User Link],
    (
        SELECT COUNT(*) FROM Posts
        WHERE
            PostTypeId = 1 AND
            LastEditorUserId = Users.Id AND
            OwnerUserId != Users.Id
    ) AS QuestionEdits,
    (
        SELECT COUNT(*) FROM Posts
        WHERE
            PostTypeId = 2 AND
            LastEditorUserId = Users.Id AND
            OwnerUserId != Users.Id
    ) AS AnswerEdits,
    (
        SELECT COUNT(*) FROM Posts
        WHERE
            LastEditorUserId = Users.Id AND
            OwnerUserId != Users.Id
    ) AS TotalEdits
    FROM Users
    ORDER BY TotalEdits DESC

END
GO


CREATE OR ALTER PROC [dbo].[usp_Q6772] @UserId INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/6772/stackoverflow-rank-and-percentile */

WITH Rankings AS (
SELECT Id, Ranking = ROW_NUMBER() OVER(ORDER BY Reputation DESC)
FROM Users
)
,Counts AS (
SELECT Count = COUNT(*)
FROM Users
WHERE Reputation > 100
)
SELECT Id, Ranking, CAST(Ranking AS decimal(20, 5)) / (SELECT Count FROM Counts) AS Percentile
FROM Rankings
WHERE Id = @UserId

END
GO



CREATE OR ALTER PROC [dbo].[usp_Q7521] @UserId INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/7521/how-unsung-am-i */

-- How Unsung am I?
-- Zero and non-zero accepted count. Self-accepted answers do not count.

select
    count(a.Id) as [Accepted Answers],
    sum(case when a.Score = 0 then 0 else 1 end) as [Scored Answers],  
    sum(case when a.Score = 0 then 1 else 0 end) as [Unscored Answers],
    sum(CASE WHEN a.Score = 0 then 1 else 0 end)*1000 / count(a.Id) / 10.0 as [Percentage Unscored]
from
    Posts q
  inner join
    Posts a
  on a.Id = q.AcceptedAnswerId
where
      a.CommunityOwnedDate is null
  and a.OwnerUserId = @UserId
  and q.OwnerUserId != @UserId
  and a.PostTypeId = 2
END
GO






CREATE OR ALTER PROC [dbo].[usp_Q8116] @UserId INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/8116/my-money-for-jam */

-- My Money for Jam
-- My Non Community Wiki Posts that earn the most Passive Reputation.
-- Reputation gained in the first 15 days of post is ignored,
-- all reputation after that is considered passive reputation.
-- Post must be at least 60 Days old.

set nocount on

declare @latestDate datetime
select @latestDate = max(CreationDate) from Posts
declare @ignoreDays numeric = 15
declare @minAgeDays numeric = @ignoreDays * 4

-- temp table moded from http://odata.stackexchange.com/stackoverflow/s/87
declare @VoteStats table (PostId int, up int, down int, CreationDate datetime)
insert @VoteStats
select
    p.Id,
    up = sum(case when VoteTypeId = 2 then
        case when p.ParentId is null then 5 else 10 end
        else 0 end),
    down = sum(case when VoteTypeId = 3 then 2 else 0 end),
    p.CreationDate
from Votes v join Posts p on v.PostId = p.Id
where v.VoteTypeId in (2,3)
and OwnerUserId = @UserId
and p.CommunityOwnedDate is null
and datediff(day, p.CreationDate, v.CreationDate) > @ignoreDays
and datediff(day, p.CreationDate, @latestDate) > @minAgeDays
group by p.Id, p.CreationDate, p.ParentId

set nocount off

select top 100 PostId as [Post Link],
  convert(decimal(10,2), up - down)/(datediff(day, vs.CreationDate, @latestDate) - @ignoreDays) as [Passive Rep Per Day],
  (up - down) as [Passive Rep],
  up as [Passive Up Reputation],
  down as [Passive Down Reputation],
  datediff(day, vs.CreationDate, @latestDate) - @ignoreDays as [Days Counted]
from @VoteStats vs
order by [Passive Rep Per Day] desc


END
GO




CREATE OR ALTER   PROC [dbo].[usp_Report3] @SinceLastAccessDate DATETIME2 AS
BEGIN
SELECT r.DisplayName, r.UserId, r.CreationDate, r.LastAccessDate, u.AboutMe, r.Questions, r.Answers, r.Comments
  FROM dbo.Report_UsersByQuestions r
  INNER JOIN dbo.Users u ON r.UserId = u.Id AND r.DisplayName = u.DisplayName
  WHERE r.LastAccessDate > @SinceLastAccessDate
  ORDER BY r.LastAccessDate
END
GO





CREATE OR ALTER FUNCTION dbo.RelatedPosts ( @PostId INT )
RETURNS @Out TABLE ( PostId BIGINT )
AS
    BEGIN
        INSERT  INTO @Out(PostId)
		SELECT TOP 10 pRelative.Id
		  FROM dbo.PostLinks pl
		  INNER JOIN dbo.Posts pRelative ON pl.RelatedPostId = pRelative.Id
		  WHERE pl.LinkTypeId = 1 AND pRelative.PostTypeId = 1
		  ORDER BY pl.CreationDate DESC;
		 RETURN;
    END;
GO

CREATE OR ALTER VIEW dbo.PostsWithRelatives AS
SELECT p.Id AS OriginalPostId, pRelatives.*
	FROM dbo.Posts p
	CROSS APPLY dbo.RelatedPosts (p.Id) rp
	INNER JOIN dbo.Posts pRelatives ON rp.PostId = pRelatives.Id
GO


CREATE OR ALTER PROC usp_FindRelatedPosts @PostId INT AS
BEGIN
SELECT TOP 10 *,
	CommentCount = (SELECT COUNT(*) FROM dbo.Comments WHERE PostId = pwr.Id)
FROM dbo.PostsWithRelatives pwr
WHERE pwr.OriginalPostId = @PostId
ORDER BY pwr.LastActivityDate DESC;
END
GO


CREATE OR ALTER PROC dbo.usp_Q1080 @StartYear INT, @EndYear INT AS
BEGIN

/* Source: http://data.stackexchange.com/stackoverflow/query/1080/top-users-by-number-of-bounties-won  (but modified) */

SELECT Users.DisplayName, Users.Location, Users.Reputation, Users.WebsiteUrl, Posts.OwnerUserId As [User Link], COUNT(*) As BountiesWon, SUM(Votes.BountyAmount) AS BountyReputation
FROM Votes
  INNER JOIN Posts ON Votes.PostId = Posts.Id
  INNER JOIN Users ON Posts.OwnerUserId = Users.Id
WHERE
  VoteTypeId=9
  AND YEAR(Votes.CreationDate) BETWEEN @StartYear AND @EndYear
GROUP BY
  Posts.OwnerUserId, Users.DisplayName, Users.Location, Users.Reputation, Users.WebsiteUrl
ORDER BY
  BountiesWon DESC;
END
GO

CREATE OR ALTER PROC [dbo].[usp_QueryLab5_Setup] AS
BEGIN
	EXEC DropIndexes @SchemaName = 'dbo', @TableName = 'Users';
	EXEC DropIndexes @SchemaName = 'dbo', @TableName = 'Posts';
END
GO


CREATE OR ALTER PROC [dbo].[usp_QueryLab6] WITH RECOMPILE AS
BEGIN
/* Hi! You can ignore this stored procedure.
   This is used to run different random stored procs as part of your class.
   Don't change this in order to "tune" things.
*/
SET NOCOUNT ON

DECLARE @Id1 INT = CAST(RAND() * 10000000 AS INT) + 1;

IF @Id1 % 23 = 22
	EXEC usp_Q1080 2014, 2014
ELSE IF @Id1 % 23 = 21
	EXEC usp_Q1080 2018, 2018
ELSE IF @Id1 % 23 = 20
	EXEC usp_Q1080 2015, 2018
ELSE IF @Id1 % 23 = 19
	EXEC usp_Report3 '2014/01/01'
ELSE IF @Id1 % 23 = 18
	EXEC usp_Report3 '2017/01/01'
ELSE IF @Id1 % 23 = 17
	EXEC usp_Q7521 26837
ELSE IF @Id1 % 23 = 16
	EXEC usp_Q7521 22656
ELSE IF @Id1 % 23 = 15
	EXEC usp_MQT6925 @CreationDate = '2014/01/01', @Reputation = 1
ELSE IF @Id1 % 23 = 14
	EXEC usp_MQT6925 @CreationDate = '2018/01/01', @Reputation = 100
ELSE IF @Id1 % 23 = 13
	EXEC usp_MQT6925 @UserId = 499
ELSE IF @Id1 % 23 = 12
	EXEC usp_MQT6925 @UserId = 22656
ELSE IF @Id1 % 23 = 11
	EXEC usp_MQT6925 @UserId = 26837
ELSE IF @Id1 % 23 = 10
	EXEC usp_Q8116 22656;
ELSE IF @Id1 % 23 = 9
	EXEC usp_Q8116 26837;
ELSE IF @Id1 % 23 = 8
	EXEC usp_MQT6856 @MinReputation = 100, @Upvotes = 1;
ELSE IF @Id1 % 23 = 7
	EXEC usp_MQT6856 @MinReputation = 1, @Upvotes = 100;
ELSE IF @Id1 % 23 = 6
	EXEC usp_MQT6856 @MinReputation = 1, @Upvotes = 1;
ELSE IF @Id1 % 23 = 5
	EXEC usp_MQT6856 @MinReputation = 100, @Upvotes = 100;
ELSE IF @Id1 % 23 = 4
	EXEC dbo.usp_Q6772 26837;
ELSE IF @Id1 % 23 = 3
	EXEC dbo.usp_Q6627;
ELSE IF @Id1 % 23 = 2
	EXEC usp_FindRelatedPosts 28345582;
ELSE
	EXEC usp_FindRelatedPosts 26950274;

WHILE @@TRANCOUNT > 0
	BEGIN
	COMMIT
	END
END
GO

EXEC usp_QueryLab5_Setup