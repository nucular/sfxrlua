package = "sfxr"
version = "0.0.2-1"
source = {
  url = "git://github.com/nucular/sfxrlua",
  tag = "v0.0.2"
}
description = {
  summary = "A port of the sfxr sound effect synthesizer to Lua",
  detailed = [[
    A port of the sfxr sound effect synthesizer to pure Lua, designed to be used
    together with the awesome LÖVE game framework.
  ]],
  homepage = "https://github.com/nucular/sfxrlua",
  license = "MIT/X11"
}
dependencies = {
  "lua ~> 5.1"
  -- bitop?
}
build = {
  type = "builtin",
  modules = {
    sfxr = "sfxr.lua"
  },
  copy_directories = {
    "docs"
  }
}
