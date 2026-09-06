---
name: fetchurl-ssl-line-is-noise
description: The "SSL certificate OpenSSL verify result: unable to get local issuer certificate (20)" line in nixpkgs fetchurl/FOD build logs is benign - never diagnose it as a CA-trust or MITM problem
metadata:
  type: reference
---

In any nixpkgs fixed-output derivation (`fetchurl`, `fetchCrate`, `importCargoLock`
crate tarballs), a failing build log line like:

```
curl: (22) SSL certificate OpenSSL verify result: unable to get local issuer certificate (20)
```

is **noise, not the failure**. The FOD sets `SSL_CERT_FILE=/no-cert-file.crt` and runs
curl with `--insecure` on purpose - the output hash provides integrity, so cert
verification is deliberately skipped. curl prints the verify-result as an informational
note whenever `-k` is in effect.

**Why:** curl exit code **22 means "HTTP returned an error"**, not a TLS failure (that
would be exit 60). So the real cause is always the HTTP status on the *following* lines
(403/404/429), never the certificate.

**How to apply:** when a crate/tarball fetch fails, ignore the SSL line entirely and read
the HTTP code. Reproduce with a plain `curl -sSL -o /dev/null -w '%{http_code}'` against
the exact `urls` from `nix derivation show <drv>`. Do not investigate the system CA
bundle, `NIX_SSL_CERT_FILE`, proxies, or clock skew on the strength of that line alone.
Related: [[spec-contract-module-list-drift]].
