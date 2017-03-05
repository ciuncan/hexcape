# Package

version       = "1.0"
author        = "Ceyhun Can ULKER"
description   = "An open-source puzzle game written in Nim using SDL, inspired by WayOut 2: Hex."
license       = "MIT"

bin           = @["hexcape"]
# binDir        = "bin"

# Dependencies

requires "nim >= 0.10.0"
requires "sdl2 >= 1.1"
requires "html5_canvas >= 0.1.0"

task html5, "Generate HTML5 game":
    bin = @["hexcape.js"]
    exec "nim js -d:browser hexcape.nim"

task index, "":
    exec "touch www/index.html"
    exec "rm www/index.html"
    exec "touch www/index.html"
    exec "cat www/_index_pre.html   | tee -a www/index.html > /dev/null"
    exec "cat nimcache/hexcape.js   | tee -a www/index.html > /dev/null"
    exec "cat www/_index_post.html  | tee -a www/index.html > /dev/null"

task serve, "Serve html files":
    exec "cd www; http-server"