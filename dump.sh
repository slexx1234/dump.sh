#!/usr/bin/env bash

set -e

#########################################
# Constants
#########################################

readonly D_START=$(pwd)
readonly START_TIME=`date +%s`

# Colors
readonly C_ERROR="\e[1;31m"
readonly C_RESET="\e[0m"
readonly C_SUCCESS="\e[1;32m"
readonly C_INFO="\e[1;34m"

# Error codes
readonly E_UNKNOWN_OPTION=1
readonly E_INVALID_OPTION=2
readonly E_DIRECTORY_IS_NOT_CREATED=3
readonly E_DUMP_FAILED=4
readonly E_COPY_FAILED=5
readonly E_DUMP_ZERO_SIZE=6
readonly E_REMOVE_FAILED=7

#########################################
# Text functions
#########################################

error () {
    echo -e "  ${C_ERROR}ERROR: ${1}${C_RESET}"
}

success () {
    echo -e "  ${C_SUCCESS}${1}${C_RESET}"
}

info () {
    echo -e "  ${C_INFO}${1}${C_RESET}"
}

text () {
    echo -e "  ${1}"
}

nl () {
    echo ""
}

#########################################
# ART
#########################################

nl
success "DUMP.SH"
nl
info "Repository: https://github.com/slexx1234/dump.sh"
info "Licence:    MIT"
nl

#########################################
# Commands
#########################################

command_help () {
    text "Commands:"
    nl
    echo -e "  ${C_INFO}help${C_RESET}               - Getting help"
    echo -e "  ${C_INFO}authors${C_RESET}            - Show authors"
    nl
    text "Options:"
    nl
    echo -e "  ${C_INFO}-r or --root${C_RESET}       - Directory to save dumps ${C_ERROR}(required)${C_RESET}"
    echo -e "  ${C_INFO}-u or --user${C_RESET}       - MySQL user name ${C_ERROR}(required)${C_RESET}"
    echo -e "  ${C_INFO}-p or --password${C_RESET}   - MySQL password ${C_SUCCESS}(nullable)${C_RESET}"
    echo -e "  ${C_INFO}-h or --host${C_RESET}       - MySQL host ${C_SUCCESS}(default: localhost)${C_RESET}"
    echo -e "  ${C_INFO}-d or --database${C_RESET}   - MySQL databases"
    exit 0
}

command_authors () {
    success "ALEKSEI SHCHEPKIN"
    info "Role:    Developer"
    info "Email:   slexx1234@gmail.com"
    info "GitHub:  https://github.com/slexx1234"
    info "WebSite: https://slexx1234.netlify.com/"
    exit 0
}

#########################################
# Run commands
#########################################

if [ -z $1 ]
then
    command_help
else
    case $1 in
        help)
        command_help
        ;;

        authors)
        command_authors
        ;;
    esac
fi

#########################################
# Parse options
#########################################

NAMES=()

for i in "$@"
do
case $i in
    -r=*|--root=*)
    # Trim slash
    d="${i#*=}"
    [[ ${d:length-1:1} == "/" ]] && d=${d:0:length-1}; :
    readonly O_DIRECTORY=${d}
    shift
    ;;

    -u=*|--user=*)
    readonly O_USER="${i#*=}"
    shift
    ;;

    -p=*|--password=*)
    readonly O_PASSWORD="${i#*=}"
    shift
    ;;

    -h=*|--host=*)
    readonly O_HOST="${i#*=}"
    readonly O_IP="${O_HOST%%:*}"
    readonly O_PORT="${O_HOST##*:}"
    shift
    ;;

    -d=*|--database=*)
    NAMES=( "${NAMES[@]}" "${i#*=}" )
    shift
    ;;

    *)
    error "Unknown option!"
    exit ${E_UNKNOWN_OPTION}
    ;;
esac
done

#########################################
# Functions
#########################################

make_directory_if_not_exists () {
    if ! [ -d ${1} ]
    then
        if mkdir -p ${1}
        then
            info "Directory \"${1}\" created"
        else
            error "Directory \"${1}\" is not created!"
            exit ${E_DIRECTORY_IS_NOT_CREATED}
        fi
    fi
}

remove_file_if_exists () {
    if [ -f ${1} ]
    then
        if ! rm -f ${1}
        then
            error "Failed \"${1}\" remove file!"
            exit ${E_REMOVE_FAILED}
        fi
    fi
}

copy_file () {
    if ! cp ${1} ${2}
    then
        error "Failed copy file from \"${1}\" to \"${2}\""
        exit ${E_COPY_FAILED}
    fi
}

dump () {
    if ! [ -z ${O_PASSWORD} ]
    then
        if ! mysqldump --user=${O_USER} --host=${O_IP} --port=${O_PORT} --password=${O_PASSWORD} ${1} | gzip > ${2}
        then
            return 1
        fi

        return 0
    fi

    if ! mysqldump --user=${O_USER} --host=${O_HOST} --port=${O_PORT} ${1} | gzip > ${2}
    then
        return 1
    fi

    return 0
}

#########################################
# Validate options
#########################################

if [ -z ${O_DIRECTORY} ]
then
    error "Directory option is required!"
    exit ${E_INVALID_OPTION}
fi

if [ -z ${O_USER} ]
then
    error "User option is required!"
    exit ${E_INVALID_OPTION}
fi

if [ -z ${O_DIRECTORY} ]
then
    error "Directory option is required!"
    exit ${E_INVALID_OPTION}
fi

if [ -z ${O_IP} ]
then
    readonly O_IP="localhost"
fi

if [ -z ${O_PORT} ]
then
    readonly O_PORT=3306
fi

#########################################
# Create directories if not exists
#########################################

make_directory_if_not_exists ${O_DIRECTORY}/test
make_directory_if_not_exists ${O_DIRECTORY}/monthly
make_directory_if_not_exists ${O_DIRECTORY}/daily
make_directory_if_not_exists ${O_DIRECTORY}/hourly

#########################################
# Run
#########################################

for name in "${NAMES[@]}"
do
    info "Start dump \"${name}\" database"

    file="${O_DIRECTORY}/test/${name}.sql.gz"
    monthly="${O_DIRECTORY}/monthly/${name}_`date +\%Y_\%M`.sql.gz"
    daily="${O_DIRECTORY}/daily/${name}_`date +\%u`.sql.gz"
    hourly="${O_DIRECTORY}/hourly/${name}_`date +\%H`.sql.gz"

    remove_file_if_exists ${file}
    dump ${name} ${file}

    # Check size
    if ! [ -s ${file} ]
    then
        error "Dump is empty!"
        remove_file_if_exists ${file}
        exit ${E_DUMP_ZERO_SIZE}
    fi

    # Remove old files and copies
    remove_file_if_exists ${monthly}
    remove_file_if_exists ${daily}
    remove_file_if_exists ${hourly}

    copy_file ${file} ${monthly}
    copy_file ${file} ${daily}
    copy_file ${file} ${hourly}

    remove_file_if_exists ${file}
done

# Finish
cd ${D_START}
info "Script execution time $((`date +%s`-START_TIME)) seconds"
