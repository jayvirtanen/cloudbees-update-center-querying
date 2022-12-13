#!/bin/bash

show_help() {
cat << EOF
Usage: ${0##*/} -v <CI_VERSION> [-f <path/to/plugins.yaml>]
    -f FILE     path to the plugins.yaml file
    -v          The version of CloudBees CI (e.g. 2.263.4.2)
EOF
}

CI_VERSION=

while getopts hv:f opt; do
    case $opt in
        h)
            show_help
            exit 0
            ;;
        v)  CI_VERSION=$OPTARG
            ;;
        f)  PLUGIN_YAML_PATH=$OPTARG
            ;;
        *)
            show_help >&2
            exit 1
            ;;
    esac
done

CB_UPDATE_CENTER=${CB_UPDATE_CENTER:="https://jenkins-updates.cloudbees.com/update-center/envelope-core-mm"}
UC_URL="$CB_UPDATE_CENTER/update-center.json?version=$CI_VERSION"
PLUGIN_YAML_PATH="plugins.yaml"

echo "fetching update center:"
echo $UC_URL

wget -q -O - $UC_URL | sed '1d' | sed '$d' > uc.json

LENGTH=$(cat plugins.yaml | yq '.plugins.[]' | wc -l)

$((LENGTH--)) >/dev/null 2>&1

for i in `seq 0 1 $LENGTH`
do    
  PLUGIN=$(yq e ".plugins.[$i]" $PLUGIN_YAML_PATH)
  arrPLUGIN=(${PLUGIN//:/ })
  PLUGIN_ARRAY[i]=${arrPLUGIN[1]}
done

echo "Versions for listed plugins:" > plugins.txt

echo "Checking Update Center for versions of listed plugins..."

for i in "${PLUGIN_ARRAY[@]}"
do
  PLUG=$(jq -r --arg NAME "$i" '[.plugins[] | {name: .name, version: .version } | select(.name==$NAME)  ]' uc.json \
  | dsq -s json 'select name, version from {}')
  PLUG_ARRAY+=($PLUG)
  echo $PLUG >> plugins.txt
done

echo "Dependency plugins:" >> plugins.txt

echo "Checking Update Center for versions of plugin dependencies..."

for i in "${PLUGIN_ARRAY[@]}"
do
   DEPS=$(jq -r --arg NAME "$i" '[.plugins[] | {name: .name, dep: .dependencies[].name  } | select(.name==$NAME)  ]' uc.json | jq '.[].dep')
   x=($DEPS)
   for j in "${x[@]}"
   do
    j=$(echo "$j" | tr -d '"')
    DEP=$(jq -r --arg NAME "$j" '[.plugins[] | {name: .name, version: .version } | select(.name==$NAME)  ]' uc.json \
    | dsq -s json 'select name, version from {}')
    DEP_ARRAY+=($DEP)
    done
done

UNIQUE_DEPS=($(echo "${DEP_ARRAY[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
ALL_PLUGINS=("${PLUG_ARRAY[@]}" "${UNIQUE_DEPS[@]}")
UNIQUE_PLUGS=($(echo "${ALL_PLUGINS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

echo "Printing results to plugins.txt"

for i in "${UNIQUE_DEPS[@]}"
do
    echo $i >> plugins.txt
done

echo "Total Plugin List:" >> plugins.txt

for i in "${UNIQUE_PLUGS[@]}"
do
    echo $i >> plugins.txt
done