# get the ORACLE_HOME from oratab
ORACLE_SID=jdedv01
ORACLE_HOME=$(grep "^${ORACLE_SID}:" /var/opt/oracle/oratab | cut -d':' -f 2)