string=YOUR-STRING
echo ${string:P}
echo ${string:P:L}

# Here P is a number that indicates the starting index of the substring and L is the length of the substring. 
# If you omit the L parameter then the rest of the string is returned, starting from position P.