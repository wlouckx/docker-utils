#!/bin/bash

## Description -------------------------------------------------------------------------- #
#  
#  REMARKS: THIS IS A TEMPLATE
#
#  Brief description of the script goes here. Regarding this script: This is just a
#  template, you've gotta believe me
#
#  Attention: Block for attention details
#
#  Exit Codes:
#   0:  Success
#   1:  Script ended with error
#   4:  Script ended by user choice (e.g. answer no during install requirements)
#   99: Script is not ready
#
#  More info in the usage function below.
#
## -------------------------------------------------------------------------------------- #        

# Development security
finished=0;
if [ "$finished" -ne 1 ]; then
    echo "Script is not ready. Terminating";
    exit 99;
fi


## -- Initialize all Vars -- ##

## -- Functions -- ## 

function usage(){
    echo "
    Usage: $0 [OPTIONS]

    Options:
        Required:
        --param <value>                     A required parameter with value
        --case <case1|case2>                A case, where the value has to match one of the
                                            given fields         

        Optional:
        --option1                           Optional parameter without value
        -s, --silent                        Short and long parameter

        -h, --help                          Print this message

    Example:
    $0 --help
    "
}

function getArgs() {
    while [ "$#" -gt 0 ]; do case $1 in
        -h|--help) usage; exit 0;;
        --param) value="$2"; shift;;
        --case) case="$2"; shift;;
        --option1) option1=1;;
        -s|--silent) silent=1;;
        *) >&2 echo "Unknown parameter passed: $1"; usage; exit 1;;
    esac; shift; done

    # validation of required fields
    if [ "$option1" -eq 0 ]; then                                                                  # Skip required fields of option1 is set
        if [ -z "$value" ]; then
            >&2 echo "param not set";
            usage;
            exit 1;
        fi
        if ! [[ "$case" == "case1" || "$case" == "case2" ]]; then
            >&2 echo "case not equal to 'case1' or 'case2'";
            usage;
            exit 1;
        fi
    elif [ "$option1" -eq 1 ]; then                                                                # Validation when option1 is set 
        echo "ok";
    fi
}

function printOut() {                                                                              # Silent mode check
    if [ "$silent" -ne 1 ]; then
        echo $1;
    fi
}


## -- Program -- ## 



exit 0;