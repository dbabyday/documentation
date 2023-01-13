(
	echo "From: Applications_Manager"
	echo "To: ${compareEmailRecipients}"
	echo "Subject: Oracle DB Privilege Changes"
	echo "MIME-Version: 1.0" 
	echo "Content-Type: text/html" 
	echo "Content-Disposition: inline" 
	echo "<html>"
	echo "<body>"
	echo '<pre style="font: monospace">'
	cat ${compareLog}
	echo ""
	echo ""
	echo ""
	echo ""
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "This message was generated from script ampd:/ops/scripts/uc4/oracle/archive_privs.sh"
	echo "Applications Manager job ORA_ARCHIVE_PRIVS executes this script."
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "</pre>"
	echo "</body>"
	echo "</html>"
) | /usr/sbin/sendmail -t