-- qmdmd.lua
-- Copyright (C) 2024 by Khris Griffis, Ph.D.

-- Imports
local logging = require 'logging'

-- Global variables for settings
FIG_REL = "."
FIG_ROOT = ""
FIG_MSG = pandoc.List:new()

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
  -- Remove unwanted classes
  if #el.classes > 1 then
    el.classes = { el.classes[1] }
  end
  return el
end

-- Function to strip trailing slashes from a string
function strip_trailing_slash(s)
  return s:gsub("[/\\]*$", "")
end

-- Function to check if a string is a remote link
function is_remote_link(link)
    return link:match("^https?://") ~= nil
end

-- Function to normalize paths to use "/" as the separator
function normalize_path(path)
    return path:gsub("\\", "/")
end

-- Function to create a directory if it doesn't exist
local function create_directory(dir)
  local success, msg = pcall(
    function()
      pandoc.system.make_directory(dir,true)
    end
    )
  if not success then
    warn("Error creating directory: " .. msg)
  end
end

local function move_file_to_directory(file_path, target_dir)
  -- Create target directory if it doesn't exist
  create_directory(target_dir)
  
  -- Construct the command to move the file
  local file_name = pandoc.path.filename(file_path)
  local target_path = pandoc.path.join({target_dir, file_name})
  
  local os_name = pandoc.system.os
  local command
  if os_name:match("mingw") or os_name:match("cygwin") then
    command = string.format('move "%s" "%s"', file_path, target_path)
  else
    command = string.format('mv -f "%s" "%s"', file_path, target_path)
  end

  -- Execute the command
  local success, msg = pcall(function ()
    local exe_success, exe_type, exe_val = os.execute(command)
    if not exe_success then
      error(string.format("Move file errored with %s status of %d.", exe_type, exe_val))
    end
  end)
  if not success then
    error("Error moving file from " .. file_path .. " to " .. target_path)
  end
end

-- Function to process image blocks
function process_image(el)
  -- Process attributes to ensure kramdown compliance (if any)
  if el.attributes then
    el.attributes = {}
  end
  
  -- Determine if src is a link to a remote site
  if is_remote_link(el.src) then
    return el
  end
  
    -- Process relative root
  local base = pandoc.system.get_working_directory()
  local fig_rel = FIG_REL
  local root_abs = pandoc.path.join({base,fig_rel})
  fig_rel = normalize_path(pandoc.path.make_relative(root_abs, base, true))
  
  -- Clean source path of ./, ../ or /
  local src = pandoc.path.normalize(el.src)
  local original_src = normalize_path(src)
  local image_name = pandoc.path.filename(src)
  
  -- Apply the figure root if specified
  local fig_root = FIG_ROOT
  if fig_root ~= "" then
    -- Extract the image name
    src = pandoc.path.normalize(pandoc.path.join({fig_rel, fig_root, image_name}))
  else
    -- No figure root, create path with relative root
    -- If fig_rel is '.', then we end up with original clean source
    src = pandoc.path.normalize(pandoc.path.join({fig_rel,src}))
  end

  -- Update the src attribute
  el.src = normalize_path(src)
  
  -- Report file change and move file
  if el.src ~= original_src then
    FIG_MSG:insert(pandoc.MetaString("  > '" .. original_src .. "' to '" .. el.src .. "'"))
    -- Move image from original path to new path
    local new_root = pandoc.path.directory(src)
    local file_src = pandoc.path.normalize(original_src)
    local old_root = pandoc.path.directory(file_src)
    logging.output("Moving", image_name, "from", old_root, "to", new_root, "...")
    move_file_to_directory(file_src,new_root)
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
  -- Update global variables from qmdmd settings
  if docMeta.qmdmd then
    if docMeta.qmdmd["fig-rel"] then
      local fig_rel = pandoc.utils.stringify(docMeta.qmdmd["fig-rel"])
      if fig_rel:match("^%.") == nil then
          error("Option 'fig-rel' must start with a relative folder directive, e.g., '..'.")
          os.exit(1) -- error status
      end
      FIG_REL = strip_trailing_slash(fig_rel)
    end
    if docMeta.qmdmd["fig-root"] then
      FIG_ROOT = strip_trailing_slash(pandoc.utils.stringify(docMeta.qmdmd["fig-root"]))
    end
  end
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
  -- Return final metadata stucture
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
  -- Announce If Files were changed
  if #FIG_MSG > 0 then
    logging.output("\n")
    FIG_MSG:insert(1,pandoc.MetaString("Figure file paths have changed!"))
    FIG_MSG:insert(2,pandoc.MetaString("  Be sure to relocate any generated figures."))
    FIG_MSG:insert(3,pandoc.MetaString("  --- Original URL -> Modified URL ---  "))
    FIG_MSG:map(function (m) logging.output(m) end)
    logging.output("\n")
  end
  
  return doc
end
