/*
Fundamentals of Query Tuning: Run the Workload

v1.0 - 2019-06-30

https://www.BrentOzar.com/go/queryfund


This demo requires:
* Any supported version of SQL Server
* Any Stack Overflow database: https://www.BrentOzar.com/go/querystack

Before running this setup script, restore the Stack Overflow database and do
the index & stored proc setup scripts shown in the prior script.

This script will run for tens of minutes - but even if you just let it run for
a few minutes, you'll have enough stuff in your plan cache to start analysis.
You can cancel it whenever you want.
*/
USE [StackOverflow2013]
GO
DBCC FREEPROCCACHE
GO
DECLARE @Counter INT = 1
WHILE @Counter < 10
    BEGIN
    EXEC usp_rpt_PopularLocations;
    EXEC usp_UsersInTop5Locations;
    EXEC dbo.usp_CommentBattles @UserId1 = 26837, @UserId2 = 1504529;
    EXEC dbo.usp_CommentBattles @UserId1 = 505088, @UserId2 = 22656;
    EXEC dbo.usp_CommentBattles @UserId1 = 17034, @UserId2 = 22656;
    EXEC usp_UsersOutracingMe @UserId = 22656;
    EXEC usp_UsersOutracingMe @UserId = 26837;
    EXEC usp_UsersOutracingMe @UserId = 2723201;
    EXEC usp_SearchComments 'India', '2013-08-01', '2013-08-30';
    EXEC usp_SearchComments 'Helsinki, Finland', '2013-08-01', '2013-08-30';
    EXEC usp_SearchComments 'Helsinki, Finland', '2008-01-01', '2020-12-31';
    EXEC usp_SearchComments 'India', '2008-01-01', '2020-12-31';
    IF @Counter IN (4, 7, 10)
        EXEC usp_rpt_ControversialPosts;
    SET @Counter = @Counter + 1;
END


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