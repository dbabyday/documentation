/*
Mastering Query Tuning - Lab 2 Setup

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
EXEC sys.sp_configure N'cost threshold for parallelism', N'50';
GO
RECONFIGURE;
GO
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 140
GO



CREATE OR ALTER   PROC [dbo].[usp_RptUsersByQuestions] @DisplayName NVARCHAR(40)
AS
BEGIN
SELECT *
  FROM dbo.Report_UsersByQuestions
  WHERE DisplayName = @DisplayName
  ORDER BY Questions DESC;
END;
GO





CREATE OR ALTER   PROC [dbo].[usp_RptCommentsByUserDisplayName] @DisplayName NVARCHAR(40)
AS
SELECT c.CreationDate, c.Score, c.Text, p.Title, p.PostTypeId
FROM dbo.Users u
INNER JOIN dbo.Comments c ON u.Id = c.UserId
INNER JOIN dbo.Posts p ON c.PostId = p.Id
WHERE u.DisplayName = @DisplayName
ORDER BY c.CreationDate;
GO

CREATE OR ALTER PROC dbo.usp_UserActivityByHour @UserId INT AS
BEGIN
/* From: https://data.stackexchange.com/stackoverflow/query/17321/my-activity-by-utc-hour */
SELECT
 datepart(hour,CreationDate) AS hour,
 count(CASE WHEN PostTypeId = 1 THEN 1 END) AS questions,
 count(CASE WHEN PostTypeId = 2 THEN 1 END) AS answers
FROM dbo.Posts
WHERE
  PostTypeId IN (1,2) AND
  OwnerUserId=@UserId
GROUP BY datepart(hour,CreationDate)
ORDER BY hour
END
GO


CREATE OR ALTER   PROC [dbo].[usp_RptMostControversialPosts] AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/466/most-controversial-posts-on-the-site */
set nocount on 

declare @VoteStats table (PostId int, up int, down int) 

insert @VoteStats
select
    PostId, 
    up = sum(case when VoteTypeId = 2 then 1 else 0 end), 
    down = sum(case when VoteTypeId = 3 then 1 else 0 end)
from Votes
where VoteTypeId in (2,3)
group by PostId

set nocount off


select top 100 p.Id as [Post Link] , up, down from @VoteStats 
join Posts p on PostId = p.Id
where down > (up * 0.5) and p.CommunityOwnedDate is null and p.ClosedDate is null
order by up desc
END
GO


CREATE OR ALTER PROC dbo.usp_TopUsersByCountry @Country NVARCHAR(40) AS
BEGIN
-- Top Users by Country
-- Created by samliew (http://stackoverflow.com/users/584192/samuel-liew)
/* From: https://data.stackexchange.com/stackoverflow/query/53058/top-users-by-country */

SELECT
    ROW_NUMBER() OVER(ORDER BY Reputation DESC) AS [#], 
    Id AS [User Link], 
    Reputation
FROM
    Users
WHERE
    LOWER(Location) LIKE LOWER(@Country)
ORDER BY
    Reputation DESC;
END
GO




CREATE OR ALTER PROC dbo.usp_RptReputationGainFromOldPosts @UserId INT AS
BEGIN
-- Staying Power
-- Total passive reputation gained from old posts
-- Reputation gained in the first 15 days of post is ignored,
-- all reputation after that is considered passive reputation.
-- Post must be at least 60 Days old.
-- Mostly copied from http://data.stackexchange.com/stackoverflow/s/348/my-money-for-jam
/* From: https://data.stackexchange.com/stackoverflow/query/27741/staying-power */

set nocount on

declare @latestDate datetime
select @latestDate = max(CreationDate) from Posts
declare @ignoreDays numeric = 15
declare @minAgeDays numeric = @ignoreDays * 4

-- temp table moded from http://data.stackexchange.com/stackoverflow/s/87
declare @VoteStats table (PostId int, up int, down int, CreationDate datetime)
insert @VoteStats
select
    p.Id,
    up = sum(case when VoteTypeId = 2 then
        case when p.ParentId is null then 5 else 10 end
        else 0 end),
    down = sum(case when VoteTypeId = 3 then 2 else 0 end),
    p.CreationDate
from Votes v join posts p on v.postid = p.id
where v.VoteTypeId in (2,3)
and OwnerUserId = @UserId
and p.CommunityOwnedDate is null
and datediff(day, p.CreationDate, v.CreationDate) > @ignoreDays
and datediff(day, p.CreationDate, @latestDate) > @minAgeDays
group by p.Id, p.CreationDate, p.ParentId

set nocount off

select sum(convert(decimal(10,2), up - down)/(datediff(day, vs.CreationDate, @latestDate) - @ignoreDays)) as [Passive Rep Per Day],
  sum((up - down)) as [Passive Rep]
from @VoteStats vs
END
GO





CREATE OR ALTER PROC dbo.mqt_Lab2_Level1 AS
/* Gets the most-viewed questions written by the top-ranking users. */

SELECT TOP 500 u.DisplayName, u.Id AS UserId, p.Title, p.ViewCount AS PostViews
FROM dbo.Users u
INNER JOIN dbo.Posts p ON u.Id = p.OwnerUserId
WHERE (u.Reputation + u.Views) > 1000000 /* High ranking users */
  AND p.PostTypeId = 1 /* Questions */
ORDER BY p.ViewCount DESC;
GO

IF NOT EXISTS(SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Report_UsersByQuestions') AND name = 'IX_DisplayName')
	CREATE INDEX IX_DisplayName ON dbo.Report_UsersByQuestions(DisplayName);
GO




CREATE OR ALTER PROC [dbo].[usp_QueryLab2] WITH RECOMPILE AS
BEGIN
/* Hi! You can ignore this stored procedure.
   This is used to run different random stored procs as part of your class.
   Don't change this in order to "tune" things.
*/
SET NOCOUNT ON

DECLARE @Id1 INT = CAST(RAND() * 10000000 AS INT) + 1;

IF @Id1 % 12 = 0
	EXEC [usp_RptUsersByQuestions] @DisplayName = 'Brent Ozar'
ELSE IF @Id1 % 12 = 11
	EXEC [usp_RptUsersByQuestions] @DisplayName = 'Jon Skeet'
ELSE IF @Id1 % 12 = 10
	EXEC [usp_RptCommentsByUserDisplayName] @DisplayName = 'ZXR'
ELSE IF @Id1 % 12 = 9
	EXEC [usp_RptCommentsByUserDisplayName] @DisplayName = 'GmA'
ELSE IF @Id1 % 12 = 8
	EXEC [usp_RptCommentsByUserDisplayName] @DisplayName = 'Fred -ii-'
ELSE IF @Id1 % 12 = 7
	EXEC [usp_RptCommentsByUserDisplayName] @DisplayName = 'Lightness Races in Orbit'
ELSE IF @Id1 % 12 = 6
	EXEC usp_UserActivityByHour @UserId = 22656;
ELSE IF @Id1 % 12 = 5
	EXEC [usp_RptMostControversialPosts];
ELSE IF @Id1 % 12 = 4
	EXEC usp_TopUsersByCountry 'United States';
ELSE IF @Id1 % 12 = 3
	EXEC mqt_Lab2_Level1;
ELSE
	EXEC usp_RptReputationGainFromOldPosts @UserId = @Id1;

WHILE @@TRANCOUNT > 0
	BEGIN
	COMMIT
	END
END
GO


DBCC FREEPROCCACHE;
GO