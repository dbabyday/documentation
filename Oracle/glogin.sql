--
-- Copyright (c) 1988, 2005, Oracle.  All Rights Reserved.
--
-- NAME
--   glogin.sql
--
-- DESCRIPTION
--   SQL*Plus global login "site profile" file
--
--   Add any SQL*Plus commands here that are to be executed when a
--   user starts SQL*Plus, or uses the SQL*Plus CONNECT command.
--
-- USAGE
--   This script is automatically run
--

-- no need to display what we are doing
set termout off

-- sqlplus settings
set history on
set linesize 200
set pagesize 50
set long 2000000
set serveroutput on
set trimout on
set trimspool on

-- set sqlprompt
define _DB_NAME=' '
define _DB_USER=' '
column global_name new_value _DB_NAME noprint;
column userid      new_value _DB_USER noprint;
select lower(user) userid, lower(global_name) global_name from global_name;
set SQLPROMPT '(&_DB_USER)&_DB_NAME SQL> '
undefine _DB_NAME
undefine _DB_USER

-- format date and times
alter session set nls_date_format='YYYY-MM-DD HH24:MI:SS';
alter session set nls_timestamp_format='YYYY-MM-DD HH24:MI:SS';

-- remove any column settings we made in here
clear columns

-- start showing output again
set termout on