love.window.setTitle("Palette Town")

function love.load()
    showText = true
    font = love.graphics.newFont("font/PixelifySans-VariableFont_wght.ttf", 26)

    wf = require 'libraries/windfield'
    world = wf.newWorld()

	anim8 = require 'libraries/anim8'
    love.graphics.setDefaultFilter("nearest", "nearest")

    sti = require 'libraries/sti'
    gameMap = sti('maps/johto.lua')

    scale = 1.5
    camera = require 'libraries/camera'
    cam = camera()
    cam.scale = scale

    player = {}
    highlight = {}

    player.collider = world:newRectangleCollider(138, 130, 30, 30)
    player.collider:setFixedRotation(true)

    player.sx = 3.0
    player.sy = 3.0

    player.rotation = 0

    player.ox = 6
    player.oy = 9

    player.verticalSpeed = 300
    player.horizontalSpeed = 300

    player.rotationSpeed = nil

    player.spriteSheet = love.graphics.newImage('sprites/player-sheet.png')
    player.grid = anim8.newGrid(12, 18, player.spriteSheet:getWidth(), player.spriteSheet:getHeight())

    highlight.spriteSheet = love.graphics.newImage('sprites/highlight.png')
    highlight.grid = anim8.newGrid(36, 36, highlight.spriteSheet:getWidth(), highlight.spriteSheet:getHeight())

    highlight.anim = anim8.newAnimation(highlight.grid('1-8', 1, '7-2', 1), 0.1)

    player.animations = {}
    player.animations.down = anim8.newAnimation(player.grid('1-4', 1), 0.1)
    player.animations.up = anim8.newAnimation(player.grid('1-4', 4), 0.1)
    player.animations.right = anim8.newAnimation(player.grid('1-4', 3), 0.1)
    player.animations.left = anim8.newAnimation(player.grid('1-4', 2), 0.1)

    player.anim = player.animations.down

    walls = {}
    if gameMap.layers["Walls"] then
        for i, obj in pairs(gameMap.layers["Walls"].objects) do
            local wall = world:newRectangleCollider(obj.x, obj.y, obj.width, obj.height)
            wall:setType("static")
            table.insert(walls, wall)
        end
    end

    sounds = {}
    sounds.music = love.audio.newSource("sounds/Who's Ready for Tomorrow.flac", "stream")
    sounds.kojima = love.audio.newSource("sounds/invisible.flac", "stream")
    sounds.music:setLooping(true)
    sounds.kojima:setLooping(true)

    gameState = "world"

    combatPositions = {
        {x1 = 14, x2 = 17, y1 = 12, y2 = 14},
        {x1 = 14, x2 = 17, y1 = 32, y2 = 34},
        {x1 = 14, x2 = 17, y1 = 22, y2 = 24}
    }

    combat = {score = 5, duration = 30, timer = 30,
        heart = {x = 0, y = 0, size = 14, speed = 250, color = {0, 1, 1}},

        attacks = {},
        spawnTimer = 0,
        spawnInterval = 0.45,

        arena = {
            x = 0,
            y = 0,
            width = 400,
            height = 300
        },

        result = ""
    }

    combat.heart.complement = {
        1 - combat.heart.color[1],
        1 - combat.heart.color[2],
        1 - combat.heart.color[3]
    }
end

function love.update(dt)
    if (player.collider:getY() < (40 * gameMap.tileheight)) then
        if not sounds.music:isPlaying() then
            sounds.kojima:stop()
            sounds.music:play()
        end
    elseif (player.collider:getY() >= (40 * gameMap.tileheight)) then
        if not sounds.kojima:isPlaying() then
            sounds.music:stop()
            sounds.kojima:play()
        end
    end

    local isMoving = false
    local vx = 0
    local vy = 0

    if gameState == "world" then
        if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
            isMoving = true
            player.anim = player.animations.right
            vx = player.horizontalSpeed
        end

        if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
            isMoving = true
            player.anim = player.animations.left
            vx = player.horizontalSpeed * -1
        end

        if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
            isMoving = true
            player.anim = player.animations.up
            vy = player.verticalSpeed * -1
        end
        if love.keyboard.isDown("down") or love.keyboard.isDown("s") then
            isMoving = true
            player.anim = player.animations.down
            vy = player.verticalSpeed
        end
    end

    player.collider:setLinearVelocity(vx, vy)

    if isMoving == false then
        player.anim:gotoFrame(2)
    end

    world:update(dt)
    player.x = player.collider:getX()
    player.y = player.collider:getY() - 10

    player.anim:update(dt)
    highlight.anim:update(dt)

    cam:lookAt(player.x, player.y)

    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    local viewW = w / scale
    local viewH = h / scale

    local mapW = gameMap.width * gameMap.tilewidth
    local mapH = gameMap.height * gameMap.tileheight

    if mapW >= viewW then
        cam.x = math.max(viewW / 2, math.min(mapW - viewW / 2, cam.x))
    else
        cam.x = mapW / 2
    end

    if mapH >= viewH then
        cam.y = math.max(viewH / 2, math.min(mapH - viewH / 2, cam.y))
    else
        cam.y = mapH / 2
    end

    if gameState == "combat" then
            updateCombat(dt)
            return
        end

    if gameState == "result" then
        return
    end
