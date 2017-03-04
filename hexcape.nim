# https://hookrace.net/blog/writing-a-2d-platform-game-in-nim-with-sdl2/#8-text-rendering
# http://piumarta.com/software/sdlprims/
# https://github.com/nim-lang/sdl2/blob/master/src/sdl2.nim
# https://nim-lang.org/docs/random.html#random,int
# https://nim-by-example.github.io/oop/
# https://nim-lang.org/docs/tut1.html#advanced-types-tuples
when defined(browser):
    from hexcapepkg.html5_game import main
else:
    from hexcapepkg.sdl_game import main

main()
