#!/bin/bash

show_help() {
cat << EOF
Usage: ${0##*/} -v <CI_VERSION> [-f <path/to/plugins.yaml>]
    -f FILE     path to the plugins.yaml file
    -v          The version of CloudBees CI (e.g. 2.263.4.2)
EOF
}

CI_VERSION=2.263.4.2
PLUGIN_YAML_PATH="plugins.yaml"

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

echo "fetching update center:"
echo $UC_URL

wget -q -O - $UC_URL | sed '1d' | sed '$d' > uc.json

LENGTH=$(cat plugins.yaml | yq '.plugins.[]' | wc -l)

#Decrements plugin list length to loop through and build into array
$((LENGTH--)) >/dev/null 2>&1
for i in `seq 0 1 $LENGTH`
do    
  PLUGIN=$(yq e ".plugins.[$i]" $PLUGIN_YAML_PATH)
  arrPLUGIN=(${PLUGIN//:/ })
  PLUGIN_ARRAY[i]=${arrPLUGIN[1]}
done

echo "Versions for listed plugins:" > plugins.txt
echo "Checking Update Center for versions of listed plugins..."

#Pulls the versions of the plugins listed in the plugins.yaml from the JSON provided by the UC
for i in "${PLUGIN_ARRAY[@]}"
do
  PLUG=$(jq -r --arg NAME "$i" '[.plugins[] | {name: .name, version: .version } | select(.name==$NAME)  ]' uc.json \
  | dsq -s json 'select name, version from {}')
  PLUG_ARRAY+=($PLUG)
  echo $PLUG >> plugins.txt
done

echo "Dependency plugins:" >> plugins.txt
echo "Checking Update Center for versions of plugin dependencies..."

#Pulls the dependencies of the requested plugins from the UC JSON and then fetches the versions of those plugins from the UC JSON
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

#Deduplicates dependency array and then combines with first array which is then deduped again
UNIQUE_DEPS=($(echo "${DEP_ARRAY[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
ALL_PLUGINS=("${PLUG_ARRAY[@]}" "${UNIQUE_DEPS[@]}")
UNIQUE_PLUGS=($(echo "${ALL_PLUGINS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

echo "Printing results to plugins.txt"

#writes complete array list to file
for i in "${UNIQUE_DEPS[@]}"
do
    echo $i >> plugins.txt
done

echo "Total Plugin List:" >> plugins.txt
echo '{"plugins":[' > plugins.json

#Combines all JSON objects from array into single object
for i in "${UNIQUE_PLUGS[@]}"
do
    echo $i >> plugins.txt
    CLEAN=$(echo $i |sed 's/[][]//g')
    echo $CLEAN"," >> plugins.json
done

echo "Building new_plugins.yaml..."
#trims hanging comma and adds close bracket to complete json file and convert it to yaml
sed -r '$s/(.*),/\1 /' plugins.json > trimmed.json
echo ']}' >> trimmed.json
cat trimmed.json | yq -P > new_plugins.yaml

echo "Cleaning YAML..."
#remove version fields and correct spacing
sed -i '' '/version/d' new_plugins.yaml
sed -i '' 's/name/id/g' new_plugins.yaml
sed -i '' 's/  id/- id/g' new_plugins.yaml

echo "Cleaning up temp files..."
rm plugins.json
rm trimmed.json

echo "New Plugins.yaml"
cat new_plugins.yaml