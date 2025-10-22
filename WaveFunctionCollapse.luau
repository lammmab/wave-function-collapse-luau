math.randomseed(os.time()) -- randomize seed as much as possible
math.random(); math.random(); math.random()

local MinHeap = {}
MinHeap.__index = MinHeap

function MinHeap.new()
    return setmetatable({items = {}}, MinHeap)
end

local function swap(tbl, i, j)
    tbl[i], tbl[j] = tbl[j], tbl[i]
end

local function parent(i) return math.floor(i / 2) end
local function leftChild(i) return i * 2 end
local function rightChild(i) return i * 2 + 1 end

function MinHeap:insert(entropy, tile)
    local node = {entropy = entropy, tile = tile}
    table.insert(self.items, node)
    local i = #self.items

    while i > 1 and self.items[i].entropy < self.items[parent(i)].entropy do
        swap(self.items, i, parent(i))
        i = parent(i)
    end
end

function MinHeap:peek()
    return self.items[1]
end

function MinHeap:pop()
    local size = #self.items
    if size == 0 then return nil end

    swap(self.items, 1, size)
    local minNode = table.remove(self.items)
    self:heapify(1)
    return minNode
end

function MinHeap:heapify(i)
    local l = leftChild(i)
    local r = rightChild(i)
    local smallest = i

    if l <= #self.items and self.items[l].entropy < self.items[smallest].entropy then
        smallest = l
    end
    if r <= #self.items and self.items[r].entropy < self.items[smallest].entropy then
        smallest = r
    end
    if smallest ~= i then
        swap(self.items, i, smallest)
        self:heapify(smallest)
    end
end

local ANY = "*"

local WaveFunctionCollapse = {}
WaveFunctionCollapse.__index = WaveFunctionCollapse

local Direction = {
    N = "N",
    E = "E",
    S = "S",
    W = "W"
}

local OppositeDirection = {
    [Direction.N] = Direction.S,
    [Direction.E] = Direction.W,
    [Direction.S] = Direction.N,
    [Direction.W] = Direction.E
}

type Vec2 = {
    x: number,
    y: number
}

local DirectionOffset = {
    [Direction.N] = {x = 0, y = -1},
    [Direction.E] = {x = 1, y = 0},
    [Direction.S] = {x = 0, y = 1},
    [Direction.W] = {x = -1, y = 0}
}


type Tile = {
    pos: Vec2, -- x and y of tile on grid
    name: string, -- name of tile
    neighbors: { Vec2? }, -- neighbors of tiles
    possible: { string }, -- possible states as names
    collapsed: boolean, -- collapsed state
    id: number -- unique ID
}

type Tileset = {
    tiles: { string }, -- all tiles in tileset
    rules: { [string]: { table } } -- all rules in adjacency rules
}

type Map = {
    tileset: Tileset, -- a reference to all possible tiles
    width: number, -- the width of the grid (in tiles)
    height: number, -- the height of the grid (in tiles)
    grid: { { Tile } } -- the actual grid
}

local function createGrid(width: number, height: number, tileset: Tileset)
    local grid = {}
    local tilesize = #tileset.tiles


    local heap = MinHeap.new()
    for x = 1, width do
        grid[x] = {}
        for y = 1, height do
            local possible_tiles = {}
            for i=1,tilesize do
                local tile = tileset.tiles[i]
                table.insert(possible_tiles,tile)
            end

            local id = tostring(x + y * width)
            local tile = {
                pos = {
                    x = x,
                    y = y,
                },
                name = "",
                neighbors = {},
                possible = possible_tiles,
                collapsed = false,
                id = id,
                entropy = tilesize,
            } :: Tile

            grid[x][y] = tile
            heap:insert(tile.entropy,tile)
        end
    end

    return grid, heap
end

local function supportCounts(createdGrid, tileset, width, height)
    local support = {}
    for x = 1, width do
        for y = 1, height do
            local cell = createdGrid[x][y]
            support[cell.id] = {}
            for _, tile_name in ipairs(tileset.tiles) do
                support[cell.id][tile_name] = {}
                for _, dir in pairs(Direction) do
                    local offset = DirectionOffset[dir]
                    local nx, ny = cell.pos.x + offset.x, cell.pos.y + offset.y

                    local count = 0
                    if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
                        for _, neighbor_tile in ipairs(tileset.tiles) do
                            local rules = tileset.rules[tile_name][dir] or {}
                            for _, valid in ipairs(rules) do
                                if valid == neighbor_tile then
                                    count = count + 1
                                end
                            end
                        end
                    end
                    support[cell.id][tile_name][dir] = count
                end
            end
        end
    end
    return support
end

