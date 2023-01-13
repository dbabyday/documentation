/*
https://datacadamia.com/lang/sqlplus/bind_variable#:~:text=%203%20-%20How%20to%20%201%203.1,by%20typing%20a%20colon%20%28%3A%29%20followed...%20More%20
*/

/* -- old way (still works) 
VARIABLE User_Login   VARCHAR2(10);
VARIABLE Object_Class NUMBER;
VARIABLE Start_Date   VARCHAR2(19);
VARIABLE End_Date     VARCHAR2(19);
VARIABLE All_Actions  NUMBER;


BEGIN
    :User_Login   := 'abc';
    :Object_Class := 1;
    :Start_Date   := to_date('2021-05-10 12:12:12','YYYY-MM-DD HH24:MI:SS');
    :End_Date     := to_date('2021-05-10 11:11:11','YYYY-MM-DD HH24:MI:SS');
    :All_Actions  := 1;
END;
/
*/

/* new way */
variable User_Login   = 'abc';
variable Object_Class = 1;
variable Start_Date   = to_date('2021-05-10 12:12:12','YYYY-MM-DD HH24:MI:SS');
variable End_Date     = to_date('2021-05-10 11:11:11','YYYY-MM-DD HH24:MI:SS');
variable All_Actions  = 1;



select timestamp
     , loginid
     , class
     , object
     , action
     , details
from  (    select     to_char(h.timestamp, 'yyyy/mm/dd hh24:mi:ss') as timestamp
                    , u.loginid
                    , n.description as class
                    , coalesce(i.item_number, p.part_number, m.city, c.cust_no) as object
                    , l.entryvalue as action
                    , dbms_lob.substr(h.details, 200) as details
           from       agile.item_history h
           left join  agile.item i on h.item = i.id and h.class in (9000, 10000)
           left join  agile.manu_parts p on h.item = p.id and h.class = 1483
           left join  agile.manufacturers m on h.item = m.id and h.class = 442
           left join  agile.customer c on h.item = c.id and h.class = 4983
           inner join agile.agileuser u on h.user_id = u.id
           inner join agile.nodetable n on h.class = n.id and n.parentid = 5002
           left join  agile.listentry l on h.action = l.entryid and l.parentid = 4456 and l.langid = 0
           where      u.loginid in (:User_Login)
                      and h.class in (:Object_Class)
                      and h.timestamp between trunc(:Start_Date) and trunc(:End_Date)
                      and coalesce(i.id, p.id, m.id, c.id) is not null
                      and (:All_Actions = 1 or l.entryvalue in ('Modify Change Controlled','Open file attachment','Create','Redline line item','Approve','Modify affected item','Add manufacturer part','View file attachment'))
           union all
           select     to_char(h.timestamp, 'yyyy/mm/dd hh24:mi:ss') as timestamp, u.loginid, n.description as class, coalesce(c.change_number, q.qcr_number, p.psr_no) as object, l.entryvalue as action, dbms_lob.substr(h.details, 200) as details
           from       agile.change_history h
           left join  agile.change c on h.change_id = c.id and h.class_id in (6000, 7000, 1450, 8000)
           left join  agile.qcr q on h.change_id = q.id and h.class_id in (4928, 4428)
           left join  agile.psr p on h.change_id = p.id and h.class_id = 4878
           inner join agile.agileuser u on h.user_id = u.id
           inner join agile.nodetable n on h.class_id = n.id and n.parentid = 5002
           left join  agile.listentry l on h.event_type = l.entryid and l.parentid = 4457 and l.langid = 0
           where      u.loginid in (:User_Login)
                      and h.class_id in (:Object_Class)
                      and h.timestamp between trunc(:Start_Date) and trunc(:End_Date)
                      and coalesce(c.id, q.id, p.id) is not null
                      and (:All_Actions = 1 or l.entryvalue in ('Modify Change Controlled','Open file attachment','Create','Redline line item','Approve','Modify affected item','Add manufacturer part','View file attachment'))
      )q
/