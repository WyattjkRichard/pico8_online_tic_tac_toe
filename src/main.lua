function _init()
    poke(0x5f2d, 0x1)   -- enable mouse and keyboard

    -- registers
    player_value_reg = 0x5f80 + 0 -- either host (0) or guest (1)
    rw_indicator_reg = 0x5f80 + 1 -- no data (0), data written (1), data to read (2)
    connection_status_reg = 0x5f80 + 2 -- waiting to connect (0), connected (1), disconnected (2)
    game_board_reg_offset = 0x5f80 + 3 -- offset for registers containing the current game state

    game_board = {{0, 0, 0}, {0, 0, 0}, {0, 0, 0}}

    x, y, x_coord, y_coord, winner = 0, 0, 0, 0, 0

    player_value = peek(player_value_reg)
    if player_value == 0 then
        is_player_turn = true
    else
        is_player_turn = false
    end
end

function _update()

    connection_status = peek(connection_status_reg)

    -- for testing
    -- connection_status = 1
    -- end testing

    if connection_status == 0 then
        -- waiting to connect
    elseif connection_status == 1 then
        -- connected
        x, y = mid(stat(32), 0, 127), mid(stat(33), 0, 127)
        x_coord, y_coord = check_coords(x, y)

        if is_player_turn then
            if stat(34) & 1 == 1 then
                if game_board[x_coord][y_coord] == 0 then
                    game_board[x_coord][y_coord] = player_value + 1
                    is_player_turn = false
                    export_game_board()
                    poke(rw_indicator_reg, 1)
                    winner = check_for_winner()
                end
            end
        else
            -- wait for guest to make a move
            if peek(rw_indicator_reg) == 2 then
                import_game_board()
                is_player_turn = true
                poke(rw_indicator_reg, 0)
                winner = check_for_winner()
            end
        end

    elseif connection_status == 2 then
        -- disconnected
    end
end

function _draw()
    cls()
    if winner != 0 then
        print("player "..winner.." wins", 0, 0, 7)
    elseif connection_status == 0 then
        -- waiting to connect
        if player_value == 0 then
            print("you are the host", 0, 0, 7)
            print("waiting for guest to connect", 0, 10, 7)
            print("send them the link bellow", 0, 20, 7)
            print("paste their link in the empty \nfield", 0, 30, 7)
        elseif player_value == 1 then
            print("you are the guest", 0, 0, 7)
            print("send the link bellow to the host", 0, 10, 7)
        end
    elseif connection_status == 1 then
        -- connected
        draw_game_board()
        draw_cursor(x, y)
        if is_player_turn then
            draw_ghost(x_coord, y_coord)
        end

        -- debug info
        --[[
        print("x: "..x, 0, 0, 7)
        print("y: "..y, 0, 10, 7)
        print("x_coord: "..x_coord, 0, 20, 7)
        print("y_coord: "..y_coord, 0, 30, 7)
        --]]
        -- end debug info
    elseif connection_status == 2 then
        -- disconnected
        print("connection lost", 0, 0, 7)
    end

    
end

function draw_game_board()
    line( 42, 0, 42, 127, 7 )
    line( 85, 0, 85, 127, 7 )
    line( 0, 42, 127, 42, 7 )
    line( 0, 85, 127, 85, 7 )

    for i = 1, 3 do
        for j = 1, 3 do
            if game_board[i][j] == 1 then
                circ((i * 42) - 21, (j * 42) - 21, 15, 7)
            elseif game_board[i][j] == 2 then
                line((i * 42) - 36, (j * 42) - 36, (i * 42) - 6, (j * 42) - 6, 7)
                line((i * 42) - 36, (j * 42) - 6, (i * 42) - 6, (j * 42) - 36, 7)
            end
        end
    end
end

function draw_cursor(x, y)
    spr(1, x, y)
    spr(2, x + 8, y)
    spr(16, x - 8, y + 8)
    spr(17, x, y + 8)
    spr(18, x + 8, y + 8)
    spr(33, x, y + 16)
    spr(34, x + 8, y + 16)
end

function draw_ghost(x, y)
    if game_board[x][y] == 0 then
        if player_value == 0 then
            circ((x * 42) - 21, (y * 42) - 21, 15, 7)
        else
            line((x * 42) - 36, (y * 42) - 36, (x * 42) - 6, (y * 42) - 6, 7)
            line((x * 42) - 36, (y * 42) - 6, (x * 42) - 6, (y * 42) - 36, 7)
        end
    end
end

function check_coords(x, y)
    x = mid(flr(x / 42) + 1, 1, 3)
    y = mid(flr(y / 42) + 1, 1, 3)
    return x, y
end

function export_game_board()
    for i = 1, 3 do
        for j = 1, 3 do
            poke(game_board_reg_offset + (i - 1)*3 + j - 1, game_board[i][j])
        end
    end
end

function import_game_board()
    val = 0
    for i = 1, 3 do
        for j = 1, 3 do
            game_board[i][j] = peek(game_board_reg_offset + (i - 1)*3 + j - 1)
        end
    end
end

function check_for_winner()
    -- check rows
    for i = 1, 3 do
        if game_board[i][1] == game_board[i][2] and game_board[i][2] == game_board[i][3] and game_board[i][1] ~= 0 then
            return game_board[i][1]
        end
    end

    -- check columns
    for i = 1, 3 do
        if game_board[1][i] == game_board[2][i] and game_board[2][i] == game_board[3][i] and game_board[1][i] ~= 0 then
            return game_board[1][i]
        end
    end

    -- check diagonals
    if game_board[1][1] == game_board[2][2] and game_board[2][2] == game_board[3][3] and game_board[1][1] ~= 0 then
        return game_board[1][1]
    end

    if game_board[1][3] == game_board[2][2] and game_board[2][2] == game_board[3][1] and game_board[1][3] ~= 0 then
        return game_board[1][3]
    end

    return 0
end

-- online multiplayer tic tac toe
-- on boot up, the game will check the webpage to see if they are host or guest (player_value will be set via js)
-- host will make the fist move
-- once a move is made, pico will set two gpio pins, one to indicate that there is data to be sent and one that contains the game state
-- webrts will transmit the game state to the guest
-- the guest will then make a move and send the game state back to the host



-- poke / peek bytes between 0x5f80 and 0x5fff
-- values between 0 and 255

-- to export to webplayer, run 'export mygame.html' in pico-8 console

-- to read/write values in js:
-- var pico8_gpio = new Array(128);
-- pico8_gpio[0] = 10;
