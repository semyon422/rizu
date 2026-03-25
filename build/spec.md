
Rizu build system.

Targets 3 OS: Windows, Linux, MacOS.
Targets 1 arch: x86_64

Build system works on Ubuntu.

3 stages:
- deps fetch and extract
- binary cross compilation
- packaging: zip archive with full game and repo folder for updater



Deps (archives) should be downloaded to `build/downloads` folder.
Deps (archives) should be extracted to `build/deps` folder.
Deps (git repos) should be cloned to `build/deps` folder.



Packaging stage produces this file structure:
    build/repo/
        files.json
        rizu_macos.zip/rizu.app/
        macos/rizu.app/
        rizu.zip/rizu/
        rizu/
