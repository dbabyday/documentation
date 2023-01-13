mapfile -t PS_SMON < <(ps -ef | grep smon | grep -v grep)
NUM_LINES=${#PS_SMON[@]}
i=0
while [[ $i -lt $NUM_LINES ]]
do
	LINE=${PS_SMON[$i]}
	((i++))

	# stuff to do
done


###############################################################################################################

while IFS= read -r line
do
  echo "------------------------ START ------------------------"
  echo "$line"
  echo "------------------------- END -------------------------"
done < <(ps -ef | grep tnslsnr | grep $ORACLE_HOME | grep -v grep)