end

function love.draw()
    highlight.x1 = 15 * gameMap.tilewidth
    highlight.y1 = 13 * gameMap.tileheight
    highlight.x2 = 15 * gameMap.tilewidth
    highlight.y2 = 23 * gameMap.tileheight
    highlight.x3 = 15 * gameMap.tileheight
    highlight.y3 = 33 * gameMap.tileheight

    final = {}
    final.x = 32 * gameMap.tilewidth
    final.y = 47 * gameMap.tileheight
    final.x2 = 3 * gameMap.tilewidth
    final.y2 = 47 * gameMap.tileheight

    if gameState == "world" then

        cam:attach()
        gameMap:drawLayer(gameMap.layers["Terrain"])
        gameMap:drawLayer(gameMap.layers["Ground"])
        gameMap:drawLayer(gameMap.layers["MiscDown"])
        highlight.anim:draw(highlight.spriteSheet, highlight.x1, highlight.y1, 0, 2.5, 2.5, 11.5, 16)
        highlight.anim:draw(highlight.spriteSheet, highlight.x2, highlight.y2, 0, 2.5, 2.5, 11.5, 16)
        highlight.anim:draw(highlight.spriteSheet, highlight.x3, highlight.y3, 0, 2.5, 2.5, 11.5, 16)
        gameMap:drawLayer(gameMap.layers["MiscMiddleDown"])
        love.graphics.print("THE END", final.x, final.y)
        love.graphics.print("You are the Biggest Boss.", final.x2, final.y2)
        player.anim:draw(player.spriteSheet, player.x, player.y, player.rotation, player.sx, player.sy, player.ox, player.oy)
        gameMap:drawLayer(gameMap.layers["MiscMiddleUp"])
        gameMap:drawLayer(gameMap.layers["MiscUp"])
        cam:detach()
        if showText then
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(font)
            love.graphics.print("Press ENTER or F near a Statue\n                      to interact.", 210, 30, 0)
            love.graphics.setColor(1, 1, 1)
        end

    elseif gameState == "instructions" then
        drawInstructions()
    elseif gameState == "combat" then
        drawCombat()
    elseif gameState == "result" then
        drawResult()
    end
end

function isCombatTile()
    local tileX = math.floor(player.x / gameMap.tilewidth) + 1
    local tileY = math.floor(player.y / gameMap.tileheight) + 1

    for i, position in ipairs(combatPositions) do
        if (position.x1 <= tileX and tileX <= position.x2) and (position.y1 <= tileY and tileY <= position.y2) then
            showText = false
            return i
        end
    end

    return false
end

function love.keypressed(key)
    if gameState == "world" then
        if key == "return" or key == "f" or key == "F" then
            local position = isCombatTile()
            if position then
                startCombat(position)
            end
        end
    elseif gameState == "instructions" then
        if key == "return" or key == "f" or key == "F" then
            gameState = "combat"
        end
    elseif gameState == "result" then
        if key == "return" or key == "f" or key == "F" then
            gameState = "world"
        end
    end
end

