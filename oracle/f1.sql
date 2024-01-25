--create role proddta_select not identified;
create role proddta_insert not identified;
create role proddta_update not identified;
create role proddta_delete not identified;


begin
        for x in (select owner, table_name from dba_tables where owner='PRODDTA')
        loop
                --execute immediate 'grant select on '||x.owner||'.'||x.table_name||' to proddta_select';
                execute immediate 'grant insert on '||x.owner||'.'||x.table_name||' to proddta_insert';
                execute immediate 'grant update on '||x.owner||'.'||x.table_name||' to proddta_update';
                execute immediate 'grant delete on '||x.owner||'.'||x.table_name||' to proddta_delete';
        end loop;
end;
/