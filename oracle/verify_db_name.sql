whenever sqlerror exit sql.sqlcode
whenever oserror exit failure

declare
        l_dbexpected varchar2(9) := 'ggpy01';
        l_dbname varchar2(9);
begin
        select lower(name) into l_dbname from v$database;
        if l_dbname <> l_dbexpected then
                raise_application_error(-20001,'Wrong database. Expecting '||l_dbexpected||', but you connected to '||l_dbname);
        end if;
end;
/
