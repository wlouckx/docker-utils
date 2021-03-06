#!/bin/bash

## Description -------------------------------------------------------------------------- #
#  
#  REMARKS: Use this script at your own risk. It might not be compatible with your setup!
#
#  This script will get secret information for docker from a Bitwarden Vault. The script
#  will ask for the users credentials during run, unless they are provided as arugments.
#
#  Attention: The bitwarden vault should contain the secrets as a unique object and will
#             be added to the docker secrets with the name provided. Note that you can't
#             update docker secrets (docker limitation).
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
finished=1;
if [ "$finished" -ne 1 ]; then
    echo "Script is not ready. Terminating";
    exit 99;
fi


## -- Initialize all Vars -- ##
object='';
type='';
secret='';

skipinstall=0;
forceinstall=0;
silent=0;
installonly=0;

email='';
password='';
totp='';
bulkfile='';

code='';
2fa='';


## -- Functions -- ## 

function usage(){
    echo "
    Usage: $0 [OPTIONS]

    Options:
        Required:
        --object <object name>              The name of the object in Bitwarden
        --type <note|password>              Note: gets the notes field of a note object
                                            Password: Gets the password field of an object         
        --secret <secret name>              The name of the docker secret


        Optional:
        --skipinstall                       Skip the installation of requirements, overrides
                                            --forceinstall (also in silent mode).
        -f, --forceinstall                  Install the requirements without asking
        -s, --silent                        No output except for user interactions.
                                            --forceinstall is implied.
        --email <email>                     Email adres to login into Bitwarden
        --password <password>               The vaults master password
        --totp <key>                        Pass the Bitwarden TOTP base32 key for automatic
                                            login with 2FA. The code will be generated with
                                            oathtool. The tool will look for a file .totp
                                            regardess of this option
        --bulk <file>                       Create secrets in bulk with an input file (omits
                                            required fields). The file should contain one
                                            secret per line in following format:
                                            <object> <type> <secret name>
        --installonly                       Only install all necessary packages. This removes
                                            the need of the required options. --forceinstall
                                            is implied.

        -h, --help                          Print this message

    Example:
    $0 --object clientcert.key --type note --secret nginx_clientcert_key --forceinstall
    "
}

function getArgs() {
    while [ "$#" -gt 0 ]; do case $1 in
        -h|--help) usage; exit 0;;
        --object) object="$2"; shift;;
        --type) type="$2"; shift;;
        --secret) secret="$2"; shift;;
        --skipinstall) skipinstall=1;;
        -f|--forceinstall) forceinstall=1;;
        -s|--silent) silent=1; forceinstall=1;;
        --email) email="$2"; shift;;
        --password) password="$2"; shift;;
        --bulk) bulkfile="$2"; shift;;
        --totp) totp="$2"; shift;;
        --installonly) installonly=1; forceinstall=1;;
        *) >&2 echo "Unknown parameter passed: $1"; usage; exit 1;;
    esac; shift; done

    # validation of required fields
    if [ -z "$bulkfile" ] || [ "$installonly" -eq 0 ]; then
        if [ -z "$object" ]; then
            >&2 echo "Object not set";
            usage;
            exit 1;
        fi
        if [ -z "$type" ]; then
            >&2 echo "Type not set";
            usage;
            exit 1;
        fi
        if [ -z "$secret" ]; then
            >&2 echo "secret not set";
            usage;
            exit 1;
        fi
        if ! [[ "$type" == "note" || "$type" == "password" ]]; then
            >&2 echo "Type not equal to 'note' or 'password'";
            usage;
            exit 1;
        fi
    elif [ -n "$bulkfile" ] || [ "$installonly" -eq 0 ]; then
        if ! [ -r "$bulkfile" ]; then
            >&2 echo "Cannot read the inputfile $bulkfile";
        fi
    fi
}

function printOut() {                                                                              # Silent mode check
    if [ "$silent" -ne 1 ]; then
        echo $1;
    fi
}

function checkSudo(){                                                                              # Function to check elevated rights
    printOut "Checking elevated rights..."
    if [ "$EUID" -ne 0 ]; then
        >&2 echo "Please run as root/sudo";
        exit 1;
    else
        printOut "Ok.";
    fi
}


