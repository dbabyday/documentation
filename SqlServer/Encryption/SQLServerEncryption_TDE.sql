/*******************************************************************************************
* 
* TDE - Transparent Data Encryption (Encryption at rest)
* 
* References:
*     https://msdn.microsoft.com/en-us/library/bb934049.aspx
*     http://sqlmag.com/database-security/using-transparent-data-encryption
*     Removing TDE - http://www.sqlservercentral.com/articles/Security/76141/
*     Master Key Info - https://msdn.microsoft.com/en-us/library/ms174382.aspx
* 
* 
* Enterprise only feature
* 
* Encrypts files and backups
* 
* Encryption hierarchy:
* 	Service Master Key (in master)
* 	Database Master Key (in master)
* 	Certificate (in master)
* 	Symetric Key (in MyDatabase)
* 	Data
* 
* Steps
* 	1. Create a master key for the master database
* 	2. Create a certificate that's protected by the master key (in master)
* 	3. Create a database encyption key (DEK) that's protected by the certificate (in MyDatabase)
* 	4. Set the database to use encryption
* 
* Backup server certificates and keys
* 
* sys.symmetric_keys
* sys.certificates
* sys.dm_database_encryption_keys
* 
* Fails if...
* 	- filegroup(s) in READ ONLY
* 	- if database is read-only
* 	- database is offline
* 	- data backup is running
* 	- ALTER DATABASE is executing
* 	- snapshot in progress
* 	- database maintenance tasks
* 
* Not recommended to use TDE and backup compression together
* 
* Full-text indexes can cause column's data to be written in plain text onto the disk during full-text scan
* 
* tempdb will be encrypted - may have performance impact on all databases on instance (even the non-encrypted ones)
* 
*******************************************************************************************/


----------------------------------------------------------------------
--// ENALBLE TDE                                                  //--
----------------------------------------------------------------------

-- The master key must be in the master database.
USE [master];
GO

-- Backup the service master key if has not already been done.
BACKUP SERVICE MASTER KEY TO FILE = 'path_to_file' -- 'D:\xfr\ServiceMasterKey_ServerName_Instance_Date.key'
    ENCRYPTION BY PASSWORD = 'MyServiceMasterKeyPassword';
GO

-- Create the master key. (this is the database master key for the master database)
-- SELECT * FROM master.sys.symmetric_keys;
CREATE MASTER KEY 
	ENCRYPTION BY PASSWORD = 'MyMasterKeyPassword';
GO

-- Backup the master key.
BACKUP MASTER KEY TO FILE = 'path_to_file' -- 'D:\xfr\DatabaseMasterKey_ServerName_Instance_master_Date.key' 
    ENCRYPTION BY PASSWORD = 'MyMasterKeyBackupPassword';
GO

-- Create a certificate.
CREATE CERTIFICATE MySQLCert  -- CERT_DBName_Environment
	WITH SUBJECT = 'Protects MyDatabase DEK';
GO

-- Backup the certificate.
BACKUP CERTIFICATE MySQLCert
	TO FILE = 'path_to_file' -- 'D:\xfr\CERT_DBName_Environment_Date.cert'
	WITH PRIVATE KEY ( FILE = 'path_to_file', -- 'D:\xfr\CERT_DBName_Environment_Date.prvk'
	ENCRYPTION BY PASSWORD = 'MyCertBackupPassword' );
GO

-- Use the database to enable TDE.
USE [MyDatabase];
GO

-- Create DEK protected by certificate.
CREATE DATABASE ENCRYPTION KEY
	WITH ALGORITHM = AES_128
	ENCRYPTION BY SERVER CERTIFICATE MySQLCert;
GO

-- Encrypt the database.
ALTER DATABASE MyDatabase
	SET ENCRYPTION ON;
GO

-- Store the key backups, certificate backups, and passwords in CyberArk
-- Delete the backups from the server.

----------------------------------------------------------------------
--// MONITORING TDE                                               //--
----------------------------------------------------------------------

-- databases
SELECT 
	db_name(database_id) AS 'database', 
	CASE encryption_state
		WHEN 0 THEN 'no database encryption key present, no encryption'
		WHEN 1 THEN 'unencrypted'
		WHEN 2 THEN 'encryption in progress'
		WHEN 3 THEN 'encrypted'
		WHEN 4 THEN 'key change in progress'
		WHEN 5 THEN 'decryption in progress'
		WHEN 6 THEN 'protection change in progress'
	END AS 'encryption_state',
	percent_complete, 
	key_algorithm, 
	key_length 
FROM 
	sys.dm_database_encryption_keys;

-- certificate
SELECT * FROM master.sys.certificates; 

-- master keys
SELECT * FROM master.sys.symmetric_keys; 


----------------------------------------------------------------------
--// RESTORE CERTIFICATE ON A NEW INSTANCE                        //--
----------------------------------------------------------------------

USE [master];
GO

-- Create a master key for this instance.
CREATE MASTER KEY 
	ENCRYPTION BY PASSWORD = 'MyMasterKeyPassword_2'; -- different pw than the master key above (this is a different master db on a different instance)
GO

-- Restore the certificate. (get the files from CyberArk)
CREATE CERTIFICATE MySQLCert
	FROM FILE='D:\xfr\CERT_DBName_Environment_Date.cert'
	WITH PRIVATE KEY ( FILE = 'D:\xfr\CERT_DBName_Environment.prvk',
	DECRYPTION BY PASSWORD = 'MyCertBackupPassword' ); -- same pw as the cert backup above (these are the same cert backup files)
GO


----------------------------------------------------------------------
--// REMOVE TDE                                                   //--
----------------------------------------------------------------------

-- The master key must be in the master database.
USE [master];
GO

-- Decrypt the database.
ALTER DATABASE TDE_Testing_SMS2008
	SET ENCRYPTION OFF;
GO




