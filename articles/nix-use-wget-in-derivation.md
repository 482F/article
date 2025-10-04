---
title: "Nix derivation 内で wget する"
emoji: "🗒"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Neovim", "Lua"]
published: false
---

```nix
(pkgs.stdenv.mkDerivation {
  name = "fetch-test";
  buildCommand = ''
    echo $HTTPS_PROXY
    echo $SSL_CERT_FILE
    ls $SSL_CERT_FILE
    # ${pkgs.curl}/bin/curl -vvv https://ipconfig.io
    ${pkgs.wget}/bin/wget -vvv --ca-certificate=$SSL_CERT_FILE --timeout 2 https://ipconfig.io
    mkdir -p $out/bin
    mv index.html $out/bin/network-test.sh
    chmod 744 $out/bin/network-test.sh
  '';
  HTTP_PROXY = "http://172.21.252.1:12080";
  HTTPS_PROXY = "http://172.21.252.1:12080";
  http_proxy = "http://172.21.252.1:12080";
  https_proxy = "http://172.21.252.1:12080";
  SSL_CERT_FILE = "${
    pkgs.cacert.override {
      extraCertificateStrings = builtins.attrValues env.pki.certificates;
    }
  }/etc/ssl/certs/ca-bundle.crt";
  outputHash = "0jad1y9b341c4pajc3xpzmxih6xpdbdkpq5y7wk43j8fafkb0q6j";
  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
})
```
