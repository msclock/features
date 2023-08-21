
# Vcpkg Tool (vcpkg)

A vcpkg tool feature

## Example Usage

```json
"features": {
    "ghcr.io/msclock/features/vcpkg:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| username | Enter name of a non-root user to configure or none to skip | string | automatic |
| vcpkgversion | Enter vcpkg version tag or stable or latest | string | latest |
| vcpkgroot | Enter VCPKGROOT as vcpkg root path | string | /usr/local/vcpkg |
| vcpkgdownload | Enter VCPKGDOWNLOAD as vcpkg download path | string | /usr/local/vcpkg-downloads |

## Customizations

### VS Code Extensions

- `ms-vscode.cpptools`
- `ms-vscode.cmake-tools`
- `twxs.cmake`

## Using vcpkg

This feature includes [vcpkg package manager](https://github.com/microsoft/vcpkg). If CMake is not installed in advance, a suitable version will be installed into the path `/usr/local/bin/cmake` automatically from vcpkg.

## OS Support

This Feature should work on recent versions of Debian/Ubuntu, RedHat Enterprise Linux, Fedora, RockyLinux, and Alpine Linux.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/msclock/features/blob/main/src/vcpkg/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
