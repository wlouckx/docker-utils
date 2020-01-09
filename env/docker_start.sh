#!/bin/bash

## Description -------------------------------------------------------------------------- #
#  
#  REMARKS: This script is unfinished and not tested
#           Use this script at your own risk. It might not be compatible with your setup!
#
#  This script checks out a git repo, loads secrets into docker, and runs 'docker stack
#  deploy'. This script can run with or without arguments.
#  The configuration can be specified by arguments, a specific config file, environment
#  variables, in a dockerstart.conf file, pre-configured in this file. 
#  If a file or git folder is not found, the task will be skipped. Other errors will 
#  result in EC 1.
#
#  Attention: the secrets.txt file should contain the secrets from Bitwarden in
#             following format:
#             <object> <type> <secret name>
#             Bitwarden totp base32 key has to be provided .totp, if needed for full
#             automation.
#             
#
#  Exit Codes:
#   0:  Success
#   1:  Script ended with error
#   4:  Script ended by user choice
#   99: Script is not ready
#
#  More info in the usage function below.
#
#
#
#
## -------------------------------------------------------------------------------------- #        

# Development security
finished=0;
if [ "$finished" -ne 1 ]; then
    echo "Script is not ready. Terminating";
    exit 99;
fi


## -- Initialize all Vars -- ##

# CONFIGURATION DEFAULTS (array)
declare -A CONFIG=(
    # Default files
    [secretfile]='secret.txt'
    [composefile]='docker-compose.yml'
    [config]='dockerstart.conf'
    [stack]=''
    
    # Flags
    [nogit]=0
    [nosecret]=0
    [nodocker]=0
    [silent]=0
)

# Environment config
declare -A ENVCONF=(
    [DS_SECRETFILE]=$DS_SECRETFILE
    [DS_COMPOSEFILE]=$DS_COMPOSEFILE
    [DS_CONFIG]=$DS_CONFIG
    [DS_NOGIT]=$DS_NOGIT
    [DS_NOSECRET]=$DS_NOSECRET
    [DS_NODOCKER]=$DS_NODOCKER
    [DS_SILENT]=$DS_SILENT
    [DS_STACK]=$DS_STACK
)


# TMP config from arguments
declare -A ARGS=(
    [secretfile]=''
    [composefile]=''
    [nogit]=''
    [nosecret]=''
    [nodocker]=''
    [silent]=''
    [stack]=''
)

createconfig=0;

## -- Functions -- ## 

function usage(){
    echo "
    Usage: $0 [OPTIONS] --stack <name>

    Options:
        Most likely required:
        --stack <name>                      Your docker stack name to deploy.      

        Optional:
        -g, --nogit                         Disable automatic git pull
        -S, --nosecret                      Disable secret creation
        --secretfile <file>                 Alternate file for secrets.txt
        -d, --nodocker                      Disable docker stack deploy
        --composefile <file>                Alternate file for docker-compose.y(a)ml
        --config <file>                     Alternate file for dockerstart.conf

        -s, --silent                        Silent mode.
        -h, --help                          Print this message
        --createconfig                      Creates a dockerstart.conf file (with the scripts'
                                            current build-in config). Use --config <file> to
                                            output to a different file name

    Environment variables:
        You can use Environment variables that will be read to this script. Note that option
        arguments or a config file as option will take precedence on environment variables.

        DS_SECRETFILE                       Full path of the secret file
        DS_COMPOSEFILE                      Full path of the compose docker-compose.yml file
        DS_CONFIG                           Full path of the config file.
                                              This will override other Env Vars when set in the
                                              config!
        DS_NOGIT                            When set to '1', Git pull is skipped
        DS_NOSECRET                         When set to '1', Secret creation is skipped
        DS_NODOCKER                         When set to '1', Stack deploy is skipped
        DS_SILENT                           When set to '1', silent mode is on.

    Cascading configuration:
        The script uses cascading configuration. This provides a fall back to defaults and the
        possibility to override a single config setting by a higher level.

        Priority sequence:
        1) Command Line arguments to the script
        2) Custom config file passed by argument or environment to the script
        3) Environment variables
        4) dockerstart.conf in the same directory as the script
        5) Default configuration in the script


    Example:
    $0 --help
    "
}

function getArgs() {
    while [ "$#" -gt 0 ]; do case $1 in
        -h|--help) usage; exit 0;;
        -g|--nogit) ARGS[nogit]=1;;
        -S|--nosecret) ARGS[nosecret]=1;;
        -d|--nodocker) ARGS[nodocker]=1;;
        --secretfile) ARGS[secretfile]="$2"; shift;;
        --composefile) ARGS[composefile]="$2"; shift;;
        --config) ARGS[config]="$2"; shift;;
        -s|--silent) silent=1;;
        --createconfig) createconfig=1;;
        --stack) ARGS[stack]=$2; shift;;
        *) >&2 echo "Unknown parameter passed: $1"; usage; exit 1;;
    esac; shift; done
}

