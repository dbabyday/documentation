BEGIN
       LOOP
              update proddta.f554102 
              set    i2$ccf9 = ' '
              where  i2$ccf9 is null
                     and rownum <= 100000;
              exit when sql%notfound;
              commit;
       END LOOP;
       commit;
END;
/