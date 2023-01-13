
/*

	https://asktom.oracle.com/pls/asktom/f?p=100:11:0::::P11_QUESTION_ID:9534169900346876704

	z##_cnt
		-1 for records in target
		 1 for records in source
	
	sum(z##_cnt)  
		 0 recors are identical in both source and target
		-1 record is in target only
		 1 record is in source only

	count(*) over (partition by pk)
		1 pk exists in either source or target
		2 pk exists in both source and target

	z##uid_flag
		0 INSERT - pk in source only
		1 UPDATE - pk in both, this is the source record, target record has differnt values in non-pk field(s)
		2 DELETE - pk in target only
		3 EXCLUDE - pk in both, this is the target record, source record has different values in non-pk field(s)
	
*/

merge into target_schema.target_table t
using (  select * 
         from   (  select   pk
                          , x
                          , y
                          , count(*) over(partition by pk) - sum(z##_cnt) z##iud_flag
                   from     (  select pk
                                    , x
                                    , y
                                    , -1 z##_cnt
                               from   target_schema.target_table
                               union all
                               select pk
                                    , x
                                    , y
                                    , 1 z##_cnt
                               from   source_schema.source_table
                            )
                   group by pk
                          , x
                          , y
                   having   sum(z##_cnt) != 0
                )
         where z##iud_flag < 3
      ) s ON (s.pk=t.pk)
when matched then update set t.x=s.x
                           , t.y=s.y
                  delete where s.z##iud_flag = 2
when not matched then insert (pk,x,y)
                      values (s.pk,s.x,s.y)
/