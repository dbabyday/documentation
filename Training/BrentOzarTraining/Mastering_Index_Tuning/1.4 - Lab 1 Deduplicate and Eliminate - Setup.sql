/*
Mastering Index Tuning - Lab 1
Last updated: 2023-11-28

This script is from our Mastering Index Tuning class.
To learn more: https://www.BrentOzar.com/go/tuninglabs

Before running this setup script, restore the Stack Overflow database.
As long as you've done the setup described in the prerequisites for
the class, this script should finish in 5-10 seconds.

If you're not sure if you've run it before, you can run it again.
It's idempotent: you can rerun it repeatedly and it produces the same
end results.




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

CREATE OR ALTER PROC dbo.usp_Q7521 @UserId INT AS
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


CREATE OR ALTER PROC dbo.usp_Q36660_V1 AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/36660/most-down-voted-questions */

select top 20 count(v.PostId) as 'Vote count', v.PostId AS [Post Link],p.Body
from Votes v 
inner join Posts p on p.Id=v.PostId
where PostTypeId = 1 and v.VoteTypeId=3
group by v.PostId,p.Body
order by 'Vote count' desc

END
GO


CREATE OR ALTER PROC dbo.usp_Q94949 @UserId INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/949/what-is-my-accepted-answer-percentage-rate */

SELECT 
    (CAST(Count(a.Id) AS float) / (SELECT Count(*) FROM Posts WHERE OwnerUserId = @UserId AND PostTypeId = 2) * 100) AS AcceptedPercentage
FROM
    Posts q
  INNER JOIN
    Posts a ON q.AcceptedAnswerId = a.Id
WHERE
    a.OwnerUserId = @UserId
  AND
    a.PostTypeId = 2

END
GO



CREATE OR ALTER PROC dbo.usp_Q466 AS
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




CREATE OR ALTER PROC dbo.usp_Q749947 @UserId INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/947/my-comment-score-distribution */

SELECT 
    Count(*) AS CommentCount,
    Score
FROM 
    Comments
WHERE 
    UserId = @UserId
GROUP BY 
    Score
ORDER BY 
    Score DESC
END
GO




CREATE OR ALTER PROC dbo.usp_Q3160 @UserId INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/3160/jon-skeet-comparison */

with fights as (
  select myAnswer.ParentId as Question,
   myAnswer.Score as MyScore,
   jonsAnswer.Score as JonsScore
  from Posts as myAnswer
  inner join Posts as jonsAnswer
   on jonsAnswer.OwnerUserId = 22656 and myAnswer.ParentId = jonsAnswer.ParentId
  where myAnswer.OwnerUserId = @UserId and myAnswer.PostTypeId = 2
)

select
  case
   when MyScore > JonsScore then 'You win'
   when MyScore < JonsScore then 'Jon wins'
   else 'Tie'
  end as 'Winner',
  Question as [Post Link],
  MyScore as 'My score',
  JonsScore as 'Jon''s score'
from fights;
END
GO




CREATE OR ALTER PROC dbo.usp_Q6627 AS
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






CREATE OR ALTER PROC dbo.usp_Q6772 @UserId INT AS
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









CREATE OR ALTER PROC dbo.usp_Q6856 @MinReputation INT, @Upvotes INT = 100 AS
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




CREATE OR ALTER PROC dbo.usp_Q952 AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/952/top-500-answerers-on-the-site */

SELECT 
    TOP 500
    Users.Id as [User Link],
    Count(Posts.Id) AS Answers,
    CAST(AVG(CAST(Score AS float)) as numeric(6,2)) AS [Average Answer Score]
FROM
    Posts
  INNER JOIN
    Users ON Users.Id = OwnerUserId
WHERE 
    PostTypeId = 2 and CommunityOwnedDate is null and ClosedDate is null
GROUP BY
    Users.Id, DisplayName
HAVING
    Count(Posts.Id) > 10
ORDER BY
    [Average Answer Score] DESC

END
GO


CREATE OR ALTER PROC usp_Q53058 @CountryName NVARCHAR(100) AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/53058/top-users-by-country */

