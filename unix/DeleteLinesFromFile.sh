# trim the log file
LOGFILE=/orahome/oracle/rman_delete_archivelog.log
MATCHSTRING=$(gdate -d "-6 days" +%F)
LINENUM=$(grep -n ${MATCHSTRING} ${LOGFILE} | head -n 1 | cut -d: -f1)
((LINENUM-=4))

echo ""
echo `date +"%F %T"`" - Trimming ${LOGFILE} of entries before ${MATCHSTRING}"

if (( LINENUM > 0 )); then
		ed -s ${LOGFILE} <<-EOF
				1,${LINENUM}d
				w
		EOF
fi