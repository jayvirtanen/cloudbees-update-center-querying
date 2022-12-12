#!/bin/bash
UC_URL="https://jenkins-updates.cloudbees.com/update-center/envelope-cje/update-center.json?version=2.303.3.3"
wget -q -O - $UC_URL | sed '1d' | sed '$d' > uc.json

LENGTH=$(cat plugins.yaml | yq '.plugins.[]' | wc -l)

NULL=$((LENGTH--))

declare -a PLUGIN_ARRAY

declare -a DEP_ARRAY

for i in `seq 0 1 $LENGTH`
do    
  PLUGIN=$(cat plugins.yaml | yq ".plugins.[$i]")
  arrPLUGIN=(${PLUGIN//:/ })
  PLUGIN_ARRAY[i]=${arrPLUGIN[1]}
done

echo "Versions for listed plugins:" > plugins.txt

for i in "${PLUGIN_ARRAY[@]}"
do
    jq -r --arg NAME "$i" '[.plugins[] | {name: .name, version: .version } | select(.name==$NAME)  ]' uc.json \
  | dsq -s json 'select name, version from {}' >> plugins.txt
done

echo "Dependency plugins:" >> plugins.txt

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

echo ${#DEP_ARRAY[@]}
UNIQUE_DEPS=($(echo "${DEP_ARRAY[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
echo ${#UNIQUE_DEPS[@]}

for i in "${UNIQUE_DEPS[@]}"
do
    echo $i >> plugins.txt
done