function printOut() {                                                                              # Silent mode check
    if [ "$silent" -ne 1 ]; then
        echo $1;
    fi
}

function createConfig() {
    printOut "Creating ${CONFIG[config]}";
    for key in "${!CONFIG[@]}"; do 
    output+="$key=${CONFIG[$K]}";
    done
    cat <<< $output > ${CONFIG[config]}
    exit 0;
}

function canSudo() {                                                                               # Check if current user can sudo a certain command
    pass=1
    while [ "$#" -gt 0 ]; do
        sudo -l $1;
        if [ $? -ne 0 ]; then
            pass=0;
        fi
        shift;
    done
    
    if [ "$pass" -eq 1 ] ; then
        return true;
    else
        return false;
    fi
}

function checkGit() {                                                                              # Check if current folder is part of git repository
    if git rev-parse --is-inside-work-tree; then
        return true;
    else
        return false;
    fi
}

function readEnvironment () {
    for KEY in "${!ENVCONF[@]}"; do 
        key=$(sed -r 's/^.*\_(.*)/\L\1/' <<< ${KEY});                                              # Take KEY out of DS_KEY and make it key
        if [ -n "${ENVCONF[$KEY]}" ]; then                                                         # If a key is set, overwrite the current config
            CONFIG[$key]=${ENVCONF[$KEY]};
        fi
    done
}

function readConfig() {
    if [ -r ${CONFIG[config]} ]; then
        nocomments=$(sed '/^[[:blank:]]*#/d;s/#.*//' ${CONFIG[config]});                           # Clear out all the comments in a configuration file
        for line in $nocomments; do
            IFS== read key value <<< "$line"                                                       # Split line on '=' and store key and value
            if [ -n "$value" ]; then                                                               # If a key is set, overwrite the current config
                CONFIG[$key]=$value;
            fi
        fi
    fi
}

function readArgs () {
    for key in "${!ARGS[@]}"; do
        if [ -n "${ARGS[$key]}" ]; then                                                            # If a key is set, overwrite the current config
            CONFIG[$key]=${ARGS[$key]};
        fi
    done
}


## -- Program -- ## 
readConfig;                                                                                         # Read the default configfile
readEnvironment;                                                                                    # Read the environment
if [ -n "${ENVCONF[DS_CONFIG]}" ]; then
    readConfig;                                                                                     # Read the config file again cause it was (re-)specified in the environment
fi
getArgs "$@";
if [ -n "${ARGS[config]}" ]; then
    CONFIG[config]=${ARGS[config]};
    readConfig;                                                                                     # Read config file specified by arguments
fi
readArgs;                                                                                           # Read all arguments, if set, into the config as they have highest priority

if [ "$createconfig" -eq 1 ]; then
    createConfig;
    exit 0;
fi

# Prioritize params from Arguments


# Git pull
if [ "${CONFIG[nogit]}" -eq = 0 ] && checkGit; then
    printOut "This directory is a GIT repository";
    git pull;
else
    printOut "Not a GIT repository or manually disabled. Skipping git pull";
fi

# Create Secrets
if [ "${CONFIG[nosecret]}" -eq = 0 ] && [ -r "${CONFIG[secretfile]}" ]; then
    printOut "Checking necessary sudo rights...";
    if canSudo ./secret_init.sh docker; then
        printOut "Reading ${CONFIG[secretfile]} and creating secrets";
        if [ -x "secret_init.sh" ]; then
            sudo ./secret_init.sh --bulk ${CONFIG[secretfile]}
        else
            >&2 echo "Cannot find or execute secret_init.sh";
            exit 1;
        fi
    else 
        >&2 echo "You have not sufficient sudo rights to execute the secret creation commands";
        exit 1;
    fi
else
    printOut "No secret configuration found or manually disabled. Skipping secret creation";
fi

# Docker stack deploy
if [ "${CONFIG[nodocker]}" -eq 0 ] && [ -r "${CONFIG[dockerfile]}" ]; then
    if [ -z ${CONFIG[stack]} ]; then
        >&2 echo "No stack defined, exiting"
        exit 1;
    fi
    printOut "Checking necessary sudo rights...";
    if canSudo docker; then
        printOut "Reading ${CONFIG[dockerfile]} and creating executing docker stack deploy";
        sudo docker stack deploy -c ${CONFIG[dockerfile]} ${CONFIG[stack]}
    else 
        >&2 echo "You have not sufficient sudo rights to execute the docker commands";
        exit 1;
    fi
else
    printOut "No docker configuration found or manually disabled. Skipping docker stack deploy";
fi


## base logic

# automatic flow. Can be forced with arguments
# Check for git/secrets.txt/docker-compose.yml
# if git ok: git pull
# if secrets.txt: create secrets
# if docker-compose: stack deploy


exit 0;