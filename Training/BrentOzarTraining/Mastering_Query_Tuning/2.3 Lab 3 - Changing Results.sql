/*
Mastering Query Tuning - Lab 3 Setup

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

CREATE OR ALTER FUNCTION [dbo].[UpVotes] ( @PostId INT )
RETURNS BIT
    WITH RETURNS NULL ON NULL INPUT
AS
    BEGIN
        DECLARE @VoteCount INT;
		SELECT @VoteCount = SUM(1)
		  FROM dbo.Votes v
		  WHERE v.VoteTypeId=3
		    AND PostId = @PostId
        RETURN @VoteCount;
    END;
GO


CREATE OR ALTER   PROC [dbo].[usp_MQT36660] AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/36660/most-down-voted-questions */

select top 20 dbo.UpVotes(p.Id) as 'Vote count', p.Id AS [Post Link],p.Body
from Posts p
where p.PostTypeId = 1
order by dbo.UpVotes(p.Id) desc

END
GO


CREATE OR ALTER   PROC [dbo].[usp_MQT36660_Clue] AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/36660/most-down-voted-questions */

select top 20 dbo.UpVotes(p.Id) as 'Vote count', p.Id AS [Post Link],p.Body
from Posts p
where p.PostTypeId = 1
order by dbo.UpVotes(p.Id) desc /* CLUE #1: Ordering by a function is bad. */


/* MORE CLUES:

When you order by a user-defined function, SQL Server has to run that function
against every row in the result set in order to find the top 20. We have a lot
of Posts rows here, so the function would take a long time.

If you're on SQL Server 2019, you can also try putting the database into compat
level 150 (2019) to see if SQL Server will inline the function, but remember
that this will clear your plan cache, so if you're relying on sp_BlitzCache
results to prioritize queries, you may want to make sure you keep that results
window from sp_BlitzCache up and not close it accidentally:

ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 150
GO

And to put it back when you're done testing:

ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 140
GO
*/
END
GO





CREATE OR ALTER PROC dbo.usp_ActivityByLocation
	@LocationList NVARCHAR(MAX) AS
BEGIN

SELECT u.DisplayName, u.Id AS UserId, pt.Type AS PostType, p.Id AS PostId,
	p.Title, p.Tags, p.Score, p.CreationDate, p.Body
  FROM dbo.Users u
  INNER JOIN dbo.Posts p ON u.Id = p.OwnerUserId
  INNER JOIN dbo.PostTypes pt ON p.PostTypeId = pt.Id
  WHERE u.Location IN (SELECT TRIM(value) FROM STRING_SPLIT(@LocationList,'|'))
  ORDER BY p.CreationDate;

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

CREATE OR ALTER PROC dbo.usp_ActivityByLocation_Clue
	@LocationList NVARCHAR(MAX) = 'Paris|Paris, France|France' AS
BEGIN

SELECT u.DisplayName, u.Id AS UserId, pt.Type AS PostType, p.Id AS PostId,
	p.Title, p.Tags, p.Score, p.CreationDate, p.Body
  FROM dbo.Users u
  INNER JOIN dbo.Posts p ON u.Id = p.OwnerUserId
  INNER JOIN dbo.PostTypes pt ON p.PostTypeId = pt.Id
  WHERE u.Location IN (SELECT TRIM(value) FROM STRING_SPLIT(@LocationList,'|'))
  ORDER BY p.CreationDate;

/* THE CLUE:

First, functions can cause really bad guesses on how many rows are going to
come out. Even when they're system-defined functions like STRING_SPLIT, that
can happen - SQL Server doesn't know how many rows are going to come out, much
less what their contents are going to be, until long after it's built the plan.

Just doing OPTION RECOMPILE won't be enough: SQL Server will still build the
entire plan all at once first.

Try breaking the query up into two parts. First, find the contents of the
STRING_SPLIT, save those off, and then use those (after SQL Server understands
what they're going to be) in the second part of the query.
*/

END
GO




CREATE OR ALTER PROC dbo.usp_TopQuestionersByTag_Difficult
	@Tag NVARCHAR(150), 
	@StartDate DATE, 
	@EndDate DATE AS
