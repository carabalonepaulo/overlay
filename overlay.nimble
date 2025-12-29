# Package

version = "0.1.0"
author = "Paulo Carabalone"
description = "A new awesome nimble package"
license = "MIT"
srcDir = "src"
binDir = "bin"
namedBin = {"main": "overlay"}.toTable

# Dependencies

requires "nim >= 2.2.4"
requires "winim"
requires "pixie"
requires "results"
