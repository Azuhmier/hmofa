#!/bin/bash

#header
script_name=`basename $0`
echo "The name of this script is $script_name."

#json diff
diff -u <(sort ./json/masterbin2.json | sed 's/,$//') <(sort ./json/masterbin.json | sed 's/,$//')
diff -u <(sort ./json/catalog2.json   | sed 's/,$//') <(sort ./json/catalog.json   | sed 's/,$//')
diff -u <(sort ./json/hmofa_lib3.json | sed 's/,$//') <(sort ./json/hmofa_lib.json | sed 's/,$//')

#txt file diff
diff -u ~/hmofa/hmofa/tagCatalog.txt ./result/catalog.txt
diff -u ~/hmofa/hmofa/masterbin.txt  ./result/masterbin.txt
diff -u ./result/hmofa_lib.txt ./result/hmofa_lib2.txt