BEGIN
SELECT YEAR(q.CreationDate) AS CreationYear,
		MONTH(q.CreationDate) AS CreationMonth,
		uQ.DisplayName AS QuestionerDisplayName,
		uQ.Id AS QuestionerUserId,
		COUNT(DISTINCT q.Id) AS Questions,
		COUNT(DISTINCT a.Id) AS Answers,
		AVG(q.Score) AS QuestionAvgScore,
		AVG(a.Score) AS AnswerAvgScore
  FROM dbo.Posts q
    INNER JOIN dbo.Users uQ ON q.OwnerUserId = uQ.Id
    LEFT OUTER JOIN dbo.Posts a ON q.Id = a.ParentId
  WHERE q.PostTypeId = 1
    AND q.Tags = @Tag
    AND q.CreationDate BETWEEN @StartDate AND @EndDate
  GROUP BY YEAR(q.CreationDate), MONTH(q.CreationDate), uQ.DisplayName, uQ.Id
  ORDER BY YEAR(q.CreationDate), MONTH(q.CreationDate), COUNT(DISTINCT q.Id) DESC;
END
GO



CREATE OR ALTER PROC dbo.usp_TopQuestionersByTag_Difficult_Clue
	@Tag NVARCHAR(150) = '<android>', 
	@StartDate DATE = '2010-01-01', 
	@EndDate DATE = '2019-12-31' AS
BEGIN
SELECT YEAR(q.CreationDate) AS CreationYear,
		MONTH(q.CreationDate) AS CreationMonth,
		uQ.DisplayName AS QuestionerDisplayName,
		uQ.Id AS QuestionerUserId,
		COUNT(DISTINCT q.Id) AS Questions,
		COUNT(DISTINCT a.Id) AS Answers,
		AVG(q.Score) AS QuestionAvgScore,
		AVG(a.Score) AS AnswerAvgScore
  FROM dbo.Posts q
    INNER JOIN dbo.Users uQ ON q.OwnerUserId = uQ.Id
    LEFT OUTER JOIN dbo.Posts a ON q.Id = a.ParentId
  WHERE q.PostTypeId = 1
    AND q.Tags = @Tag
    AND q.CreationDate BETWEEN @StartDate AND @EndDate
  GROUP BY YEAR(q.CreationDate), MONTH(q.CreationDate), uQ.DisplayName, uQ.Id
  ORDER BY YEAR(q.CreationDate), MONTH(q.CreationDate), COUNT(DISTINCT q.Id) DESC;

/* THE CLUE:
Run it with these parameters:

EXEC usp_TopQuestionersByTag @Tag = '<android>', @StartDate = '2010-01-01', @EndDate = '2019-12-31';

When it finishes a minute or so later, look at the number of rows it produces.
Is anybody really reading a report with tens of thousands of rows? Probably not.
Try implementing pagination, or forcing them to pick a smaller date range.
*/

END
GO




CREATE OR ALTER PROC dbo.usp_RptQuestionsAndAnswersByMonth_Difficult AS
BEGIN
/* From: https://data.stackexchange.com/stackoverflow/query/6134/total-questions-and-answers-per-month-for-the-last-12 */
set nocount on 

declare @oldestPost dateTime

select top 1 @oldestPost = CreationDate from Posts 
order by CreationDate desc;


-- look at 30 day chunks, so stats remain fairly accurate 
-- (month will depend on days per month)

create table #ranges (Id int identity, [start] datetime, [finish] datetime)

insert #ranges
select top 12 null, null
from sysobjects

update #ranges 
  set 
   [start] = DateAdd(d, (0 - Id) * 30, @oldestPost),
   [finish] = DateAdd(d, (1 - Id) * 30, @oldestPost)


select start, (select count(*) from Posts where ParentId is null 
   and CreationDate between [start] and [finish] ) as [Total Questions],
    (select count(*) from Posts where ParentId is not null 
   and CreationDate between [start] and [finish] ) as [Total Answers]
from #ranges
END
GO


CREATE OR ALTER PROC dbo.usp_RptQuestionsAndAnswersByMonth_Difficult_Clue AS
BEGIN

/* This stored proc is:
	1. Getting the newest CreationDate
	2. Building a temp table with 12 rows, one per month
	3. Joining that to the Posts table to get dates on a 12-month basis

This probably feels clumsy and unintuitive.
You might want to rewrite this one from scratch,
trying to do the same thing in a clearer (to you and me) way.

Could you do the below in a simpler way?
*/

declare @oldestPost dateTime

select top 1 @oldestPost = CreationDate from Posts 
order by CreationDate desc;


-- look at 30 day chunks, so stats remain fairly accurate 
-- (month will depend on days per month)

create table #ranges (Id int identity, [start] datetime, [finish] datetime)

insert #ranges
select top 12 null, null
from sysobjects

