# CA certificate bundle

`cacert.pem` is the Mozilla CA certificate store converted to PEM by curl.

Source:

https://curl.se/ca/cacert.pem

Update with:

```bash
curl -fsSL https://curl.se/ca/cacert.pem -o resources/certs/cacert.pem
```

Keep this file bundled for LuaSec/OpenSSL clients on platforms where a system CA
store is not reliably available through LuaSec.
