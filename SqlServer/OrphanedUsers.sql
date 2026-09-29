/********************************************************************
* 
* Orphaned Users
* 
* Notes:
*     Olny occurs with SQL Server logins.
*     Windows logins are controlled by Windows or Active Directory
* 
********************************************************************/


-----------------------------------------
--// Find Orphaned Users             //--
-----------------------------------------

EXECUTE sp_change_users_login 'REPORT';


-----------------------------------------
--// Fix Orphaned User               //--
-----------------------------------------

EXECUTE sp_change_users_login 'UPDATE_ONE','myUserName','myLoginName';