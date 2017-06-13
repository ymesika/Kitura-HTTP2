#!/bin/bash

mkdir curl_build
cd curl_build

# Get nghttp2 build requirements
sudo apt-get install binutils libcunit1-dev libssl-dev libxml2-dev libev-dev \
  libevent-dev libjansson-dev libjemalloc-dev cython python-setuptools

# Build nghttp2 from source
wget https://github.com/nghttp2/nghttp2/releases/download/v1.23.1/nghttp2-1.23.1.tar.bz2
tar -xvjf nghttp2-1.23.1.tar.bz2
cd nghttp2-1.23.1
autoreconf -i
automake
autoconf
./configure --enable-lib-only
make
sudo make install
cd ..

# Get curl build requirements
sudo apt-get install build-essential

# Build curl from source
wget https://curl.haxx.se/download/curl-7.54.0.tar.bz2
tar -xvjf curl-7.54.0.tar.bz2
cd curl-7.54.0
./configure --with-nghttp2 --prefix=/usr/local
make
sudo make install
sudo ldconfig
cd ..

cd ..
 
curl --version
