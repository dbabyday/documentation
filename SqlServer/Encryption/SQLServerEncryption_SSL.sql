/*******************************************************************************************
* 
* SQL Server SSL Encryption (Encypted connections)
* 
* https://support.microsoft.com/en-us/kb/316898
* https://msdn.microsoft.com/en-us/library/ms191192(v=sql.110).aspx
* https://technet.microsoft.com/en-us/library/ms189067(v=sql.105).aspx
* 
* 
* ----------------------------------------------------------------------
* --// REQUEST A CERTIFICATE THROUGH SERVICE NOW                    //--
* ----------------------------------------------------------------------
* 
* Service Catalog > IT - Use Only > SSL Certificate Request
* Common Name: FQDN (co-db-900.na.plexus.com)
* Certificate Type: Plexus PKI
* Certificate Item: 3 years	
* Primary Host: server name (co-db-900)
* DSL Entry?: application name (PSOM-SMS/KMS)
* 
* ask the security team for help if you are unsure of the details
* 
* 
* ----------------------------------------------------------------------
* --// PROVISION A CERTIFICATE ON THE SERVER                        //--
* ----------------------------------------------------------------------
* 
* 1.	Log onto the machine as the service account running SQL Server Engine
* 2.	Open MMC console 									(Start > Run > MMC)
* 3.	File > Add/Remove Snap-in 							(In the MMC console)
* 4.	'Certificates', 'Add'								(In the Add Standalone Snap-in dialog box)
* 5.	'Computer account', 'Next', 'Finish'				(In the Certificates snap-in dialog box)
* 6.	'Close'												(In the Add Standalone Snap-in dialog box)
* 7.	'OK'												(In the Add/Remove Snap-in dialog box)
* 8.	expand 'Certificates', 'Personal'					(In the Certificates snap-in)
* 9.	right-click 'Certificates' > 'All Tasks' > 'Import'	(In the Certificates snap-in)
* 10.	'Next'
* 11.	'Browse...' > locate and select your certificate
* 12.	'Open', 'Next'
* 13.	Enter the password you received with the certificate
* 14.	'Next', 'Next', 'Finish'
* 15.	close the MMC console.
* 
* 
* ----------------------------------------------------------------------
* --// CONFIGURE SQL SERVER TO ACCEPTED ENCRYPTED CONNECTIONS       //--
* ----------------------------------------------------------------------
* 
* SQL Server Configuration Manager
* Expand 'SQL Server Network Configuration'
* Rt. Click 'Protocols for MSSQLSERVER' > 'Properties' > Certificate (tab)
* Click dropdown under Certificate: > select your certificate
* OPTION: Force Encryption - this will force all connections to use SSL encryption
*     Select tab 'Flags'
*     Select 'Yes' for 'Force Encryption'
* 'Apply'
* 'OK'
* Restart SQL Server services
* 
* 
* ----------------------------------------------------------------------
* --// CONFIGURE THE CLIENT TO REQUEST ENCRYPTED CONNECTIONS        //--
* ----------------------------------------------------------------------
* 
* This applies if you did NOT select 'Force Encryption'
*      If you did not select ‘Force Encyption’, the client must request encryption in the connection string. 
*      If you did set ‘Force Encyption’ to ‘Yes’, then the client does not need to request encryption, it will automatically be encrypted. 
* 
* Using SSMS to connect with SSL encryption if ‘Force Encryption’ is set to ‘No’
*     Server name: FQDN (co-db-900.na.plexus.com)
*     Click 'Options'
*     Check 'Encrypt connection'
*     Click 'Connect'
* 
* -- application
* https://technet.microsoft.com/en-us/library/bb879949(v=sql.110).aspx
* https://msdn.microsoft.com/en-us/library/bb879943(v=sql.110).aspx
* 
*******************************************************************************************/

----------------------------------------------------------------------
--// VERIFY CONNECTION IS ENCRYPTED                               //--
----------------------------------------------------------------------

SELECT session_id, encrypt_option 
FROM sys.dm_exec_connections; 
--WHERE session_id = @@SPID