update #ranges 
  set 
   [start] = DateAdd(d, (0 - Id) * 30, @oldestPost),
   [finish] = DateAdd(d, (1 - Id) * 30, @oldestPost)

END
GO




CREATE OR ALTER     PROC [dbo].[usp_RptCommentsByUserDisplayName] @DisplayName NVARCHAR(40)
AS
SELECT c.CreationDate, c.Score, c.Text, p.Title, p.PostTypeId
FROM dbo.Users u
INNER JOIN dbo.Comments c ON u.Id = c.UserId
INNER JOIN dbo.Posts p ON c.PostId = p.Id
WHERE u.DisplayName = @DisplayName
ORDER BY c.CreationDate;
GO



CREATE OR ALTER PROC dbo.mqt_Lab3_Level1 @StartYear INT, @EndYear INT AS
BEGIN
/* 
Source: http://data.stackexchange.com/stackoverflow/query/1080/top-users-by-number-of-bounties-won  (but modified) 

Turn on stats IO and actual execution plans, and then run this:

EXEC dbo.mqt_Lab3_Level1 @StartYear = 2017, @EndYear = 2018

Sometimes our reports team writes reports in order to show the data they need,
and they're not really concerned about performance. In this case, users asked
to see who's winning the most bounties at Stack Overflow across date ranges.

Bounties are questions where a user has said, "I'll give up X of my reputation
points if you can give me a really good answer to this question." Here's some:
https://stackoverflow.com/?tab=featured

Looking at the execution plan and stats IO, think about:

* In the top right operator, the driver table, are our estimates right?
* Are we doing a seek or a scan?
* 
* How much data are we returning? Should we maybe paginate this data, or only
  return a smaller subset of rows? If so, how does that change the plan?
* 

*/

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





CREATE OR ALTER PROC [dbo].[usp_QueryLab3] WITH RECOMPILE AS
BEGIN
/* Hi! You can ignore this stored procedure.
   This is used to run different random stored procs as part of your class.
   Don't change this in order to "tune" things.
*/
SET NOCOUNT ON

DECLARE @Id1 INT = CAST(RAND() * 10000000 AS INT) + 1;

IF @Id1 % 9 = 8
	EXEC mqt_Lab3_Level1 @StartYear = 2017, @EndYear = 2018
ELSE IF @Id1 % 9 = 7
	EXEC mqt_Lab3_Level1 @StartYear = 2016, @EndYear = 2017
ELSE IF @Id1 % 9 = 6
	EXEC usp_TopQuestionersByTag_Difficult @Tag = '<php>', @StartDate = '2010-01-01', @EndDate = '2019-12-31';
ELSE IF @Id1 % 9 = 5
	EXEC usp_TopQuestionersByTag_Difficult @Tag = '<javascript>', @StartDate = '2010-01-01', @EndDate = '2019-12-31';
ELSE IF @Id1 % 9 = 4
	EXEC usp_TopQuestionersByTag_Difficult @Tag = '<android>', @StartDate = '2010-01-01', @EndDate = '2019-12-31';
ELSE IF @Id1 % 9 = 3
	EXEC usp_ActivityByLocation @LocationList = N'Berlin|Berlin, Germany'
ELSE IF @Id1 % 9 = 2
	EXEC usp_ActivityByLocation @LocationList = N'London, United Kingdom|London'
ELSE IF @Id1 % 9 = 1
	EXEC usp_RptQuestionsAndAnswersByMonth_Difficult;
ELSE
	EXEC usp_MQT36660;


WHILE @@TRANCOUNT > 0
	BEGIN
	COMMIT
	END
END
GO


CREATE OR ALTER PROC [dbo].[usp_QueryLab3_Setup] AS
BEGIN
	EXEC DropIndexes @SchemaName = 'dbo', @TableName = 'Posts',
		@ExceptIndexNames = '_dta_index_Posts_5_85575343__K2,IX_AcceptedAnswerId,_dta_index_Posts_5_85575343__K2_K14,_dta_index_Posts_5_85575343__K8,IX_LastActivityDate_Includes,IX_LastEditorUserId,IX_ParentId,IX_PostTypeId,_dta_index_Posts_5_85575343__K16_K7_K5_K14_17,IX_ViewCount_Includes'
	EXEC DropIndexes @SchemaName = 'dbo', @TableName = 'Votes',
		@ExceptIndexNames = 'IX_PostId_UserId,IX_UserId,_dta_index_Votes_5_181575685__K3_K2_K5'
END
GO

EXEC usp_QueryLab3_Setup;