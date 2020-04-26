# tidb-helper

Help TiDB become better. This repo is used for building TiDB automatically. 

### Generate Binaries/Packages

Generate binaries/pkgs in build/dist/:

```
make binary TAG=v3.0.7
make rpm TAG=v3.0.7
make deb TAG=v3.0.7
```

This will use docker as build environment, if you'd like to build without the need of docker, you may try:

```
make binary TAG=v3.0.7 BUILD_MODE=local
```

Make sure you've installed the needed packages.


### Install with rpm

[Docs](./INSTALL.md)
