# Package

version       = "0.0.1"
author        = "waxodium"
description   = "A fluid, customizable clock app in the terminal"
license       = "Apache-2.0"
srcDir        = "src"
bin           = @["tickterm"]


# Dependencies

requires "nim >= 2.2.10"
requires "parsetoml"
requires "cligen"