function WaveFunctionCollapse.new(tileset: Tileset, width: number, height: number): typeof(WaveFunctionCollapse)
    if type(tileset) ~= "table" then
        error("WFC: variable tileset must be a table!")
    end

    if type(width) ~= "number" or type(height) ~= "number" then
        error("WFC: width and height must both be numbers!")
    end

    local self = setmetatable({}, WaveFunctionCollapse)

    local createdGrid,entropies = createGrid(width, height, tileset)

    self.entropies = entropies

    self.support = supportCounts(createdGrid, tileset, width, height)

    self.current_map = {
        tileset = tileset,
        width = width,
        height = height,
        grid = createdGrid,
    } :: Map

    return self
end

function WaveFunctionCollapse:GetLowestEntropy()
    return self.entropies:pop()
end

function WaveFunctionCollapse:AdjustEntropy(tile)
    tile.entropy = #tile.possible
    if tile.entropy > 0 then
        self.entropies:insert(tile.entropy, tile)
    end
end

function WaveFunctionCollapse:CheckAdjacency(cell, tile_name, direction)
    local rules = self.current_map.tileset.rules[tile_name][direction] or {}

    for _, valid in ipairs(rules) do
        if valid == ANY then
            return true
        end
    end


    local support_count = self.support[cell.tile.id][tile_name][direction]
    return support_count > 0
end

function WaveFunctionCollapse:Propagate(collapsed_cell: Tile)
    local queue = {}
    local head, tail = 1, 0

    local function enqueue(cell)
        tail += 1
        queue[tail] = cell
    end

    local function dequeue()
        if head > tail then return nil end
        local cell = queue[head]
        queue[head] = nil
        head += 1
        return cell
    end
    enqueue(collapsed_cell)

    while head <= tail do
        local cur_cell = dequeue()
        if #cur_cell.tile.neighbors == 0 then
            self:GetNeighbors(cur_cell)
        end

        for direction,neighbor in pairs(cur_cell.tile.neighbors) do
            if not neighbor then continue end -- skip non-existent neighbors (likely goes off-grid)
            local neighborTile = neighbor -- get the neighboring tile
            if neighborTile.collapsed then continue end -- skip collapsed neighbors
            if #neighborTile.possible == 0 then return false end -- if there's no possible choices, the algorithm has reached a dead end

            local changed = false
            for i = #neighborTile.possible, 1, -1 do
                local tile_name = neighborTile.possible[i]
                if not self:CheckAdjacency(cur_cell, tile_name, direction) then
                    changed = true
                    table.remove(neighborTile.possible, i)
                    local oppDir = OppositeDirection[direction]

                    for _, cur_tile_name in ipairs(cur_cell.possible) do
                        if self.support[neighborTile.id][cur_tile_name][oppDir] then
                            self.support[neighborTile.id][cur_tile_name][oppDir] -= 1
                        end
                    end
                end
            end

            if changed then
                self:AdjustEntropy(neighborTile)
                enqueue(neighborTile)
            end
        end
    end

    return true
end

function WaveFunctionCollapse:Collapse(cell: Tile)

    if #cell.tile.possible == 0 then return false end

    local chosen = cell.tile.possible[math.random(1,#cell.tile.possible)]
    if not chosen then return false end

    cell.tile.collapsed = true
    cell.tile.name = chosen

    return true
end

function WaveFunctionCollapse:GetNeighbors(cell: Tile)
    local cell = cell.tile
    cell.neighbors = {
        [Direction.N] = (cell.pos.y > 1) and self.current_map.grid[cell.pos.x][cell.pos.y-1] or nil,
        [Direction.E] = (cell.pos.x < self.current_map.width) and self.current_map.grid[cell.pos.x+1][cell.pos.y] or nil,
        [Direction.S] = (cell.pos.y < self.current_map.height) and self.current_map.grid[cell.pos.x][cell.pos.y+1] or nil,
        [Direction.W] = (cell.pos.x > 1) and self.current_map.grid[cell.pos.x-1][cell.pos.y] or nil,
    }
end

function WaveFunctionCollapse:MapToTable()
    local t = {}
    for x=1,self.current_map.width do
        t[x] = {}
        for y=1,self.current_map.height do
            t[x][y] = self.current_map.grid[x][y].name
        end
    end
    return t
end

function WaveFunctionCollapse:Run()
    local failed = false
    while not failed and self.entropies:peek() do
        local cell = self:GetLowestEntropy()
        if not self:Collapse(cell) then
            print("Collapse failed.")
            failed = true
            break
        end
        if not self:Propagate(cell) then
            failed = true
            print("Propagate failed.")
            break
        end
    end

    if not failed then
        return self:MapToTable()
    end

    return false
end

return WaveFunctionCollapse
