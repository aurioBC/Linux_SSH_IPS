#!/bin/bash

# ---- VALIDATE CMD ARGS ---- #
if [ -z $1 ]; then
    echo "Usage: ./ips.sh <ATTEMPTS> <HOUR> <MIN> <SEC>"
    exit
fi

if [ -z $2 ]; then
    echo "Usage: ./ips.sh <ATTEMPTS> <HOUR> <MIN> <SEC>"
    exit
fi

if [ -z $3 ]; then
    echo "Usage: ./ips.sh <ATTEMPTS> <HOUR> <MIN> <SEC>"
    exit
fi

if [ -z $4 ]; then
    echo "Usage: ./ips.sh <ATTEMPTS> <HOUR> <MIN> <SEC>"
    exit
fi

# ---- CREATE LOG FILES ---- #
touch banned.log
touch suspect.log

chmod 755 banned.log
chmod 755 suspect.log
chmod 755 failed_atmps.log
chmod 755 tmp

# ---- CALCULATE TIMEOUT ---- #
let HR_SEC=($2*60*60)
let MIN_SEC=($3*60)
let SEC=$HR_SEC+$MIN_SEC+$4

# ---- GET CURRENT DAY OF THE MONTH ---- #
CURR_DAY=`date +%-d`
#echo Current Day: $CURR_DAY

# ---- SET INITIAL TIME ---- #
INIT_TIME=$(date --date="10"' seconds ago' +"%T");
#echo Initial Time: $INIT_TIME

while true
do
    let "LINE=1"

    # ---- CHECK IF AN IP CAN BE UNBANNED ---- #
    while read line; do

        # extract timeout from log file
        TIMEOUT_STR=`echo $line | awk '{print $2;}'`

        # get current time
        CURR_TIME=$(date +"%T")

        # check if timeout had occured and can unban
        if [ "$CURR_TIME" ">" "$TIMEOUT_STR" ]; then
            #echo ****** UNBANNNING THE IP *******
            IP=`echo $line | awk '{print $1;}'`

            # unban ip
            iptables -D OUTPUT -d $IP -j DROP
            iptables -D INPUT -d $IP -j DROP
            sed -i "$LINE"d banned.log # delete banned log entry
            break;
        fi

        let "LINE=LINE+1"
    done < banned.log

    # ---- EXTRACT ALL FAILED SSH PASSWORD ATTEMPT LOG ENTRIES ---- #
    grep "Failed password" /var/log/secure > tmp

    # ---- EXTRACT DAY, TIME AND IP OF ENTRY TO FAILED ATTEMPT LOG FILE ---- #
    awk '{print $2 " " $3 " " $11}' tmp > failed_atmps.log


    # ---- PARSE THE FAILED ATTEMPT LOG FILE LINE BY LINE ---- #
    while read line; do

        # extract day of log entry
        DAY_STR=`echo $line | awk '{print $1;}'`
        #echo - Day of log : $DAY_STR

        # check if the log entry is from today
        if [[ $CURR_DAY = $DAY_STR ]]; then
            #echo - THIS LOG IS FROM TODAY

            # extract the time of the log entry
            TIME_STR=`echo $line | awk '{print $2;}'`
            #echo - Time of log: $TIME_STR

            # ---- CHECK IF IT IS A NEW LOG ENTRY ---- #
            if [ "$TIME_STR" ">" "$INIT_TIME" ]; then
                IP_STR=`echo $line | awk '{print $3;}'`  # get the IP from file
                INIT_TIME=$TIME_STR # update the initial time
                #echo - New entry detected-- $DAY_STR $TIME_STR $IP_STR

                IS_BANNED=0

                # ---- CHECK IF IP IS ALREADY BANNED ---- #
                while read line; do
                    # get IP in banned log
                    TMP_IP=`echo $line | awk '{print $1;}'`
                    #echo is $TMP_IP the same as $IP_STR???

                    # check if IPs are the same
                    if [[ $TMP_IP = $IP_STR ]]; then
                        #echo - IP BANNED ALREADY 
                        IS_BANNED=1
                        break
                    fi
                done < banned.log

                # check if the IP is not banned
                if [[ $IS_BANNED -eq $zero ]]; then
                    #echo - IP NOT BANNED YET
                    let "CURR_LINE=1"

                    IS_SUSPECT=0

                    # ---- CHECK IF THERE IS SUSPECT LOG ENTRY FOR THIS IP ---- #
                    while read line; do
                        # get IP from the log file
                        TMP_IP=`echo $line | awk '{print $1;}'`

                        # check if the IPs are the same
                        if [[ $TMP_IP = $IP_STR ]]; then
                            #echo - IP IS SUSPECT
                            IS_SUSPECT=1

                            # increment the IP's fail counter
                            OLD_COUNT=`echo $line | awk '{print $2;}'`
                            let "NEW_COUNT=OLD_COUNT+1"

                            # ---- CHECK IF IP SHOULD BE BANNED ---- #
                            if [[ $NEW_COUNT = $1 ]]; then
                                # ---- BAN IP ---- #
                                iptables -A OUTPUT -d $IP_STR -j DROP
                                iptables -A INPUT -d $IP_STR -j DROP

                                # calculate the ban timeout expiry time
                                TIMEOUT=$(date --date="$SEC"' seconds' +"%T");
                                #echo "$TIMEOUT";

                                # add the IP and timeout expiry time to the ban file
                                echo $IP_STR $TIMEOUT >> banned.log

                                # delete line from suspect file
                                sed -i "$CURR_LINE"d suspect.log
                            else
                                # update suspect file
                                sed -i "${CURR_LINE}s/$IP_STR $OLD_COUNT/$IP_STR $NEW_COUNT/g" suspect.log
                            fi
                            break
                        fi

                        let "CURR_LINE=CURR_LINE+1"
                    done < suspect.log

                    # ---- IF NOT SUSPECT APPEND NEW ENTRY---- #
                    if [[ $IS_SUSPECT -eq $zero ]]; then
                        #echo **ADDING $IP_STR TO SUSPECT FILE**
                        echo $IP_STR 1 >> suspect.log
                    fi
                fi
            fi
        fi
    done < failed_atmps.log
done
