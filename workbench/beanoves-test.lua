local Command = {}
Command.__index = Command

function Command:clear()
  self.all__ = {}
  self.by_name__ = {}
  self.output__ = {}
end

Command:clear()

function Command:output(message)
  if message == true then
    self.output__ = {}
  elseif message then
    self.output__[#self.output__+1] = message
  end
  return self.output__
end

function Command:already(name, signature) --> Command?
  if signature then
    name = name..":"..signature
  end
  return self.by_name__[name]
end

function Command:base_signature(name) --> String, String?
  local pattern = "^([a-zA-Z_@]*):([NncVvoxefpwDTF]*)"
  local base, signature = name:match(pattern)
  if base then
    return base, signature
  end
  return name
end

function Command:make(name, signature) --> Command?
  -- self:output("name: "..name..", signature: "..(signature or "")..", "..(name:find("bnvs") and "OK" or "KO"))
  if not name:find("bnvs") then
    return nil
  end
  if name:find("q__") then
    return nil
  end
  if name:find("DEBUG") then
    return nil
  end
  if name:len()<7 then
    return nil
  end
  if signature then
    name = name..":"..signature
  end
  local o = self.by_name__[name]
  if o then
    return o
  end
  local base, signature = self:base_signature(name)
  o = {
    name = name,
    base = base,
    signature = signature,
  }
  setmetatable(o, self)
  table.insert(self.all__, o)
  self.by_name__[name] = o
  if name:match("^c__") then
    o.is_constant = true
  elseif name:match("^[lg]__") then
    o.is_variable = true
  else
    o.is_function = true
  end
  return o
end

function iter (a, i)
  i = i + 1
  local v = a[i]
  if v then
    return i, v
  end
end

function Command:sorted()
  table.sort(self.all__, function(l, r) return l.name < r.name end)
  return iter, self.all__, 0
end

function Command:sorted_functions()
  local t = {}
  for _,cmd in self:sorted() do
    if cmd.is_function then
      t[#t+1] = cmd
    end
  end
  return iter, t, 0
end

function Command:parse_all(s)
  local n = 0
  local pattern = "%f[\\]"..--
[[\([a-zA-Z_@:]+)]]
  for name in string.gmatch (s, pattern) do
    if not self:already(name) and self:make(name) then
      n = n+1
    end
  end
  self:output("-> "..n.." bnvs commands parsed")
end

function Command:parse_set_eq(s)
  local n = 0
  local pattern = "\\cs_set_eq:NN%s*"..
"\\([a-zA-Z_@:]+)"
  for name in string.gmatch (s, pattern) do
    local cmd = self:make(name)
    if cmd then
      cmd.is_defined = true
      n = n+1
    end
  end
  self:output("-> "..n.." bnvs command copy")
end

function Command:parse_action(s, action)
  local n = 0
  local pattern = "\\cs_"..action..":Np?n%s+"..
"\\([a-zA-Z_@:]*)"
  for name in string.gmatch (s, pattern) do
    local cmd = self:make(name)
    if cmd then
      cmd.is_defined = true
      n = n+1
    end
  end
  self:output("-> "..n.." command definition "..action)
end

function Command:parse_BNVS_action(s, action)
  local n = 0
  local pattern = "\\BNVS_"..action..":cpn%s*{"..
"%s*([a-zA-Z_@:]*)%s*}"
  for name in string.gmatch (s, pattern) do
    name = "__bnvs_"..name
    local cmd = self:make(name)
    if cmd then
      cmd.is_defined = true
      n = n+1
    end
  end
  self:output("-> "..n.." bnvs command definition "..action)
end

function Command:parse_BNVS_new_signed(s, signature)
  local n = 0
  local pattern = "BNVS_new_"..signature..":ncn?%s*{%s*"..
"([a-zA-Z_@]*)%s*}%s*{%s*"..
"([a-zA-Z_@]*)%s*}"
  for module, name in string.gmatch (s, pattern) do
    name = "__bnvs_"..module.."_"..name
    local cmd = self:make(name..":"..signature)
    if cmd then
      cmd.is_defined = true
      n = n+1
    end
  end
  self:output("-> "..n.." bnvs new definition "..signature)
end

function Command:parse_BNVS_new_tl_signed(s, signature)
  local n = 0
  local pattern = "\\BNVS_new_tl_"..signature..":c?%s*{%s*"..
"([a-zA-Z_@]*)%s*}"
  for name in string.gmatch (s, pattern) do
    name = "__bnvs_tl_"..name..":"..signature
    local cmd = self:make(name)
    if cmd then
      cmd.is_defined = true
      n = n+1
    end
  end
  self:output("-> "..n.." bnvs new tl definition "..signature)
end

function Command:complete_variant(variant, signature) --> String
  if #variant < #signature then
    local ans = {}
    for i=1,#signature do
      ans[#ans+1] = signature:sub(i, i)
    end
    for i=1,#variant do
      ans[i] = variant:sub(i, i)
    end
    return table.concat(ans)
  end
  return variant
end

function Command:parse_generate_variant(s)
  local n = 0
  local pattern = "\\cs_generate_variant:Nn%s*"..
"\\([a-zA-Z_@:]*)%s*"..
"{([NncVvoxefpwDTF,%s]-)}"
  for core, variants in string.gmatch (s, pattern) do
    local cmd = self:already(core)
    if cmd then
      cmd.is_core = true
    end
    local base, signature = self:base_signature(core)
    if signature then
      for v in variants:gmatch("([NncVvoxefpwDTF]+)") do
        v = self:complete_variant(v, signature)
        local name = base..":"..v
        local generated = self:already(name)
        if generated then
          generated.is_defined = true
          generated.core = core
        else
          generated = self:make(name)
          if generated then
            generated.is_defined = true
            generated.is_unused = true
            generated.core = core
          end
        end
        n = n+1
      end
    else
      self:output("INCONSISTENCY, No signature: "..core)
    end
  end
  self:output("-> "..n.." bnvs variants generated")
end

function Command:parse_BNVS_generate_variant(s)
  local n = 0
  local pattern = "\\BNVS_generate_variant:cn%s*"..
"{%s*"..
"([a-zA-Z_@:]*)%s*}%s*"..
"{([NncVvoxefpwDTF,%s]-)}"
  for core, variants in string.gmatch (s, pattern) do
    core = "__bnvs_"..core
    local cmd = self:already(core)
    if cmd then
      cmd.is_core = true
    end
    local base, signature = self:base_signature(core)
    if signature then
      for v in variants:gmatch("([NncVvoxefpwDTF]+)") do
        v = self:complete_variant(v, signature)
        local name = base..":"..v
        local generated = self:already(name)
        if generated then
          generated.is_defined = true
          generated.core = core
        else
          generated = self:make(name)
          if generated then
            generated.is_defined = true
            generated.is_unused = true
            generated.core = core
          end
        end
        n = n+1
      end
    else
      self:output("INCONSISTENCY, No signature: "..core)
    end
  end
  self:output("-> "..n.." bnvs variants generated")
end

function Command:parse_core_conditional(s)
  local n = 0
  local pattern = "\\prg_(?:new|set)_conditional:Npnn%s*"..
"\\([a-zA-Z_@:]*)%s*"..
"[^{"..--}
"]*{([pTF,%s]-)}"
  for core, conditionals in string.gmatch (s, pattern) do
    local from = self:already(core)
    if from then
      from.is_conditional_core = true
    end
    local base, signature = self:base_signature(core)
    for c in conditionals:gmatch("([pTF]+)") do
      local name = c == "p" and (signature and base.."_p:"..signature or core.."_p") or core..c
      local generated = self:make(name)
      if generated then
        generated.is_defined = true
        generated.conditional_core = core
        n = n+1
      end
    end
  end
  self:output("-> "..n.." bnvs conditionals created")
end

function Command:parse_generate_conditional_variant(s)
  local n = 0
  local pattern = "\\prg_generate_conditional_variant:Nnn%s*"..
"\\([a-zA-Z_@:]*)%s*"..
"{([NncVvoxefpwDTF,%s]-)}%s*"..
"{([pTF,%s]-)}"
  for name, variants, conditionals in string.gmatch (s, pattern) do
    local base, signature = self:base_signature(name)
    if signature then
      for v in variants:gmatch("([NncVvoxefpwDTF]+)") do
        local vv = self:complete_variant(v, signature)
        for c in conditionals:gmatch("([pTF]+)") do
          local name = c == "p" and base.."_p:"..vv or base..":"..vv..c
          local generated = self:already(name)
          if generated then
            generated.is_defined = true
            generated.is_TF = c == "TF"
            n = n+1
          else
            generated = self:make(name)
            if generated then
              generated.is_defined = true
              generated.is_TF = c == "TF"
              generated.is_unused_conditional = true
              n = n+1
            end
          end
        end
      end
    else
      self:output("INCONSISTENCY, No signature: "..name)
    end
  end
  self:output("-> "..n.." bnvs conditional variants generated")
end

function Command:parse_BNVS_generate_conditional_variant(s)
  local n = 0
  local pattern = "\\BNVS_generate_conditional_variant:cnn%s*"..
"{%s*([a-zA-Z_@:]*)%s*}%s*"..
"{([NncVvoxefpwDTF,%s]-)}%s*"..
"{([pTF,%s]-)}"
  for name, variants, conditionals in string.gmatch (s, pattern) do
    local base, signature = self:base_signature(name)
    base = "__bnvs_"..base
    if signature then
      for v in variants:gmatch("([NncVvoxefpwDTF]+)") do
        local vv = self:complete_variant(v, signature)
        for c in conditionals:gmatch("([pTF]+)") do
          local name = c == "p" and base.."_p:"..vv or base..":"..vv..c
          local generated = self:already(name)
          if generated then
            generated.is_defined = true
            generated.is_TF = c == "TF"
            n = n+1
          else
            generated = self:make(name)
            if generated then
              generated.is_defined = true
              generated.is_TF = c == "TF"
              generated.is_unused_conditional = true
              n = n+1
            end
          end
        end
      end
    else
      self:output("INCONSISTENCY, No signature: "..name)
    end
  end
  self:output("-> "..n.." bnvs conditional variants generated")
end

function Command:parse_BNVS_new_conditional(s, signature)
  local n = 0
  local pattern = "BNVS_new_conditional_"..signature..":cn%s*{%s*"..
"([a-zA-Z_@]*)%s*}"
  for base in string.gmatch (s, pattern) do
    for _,c in ipairs({"T", "F", "TF"}) do
      local name = "__bnvs_"..base..":"..signature..c
      local generated = self:already(name)
      if generated then
        generated.is_defined = true
        generated.is_TF = c == "TF"
        n = n+1
      else
        generated = self:make(name)
        if generated then
          generated.is_defined = true
          generated.is_TF = c == "TF"
          generated.is_unused_conditional = true
          n = n+1
        end
      end
    end
  end
  self:output("-> "..n.." "..signature.." bnvs conditional variants generated")
end

function Command:parse_BNVS_new_conditional_nc(s)
  local n = 0
  local pattern = "BNVS_new_conditional_([a-z]*):ncn?%s*{%s*"..
"([a-z]*)%s*}%s*{%s*"..
"([a-zA-Z_@]*)%s*}"
  for signature, module, base in string.gmatch (s, pattern) do
    for _,c in ipairs({"T", "F", "TF"}) do
      local name = "__bnvs_"..module.."_"..base..":"..signature..c
      local generated = self:already(name)
      if generated then
        generated.is_defined = true
        generated.is_TF = c == "TF"
        n = n+1
      else
        generated = self:make(name)
        if generated then
          generated.is_defined = true
          generated.is_TF = c == "TF"
          generated.is_unused_conditional = true
          n = n+1
        end
      end
    end
  end
  self:output("-> "..n.." bnvs ncn conditional variants generated")
end

function Command:parse_BNVS_new_conditional_cc(s)
  local n = 0
  local pattern = "BNVS_new_conditional_cc:ncnn%s*{%s*"..
"([a-zA-Z_@]*)%s*}%s*{%s*"..
"([a-zA-Z_@]*)%s*}"
  for module, base in string.gmatch (s, pattern) do
    for _,c in ipairs({"T", "F", "TF"}) do
      local name = "__bnvs_"..module.."_"..base..":cc"..c
      local generated = self:already(name)
      if generated then
        generated.is_defined = true
        generated.is_TF = c == "TF"
        n = n+1
      else
        generated = self:make(name)
        if generated then
          generated.is_defined = true
          generated.is_TF = c == "TF"
          generated.is_unused_conditional = true
          n = n+1
        end
      end
    end
  end
  self:output("-> "..n.." bnvs cc conditional variants generated")
end

function Command:parse_BNVS_new_conditional_signed(s, signature)
  local n = 0
  local pattern = "BNVS_new_conditional_"..signature..":ncn*%s*{%s*"..
"([a-zA-Z_@]*)%s*}%s*{%s*"..
"([a-zA-Z_@]*)%s*}"
  for module, base in string.gmatch (s, pattern) do
    for _,c in ipairs({"T", "F", "TF"}) do
      local name = "__bnvs_"..module.."_"..base..":"..signature..c
      local generated = self:already(name)
      if generated then
        generated.is_defined = true
        generated.is_TF = c == "TF"
        n = n+1
      else
        generated = self:make(name)
        if generated then
          generated.is_defined = true
          generated.is_TF = c == "TF"
          generated.is_unused_conditional = true
          n = n+1
        end
      end
    end
  end
  self:output("-> "..n.." bnvs cc conditional variants generated")
end

function Command:parse_BNVS_new_conditional_tl(s, signature, is_tl)
  is_tl = is_tl == nil and false or is_tl
  local n = 0
  local pattern = "BNVS_new_conditional_tl_"..signature..":cn%s*{%s*"..
"([a-zA-Z_@]*)%s*}"
  local prefix = is_tl and "__bnvs_tl_" or "__bnvs_"
  for base in string.gmatch (s, pattern) do
    for _,c in ipairs({"T", "F", "TF"}) do
      local name = prefix..base..":"..signature..c
  self:output("-> "..name)
      local generated = self:already(name)
      if generated then
        generated.is_defined = true
        generated.is_TF = c == "TF"
        n = n+1
      else
        generated = self:make(name)
        if generated then
          generated.is_defined = true
          generated.is_TF = c == "TF"
          generated.is_unused_conditional = true
          n = n+1
        end
      end
    end
  end
  self:output("-> "..n.." bnvs cn conditional variants generated")
end

function Command:parse_BNVS_new_conditional_cpnn(s)
  local n = 0
  local pattern = "BNVS_new_conditional:cpnn%s*{%s*"..
"([a-zA-Z_@]*):([a-zA-Z_@]*)%s*}[^{"..--}
"]*{%s*"..
"([pTF,%s]*)%s*}"
  local pattern_pTF = "([pTF]+)"
  for base, signature, pTFs in string.gmatch(s, pattern) do
    for pTF in string.gmatch(pTFs, pattern_pTF) do
      local name = "__bnvs_"..base
      if pTF == "p" then
        name = name.."_p:"..signature
      else
        name = name..":"..signature..pTF
      end
      local generated = self:already(name)
      if generated then
        generated.is_defined = true
        generated.is_TF = pTF == "TF"
        n = n+1
      else
        generated = self:make(name)
        if generated then
          generated.is_defined = true
          generated.is_TF = pTF == "TF"
          generated.is_unused_conditional = true
          n = n+1
        end
      end
    end
  end
  self:output("-> "..n.." bnvs raw conditional variants generated")
end

function Command:check_unused_variants()
  self:output("-> check for unused variants...")
  for _,cmd in self:sorted_functions() do
    if cmd.is_unused then
      self:output("  -> "..cmd.name)
    end
  end
  self:output("-> check for unused variants...DONE")
end

function Command:check_unused_conditional_variants(skip)
  if skip then
    return
  end
  self:output("-> check for unused conditional variants...")
  for _,cmd in self:sorted_functions() do
    if cmd.is_unused_conditional then
      self:output("  -> "..cmd.name)
    end
  end
  self:output("-> check for unused conditional variants...DONE")
end

function Command:check_undefined()
  self:output("-> check for undefined...")
  for _,cmd in self:sorted_functions() do
    if not cmd.is_defined and not cmd.is_conditional_core then
      if cmd.name:len() > 7 then
        self:output("!!!! "..cmd.name)
      end
    end
  end
  self:output("-> check for undefined...DONE")
end

function Command:check_variants(s) --> [String]
  self:clear()
  self:parse_all(s)
  self:parse_set_eq(s)
  self:parse_action(s,"new")
  self:parse_action(s,"set")
  self:parse_BNVS_action(s,"new")
  self:parse_BNVS_action(s,"set")
  self:parse_generate_variant(s)
  self:parse_BNVS_generate_variant(s)
  self:parse_core_conditional(s)
  self:parse_BNVS_new_signed(s, "c")
  self:parse_BNVS_new_signed(s, "cc")
  self:parse_BNVS_new_signed(s, "cn")
  self:parse_BNVS_new_signed(s, "cv")
  self:parse_BNVS_new_signed(s, "cnn")
  self:parse_BNVS_new_signed(s, "cnv")
  self:parse_BNVS_new_signed(s, "cnx")
  self:parse_BNVS_new_tl_signed(s, "c")
  self:parse_BNVS_new_tl_signed(s, "cn")
  self:parse_BNVS_new_tl_signed(s, "cv")
  self:parse_BNVS_new_conditional_cpnn(s)
  self:parse_BNVS_new_conditional_signed(s, "c")
  self:parse_BNVS_new_conditional_signed(s, "nc")
  self:parse_BNVS_new_conditional_signed(s, "cc")
  self:parse_BNVS_new_conditional_signed(s, "cn")
  self:parse_BNVS_new_conditional_signed(s, "cnn")
  self:parse_BNVS_new_conditional_signed(s, "cnv")
  self:parse_BNVS_new_conditional_signed(s, "cnx")
  self:parse_BNVS_new_conditional_tl(s, "cn", true)
  self:parse_BNVS_new_conditional_tl(s, "cv", true)
  self:parse_BNVS_new_conditional_tl(s, "vnc", false)
  self:parse_BNVS_new_conditional_tl(s, "vvc", false)
  self:parse_BNVS_new_conditional(s, "Nn")
  self:parse_BNVS_new_conditional(s, "Nv")
  self:parse_BNVS_new_conditional(s, "nn")
  self:parse_BNVS_new_conditional(s, "c")
  self:parse_BNVS_new_conditional(s, "cc")
  self:parse_BNVS_new_conditional(s, "cv")
  self:parse_BNVS_new_conditional(s, "vc")
  self:parse_BNVS_new_conditional(s, "vnc")
  self:parse_BNVS_new_conditional(s, "vvc")
  self:parse_BNVS_new_conditional(s, "vvnc")
  self:parse_BNVS_new_conditional(s, "vvvc")
  self:parse_generate_conditional_variant(s)
  self:parse_BNVS_generate_conditional_variant(s)
  self:check_unused_variants()
  self:check_unused_conditional_variants(true)
  self:check_undefined()
  return self:output()
end
local function check_variants (path) --> string?
  local file = io.open(path, "r")
  if file == nil then
    return nil
  end
  local s = file:read("a")
  file:close()
  local ra1 = Command:check_variants([[
\bnvs_TEST_A:n
\bnvs_TEST_B:nn
\cs_set:Npn \bnvs_TEST_B:nn {}
\cs_new:Npn \bnvs_C:nn {}
\BNVS_new_conditional:cpnn { if_get:nnnc } #1 #2 #3 #4 { p, T, F, TF } {}
\_generate_conditional_variant:Nnn
  \__bnvs_if_get:nnnc {nVV} { p, T, F, TF }
]])
  local ra2 = Command:check_variants(s)
  for _,v in ipairs(ra2) do
    ra1[#ra1+1] = v
  end
  return ra2
end
return {
  __INFO__ = "beanoves dedicated table for DEBUGGING",
  check_variants  = check_variants,
  Command__ = Command,
}
