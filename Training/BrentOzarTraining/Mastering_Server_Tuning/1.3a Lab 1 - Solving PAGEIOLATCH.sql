/*
Mastering Server Tuning - Lab 1 Setup

This script is from our Mastering classes.
To learn more: https://www.BrentOzar.com/go/tuninglabs

Before running this setup script, restore the Stack Overflow database.
This script runs instantly - it's just creating stored procedures.




License: Creative Commons Attribution-ShareAlike 3.0 Unported (CC BY-SA 3.0)
More info: https://creativecommons.org/licenses/by-sa/3.0/

You are free to://
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
EXEC sys.sp_configure N'show advanced', 1;
EXEC sys.sp_configure N'max degree', 1;
GO
RECONFIGURE
GO

CREATE OR ALTER PROC dbo.usp_ServerLab1_Setup AS
BEGIN
	EXEC DropIndexes;
	EXEC sys.sp_configure N'max degree of parallelism', N'1';
	RECONFIGURE;
END
GO

CREATE OR ALTER PROC [dbo].[usp_GetBadgesByUser] @UserId INT AS
BEGIN
SELECT *
  FROM dbo.Badges
  WHERE UserId = @UserId;
END
GO

CREATE OR ALTER PROC [dbo].[usp_GetCommentsByUser] @UserId INT AS
BEGIN
SELECT *
  FROM dbo.Comments
  WHERE UserId = @UserId;
END
GO

CREATE OR ALTER PROC [dbo].[usp_GetCommentsByPost] @PostId INT AS
BEGIN
SELECT *
  FROM dbo.Comments
  WHERE PostId = @PostId;
END
GO

CREATE OR ALTER PROC [dbo].[usp_GetPostsByAcceptedAnswerId] @AcceptedAnswerId INT AS
BEGIN
SELECT *
  FROM dbo.Posts
  WHERE AcceptedAnswerId = @AcceptedAnswerId;
END
GO

CREATE OR ALTER PROC [dbo].[usp_GetPostsByLastEditorUserId] @LastEditorUserId INT AS
BEGIN
SELECT *
  FROM dbo.Posts
  WHERE LastEditorUserId = @LastEditorUserId;
END
GO

CREATE OR ALTER PROC [dbo].[usp_GetPostsByOwnerUserId] @OwnerUserId INT AS
BEGIN
SELECT *
  FROM dbo.Posts
  WHERE OwnerUserId = @OwnerUserId;
END
GO

CREATE OR ALTER PROC [dbo].[usp_GetPostsByParentId] @ParentId INT AS
BEGIN
SELECT *
  FROM dbo.Posts
  WHERE ParentId = @ParentId;
END
GO

CREATE OR ALTER PROC [dbo].[usp_GetVotesByPost] @PostId INT AS
BEGIN
SELECT *
  FROM dbo.Votes
  WHERE PostId = @PostId;
END
GO

CREATE OR ALTER PROC [dbo].[usp_GetVotesByUserId] @UserId INT AS
BEGIN
SELECT *
  FROM dbo.Votes
  WHERE UserId = @UserId;
END
GO

CREATE OR ALTER PROC [dbo].[usp_ServerLab1] WITH RECOMPILE AS
BEGIN
/* Hi! You can ignore this stored procedure.
   This is used to run different random stored procs as part of your class.
   Don't change this in order to "tune" things.
*/
SET NOCOUNT ON

DECLARE @Id1 INT = CAST(RAND() * 10000000 AS INT) + 1;

IF @Id1 % 13 = 12
	EXEC dbo.[usp_GetBadgesByUser] @Id1;
ELSE IF @Id1 % 13 = 11
	EXEC dbo.[usp_GetCommentsByUser] @Id1;
ELSE IF @Id1 % 13 = 10
	EXEC dbo.[usp_GetCommentsByPost] @Id1;
ELSE IF @Id1 % 13 = 9
	EXEC dbo.[usp_GetPostsByAcceptedAnswerId] @Id1;
ELSE IF @Id1 % 13 = 8
	EXEC dbo.[usp_GetPostsByLastEditorUserId] @Id1;
ELSE IF @Id1 % 13 = 7
	EXEC dbo.[usp_GetPostsByOwnerUserId] @Id1;
ELSE IF @Id1 % 13 = 6
	EXEC dbo.[usp_GetPostsByParentId] @Id1;
ELSE IF @Id1 % 13 = 5
	EXEC dbo.[usp_GetVotesByPost] @Id1;
ELSE IF @Id1 % 13 = 4
	EXEC dbo.[usp_GetVotesByUserId] @Id1;
ELSE IF @Id1 % 13 = 3
	EXEC dbo.[usp_GetVotesByUserId] @Id1;
ELSE IF @Id1 % 13 = 2
	EXEC dbo.[usp_GetVotesByUserId] @Id1;
ELSE
	EXEC dbo.[usp_GetVotesByUserId] @Id1;

WHILE @@TRANCOUNT > 0
	BEGIN
	COMMIT
	END
END
GO


EXEC dbo.usp_ServerLab1_Setup;
GO