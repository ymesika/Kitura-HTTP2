# Kitura-HTTP2

[![Build Status - Master](https://travis-ci.org/IBM-Swift/Kitura-HTTP2.svg?branch=master)](https://travis-ci.org/IBM-Swift/Kitura-HTTP2)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)
![Apache 2](https://img.shields.io/badge/license-Apache2-blue.svg?style=flat)
&nbsp;[![Slack Status](http://swift-at-ibm-slack.mybluemix.net/badge.svg)](http://swift-at-ibm-slack.mybluemix.net/)

HTTP/2 support for Kitura

## Summary
This package will add [HTTP/2](https://http2.github.io/http2-spec/) capabilities to your Kitura based server.

Using this package will allow modern browsers to connect to your web server with HTTP/2 protocol over secured connection. Once enabled (_see Usage_) and [security has been set](http://www.kitura.io/en/resources/tutorials/ssl.html) the web browsers will automatically use HTTP/2 protocols for their communication over the older versions (HTTP/1.1).

This package will also add to your server the support for using HTTP/2 protocol over cleartext connection by using the HTTP connection upgrade mechanism. However, keep in mind that web browsers are only supporting HTTP/2 over secured connection.

## Features:

- HTTP/2 over TLS
- HTTP/2 over cleartext (unsecured) TCP

## Prerequisites:
**OpenSSL v1.0.2** and above is required as ALPN is supported only in these versions.

Currently **only Linux** is supported due to limitations of `SecuredTransport` on MacOS.  
Specifically MacOS's SecuredTransport does not expose access to the [ALPN TLS extension](https://www.rfc-editor.org/rfc/rfc7301.txt). Once this limitation is removed we will add support for MacOS too.

## Usage:

1. **Import `KituraHTTP2`:**

  ```swift
  import KituraHTTP2
  ```

2. **Enable HTTP/2:**
  ```swift
  HTTP2.using(serverDelegate: myRouter)
  ```
  where `myRouter` is your _Router_ instance or any instance of _ServerDelegate_.

## Testing
The tests will tests HTTP/2 functionality only on Linux using Curl that has the HTTP2 feature.  
- Curl with HTTP/2 module is being used for the tests client. To install it follow these steps:  
  1. Get build requirements:
     ```shell
     sudo apt-get install binutils libcunit1-dev libssl-dev libxml2-dev libev-dev \
       libevent-dev libjansson-dev libjemalloc-dev cython python-setuptools build-essential
     ```
  2. Build nghttp2 from source:
     ```shell
     wget https://github.com/nghttp2/nghttp2/releases/download/v1.23.1/nghttp2-1.23.1.tar.bz2
     tar -xjf nghttp2-1.23.1.tar.bz2
     cd nghttp2-1.23.1
     autoreconf -i
     automake
     autoconf
     ./configure --enable-lib-only
     make --quiet
     sudo make install
     cd ..
     ```
  3. Build curl from source with the nghttp2 module:
     ```shell
     wget https://curl.haxx.se/download/curl-7.54.0.tar.bz2
     tar -xjf curl-7.54.0.tar.bz2
     cd curl-7.54.0
     ./configure --with-nghttp2 --prefix=/usr/local
     make --quiet
     sudo make install
     sudo ldconfig
     cd ..
     ```

- Make sure HTTP2 is now supported in Curl by executing:
```curl --version```.  
```HTTP2``` should be listed in the list of features.

- Run the tests by executing:
```swift test```.


## Community

We love to talk server-side Swift, and Kitura. Join our [Slack](http://swift-at-ibm-slack.mybluemix.net/) to meet the team!

## License
This library is licensed under Apache 2.0. Full license text is available in [LICENSE](LICENSE.txt).
