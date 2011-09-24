require 'sugar'
eco      = require 'eco'
fs       = require 'fs'
findit   = require 'findit'


# REGEXs

name_regex = /"(\w|\d|_|\/)+"/
block_start_regex = /<% ?block "(\w|\d|_)+" ?%>/g
block_end_regex = /<% ?endblock ?%>/g
parent_regex = /^<% ?parent "(\w|\d|_|\/)+" ?%>/g
include_regex = /<% ?include "(\w|\d|_|\/)+" ?%>/g

# HELPERS

get_name = (tag) -> name_regex.exec(tag)[0].replace('"', '').replace('"', '')

parse_includes = (src, templates) ->
  tags = src.match(include_regex)  
  while tags?
    tags.each (tag) ->
      name = get_name tag

      if templates[name]?
        include_src = templates[name]
      else
        include_src = "<p>Error: Template <b>#{ name }</b> not found.</p>"
      
      src  = src.replace(tag, include_src) 
    tags = src.match(include_regex)
  src


read_blocks = (src) ->
  blocks = {}
  tags = src.match(block_start_regex)
  if tags
    tags.each (tag) ->    
      name          = get_name tag
      start         = src.search(tag)
      end           = start + src.substring(start).search(block_end_regex)
      content       = src.substring(start, end).replace(tag, '')
      blocks[name]  = content
  blocks


replace_blocks = (src, blocks) ->
  tags = src.match(block_start_regex)
  if tags
    tags.each (tag) ->
      name    = get_name tag
      start   = src.search(tag)
      end     = start + src.substring(start).search(block_end_regex)
      content = src.substring(start, end).replace(tag, '')

      src = src.replace content, blocks[name] if blocks[name]?
  src


clear_blocks = (src) ->
  src.replace(block_start_regex, '').replace(block_end_regex, '')


parse_parents = (src, templates) ->
  blocks = read_blocks(src)
  
  tags = src.match(parent_regex)
  while tags?
    name  = get_name tags.first()
    
    if templates[name]?
      parent_src = templates[name]
    else
      parent_src = "<p>Error: Template <b>#{ name }</b> not found.</p>"
    
    parent_blocks = read_blocks(parent_src)
    blocks = Object.merge( parent_blocks, blocks)
    tags = parent_src.match(parent_regex)

  src = parent_src if parent_src?
  src = replace_blocks src, blocks
  src = clear_blocks src


generate = (name, templates) ->  
  #
  # Note: Recursion is not catched
  #
  src = templates[name]
  
  
  src = parse_parents src, templates
  src = parse_includes src, templates


module.exports =
  render: (name, context, templates) ->
    if templates[name]?
      src = generate(name, templates)
      try
        html = eco.render src, context
      catch err
        html = "Error: Template <b>#{name}</b> <i>#{err}</i>"
    else
      html = "Error: Template <b>#{name}</b> not found."
    html
  
  templates: (path) ->
    templates = {}
    findit.sync path, (f) ->
      if f.endsWith('.html')
        name = f.remove(path + '/').remove('.html')
        src = fs.readFileSync(f, 'utf-8')
        templates[name] = src
    templates
  
  render_js: (templates, context) ->
    funcs = []
    Object.each templates, (name, src) ->
      if name.has('/_') or name.startsWith('_')
        try
          f = eco.compile(src)
        catch err
          f = -> console.log "Eco template '#{name}' has compilation problem: #{err}"
        funcs.push "'#{name}': #{f.toString()}"

    src = """var __templates = { #{ funcs.join(", ") } };
             var render = function(name, context){
               if (context == null) { context = {}; }
               context.conf = #{JSON.stringify(context)};
               if (__templates[name] == null) { return 'Template <b>' + name + '</b> not found.'; }
               return __templates[name](context);
             }"""

