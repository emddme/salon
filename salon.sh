#!/bin/bash

#query key
PSQL="psql -A --username=vanpuffelen --dbname=salon --tuples-only -c"

#get time of day
hr=$(date "+%H")

if [[ $hr -gt  11 ]]
    then
        greet="afternoon";
    elif [[ $hr -gt  17 ]]
        then
            greet="evening";
    else
        greet="morning";
fi

#header & welcome message
echo -e "\n->->---------->> Salon Rikkestein <<----------<-<-"
echo -e "\nGood $greet, valued customer. What can we do for you today?\n"

## Menus
#get treatments and read request
MAIN_MENU() {
    if [[ ! -z $1 ]]
        then echo -e "\n$1\n";
    fi
    #get and present available treatments, prompt input
    
    PSQL="psql -A --username=vanpuffelen --dbname=salon --tuples-only --record-separator=\n -c"
    resp=$($PSQL "SELECT service_id,name FROM services");
    echo -e "$resp\n" | sed 's/|/) /g';
    read SERVICE_ID_SELECTED;
    CHECK_SERVICE_SELECTION;   
}



CUSTOMER_DETAILS_MENU() {
    echo -e "\nPlease enter your phone number:"
    read CUSTOMER_PHONE;
    #check if known customer
    resp=$($PSQL"SELECT name FROM customers WHERE phone='$CUSTOMER_PHONE'")
    if [[ -z $resp ]]
        then 
            #customer not known: ask name
            echo -e "\nPlease enter your name:"
            read CUSTOMER_NAME;
            resp=$($PSQL "INSERT INTO customers(name,phone) VALUES('$CUSTOMER_NAME','$CUSTOMER_PHONE')")
        else 
            #customer known: get name
            CUSTOMER_NAME=$($PSQL "SELECT name FROM customers WHERE phone='$CUSTOMER_PHONE'");
    fi
    APPOINTMENT_MENU;
}


APPOINTMENT_MENU() {
    if [[ ! -z $1 ]]
        then echo -e "\n$1\n";
    fi
    #get customer_id
    CUSTOMER_ID=$($PSQL "SELECT customer_id FROM customers WHERE phone='$CUSTOMER_PHONE'")
    #ask for time
    echo -e "\nWe have 30-min. time-slots availabe daily from 08:00 untill 17:30.\nAt what time would you like to schedule your appointment? Please enter hh:mm"
    read SERVICE_TIME;
    CHECK_SERVICE_TIME $SERVICE_TIME;
}

## Check-functions
#check service selection
CHECK_SERVICE_SELECTION() {
    PSQL="psql -A --username=vanpuffelen --dbname=salon --tuples-only -c"
    AVAILABLE=($($PSQL "SELECT service_id FROM services"));
    hit=false;
    for (( i = 0; i < ${#AVAILABLE[*]}; i++ ))
        do
            if [[ $SERVICE_ID_SELECTED == ${AVAILABLE[i]} ]]
                then
                    hit=true;
                    break;
            fi
        done
        if [[ $hit == true ]]
            then
                CUSTOMER_DETAILS_MENU;
            else 
                MAIN_MENU "Selected service not available, try again:";
        fi
}

#check service time format
CHECK_SERVICE_TIME() {
    #check for correct hh:mm input
    [[ ${1:0:5} =~ ^[0-1][0-9]:[30][0]$ ]]
    if [[ $? == 0 ]]
        then 
        CHECK_TIMESLOT;
        return
    fi
    [[ ${1:0:5} =~ ^2[0-3]:[30][0]$ ]]
    if [[ $? == 0 ]]
        then 
        CHECK_TIMESLOT
        return
    fi
    #check and reformat am/pm input
    if [[ ${#1} == 3 && ${1:1:2} == 'am' && ${1:0:1} =~ [0-9] ]]
        then 
        SERVICE_TIME=$(echo $1 | sed -E 's/(^[0-9]).*/0\1:00/');
        CHECK_TIMESLOT
        
    elif [[ ${#1} == 4 && ${1:2:2} == 'am' && (${1:0:2} == 10 || ${1:0:2} == 11) ]]
        then
        SERVICE_TIME=$(echo $1 | sed -E 's/(^[0-9]+).*/\1:00/');
        CHECK_TIMESLOT
        
    elif [[ ${#1} == 4 && ${1:2:2} == 'am' && ${1:0:2} == 12 ]]
        then
        SERVICE_TIME='00:00';
        CHECK_TIMESLOT
        
    elif [[ ${#1} == 3 && ${1:1:2} == 'pm' && ${1:0:1} =~ [0-9] ]]
        then
        HOURS=$(( ${1:0:1} + 12 ))
        SERVICE_TIME=$(echo "$HOURS:00");
        CHECK_TIMESLOT
        
    elif [[ ${#1} == 4 && ${1:2:2} == 'pm' && (${1:0:2} == 10 || ${1:0:2} == 11 || ${1:0:2} == 12) ]]
        then
        HOURS=$(( ${1:0:2} + 12 ))
        SERVICE_TIME=$(echo "$HOURS:00");
        CHECK_TIMESLOT
        
    else 
        APPOINTMENT_MENU "Time entry invalid"
    fi
}

#check timeslot
CHECK_TIMESLOT() {
    if [[ $SERVICE_TIME =~ ^08:00|08:30|09:00|09:30|10:00|10:30|11:30|12:00|12:30|13:00|13:30|14:00|14:30|15:00|15:30|16:30|17:00|17:30$ ]]
        then
            #check for availability timeslot
            resp=$($PSQL "SELECT appointment_id FROM appointments WHERE time='$SERVICE_TIME'");
            if [[ -z $resp ]]
                then
                    resp=$($PSQL "INSERT INTO appointments(time, customer_id, service_id) VALUES('$SERVICE_TIME',$CUSTOMER_ID,$SERVICE_ID_SELECTED)");
                    SERVICE=$($PSQL "SELECT name FROM services WHERE service_id=$SERVICE_ID_SELECTED");
                    echo -e "\nI have put you down for a $SERVICE at $SERVICE_TIME, $CUSTOMER_NAME.\n"
                else 
                    echo -e "\nWe're sorry, we're attending another customer at that time. Please try a different time:";
                    APPOINTMENT_MENU;
            fi
        else
            echo -e "\nPlease select a whole or half hour beteen 08:00 and 17:30";
            APPOINTMENT_MENU;
    fi
}

MAIN_MENU;

