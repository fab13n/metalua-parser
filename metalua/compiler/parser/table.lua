--------------------------------------------------------------------------------
-- Copyright (c) 2006-2013 Fabien Fleutot and others.
--
-- All rights reserved.
--
-- This program and the accompanying materials are made available
-- under the terms of the Eclipse Public License v1.0 which
-- accompanies this distribution, and is available at
-- http://www.eclipse.org/legal/epl-v10.html
--
-- This program and the accompanying materials are also made available
-- under the terms of the MIT public license which accompanies this
-- distribution, and is available at http://www.lua.org/license.html
--
-- Contributors:
--     Fabien Fleutot - API and implementation
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--
-- Exported API:
-- * [M.table_bracket_field()]
-- * [M.table_field()]
-- * [M.table_content()]
-- * [M.table()]
--
-- KNOWN BUG: doesn't handle final ";" or "," before final "}"
--
--------------------------------------------------------------------------------

local gg  = require 'metalua.grammar.generator'
local mlp = require 'metalua.compiler.parser.common'

local M = { }

--------------------------------------------------------------------------------
-- eta expansion to break circular dependencies:
--------------------------------------------------------------------------------
local function _expr (lx) return mlp.expr(lx) end

--------------------------------------------------------------------------------
-- [[key] = value] table field definition
--------------------------------------------------------------------------------
M.table_bracket_field = gg.sequence{ "[", _expr, "]", "=", _expr, builder = "Pair" }

--------------------------------------------------------------------------------
-- [id = value] or [value] table field definition;
-- [[key]=val] are delegated to [bracket_field()]
--------------------------------------------------------------------------------
function M.table_field (lx)
   if lx :is_keyword (lx :peek(), "[") then return M.table_bracket_field (lx) end
   local e = _expr (lx)
   if lx :is_keyword (lx :peek(), "=") then
      lx :next(); -- skip the "="
      -- Allowing only the right type of key, here `Id
      local etag = e.tag
      if etag ~= 'Id' then
         gg.parse_error(lx, 'Identifier expected, got %s.', etag)
      end
      local key = mlp.id2string(e)
      local val = mlp.expr(lx)
      local r = { tag="Pair", key, val }
      r.lineinfo = { first = key.lineinfo.first, last = val.lineinfo.last }
      return r
   else return e end
end

--------------------------------------------------------------------------------
-- table constructor, without enclosing braces; returns a full table object
--------------------------------------------------------------------------------
M.table_content  = gg.list {
   primary     =  function(...) return M.table_field(...) end,
   separators  = { ",", ";" },
   terminators = "}",
   builder     = "Table" }

--------------------------------------------------------------------------------
-- complete table constructor including [{...}]
--------------------------------------------------------------------------------
M.table = gg.sequence{ "{", function(...) return M.table_content(...) end, "}", builder = unpack }

return M
