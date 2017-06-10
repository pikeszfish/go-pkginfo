#!/usr/bin/env bash
# go-pkginfo
# Usage: pkginfo.sh -d ~/go/src/github.com/docker/docker

print_usage() {
    echo "Usage: "
    echo "  pkginfo [-d /go/src/github.com/docker/docker] [-r] [-v] [-t] [-h]"
}

while getopts "d:hrvt" opt; do
  case $opt in
    h)
      print_usage
      exit 0
      ;;
    r)
      RECURSION=true
      ;;
    d)
      DIR="$OPTARG"
      ;;
    v)
      VERBOSE=true
      ;;
    t)
      TRANSLATION=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument" >&2
      exit 1;
      ;;
  esac
done


DIR="${DIR:-`pwd`}"
RECURSION="${RECURSION:-false}"
VERBOSE="${VERBOSE:-false}"
TRANSLATION="${TRANSLATION:-false}"


# #github.com/x/x##github.com/y/y##github.com/z/z#
IMPORT_IN_ONE_LINE=""
ALL_PATH=($DIR)

grep_file_github_import() {
    file_path=$1
    grep -E "github.com/" ${file_path} | awk -F '[]"/[]' '{if ($2=="github.com")printf "%s/%s/%s\n", $2,$3,$4;if ($3=="github.com")printf "%s/%s/%s\n", $3,$4,$5}' | uniq
}

go_get_info() {
    pkg_name=$1
    curl -sSL "https://"${pkg_name} | tac | tac | head -n 50 | grep -E "<title>.*</title>" | awk -F '[<>]' '{print $3}'
}

go_translate_it() {
    info=$@
    curl -sSL "http://fanyi.youdao.com/openapi.do?keyfrom=awf-Chinese-Dict&key=19965805&version=1.1&type=data&doctype=json&q=${info}" | python -c "import json;import sys;print json.loads(sys.stdin.read())['translation'][0].encode('utf-8');"
}

index=1
while [ ${#ALL_PATH[@]} -gt 0 ]; do
    current_path_num=${#ALL_PATH[@]}
    current_path=${ALL_PATH[${current_path_num}-1]}
    unset ALL_PATH[${current_path_num}-1]
    for f in `ls ${current_path}/*.go 2>/dev/null`; do
        for ipt in `grep_file_github_import $f`; do
            if [[ ${IMPORT_IN_ONE_LINE} != *"#"${ipt}"#"* ]]
            then
                IMPORT_IN_ONE_LINE=${IMPORT_IN_ONE_LINE}"#"${ipt}"#"
                printf "\E[32m%3d. ${ipt}\n\E[0m" ${index}
                index=$(($index+1))

                if [ "${TRANSLATION}" == true ]; then
                    real_info=`go_get_info ${ipt}`
                    echo "        ${real_info}"
                    echo "        `go_translate_it ${real_info}`"
                    echo ""
                elif [ "${VERBOSE}" == true ]; then
                    real_info=`go_get_info ${ipt}`
                    echo "       ${real_info}"
                    echo ""
                fi
            fi
        done
    done

    # echo $RECURSION
    if [ "$RECURSION" == false ]; then
        break
    fi

    for p in `find ${current_path} -maxdepth 1 -type d | tail -n +2`; do
        ALL_PATH=("${ALL_PATH[@]}" $p)
    done

done
