/*
Mastering Index Tuning - Lab 5
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


USE [StackOverflow]
GO
DROP TABLE IF EXISTS dbo.Report_UsersByQuestions;
GO
CREATE TABLE dbo.Report_UsersByQuestions
	(UserId INT NOT NULL PRIMARY KEY CLUSTERED,
	 DisplayName VARCHAR(40),
	 CreationDate DATE,
	 LastAccessDate DATETIME2,
	 Location VARCHAR(100),
	 Questions INT,
	 Answers INT,
	 Comments INT);
INSERT INTO dbo.Report_UsersByQuestions (UserId, DisplayName, CreationDate, LastAccessDate, Location, Questions, Answers, Comments)
SELECT u.Id, u.DisplayName, u.CreationDate, u.LastAccessDate, u.Location, 0, 0, 0
FROM dbo.Users u;
GO

DROP TABLE IF EXISTS dbo.Report_BadgePopularity;
GO
CREATE TABLE dbo.Report_BadgePopularity
	(BadgeName VARCHAR(40) PRIMARY KEY CLUSTERED,
	 FirstAwarded VARCHAR(40),
	 FirstAwardedToUser VARCHAR(40),
	 TotalAwarded VARCHAR(40));
INSERT INTO dbo.Report_BadgePopularity (BadgeName, FirstAwarded, FirstAwardedToUser, TotalAwarded)
SELECT b.Name, MIN(Date), MIN(UserId), COUNT(*)
FROM dbo.Badges b
GROUP BY b.Name;
GO

CREATE OR ALTER PROC [dbo].[usp_IXReport1] @DisplayName NVARCHAR(40)
AS
BEGIN
SELECT *
  FROM dbo.Report_UsersByQuestions
  WHERE DisplayName = @DisplayName;
END;
GO

CREATE OR ALTER PROC [dbo].[usp_IXReport2] @LastActivityDate DATETIME, @Tags NVARCHAR(150) AS
BEGIN
/* Sample parameters: @LastActivityDate = '2017-07-17 23:16:39.037', @Tags = '%<indexing>%' */
SELECT TOP 100 u.DisplayName, u.Id AS UserId, u.Location, p.Id AS PostId, p.LastActivityDate, p.Body
  FROM dbo.Posts p
    INNER JOIN dbo.Users u ON p.OwnerUserId = u.Id
  WHERE p.Tags LIKE '%<sql-server>%'
    AND p.Tags LIKE @Tags
    AND p.LastActivityDate > @LastActivityDate
  ORDER BY u.DisplayName
END
GO


CREATE OR ALTER PROC [dbo].[usp_IXReport3] @SinceLastAccessDate DATETIME2 AS
BEGIN
SELECT TOP 200 r.DisplayName, r.UserId, r.CreationDate, r.LastAccessDate, u.AboutMe, r.Questions, r.Answers, r.Comments
  FROM dbo.Report_UsersByQuestions r
  INNER JOIN dbo.Users u ON r.UserId = u.Id AND r.DisplayName = u.DisplayName
  WHERE r.LastAccessDate > @SinceLastAccessDate
  ORDER BY r.LastAccessDate
END
GO