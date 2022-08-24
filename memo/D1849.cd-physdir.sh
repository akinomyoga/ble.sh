#!/usr/bin/env bash

mkdir -p tmp1
cd tmp1
touch hello.txt
(cd ..; mv tmp1 tmp2)
save_pwd1=$PWD
echo -n "1 $PWD "; pwd
ls -la

echo "# cd -L ."
cd -L .
PWD=$save_pwd1
echo -n "2 $PWD "; pwd

echo "# cd $save_pwd1"
cd "$save_pwd1"
echo -n "3 $PWD "; pwd


cd ..
rm -rf tmp1 tmp2