function checkBw(){                                                                                # Check for BW-cli, install if not present
    printOut "Checking if Bitwarden is installed..."
    if ! [ -x "$(command -v bw)" ]; then                            
        while true; do
            read -p "Bitwarden is not installed. Do you want to install Bitwarden? (Y/N):" yn
            case $yn in
                [Yy]* ) break;;
                [Nn]* ) exit 4;;
                * ) echo "Please answer with Y/N";;
            esac
        done
        apt-get install -y wget unzip && \
            wget -O bw.zip https://vault.bitwarden.com/download/?app=cli\&platform=linux && \
            unzip bw.zip -d /usr/local/bin/ && \
            chmod 755 /usr/local/bin/bw && \
            rm -f bw.zip;
        if ! [ -x "$(command -v bw)" ]; then
            >&2 echo "Failed to install Bitwarden CLI. Please install manually.";
            exit 1;
        else
            printOut "Bitwarden Installed.";
        fi
    else
        printOut "Ok.";
    fi
}

function checkJq(){                                                                                # Check for Jq, install if not present
    printOut "Checking if JQ is installed..."
    if ! [ -x "$(command -v jq)" ]; then
        if [ "$forceinstall" -ne 1 ]; then
            while true; do
                read -p "JQ is not installed. Do you want to install JQ? (Y/N):" yn
                case $yn in
                    [Yy]* ) break;;
                    [Nn]* ) exit 4;;
                    * ) echo "Please answer with Y/N";;
                esac
            done
        fi
        printOut "Installing JQ";
        apt-get install -y jq;
        if ! [ -x "$(command -v jq)" ]; then
            >&2 echo "Failed to install JQ. Please install manually.";
            exit 1;
        else
            printOut "JQ installed.";
        fi
    else
    printOut "Ok.";
    fi
}

function checkOath(){                                                                              # Check for Oathtool, install if not present
    printOut "Checking if oathtool is installed..."
    if ! [ -x "$(command -v oathtool)" ]; then
        if [ "$forceinstall" -ne 1 ]; then
            while true; do
                read -p "Oathtool is not installed. Do you want to install Oathtool? (Y/N):" yn
                case $yn in
                    [Yy]* ) break;;
                    [Nn]* ) exit 4;;
                    * ) echo "Please answer with Y/N";;
                esac
            done
        fi
        printOut "Installing Oathtool";
        apt-get install -y oathtool;
        if ! [ -x "$(command -v oathtool)" ]; then
            >&2 echo "Failed to install Oathtool. Please install manually.";
            exit 1;
        else
            printOut "Oathtool installed.";
        fi
    else
    printOut "Ok.";
    fi
}


function createSecret(){
    if [[ "$type" == "note" ]]; then
        bw --session $id get item "$object" | jq '.notes' | sed -e 's/\\n/\n/g' | sed s/\"// | docker secret create $secret -
    elif [[ "$type" == "password" ]]; then
        bw --session $id get password $object | docker secret create $secret -
    else
        >&2 echo "Unexpected error, type not set correctly";
        exit 1;
    fi 

}

function varInFile() {                                                                             # varInFile <variable>: Checks if variable is set, if not it will look for a file named .variable
    var=$1
    if [ -z "${!var}" ] && [ -r ".$var" ]; then                                                    # ${!var} returns the value of $var as name of a variable
        output=`head -1 .$var`;
        eval $var=\$output;                                                                        # Sets the value of output to the value of $var as variable. Escapes any special characters in output with \$
    fi
}

## -- Program -- ## 

getArgs "$@";                                                                                      # Read the arguments
checkSudo;                                                                                         # Check for elevated rights

if [ "$skipinstall" -ne 1 ]; then                                                                  # Install prereqs if not omitted
    printOut "Checking prerequisites...";
    checkBw;
    checkJq;
    checkOath;
else
    printOut "Skipping installation of prerequisites...";
fi

if [ "$installonly" -eq 0 ]; then
    printOut "
    Prechecks done

    Requesting Bitwarden session ID...";
    varInFile totp                                                                                 # check for key in .totp if any
    if [ -n "$totp" ]; then
        code=`oathtool -b --totp ${totp}`;
        2fa="--method 1 --code ${code}";
    fi
    
    varInFile email                                                                                # check for email in .email if any
    varInFile password                                                                             # check for password in .password

    id=`bw login ${email} ${password} ${code} --raw`;                                              # Get our Session ID
    if [ -z $id ]; then
        id=`bw unlock ${password}--raw`;
    fi

    printOut "Obtained session ID. Syncing Vault...";
    bw sync;
    printOut "Sync done. Creating secrets";

    if [ -r "$bulkfile" ]; then                                                                    # Check if we are in bulkmode and read file or execute single creation from arguments
        while read -r line; do
            read -ra arr <<<"$line"
            object=$arr[0];
            type=$arr[1];
            secret=$arr[2];
            if [ -n "$object" ] && [ -n "$type" ] && [ -n "$secret" ]; then
                createSecret;
            else
                >&2 echo "The following line does not contain 3 values: $line";
            fi
        done < $bulkfile
    else
        createSecret;
    fi
fi
exit 0;