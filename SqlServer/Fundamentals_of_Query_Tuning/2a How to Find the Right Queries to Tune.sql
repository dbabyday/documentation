/*
Fundamentals of Query Tuning: sp_BlitzCache Lab Setup

v1.0 - 2019-06-30

https://www.BrentOzar.com/go/queryfund


This demo requires:
* Any supported version of SQL Server
* Any Stack Overflow database: https://www.BrentOzar.com/go/querystack

Before running this setup script, restore the Stack Overflow database.

This script will take a couple of minutes to create indexes & stored procs.
*/
USE [StackOverflow2013]
GO
DropIndexes;
GO
/* Create a few indexes to support our queries: */
CREATE INDEX IX_Location ON dbo.Users(Location);
CREATE INDEX IX_UserId ON dbo.Comments(UserId);
CREATE INDEX IX_CreationDate ON dbo.Comments(CreationDate);
CREATE INDEX IX_VoteTypeId_PostId ON dbo.Votes(VoteTypeId, PostId);
GO



CREATE OR ALTER PROC dbo.usp_SearchComments
    @Location NVARCHAR(200),
    @StartDate DATETIME,
    @EndDate DATETIME AS
BEGIN
    SELECT u.DisplayName, u.Id AS UserId, c.Id AS CommentId, c.Score, c.Text
      FROM dbo.Users u
      INNER JOIN dbo.Comments c ON u.Id = c.UserId
      WHERE u.Location = @Location
        AND c.CreationDate BETWEEN @StartDate AND @EndDate
      ORDER BY c.Score DESC;
END
GO


CREATE OR ALTER PROC dbo.usp_rpt_PopularLocations AS
  SELECT TOP 100 Location, COUNT(*) AS UserCount
    FROM dbo.Users u
    GROUP BY Location
    ORDER BY COUNT(*) DESC;
GO



CREATE OR ALTER PROC dbo.usp_UsersInTop5Locations AS
BEGIN
WITH TopLocations AS (SELECT TOP 5 Location
  FROM dbo.Users
  WHERE Location <> ''
  GROUP BY Location
  ORDER BY COUNT(*) DESC)
SELECT u.*
  FROM TopLocations t
    INNER JOIN dbo.Users u ON t.Location = u.Location
  ORDER BY u.DisplayName;
END
GO


CREATE OR ALTER PROC dbo.usp_CommentBattles 
    @UserId1 INT,
    @UserId2 INT AS
BEGIN
WITH Battles AS (SELECT c1.PostId, c1.Score AS User1Score, c2.Score AS User2Score
                    FROM dbo.Comments c1
                    INNER JOIN dbo.Comments c2 ON c1.PostId = c2.PostId AND c1.Id <> c2.Id
                    WHERE c1.UserId = @UserId1
                      AND c2.UserId = @UserId2
)
SELECT User1Victories = COALESCE(SUM(CASE WHEN b.User1Score > b.User2Score THEN 1 ELSE 0 END),0),
       User2Victories = COALESCE(SUM(CASE WHEN b.User1Score < b.User2Score THEN 1 ELSE 0 END),0),
       Draws          = COALESCE(SUM(CASE WHEN b.User1Score = b.User2Score THEN 1 ELSE 0 END),0)
  FROM Battles b;
END
GO







CREATE OR ALTER PROC [dbo].[usp_rpt_ControversialPosts] AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/466/most-controversial-posts-on-the-site */
set nocount on 

declare @VoteStats table (PostId int, up int, down int);

insert @VoteStats
select
    PostId, 
    up = sum(case when VoteTypeId = 2 then 1 else 0 end), 
    down = sum(case when VoteTypeId = 3 then 1 else 0 end)
from Votes
where VoteTypeId in (2,3)
group by PostId;

select top 500 p.Id as [Post Link] , v.up, v.down 
from @VoteStats v
join Posts p on PostId = p.Id
where v.down > (v.up * 0.5) and p.CommunityOwnedDate is null and p.ClosedDate is null
order by v.up desc;
END
GO


CREATE OR ALTER PROC [dbo].[usp_UsersOutracingMe] @UserId INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/6925/newer-users-with-more-reputation-than-me */


SELECT u.Id as [User Link], u.Reputation, u.Reputation - me.Reputation as Difference
FROM dbo.Users me 
INNER JOIN dbo.Users u 
	ON u.CreationDate > me.CreationDate
	AND u.Reputation > me.Reputation
WHERE me.Id = @UserId

END
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