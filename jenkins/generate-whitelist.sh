#!/bin/sh

curl https://api.github.com/repos/skydive-project/skydive/contributors | jq .[].login | cut -d '"' -f 2
