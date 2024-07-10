-- qmdmd.lua
-- Copyright (C) 2024 by Khris Griffis, Ph.D.

-- Function to convert values to Pandoc MetaValue types
function to_meta_value(value)
  local t = pandoc.utils.type(value)

  if t == "List" then
    local list = pandoc.List{}
    for _, v in ipairs(value) do
      list:insert(to_meta_value(v))
    end
    return pandoc.MetaList(list)
  elseif t == "Inlines" then
    return pandoc.MetaInlines(value)
  elseif t == "Blocks" then
    return pandoc.MetaBlocks(value)
  elseif t == "Map" then
    local map = {}
    for k, v in pairs(value) do
      map[k] = to_meta_value(v)
    end
    return pandoc.MetaMap(map)
  elseif t == "boolean" then
    return pandoc.MetaBool(value)
  elseif t == "string" then
    return pandoc.MetaInlines{pandoc.Str(value)}
  elseif t == "number" then
    return pandoc.MetaInlines{pandoc.Str(tostring(value))}
  elseif t == "MetaList" or t == "MetaMap" or t == "MetaInlines" or t == "MetaBlocks" then
    return value
  elseif type(value) == "table" then
    -- Handle nested tables
    if #value > 0 then
      -- Handle as list if it's a sequence
      local list = pandoc.List{}
      for _, v in ipairs(value) do
        list:insert(to_meta_value(v))
      end
      return pandoc.MetaList(list)
    else
      -- Handle as map if it's a key-value table
      local map = {}
      for k, v in pairs(value) do
        map[k] = to_meta_value(v)
      end
      return pandoc.MetaMap(map)
    end
  else
    return pandoc.MetaString(pandoc.utils.stringify(value))
  end
end

-- Function to get the current date and time
function get_current_datetime()
  local format = "%Y-%m-%d %H:%M:%S %z"
  return os.date(format)
end

-- Function to process code blocks
function process_code_block(el)
  -- quarto.log.output(el)
  -- Remove unwanted classes
  el.classes = el.classes:filter(function(cls) return cls ~= "cell-code" end)
  return el
end

-- Function to process image blocks
function process_image(el)
  -- Check if the src is a relative link
  local src = el.src
  if src:match("^/") then
    -- If it starts with "/", prepend the ..
    src = ".." .. src
  elseif src:match("^./") then
    -- If it starts with "./", change to "../"
    src = src:gsub("^./", "../")
  elseif not src:match("^https?://") and not src:match("^../") then
    -- If it's a relative path without leading "./" or "/", add "../"
    src = "../" .. src
  end

  -- Update the src attribute
  el.src = src

  -- Process attributes to ensure kramdown compliance (if any)
  if el.attributes then
    el.attributes = {}
  end

  return el
end


-- Function to process links
function process_link(el)
  if el.classes then
    el.classes = pandoc.List()
  end
  return el
end

-- Function to parse and process the document metadata
function Meta(docMeta)
  -- Initial metadata fields with default values
  local final_meta = {
    author = docMeta.author and pandoc.MetaInlines{pandoc.Str(pandoc.utils.stringify(docMeta.author))} or pandoc.MetaInlines{pandoc.Str("unknown")},
    title = docMeta.title and to_meta_value(docMeta.title) or pandoc.MetaInlines{pandoc.Str("untitled")},
    date = docMeta.date and to_meta_value(docMeta.date) or pandoc.MetaString(get_current_datetime())
  }

  -- Parse and add additional metadata fields from docMeta.meta
  local meta_table = {}

  if docMeta.meta then
    for key, value in pairs(docMeta.meta) do
      if key == "author" or key == "title" or key == "date" then
        final_meta[key] = to_meta_value(value)
      else
        meta_table[key] = to_meta_value(value)
      end
    end
  end

  -- Add meta table to final_meta
  for k, v in pairs(meta_table) do
    final_meta[k] = v
  end
  final_meta = pandoc.Meta(final_meta)

  -- Auto-generate some YAML metadata
  final_meta.generated_on = pandoc.MetaString(os.date("%Y-%m-%d"))

  return final_meta
end

-- Main function to process the document
function Pandoc(doc)
  -- Process code blocks to ensure correct rendering
  doc = doc:walk {
    CodeBlock = process_code_block,
    Image = process_image,
    Link = process_link
  }

  return doc
end
