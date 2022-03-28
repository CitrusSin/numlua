local numlua = {}

-- Util functions

local function isTensor(obj)
    if type(obj) == "table" then
        return obj.numlua_mark == 'numlua_tensor'
    end
    return false
end

local function assertTensor(obj)
    if not isTensor(obj) then
        error('Not a tensor')
    end
end

local function safeGetShape(obj)
    if type(obj) == "number" then
        return {}
    elseif isTensor(obj) then
        return obj._shape
    elseif type(obj) == "table" then
        local shape = safeGetShape(obj[1])
        table.insert(shape, 1, #obj)
        return shape
    end
end

local function arrayCompare(a, b)
    if #a == #b then
        for i=1, #a do
            if a[i] ~= b[i] then
                return false
            end
        end
        return true
    end
    return false
end

local function arrayCopy(arr)
    local newArr = {}
    for i, v in ipairs(arr) do
        newArr[i] = v
    end
    return newArr
end

-- Tensor prototype

local tensor_prototype = {numlua_mark = 'numlua_tensor', _shape={}}

-- Tensor metatable
-- Implements features e.g. Operator overloading

tensor_prototype.__index = tensor_prototype

-- Create new tensor
function tensor_prototype:new(data)
    local newObj = {}

    local childShape = safeGetShape(data[1])
    for i, v in ipairs(data) do
        -- Construct tensor by recursion
        local subObj
        if #childShape == 0 then
            subObj = v
        else
            subObj = self:new(v)
        end
        if not arrayCompare(childShape, safeGetShape(subObj)) then
            return nil
        end
        newObj[i] = subObj
    end

    objShape = arrayCopy(childShape)
    table.insert(objShape, 1, #newObj)
    newObj._shape = objShape
    
    setmetatable(newObj, tensor_prototype)
    return newObj
end

-- Get tensor dimension
function tensor_prototype:dim()
    return #(self._shape)
end

function tensor_prototype:shape()
    return tensor_prototype:new(self._shape)
end

-- Compare shape
function tensor_prototype:shapeEqualTo(another)
    assertTensor(another)
    return arrayCompare(self._shape, another._shape)
end

function tensor_prototype:copy()
    local newTensor = {}
    for i, v in ipairs(self) do
        if isTensor(v) then
            newTensor[i] = v:copy()
        else
            newTensor[i] = v
        end
    end

    newTensor._shape = self._shape
    setmetatable(newTensor, tensor_prototype)
    return newTensor
end

function tensor_prototype:negative()
    return (-1) * self
end

tensor_prototype.__eq = function(a, b)
    if isTensor(b) and a:shapeEqualTo(b) then
        for i, v in ipairs(a) do
            if v ~= b[i] then
                return false
            end
        end
        return true
    end
    return false
end

-- Overload operator +
tensor_prototype.__add = function(a, b)
    assertTensor(a)
    assertTensor(b)
    local newTensor = {}
    if not a:shapeEqualTo(b) then
        return nil
    end

    for i=1, #a do
        newTensor[i] = a[i] + b[i]
    end

    newTensor._shape = a._shape

    setmetatable(newTensor, tensor_prototype)
    return newTensor
end

-- Overload operator -
tensor_prototype.__sub = function(a, b)
    return a + b:negative()
end

-- Multiply with num
local function tensorTimesNum(t, n)
    assertTensor(t)
    if type(n) ~= "number" then error("n is not a number") end

    local newTensor = {}
    for i, v in ipairs(t) do
        if isTensor(v) then
            newTensor[i] = tensorTimesNum(v, n)
        else
            newTensor[i] = v * n
        end
    end

    newTensor._shape = t._shape
    setmetatable(newTensor, tensor_prototype)
    return newTensor
end
-- Overload operator *
tensor_prototype.__mul = function(a, b)
    if (type(a) == "number") and isTensor(b) then
        return tensorTimesNum(b, a)
    elseif (type(b) == "number") and isTensor(a) then
        return tensorTimesNum(a, b)
    end
end

-- Overload string transformation
tensor_prototype.__tostring = function(t)
    local strList = {}
    for i, v in ipairs(t) do
        strList[i] = tostring(v)
    end
    return "{" .. table.concat(strList, ",") .. "}"
end

setmetatable(tensor_prototype, tensor_prototype)

-- Numlua functions

function numlua.tensor(data)
    return tensor_prototype:new(data)
end

function numlua.isTensor(obj)
    return isTensor(obj)
end

function numlua.numbers(shapeArray, n)
    if #shapeArray == 1 then
        local len = shapeArray[1]
        local arr = {}
        for i=1, len do
            arr[i] = n
        end

        arr._shape = {len}
        setmetatable(arr, tensor_prototype)
        return arr
    elseif #shapeArray > 1 then
        local len = shapeArray[1]

        childShape = arrayCopy(shapeArray)
        table.remove(childShape, 1)

        local arr = {}
        for i=1, len do
            arr[i] = numlua.numbers(childShape, n)
        end

        arr._shape = shapeArray
        setmetatable(arr, tensor_prototype)
        return arr
    end
end

function numlua.zeros(shapeArray)
    return numlua.numbers(shapeArray, 0)
end

function numlua.ones(shapeArray)
    return numlua.numbers(shapeArray, 1)
end

return numlua