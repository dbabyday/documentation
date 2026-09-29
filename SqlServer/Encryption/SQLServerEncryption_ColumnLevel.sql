/*******************************************************************************************
* 
* Column-Level Encryption
* 
* https://www.mssqltips.com/sqlservertip/2431/sql-server-column-level-encryption-example-using-symmetric-keys/
* 
* Encryption hierarchy:
* 	Service Master Key (in master)
* 	Database Master Key (in MyDatabase)
* 	Certificate (in MyDatabase)
* 	Symetric Key (in MyDatabase)
* 	Data
* 
* Encrypted column can only be varbinary 
* 
* User must be granted permissions to certificate and symetric key. 
* If not, null will be returned when trying to decrypt data.
* 
*******************************************************************************************/


----------------------------------------------------------------
--// ENCRYPTION HIERARCHY                                   //--
----------------------------------------------------------------

-- The service master key is in master;
USE [master];
GO

-- Backup the service master key if hasn't already been done.
BACKUP SERVICE MASTER KEY TO FILE = 'path_to_file' -- 'D:\xfr\ServiceMasterKey_ServerName_Instance.key'
    ENCRYPTION BY PASSWORD = 'MyServiceMasterKeyPassword';
GO

-- Create the remaining encryption hierarchy in MyDatabase
USE [MyDatabase];
GO

-- Create the database master key.
CREATE MASTER KEY 
	ENCRYPTION BY PASSWORD = 'MyMasterKeyPassword';
GO

-- Backup the database master key.
BACKUP MASTER KEY TO FILE = 'path_to_file' -- 'D:\xfr\MasterKey_Database_Environment.key' 
    ENCRYPTION BY PASSWORD = 'MyMasterKeyBackupPassword';
GO

-- Create a certificate.
CREATE CERTIFICATE MySQLCert  -- CERT_DBName_Environment
	WITH SUBJECT = 'Protects MyDatabase DEK';
GO

-- Backup the certificate.
BACKUP CERTIFICATE MySQLCert
	TO FILE = 'path_to_file' -- 'D:\xfr\CERT_DBName_Environment.cert'
	WITH PRIVATE KEY ( FILE = 'path_to_file', -- 'D:\xfr\CERT_DBName_Environment.prvk'
	ENCRYPTION BY PASSWORD = 'MyCertBackupPassword' );
GO

-- Create a symetric key protected by certificate.
CREATE SYMMETRIC KEY MySymmetricKey 
	WITH ALGORITHM = AES_128 
	ENCRYPTION BY CERTIFICATE MySQLCert;
GO




----------------------------------------------------------------
--// SCHEMA CHANGES                                         //--
----------------------------------------------------------------

USE MyDatabase;
GO

ALTER TABLE MyTable 
	ADD MyEncryptedColumnName varbinary(MAX) NULL;
GO


----------------------------------------------------------------
--// ENCRYPT NEW COLUMN                                     //--
----------------------------------------------------------------

USE MyDatabase;
GO

-- Opens the symmetric key for use
OPEN SYMMETRIC KEY MySymmetricKey
	DECRYPTION BY CERTIFICATE MyMySQLCert;
GO

UPDATE MyTable
	SET MyEncryptedColumnName = EncryptByKey (Key_GUID('MySymmetricKey'),MyOriginalColumnName)
	FROM MyTable;
GO

-- Closes the symmetric key
CLOSE SYMMETRIC KEY MySymmetricKey;
GO


----------------------------------------------------------------
--// REMOVE THE OLD COLUMN                                  //--
----------------------------------------------------------------

USE MyDatabase;
GO

ALTER TABLE MyTable
	DROP COLUMN MyOriginalColumnName;
GO


----------------------------------------------------------------
--// READING THE ENCRYPTED DATA                             //--
----------------------------------------------------------------

USE MyDatabase;
GO

OPEN SYMMETRIC KEY MySymmetricKey
	DECRYPTION BY CERTIFICATE MyMySQLCert;
GO

SELECT 
	MyEncryptedColumnName AS 'Encrypted Value',
	CONVERT(varchar, DecryptByKey(MyEncryptedColumnName)) AS 'Decrypted Value'
FROM 
	MyTable;
 
 -- Close the symmetric key
CLOSE SYMMETRIC KEY MySymmetricKey;
GO


----------------------------------------------------------------
--// ADDING RECORDS                                         //--
----------------------------------------------------------------

USE MyDatabase;
GO

OPEN SYMMETRIC KEY MySymmetricKey
	DECRYPTION BY CERTIFICATE MyMySQLCert;
GO

INSERT INTO MyTable (ColumnName_a, ColumnName_b, MyEncryptedColumnName)
VALUES (value_a, value_b, EncryptByKey( Key_GUID('MySymmetricKey'), CONVERT(varchar,'value_to_encrypt') ) );    
GO
 
CLOSE SYMMETRIC KEY MySymmetricKey;
GO


----------------------------------------------------------------
--// GRANT PERMISSIONS TO THE ENCRYPTED DATA                //--
----------------------------------------------------------------

GRANT VIEW DEFINITION ON SYMMETRIC KEY::MySymmetricKey TO MyUserName; 
GO
GRANT VIEW DEFINITION ON Certificate::MyMySQLCert TO MyUserName;
GO