-- Top Users by Country
-- Created by samliew (http://stackoverflow.com/users/584192/samuel-liew)

SELECT
    ROW_NUMBER() OVER(ORDER BY Reputation DESC) AS [#], 
    Id AS [User Link], 
    Reputation
FROM
    Users
WHERE
    LOWER(Location) LIKE LOWER('%' + @CountryName + '%')
ORDER BY
    Reputation DESC;

END
GO


CREATE OR ALTER PROC dbo.usp_Q89582 AS
BEGIN

DECLARE @padStr NVARCHAR(64)    = NCHAR (8199) + NCHAR (8199) + NCHAR (8199) + NCHAR (8199)
                                + NCHAR (8199) + NCHAR (8199) + NCHAR (8199) + NCHAR (8199)
                                + NCHAR (8199) + NCHAR (8199) + NCHAR (8199) + NCHAR (8199)

DECLARE @PrivilegeRequirements TABLE (
    Privilege           VARCHAR(128),
    Site                VARCHAR(128),
    [Min Reputation]    INT
)

INSERT INTO
    @PrivilegeRequirements (Privilege, Site, [Min Reputation])
VALUES
    ('Access to moderator tools',               '*All*',             10000),
    ('Approve or reject tag wiki edits',        '*All*',              5000),
    ('Ask and answer questions',                '*All*',                 1),
    ('Cast close and reopen votes',             '*All*',              3000),
    ('Comment everywhere',                      'Main Meta',             1),
    ('Comment everywhere',                      'Most sites',           50),
    ('Comment everywhere',                      'Most sites, meta',     50),
    ('Comment everywhere',                      'Stack Overflow',       50),
    ('Comment everywhere',                      'Super User',            1),
    ('Comment everywhere',                      'Super User, meta',      1),
    ('Create chat rooms',                       '*All*',               100),
    ('Create community-wiki posts',             '*All*',                10),
    ('Create gallery chat rooms',               '*All*',              1000),
    ('Create new tags',                         'Main Meta',           500),
    ('Create new tags',                         'Most sites',          300),
    ('Create new tags',                         'Most sites, meta',    300),
    ('Create new tags',                         'Stack Overflow',     1500),
    ('Create new tags',                         'Super User',          500),
    ('Create new tags',                         'Super User, meta',    500),
    ('Edit community wiki questions',           '*All*',               100),
    ('Edit questions and answers',              '*All*',              2000),
    ('Established User',                        '*All*',              1000),
    ('Flag posts',                              '*All*',                15),
    ('Participate in per-site meta',            '*All*',                 5),
    ('Perform trusted functions on the site',   '*All*',             20000),
    ('Protect questions',                       '*All*',             15000),
    ('Reduced advertising',                     'Most sites',          200),
    ('Remove new user restrictions',            '*All*',                10),
    ('Retag questions',                         '*All*',               500),
    ('Set a bounty on a question',              '*All*',                75),
    ('Suggest and vote on tag synonyms',        '*All*',              2500),
    ('Talk in chat',                            '*All*',                20),
    ('View close votes',                        '*All*',               250),
    ('Vote down questions and answers',         '*All*',               125),
    ('Vote up questions and answers',           '*All*',                15),
    ('Total Users in the data dump for this site','==>',                -1)

SELECT
            pr.Privilege,
            pr.Site,
            pr.[Min Reputation],
            -- Make it look "purty"
            RIGHT (
                @padStr +
                REPLACE (
                    CONVERT (nvarchar(64), (CAST (COUNT (u.Id) AS MONEY) ), 1),
                    N'.00',
                    N''
                )
                , 13
            )
            AS [Number of Users]

FROM        @PrivilegeRequirements pr
LEFT JOIN   Users u
ON          u.Reputation >= pr.[Min Reputation]
GROUP BY
            pr.Privilege,
            pr.Site,
            pr.[Min Reputation]
ORDER BY
            pr.[Min Reputation],
            pr.Privilege,
            pr.Site;
END
GO

CREATE OR ALTER PROC dbo.usp_Q154445 AS
BEGIN
select top 100
     Id [User Link]
     , datediff(dd, CreationDate, GETDATE() ) "Days"
     , DownVotes  
     , round(cast(nullif(DownVotes, 0)as float) / datediff(dd, CreationDate, GETDATE()),4)  [DownVotes/Day Ratio]
from Users
where  Id <> -1 and DownVotes > 100
order by 4 desc
END
GO

CREATE OR ALTER PROC dbo.usp_Q131879 @UserId INT AS
BEGIN

-- Members by Age and Reputation
-- StackOverflow members from youngest to oldest, by reputation over 1000.

DECLARE @Reputation int

SET @Reputation = (SELECT [Reputation] FROM Users WHERE Id = @UserId)

SELECT Id, DisplayName, Age, Reputation, CreationDate, LastAccessDate,
'http://stackoverflow.com/users/' + CAST(Id AS VARCHAR) AS Url
FROM Users b
WHERE (
b.Age <= 18
AND b.Reputation >= @Reputation
AND b.Id <> 1060350 
AND b.Id <> 569662 
AND b.Id <> 282601
AND b.Id <> 996493) OR b.Id = @UserId
ORDER BY b.Reputation DESC, b.Age;
END
GO


CREATE OR ALTER PROC dbo.usp_Q579975 AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/975/users-with-more-than-one-duplicate-account-and-a-more-than-1000-reputation-in-agg */

-- Users with more than one duplicate account and a more that 1000 reputation in aggregate
-- A list of users that have duplicate accounts on site, based on the EmailHash and lots of reputation is riding on it

SELECT 
    u1.EmailHash,
    Count(u1.Id) AS Accounts,
    (
        SELECT Cast(u2.Id AS varchar) + ' (' + u2.DisplayName + ' ' + Cast(u2.Reputation as varchar) + '), ' 
        FROM Users u2 
        WHERE u2.EmailHash = u1.EmailHash order by u2.Reputation desc FOR XML PATH ('')) AS IdsAndNames
FROM
    Users u1
WHERE
    u1.EmailHash IS NOT NULL
    and (select sum(u3.Reputation) from Users u3 where u3.EmailHash = u1.EmailHash) > 1000  
    and (select count(*) from Users u3 where u3.EmailHash = u1.EmailHash and Reputation > 10) > 1
GROUP BY
    u1.EmailHash
HAVING
    Count(u1.Id) > 1
ORDER BY 
    Accounts DESC

END
GO

CREATE OR ALTER PROC dbo.usp_Q300735 @AsOfDate DATE AS
BEGIN

SELECT TOP 300
  row_number() over(order by count(*) desc) as rank, 
  Badges.UserId AS [User Link],
  count(*) AS 'Badge Count',
  Users.Reputation AS 'Total user reputation',
  Users.Reputation / count(*) AS 'Ratio'
FROM
  Badges
INNER JOIN
  Users
ON
  Users.Id = Badges.UserId AND
  Badges.Name = 'Necromancer' AND
  Badges.Date < @AsOfDate
GROUP BY
  Badges.UserId, Users.Reputation
ORDER BY
  'Badge Count' DESC,
  Users.Reputation DESC;
END
GO


CREATE OR ALTER PROC dbo.usp_Q37297 AS
BEGIN
-- Top 50 most stingy power users
-- Computes the ratio of total reputation to up vote rep, to reveal the users who have gained more reputation than they have distributed to the community.
-- 
-- Users must have more than 1000 rep. Does not consider down votes, ignores the fact that questions only receive 5 rep points, ignores accepted answer rep and bounties, and ignores users who have not up-voted at all.

select top 50
  Id as [User Link],
  Reputation,
  UpVotes as "Up votes",
  cast(Reputation as numeric) / (10.0 * UpVotes) as Ratio,
  cast(Reputation as numeric) - (10.0 * UpVotes) as Difference
from
  Users
where
  UpVotes > 0
  and
  Reputation > 1000
order by
  Ratio desc
END
GO


CREATE OR ALTER PROC dbo.usp_Q8116 @UserId INT AS
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



CREATE OR ALTER PROC dbo.usp_CommentInsert_V1
	@PostId INT, @UserId INT, @Text NVARCHAR(700) AS
BEGIN
SET NOCOUNT ON
BEGIN TRAN
INSERT INTO dbo.Comments(CreationDate, PostId, Score, Text, UserId)
  VALUES (GETDATE(), @PostId, 0, @Text, @UserId)

/* Give them a reputation point for leaving a comment */
UPDATE dbo.Users 
  SET Reputation = Reputation + 1
  WHERE Id = @UserId;

/* Update the comment count on the post */
UPDATE dbo.Posts
  SET LastActivityDate = GETDATE()
  WHERE Id = @PostId;

/* If the user has added ten comments today on someone else's posts, and they haven't earned Loud Talker yet today, give them a badge */
IF 10 <= (SELECT COUNT(DISTINCT c.Id) 
			FROM dbo.Comments c
			  INNER JOIN dbo.Posts p ON c.PostId = p.Id AND p.OwnerUserId <> @UserId
			WHERE c.UserId = @UserId AND c.CreationDate >= DATEADD(DD, -24, GETDATE()))
  AND NOT EXISTS(SELECT * FROM dbo.Badges WHERE UserId = @UserId AND Name = 'Loud Talker' AND Date >= DATEADD(DD, -24, GETDATE()))
	BEGIN
	INSERT INTO dbo.Badges(Name, UserId, Date)
	  VALUES ('Loud Talker', @UserId, GETDATE());
	END
COMMIT
END
GO



CREATE OR ALTER PROC dbo.usp_PostViewed
	@PostId INT, @UserId INT AS
BEGIN
SET NOCOUNT ON
BEGIN TRAN

/* If the user hasn't accessed the site in a month, give them a point for coming back.
   This has to be done before we update the user's last access date. */
UPDATE dbo.Users 
  SET Reputation = Reputation + 1
  WHERE Id = @UserId
    AND LastAccessDate <= DATEADD(DD, -30, GETDATE());

UPDATE dbo.Posts
  SET ViewCount = ViewCount + 1
  WHERE Id = @PostId;

UPDATE dbo.Users
  SET Views = Views + 1, LastAccessDate = GETDATE()
  WHERE Id = @UserId;

COMMIT
END
GO




CREATE OR ALTER PROC dbo.usp_VoteInsert_V1
	@PostId INT, @UserId INT, @BountyAmount INT, @VoteTypeId INT AS
BEGIN
SET NOCOUNT ON
BEGIN TRAN


/* Make sure this vote hasn't already been cast */
IF NOT EXISTS(SELECT * FROM dbo.Votes WHERE PostId = @PostId AND UserId = @UserId AND VoteTypeId = @VoteTypeId)
	BEGIN

		/* Make sure the inputs are valid */
		IF NOT EXISTS (SELECT * FROM dbo.VoteTypes WHERE Id = @VoteTypeId)
			BEGIN
				RAISERROR('That VoteTypeId is not valid.', 0, 1) WITH NOWAIT;
				RETURN;
			END

		IF NOT EXISTS (SELECT * FROM dbo.Posts WHERE Id = @PostId)
			BEGIN
				RAISERROR('That PostId is not valid.', 0, 1) WITH NOWAIT;
				RETURN;
			END

		IF NOT EXISTS (SELECT * FROM dbo.Users WHERE Id = @UserId)
			BEGIN
				RAISERROR('That UserId is not valid.', 0, 1) WITH NOWAIT;
				RETURN;
			END

		INSERT INTO dbo.Votes (PostId, UserId, BountyAmount, VoteTypeId, CreationDate)
		  VALUES (@PostId, @UserId, @BountyAmount, @VoteTypeId, GETDATE());

		/* UpVotes */
		IF @VoteTypeId = 2
		BEGIN
			UPDATE dbo.Users
			  SET UpVotes = UpVotes + 1
			  WHERE Id = @UserId;
			UPDATE dbo.Posts 
			  SET Score = Score + 1, LastActivityDate = GETDATE()
			  WHERE Id = @PostId;
		END

		/* UpVotes */
		IF @VoteTypeId = 3
		BEGIN
			UPDATE dbo.Users
				SET DownVotes = DownVotes + 1
				WHERE Id = @UserId;
			UPDATE dbo.Posts 
			  SET Score = Score - 1, LastActivityDate = GETDATE()
			  WHERE Id = @PostId;
		END

		/* Favorites */
		IF @VoteTypeId = 5
		BEGIN
			UPDATE dbo.Posts
			  SET FavoriteCount = FavoriteCount + 1, LastActivityDate = GETDATE()
			  WHERE Id = @PostId;
		END

		/* Close */
		IF @VoteTypeId = 6
		BEGIN
			UPDATE dbo.Posts
			  SET ClosedDate = GETDATE(), LastActivityDate = GETDATE()
			  WHERE Id = @PostId;
		END
	END

END
COMMIT

GO


CREATE OR ALTER PROC dbo.usp_SearchUsers_CustomerService
	@SearchDisplayName NVARCHAR(100) = NULL,
	@SearchDownVotes INT = NULL,
	@SearchLastAccessDateStart DATETIME = NULL,
	@SearchLastAccessDateEnd DATETIME = NULL,
	@SearchLocation NVARCHAR(100) = NULL,
	@SearchReputation INT = NULL,
	@SearchUpVotes INT = NULL,
	@SearchWebsiteUrl NVARCHAR(200) = NULL,
	@OrderBy NVARCHAR(100) = 'CreationDate',
	@Debug_PrintQuery TINYINT = 0,
    @Debug_ExecuteQuery TINYINT = 1 AS
BEGIN
	DECLARE @StringToExecute NVARCHAR(4000), @Select NVARCHAR(4000), 
            @From NVARCHAR(4000), @Where NVARCHAR(4000), @Order NVARCHAR(4000);
 
	DECLARE @crlf NVARCHAR(2) = NCHAR(13) + NCHAR(10);
	SET @Select = @crlf + N'/* usp_SearchUsers_CustomerService */' + @crlf + N' select U.Id, U.DisplayName, U.Location ' + @crlf;
	SET @From = N' from dbo.Users U ' + @crlf;
	SET @Where = N' where 1 = 1 ' + @crlf;
 
	IF @SearchDisplayName IS NOT NULL
		SET @Where = @Where + N' and DisplayName like @searchdisplayname ' + @crlf;
 
	IF @SearchDownVotes IS NOT NULL
		SET @Where = @Where + N' and DownVotes = @searchdownvotes ' + @crlf;
 
	IF @SearchLastAccessDateStart IS NOT NULL
		SET @Where = @Where + N' and LastAccessDate >= @searchlastaccessdatestart ' + @crlf;
 
	IF @SearchLastAccessDateEnd IS NOT NULL
		SET @Where = @Where + N' and LastAccessDate <= @searchlastaccessdateend ' + @crlf;
 
	IF @SearchLocation IS NOT NULL
		SET @Where = @Where + N' and Location like @searchlocation ' + @crlf;
 
	IF @SearchReputation IS NOT NULL
		SET @Where = @Where + N' and Reputation = @searchreputation ' + @crlf;
 
	IF @SearchUpVotes IS NOT NULL
		SET @Where = @Where + N' and UpVotes = @searchupvotes ' + @crlf;
 
	IF @SearchWebsiteUrl IS NOT NULL
		SET @Where = @Where + N' and WebsiteUrl like @searchwebsiteurl ' + @crlf;
 
    IF @OrderBy IS NOT NULL
        BEGIN
        SET @Order = N' order by ';
 
        SET @Order = @Order + 
            CASE WHEN @OrderBy LIKE 'CreationDate%' THEN N' U.CreationDate '
                 WHEN @OrderBy LIKE 'DisplayName%' THEN N' U.DisplayName '
                 WHEN @OrderBy LIKE 'LastAccessDate%' THEN N' U.LastAccessDate '
                 WHEN @OrderBy LIKE 'Location%' THEN N' U.Location '
                 WHEN @OrderBy LIKE 'Reputation%' THEN N' U.Reputation '
                 WHEN @OrderBy LIKE 'WebsiteUrl%' THEN N' U.WebsiteUrl '
                 ELSE N' U.Id '   /* Or whatever default ordering you want, ideally to make SQL's life easier */
            END;
 
        IF @OrderBy LIKE '% DESC' /* You could also do this with a separate @OrderByDesc bit parameter if you want */
            SET @Order = @Order + N' desc ';
        END;
 
    SET @StringToExecute = @Select + @From + @Where + @Order;
 
    IF @Debug_PrintQuery = 1
        PRINT @StringToExecute;
 
    IF @Debug_ExecuteQuery = 1
	    EXEC sp_executesql @StringToExecute, 
		    N'@searchdisplayname nvarchar(100), @searchdownvotes int, @searchlastaccessdatestart datetime, @searchlastaccessdateend datetime, @searchlocation nvarchar(100), @searchreputation int, @searchupvotes int, @searchwebsiteurl nvarchar(200)', 
		    @SearchDisplayName, @SearchDownVotes, @SearchLastAccessDateStart, @SearchLastAccessDateEnd, @SearchLocation, @SearchReputation, @SearchUpVotes, @SearchWebsiteUrl;
END
GO



CREATE OR ALTER PROC dbo.usp_IndexLab1_Setup AS
BEGIN
EXEC DropIndexes @TableName = 'Badges',
	@ExceptIndexNames = '_dta_index_Badges_5_2105058535__K3_K2_K4,IX_Id,IX_UserId';
EXEC DropIndexes @TableName = 'Comments',
	@ExceptIndexNames = '_dta_index_Comments_5_2137058649__K6_K2_K3,IX_Id,IX_PostId,IX_UserId';
EXEC DropIndexes @TableName = 'PostLinks',
	@ExceptIndexNames = 'IX_LinkTypeId,IX_PostId,IX_RelatedPostId';
EXEC DropIndexes @TableName = 'Posts',
	@ExceptIndexNames = '_dta_index_Posts_5_85575343__K14_K16_K1_K2,_dta_index_Posts_5_85575343__K14_K16_K7_K1_K2_17,_dta_index_Posts_5_85575343__K16_K7_K5_K14_17,_dta_index_Posts_5_85575343__K2,_dta_index_Posts_5_85575343__K2_K14,_dta_index_Posts_5_85575343__K8,IX_AcceptedAnswerId,IX_LastActivityDate_Includes,IX_LastEditorUserId,IX_OwnerUserId,IX_ParentId,IX_PostTypeId,IX_ViewCount_Includes';
EXEC DropIndexes @TableName = 'PostTypes',
	@ExceptIndexNames = 'IX_Type,IX1,IX2,IX3,IX4';
EXEC DropIndexes @TableName = 'Users',
	@ExceptIndexNames = '_dta_index_Users_5_149575571__K7_K10_K1_5,IX_LastAccessDate,IX_LastAccessDate_DisplayName_Reputation,IX_Reputation_Includes,IX_Views_Includes';
EXEC DropIndexes @TableName = 'Votes',
	@ExceptIndexNames = '_dta_index_Votes_5_181575685__K3_K2_K5,IX_PostId_UserId,IX_UserId,IX_VoteTypeId';

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Badges]') AND name = N'_dta_index_Badges_5_2105058535__K3_K2_K4')
CREATE NONCLUSTERED INDEX [_dta_index_Badges_5_2105058535__K3_K2_K4] ON [dbo].[Badges]
(
	[UserId] ASC,
	[Name] ASC,
	[Date] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Badges]') AND name = N'IX_Id')
CREATE NONCLUSTERED INDEX [IX_Id] ON [dbo].[Badges]
(
	[Id] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Badges]') AND name = N'IX_UserId')
CREATE NONCLUSTERED INDEX [IX_UserId] ON [dbo].[Badges]
(
	[UserId] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Comments]') AND name = N'_dta_index_Comments_5_2137058649__K6_K2_K3')
CREATE NONCLUSTERED INDEX [_dta_index_Comments_5_2137058649__K6_K2_K3] ON [dbo].[Comments]
(
	[UserId] ASC,
	[CreationDate] ASC,
	[PostId] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Comments]') AND name = N'IX_Id')
CREATE NONCLUSTERED INDEX [IX_Id] ON [dbo].[Comments]
(
	[Id] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Comments]') AND name = N'IX_PostId')
CREATE NONCLUSTERED INDEX [IX_PostId] ON [dbo].[Comments]
(
	[PostId] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Comments]') AND name = N'IX_UserId')
CREATE NONCLUSTERED INDEX [IX_UserId] ON [dbo].[Comments]
(
	[UserId] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[PostLinks]') AND name = N'IX_LinkTypeId')
CREATE NONCLUSTERED INDEX [IX_LinkTypeId] ON [dbo].[PostLinks]
(
	[LinkTypeId] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[PostLinks]') AND name = N'IX_PostId')
CREATE NONCLUSTERED INDEX [IX_PostId] ON [dbo].[PostLinks]
(
	[PostId] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[PostLinks]') AND name = N'IX_RelatedPostId')
CREATE NONCLUSTERED INDEX [IX_RelatedPostId] ON [dbo].[PostLinks]
(
	[RelatedPostId] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Posts]') AND name = N'_dta_index_Posts_5_85575343__K14_K16_K1_K2')
CREATE NONCLUSTERED INDEX [_dta_index_Posts_5_85575343__K14_K16_K1_K2] ON [dbo].[Posts]
(
	[OwnerUserId] ASC,
	[PostTypeId] ASC,
	[Id] ASC,
	[AcceptedAnswerId] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Posts]') AND name = N'_dta_index_Posts_5_85575343__K14_K16_K7_K1_K2_17')
CREATE NONCLUSTERED INDEX [_dta_index_Posts_5_85575343__K14_K16_K7_K1_K2_17] ON [dbo].[Posts]
(
	[OwnerUserId] ASC,
	[PostTypeId] ASC,
	[CommunityOwnedDate] ASC,
	[Id] ASC,
	[AcceptedAnswerId] ASC
)
INCLUDE ( 	[Score]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Posts]') AND name = N'_dta_index_Posts_5_85575343__K16_K7_K5_K14_17')
CREATE NONCLUSTERED INDEX [_dta_index_Posts_5_85575343__K16_K7_K5_K14_17] ON [dbo].[Posts]
(
	[PostTypeId] ASC,
	[CommunityOwnedDate] ASC,
	[ClosedDate] ASC,
	[OwnerUserId] ASC
)
INCLUDE ( 	[Score]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Posts]') AND name = N'_dta_index_Posts_5_85575343__K2')
CREATE NONCLUSTERED INDEX [_dta_index_Posts_5_85575343__K2] ON [dbo].[Posts]
(
	[AcceptedAnswerId] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Posts]') AND name = N'_dta_index_Posts_5_85575343__K2_K14')
CREATE NONCLUSTERED INDEX [_dta_index_Posts_5_85575343__K2_K14] ON [dbo].[Posts]
(
	[AcceptedAnswerId] ASC,
	[OwnerUserId] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Posts]') AND name = N'_dta_index_Posts_5_85575343__K8')
CREATE NONCLUSTERED INDEX [_dta_index_Posts_5_85575343__K8] ON [dbo].[Posts]
(
	[CreationDate] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Posts]') AND name = N'IX_AcceptedAnswerId')
CREATE NONCLUSTERED INDEX [IX_AcceptedAnswerId] ON [dbo].[Posts]
(
	[AcceptedAnswerId] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Posts]') AND name = N'IX_LastActivityDate_Includes')
CREATE NONCLUSTERED INDEX [IX_LastActivityDate_Includes] ON [dbo].[Posts]
(
	[LastActivityDate] ASC
)
INCLUDE ( 	[ViewCount]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Posts]') AND name = N'IX_LastEditorUserId')
CREATE NONCLUSTERED INDEX [IX_LastEditorUserId] ON [dbo].[Posts]
(
	[LastEditorUserId] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Posts]') AND name = N'IX_OwnerUserId')
CREATE NONCLUSTERED INDEX [IX_OwnerUserId] ON [dbo].[Posts]
(
	[OwnerUserId] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Posts]') AND name = N'IX_ParentId')
CREATE NONCLUSTERED INDEX [IX_ParentId] ON [dbo].[Posts]
(
	[ParentId] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Posts]') AND name = N'IX_PostTypeId')
CREATE NONCLUSTERED INDEX [IX_PostTypeId] ON [dbo].[Posts]
(
	[PostTypeId] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Posts]') AND name = N'IX_ViewCount_Includes')
CREATE NONCLUSTERED INDEX [IX_ViewCount_Includes] ON [dbo].[Posts]
(
	[ViewCount] ASC
)
INCLUDE ( 	[LastActivityDate]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[PostTypes]') AND name = N'IX_Type')
CREATE NONCLUSTERED INDEX [IX_Type] ON [dbo].[PostTypes]
(
	[Type] ASC,
	[Id] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[PostTypes]') AND name = N'IX1')
CREATE NONCLUSTERED INDEX [IX1] ON [dbo].[PostTypes]
(
	[Type] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[PostTypes]') AND name = N'IX2')
CREATE NONCLUSTERED INDEX [IX2] ON [dbo].[PostTypes]
(
	[Id] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[PostTypes]') AND name = N'IX3')
CREATE NONCLUSTERED INDEX [IX3] ON [dbo].[PostTypes]
(
	[Type] ASC,
	[Id] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[PostTypes]') AND name = N'IX4')
CREATE NONCLUSTERED INDEX [IX4] ON [dbo].[PostTypes]
(
	[Id] ASC,
	[Type] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Users]') AND name = N'_dta_index_Users_5_149575571__K7_K10_K1_5')
CREATE NONCLUSTERED INDEX [_dta_index_Users_5_149575571__K7_K10_K1_5] ON [dbo].[Users]
(
	[EmailHash] ASC,
	[Reputation] ASC,
	[Id] ASC
)
INCLUDE ( 	[DisplayName]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Users]') AND name = N'Name of Missing Index, sysname,')
CREATE NONCLUSTERED INDEX [Name of Missing Index, sysname,] ON [dbo].[Users]
(
	[Reputation] ASC
)

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Users]') AND name = N'IX_LastAccessDate')
CREATE NONCLUSTERED INDEX [IX_LastAccessDate] ON [dbo].[Users]
(
	[LastAccessDate] ASC
);

SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Users]') AND name = N'IX_LastAccessDate_DisplayName_Reputation')
CREATE NONCLUSTERED INDEX [IX_LastAccessDate_DisplayName_Reputation] ON [dbo].[Users]
(
	[LastAccessDate] ASC,
	[DisplayName] ASC,
	[Reputation] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Users]') AND name = N'IX_Reputation_Includes')
CREATE NONCLUSTERED INDEX [IX_Reputation_Includes] ON [dbo].[Users]
(
	[Reputation] ASC
)
INCLUDE ( 	[Views]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Users]') AND name = N'IX_Views_Includes')
CREATE NONCLUSTERED INDEX [IX_Views_Includes] ON [dbo].[Users]
(
	[Views] ASC
)
INCLUDE ( 	[Reputation]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Votes]') AND name = N'_dta_index_Votes_5_181575685__K3_K2_K5')
CREATE NONCLUSTERED INDEX [_dta_index_Votes_5_181575685__K3_K2_K5] ON [dbo].[Votes]
(
	[UserId] ASC,
	[PostId] ASC,
	[VoteTypeId] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Votes]') AND name = N'IX_PostId_UserId')
CREATE NONCLUSTERED INDEX [IX_PostId_UserId] ON [dbo].[Votes]
(
	[PostId] ASC,
	[UserId] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Votes]') AND name = N'IX_UserId')
CREATE NONCLUSTERED INDEX [IX_UserId] ON [dbo].[Votes]
(
	[UserId] ASC
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Votes]') AND name = N'IX_VoteTypeId')
CREATE NONCLUSTERED INDEX [IX_VoteTypeId] ON [dbo].[Votes]
(
	[VoteTypeId] ASC
);
END
GO



CREATE OR ALTER PROC dbo.usp_IndexLab1 WITH RECOMPILE AS
BEGIN
/* Hi! You can ignore this stored procedure.
   This is used to run different random stored procs as part of your class.
   Don't change this in order to "tune" things.
*/
SET NOCOUNT ON

DECLARE @Id1 INT = CAST(RAND() * 10000000 AS INT) + 1;
DECLARE @Id2 INT = CAST(RAND() * 10000000 AS INT) + 1;
DECLARE @Id3 INT = CAST(RAND() * 10000000 AS INT) + 1;

IF @Id1 % 42 = 41
    EXEC dbo.usp_SearchUsers_CustomerService @SearchDisplayName = 'Brent Ozar', @SearchUpVotes = 0;
ELSE IF @Id1 % 42 = 40
    EXEC dbo.usp_SearchUsers_CustomerService @SearchDisplayName = 'Brent Ozar', @SearchUpVotes = 0, @OrderBy = 'LastAccessDate';
ELSE IF @Id1 % 42 = 39
    EXEC dbo.usp_SearchUsers_CustomerService @SearchDisplayName = 'Brent Ozar', @SearchDownVotes = 0;
ELSE IF @Id1 % 42 = 38
    EXEC dbo.usp_SearchUsers_CustomerService @SearchDisplayName = 'Brent Ozar', @SearchDownVotes = 0, @OrderBy = 'LastAccessDate';
ELSE IF @Id1 % 42 = 37
    EXEC dbo.usp_SearchUsers_CustomerService @SearchLocation = 'San Diego, CA', @SearchUpVotes = 0;
ELSE IF @Id1 % 42 = 36
    EXEC dbo.usp_SearchUsers_CustomerService @SearchLocation = 'San Diego, CA', @SearchUpVotes = 0, @OrderBy = 'LastAccessDate';
ELSE IF @Id1 % 42 = 35
    EXEC dbo.usp_SearchUsers_CustomerService @SearchReputation = 1, @SearchDownVotes = -1;
ELSE IF @Id1 % 42 = 34
    EXEC dbo.usp_SearchUsers_CustomerService @SearchReputation = 1, @SearchDownVotes = -1, @OrderBy = 'LastAccessDate';
ELSE IF @Id1 % 42 = 33
    EXEC dbo.usp_SearchUsers_CustomerService @SearchWebsiteUrl = 'https://www.brentozar.com', @SearchLastAccessDateStart = '2008/01/01', @OrderBy = 'LastAccessDate';
ELSE IF @Id1 % 42 = 32
    EXEC dbo.usp_SearchUsers_CustomerService @SearchWebsiteUrl = 'https://www.brentozar.com', @SearchLastAccessDateStart = '2008/01/01', @SearchLastAccessDateEnd = '2009/01/01', @OrderBy = 'Reputation';
ELSE IF @Id1 % 42 = 31
    EXEC usp_Q131879 @UserId = 26837;
ELSE IF @Id1 % 42 = 30
    EXEC usp_Q131879 @UserId = @Id1;
ELSE IF @Id1 % 42 = 29
    EXEC usp_Q89582;
ELSE IF @Id1 % 42 = 28
    EXEC usp_Q300735 '2015/11/10'
ELSE IF @Id1 % 42 = 27
    EXEC usp_Q300735 '2009/11/10'
ELSE IF @Id1 % 42 = 26
    EXEC usp_Q154445
ELSE IF @Id1 % 42 = 25
    EXEC usp_Q37297;
ELSE IF @Id1 % 42 = 24
    EXEC usp_Q53058 'United'
ELSE IF @Id1 % 42 = 23
    EXEC usp_Q53058 'Icecream'
ELSE IF @Id1 % 42 = 22
    EXEC usp_Q53058 'With the monster under your bed'
ELSE IF @Id1 % 42 = 21
    EXEC usp_Q53058 'Your Imagination'
ELSE IF @Id1 % 42 = 20
    EXEC dbo.usp_Q3160 @Id1
ELSE IF @Id1 % 42 = 19
    EXEC dbo.usp_Q36660_V1
ELSE IF @Id1 % 42 = 18
    EXEC dbo.usp_Q6772 @Id1
ELSE IF @Id1 % 42 = 17
    EXEC dbo.usp_Q6856 @Id1
ELSE IF @Id1 % 42 = 16
    EXEC dbo.usp_Q7521 @Id1
ELSE IF @Id1 % 42 = 15
    EXEC dbo.usp_Q8116 @Id1
ELSE IF @Id1 % 42 = 14
    EXEC dbo.usp_Q749947 @Id1
ELSE IF @Id1 % 42 = 13
    EXEC dbo.usp_Q94949 @Id1
ELSE IF @Id1 % 42 = 12
    EXEC dbo.usp_Q952
ELSE IF @Id1 % 42 = 11
    EXEC dbo.usp_Q579975
ELSE IF @Id1 % 42 = 10
    EXEC dbo.usp_CommentInsert_V1 @PostId = @Id1, @UserId = @Id2, @Text = 'Nice post!';
ELSE IF @Id1 % 42 = 9
    EXEC dbo.usp_PostViewed @PostId = @Id1, @UserId = @Id2;
ELSE IF @Id1 % 42 = 8
    EXEC dbo.usp_VoteInsert_V1 @PostId = @Id1, @UserId = @Id2, @BountyAmount = @Id3, @VoteTypeId = 3;
ELSE IF @Id1 % 42 = 7
    EXEC dbo.usp_CommentInsert_V1 @PostId = @Id1, @UserId = @Id2, @Text = 'Nice post!';
ELSE IF @Id1 % 42 = 6
    EXEC dbo.usp_VoteInsert_V1 @PostId = @Id1, @UserId = @Id2, @BountyAmount = @Id3, @VoteTypeId = 6;
ELSE IF @Id1 % 42 = 5
    EXEC dbo.usp_VoteInsert_V1 @PostId = @Id1, @UserId = @Id2, @BountyAmount = @Id3, @VoteTypeId = 7;
ELSE IF @Id1 % 42 = 4
    EXEC dbo.usp_VoteInsert_V1 @PostId = @Id1, @UserId = @Id2, @BountyAmount = @Id3, @VoteTypeId = 2;
ELSE
    EXEC dbo.usp_VoteInsert_V1 @PostId = @Id1, @UserId = @Id2, @BountyAmount = @Id3, @VoteTypeId = 5;

WHILE @@TRANCOUNT > 0
    BEGIN
    COMMIT
    END
END
GO

EXEC usp_IndexLab1_Setup;