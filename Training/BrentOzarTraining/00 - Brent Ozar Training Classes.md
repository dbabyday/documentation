# Brent Ozar Training Classes

What order should I attend the classes in?  
Each class has its own prerequisites listed, but overall, here's what I'd recommend:

1. How to Think Like the Engine (free)
2. How I Use the First Responder Kit
3. Fundamentals of Index Tuning
4. Optional: Fundamentals of Columnstore Indexes
5. Fundamentals of Query Tuning
6. Fundamentals of Parameter Sniffing
7. Optional: Fundamentals of TempDB
8. Mastering Index Tuning
9. Mastering Query Tuning
10. Mastering Parameter Sniffing
11. Mastering Server Tuning




# Restoring StackOverflow2013 quickly with attach

# 1. drop existing database
USE master;
GO
ALTER DATABASE StackOverflow2013 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE StackOverflow2013;
GO

# 2. move files to database and logs folders
Move-Item -Path \\dcc-sql-dv-043\f$\StackOverflow2013_OriginalFiles\StackOverflow2013_1.mdf -Destination \\dcc-sql-dv-043\f$\Databases
Move-Item -Path \\dcc-sql-dv-043\f$\StackOverflow2013_OriginalFiles\StackOverflow2013_2.ndf -Destination \\dcc-sql-dv-043\f$\Databases
Move-Item -Path \\dcc-sql-dv-043\f$\StackOverflow2013_OriginalFiles\StackOverflow2013_3.ndf -Destination \\dcc-sql-dv-043\f$\Databases
Move-Item -Path \\dcc-sql-dv-043\f$\StackOverflow2013_OriginalFiles\StackOverflow2013_4.ndf -Destination \\dcc-sql-dv-043\f$\Databases
Move-Item -Path \\dcc-sql-dv-043\f$\StackOverflow2013_OriginalFiles\StackOverflow2013_log.ldf -Destination \\dcc-sql-dv-043\g$\Logs
Remove-Item -Path \\dcc-sql-dv-043\f$\StackOverflow2013_OriginalFiles\Readme.txt

# 3. attach database
USE master;
GO
CREATE DATABASE StackOverflow2013 ON 
	  ( FILENAME = N'F:\Databases\StackOverflow2013_1.mdf' )
	, ( FILENAME = N'G:\Logs\StackOverflow2013_log.ldf' )
	, ( FILENAME = N'F:\Databases\StackOverflow2013_2.ndf' )
	, ( FILENAME = N'F:\Databases\StackOverflow2013_3.ndf' )
	, ( FILENAME = N'F:\Databases\StackOverflow2013_4.ndf' )
FOR ATTACH;
GO

# 4. unzip files to stage them for next time
& ${env:ProgramFiles}\7-Zip\7z.exe x \\dcc-sql-dv-043\f$\StackOverflow2013_201809117.7z -o\\dcc-sql-dv-043\f$\StackOverflow2013_OriginalFiles -r
