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

Currently **only Linux** is supported due to limitations of `SecuredTransport` on MacOS.  
Specifically MacOS's SecuredTransport does not expose access to the [ALPN TLS extension](https://www.rfc-editor.org/rfc/rfc7301.txt). Once this limitation is removed we will add support for MacOS too.

## Features:

- HTTP/2 over TLS
- HTTP/2 over cleartext (unsecured) TCP

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


## Community

We love to talk server-side Swift, and Kitura. Join our [Slack](http://swift-at-ibm-slack.mybluemix.net/) to meet the team!

## License
This library is licensed under Apache 2.0. Full license text is available in [LICENSE](LICENSE.txt).
