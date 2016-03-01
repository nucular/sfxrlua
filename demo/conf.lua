function love.conf(t)
    t.version = love._version:match("0%.9%.%d+") or "0.9.x"
    t.window.width = 640
    t.window.height = 600
    t.window.title = "sfxr.lua Demo"
end
