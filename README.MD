## My notes on how to query the CloudBees Update Centers



This snippet is some extensible code that helps query the UpdateCenter for plugins in various ways. It uses `jq` and [`dsq`](https://github.com/multiprocessio/dsq). Not the fairly plain sql statement that could be more complicated if desired.

``` sh
export ENVELOPE=envelope-cje
export VERSION=2.303.3.3

wget -q -O - "https://jenkins-updates.cloudbees.com/update-center/$ENVELOPE/update-center.json?version=$VERSION" | sed '1d' | sed '$d' > uc.json

jq '[.plugins | .[] | {buildDate, gav, groupId, name, releaseTimestamp, requiredCore, sha1, title, url, version}]' uc.json \
  | dsq -s json 'select name, version from {}' \
  | jq -r '(map(keys) | add | unique) as $cols | map(. as $row | $cols | map($row[.])) as $rows | $cols, $rows[] | @csv'
```

Note that the ENVELOPE variable is product- _and_ component-specific.