function startCombat(position)
    gameState = "instructions"
    combat.combatType = position

    combat.score = 5
    combat.timer = combat.duration

    combat.attacks = {}
    combat.spawnTimer = 0

    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    combat.arena.width = math.min(500, w - 60)
    combat.arena.height = math.min(350, h - 150)

    combat.arena.x = (w - combat.arena.width) / 2
    combat.arena.y = (h - combat.arena.height) / 2 + 20

    combat.heart.x = w / 2
    combat.heart.y = combat.arena.y + combat.arena.height - 50

    if combat.combatType == 2 then
        local shades = {
            {0, 0.5, 0.5},
            {0, 0.75, 0.75},
            {0, 1, 1},
            {0.25, 1, 1},
            {0.5, 1, 1}
        }

        combat.heart.color = shades[math.random(#shades)]

    elseif combat.combatType == 3 then
        local colors = {
            {1, 0, 0},
            {0, 1, 0},
            {0, 0, 1},
            {1, 1, 0},
            {1, 0, 1},
            {0, 1, 1},
            {1, 0.5, 0},
            {0.5, 0, 1},
            {1, 0.5, 0.5},
            {0.5, 1, 0.5},
            {0.5, 0.5, 1},
            {1, 1, 1}
        }

        combat.heart.color = colors[math.random(#colors)]
        combat.heart.complement = {
            1 - combat.heart.color[1],
            1 - combat.heart.color[2],
            1 - combat.heart.color[3]
        }
    end
end

function spawnAttack()
    local arena = combat.arena

    local attack = {}

    attack.x = arena.x + math.random(10, arena.width - 30)
    attack.y = arena.y - 20

    attack.width = 18
    attack.height = 18

    attack.speed = math.random(180, 300)

    if combat.combatType == 1 then
        local colors = {
            {1, 0, 0},
            {0, 1, 0},
            {0, 0, 1},
            {1, 1, 0},
            {1, 0, 1},
            {0, 1, 1}
        }

        if math.random(1, 2) == 1 then
            attack.type = "same"
            attack.color = combat.heart.color
        else
            attack.type = "different"
            repeat
                attack.color = colors[math.random(#colors)]
            until attack.color[1] ~= combat.heart.color[1] or
                attack.color[2] ~= combat.heart.color[2] or
                attack.color[3] ~= combat.heart.color[3]
        end
    elseif combat.combatType == 2 then
            local shades = {
                {0, 0.5, 0.5},
                {0, 0.75, 0.75},
                {0, 1, 1},
                {0.25, 1, 1},
                {0.5, 1, 1}
            }
    
            if math.random(1, 2) == 1 then
                attack.type = "same"
                attack.color = combat.heart.color
            else
                attack.type = "different"
                repeat
                    attack.color = shades[math.random(#shades)]
                until attack.color[1] ~= combat.heart.color[1] or
                    attack.color[2] ~= combat.heart.color[2] or
                    attack.color[3] ~= combat.heart.color[3]
            end
        else
            local colors = {
                {1, 0, 0},
                {0, 1, 0},
                {0, 0, 1},
                {1, 1, 0},
                {1, 0, 1},
                {0, 1, 1},
                {1, 0.5, 0},
                {0.5, 0, 1},
                {1, 0.5, 0.5},
                {0.5, 1, 0.5},
                {0.5, 0.5, 1},
                {1, 1, 1}
            }
    
            if math.random(1, 2) == 1 then
                attack.type = "same"
                attack.color = combat.heart.complement
            else
                attack.type = "different"
                repeat
                    attack.color = colors[math.random(#colors)]
                until attack.color[1] ~= combat.heart.complement[1] or
                    attack.color[2] ~= combat.heart.complement[2] or
                    attack.color[3] ~= combat.heart.complement[3]
            end
        end
        table.insert(combat.attacks, attack)
end

function updateCombat(dt)
    combat.timer = combat.timer - dt

    local heart = combat.heart
    local arena = combat.arena

    local vx = 0
    local vy = 0

    if gameState == "combat" then
        if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
            vx = -heart.speed
        end

        if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
            vx = heart.speed
        end

        if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
            vy = -heart.speed
        end

        if love.keyboard.isDown("down") or love.keyboard.isDown("s") then
            vy = heart.speed
        end
    end

    heart.x = heart.x + vx * dt
    heart.y = heart.y + vy * dt

    heart.x = math.max(
        arena.x + heart.size / 2,
        math.min(arena.x + arena.width - heart.size / 2, heart.x)
    )

    heart.y = math.max(
        arena.y + heart.size / 2,
        math.min(arena.y + arena.height - heart.size / 2, heart.y)
    )

    combat.spawnTimer = combat.spawnTimer + dt

    if combat.spawnTimer >= combat.spawnInterval then
        combat.spawnTimer = 0
        spawnAttack()
    end

    for i = #combat.attacks, 1, -1 do
        local attack = combat.attacks[i]

        attack.y = attack.y + attack.speed * dt

        local collision =
            heart.x - heart.size / 2 < attack.x + attack.width / 2 and
            heart.x + heart.size / 2 > attack.x - attack.width / 2 and
            heart.y - heart.size / 2 < attack.y + attack.height / 2 and
            heart.y + heart.size / 2 > attack.y - attack.height / 2

        if collision then
            if attack.type == "same" then
                combat.score = combat.score + 1
            else
                combat.score = combat.score - 5
            end

            table.remove(combat.attacks, i)
        elseif attack.y > arena.y + arena.height - 8 then
            table.remove(combat.attacks, i)
        end
    end

    if combat.score <= 0 then
        combat.score = 0
        combat.result = "Game Over."
        gameState = "result"
    elseif combat.timer <= 0 then
        combat.timer = 0
        combat.result = "Time's up!"
        gameState = "result"
    end
end

function drawInstructions()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    love.graphics.clear(0, 0, 0)

    love.graphics.setColor(1, 1, 1)

    local title = ""
    local text = ""

    if combat.combatType == 1 then
        title = "Hue"
        text = "Move using WASD or the arrow keys.\n\nCollect projectiles that match the heart's colour to gain points.\nAvoid projectiles with different colours, or you will lose points."

    elseif combat.combatType == 2 then
        title = "Saturation"
        text = "Move using WASD or the arrow keys.\n\nCollect projectiles that match the heart's shade to gain points.\nAvoid projectiles with different shades, or you will lose points."

    else
        title = "Complementary"
        text = "Move using WASD or the arrow keys.\n\nCollect projectiles that match the heart's complementary colour to gain points.\nAvoid projectiles with different colours, or you will lose points."
    end

    love.graphics.printf(
        title,
        0,
        h / 2 - 150,
        w,
        "center"
    )

    love.graphics.printf(
        text,
        w / 2 - 250,
        h / 2 - 70,
        500,
        "center"
    )

    love.graphics.printf(
        "Press ENTER or F to start",
        0,
        h / 2 + 180,
        w,
        "center"
    )
end

function drawHeart(x, y, size, color)
    love.graphics.setColor(color)

    local s = size / 2

    love.graphics.polygon("fill",
        x, y + s * 0.8,
        x - s, y,
        x - s, y - s * 0.5,
        x - s * 0.5, y - s,
        x, y - s * 0.5,
        x + s * 0.5, y - s,
        x + s, y - s * 0.5,
        x + s, y
    )

    love.graphics.setColor(1, 1, 1)
end

function drawCombat()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    local arena = combat.arena
    local heart = combat.heart

    love.graphics.clear(0, 0, 0)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(4)

    love.graphics.rectangle(
        "line",
        arena.x,
        arena.y,
        arena.width,
        arena.height
    )

    for _, attack in ipairs(combat.attacks) do
        love.graphics.setColor(attack.color)

        love.graphics.rectangle(
            "fill",
            attack.x - attack.width / 2,
            attack.y - attack.height / 2,
            attack.width,
            attack.height
        )
    end

    drawHeart(
        heart.x,
        heart.y,
        heart.size,
        heart.color
    )

    love.graphics.setColor(1, 1, 1)

    love.graphics.print(
        "Score: " .. combat.score,
        arena.x,
        arena.y + arena.height + 20
    )

    love.graphics.printf(
        "Time: " .. math.ceil(combat.timer),
        arena.x,
        arena.y + arena.height + 20,
        arena.width,
        "right"
    )

    local text = ""

    if combat.combatType == 1 then
        text = "Hue: Match the heart's colour!"
    elseif combat.combatType == 2 then
        text = "Saturation: Match the heart's shade!"
    else
        text = "Complementary: Match the heart's complementary colour!"
    end

    love.graphics.printf(
        text,
        arena.x,
        arena.y - 80,
        arena.width,
        "center"
    )

    love.graphics.setColor(1, 1, 1)
end

function drawResult()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    love.graphics.clear(0, 0, 0)

    love.graphics.setColor(1, 1, 1)

    love.graphics.printf(
        combat.result,
        0,
        h / 2 - 50,
        w,
        "center"
    )

    love.graphics.printf(
        "Final Score: " .. combat.score,
        0,
        h / 2,
        w,
        "center"
    )

    love.graphics.printf(
        "Press ENTER or F to exit.",
        0,
        h / 2 + 70,
        w,
        "center"
    )
end