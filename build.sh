#!/bin/bash

set -o verbose

mkdir curl_build
cd curl_build
sudo apt-get install build-essential nghttp2 libnghttp2-dev
wget https://curl.haxx.se/download/curl-7.54.0.tar.bz2
tar -xvjf curl-7.54.0.tar.bz2
cd curl-7.54.0
./configure --with-nghttp2 --prefix=/usr/local
make
sudo make install
sudo ldconfig
cd ..
cd ..
