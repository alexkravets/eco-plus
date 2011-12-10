require 'sugar'
eco      = require 'eco'
fs       = require 'fs'
findit   = require 'findit'


block_regex     = /<% ?block "(\w|\d|_)+" ?%>/g
endblock_regex  = /<% ?endblock ?%>/g
parent_regex    = /^<% ?parent "(\w|\d|_|\/)+" ?%>/g
include_regex   = /<% ?include "(\w|\d|_|\/)+" ?%>/g


#
# Get name from tag: <% block "main" %> name is gonna be "main"
#
get_name = (tag) ->
    name_regex = /"(\w|\d|_|\/)+"/
    return name_regex.exec(tag)[0].replace('"', '').replace('"', '')


#
#
#
parse_includes = (src, templates) ->
    tags = src.match(include_regex)
    while tags?
        tags.each (tag) ->
            name = get_name tag

            if templates[name]?
                include_src = templates[name]
            else
                include_src = "<p>Error: Template <b>#{ name }</b> not found.</p>"

            src = src.replace(tag, include_src)
        tags = src.match(include_regex)
    return src


#
# Finds block in a source, returns it's name and blocks body
# as dictionary.
#
get_block = (tag, src) ->
    block_start     = src.search(tag)
    tail            = src.substring(block_start)
    endblock_start  = tail.search(endblock_regex)
    endblock_end    = endblock_start + tail.substring(endblock_start).search('%>') + 2
    block           = tail.substring(0, endblock_end)
    return block


#
# Looks for blocks in source and returns dictionary with block names
# and block contents.
#
# Example:
#   --
#   <% block "name" %>
#     This is content.
#   <% endblock %>
#   Other content goes here...
#   <% block "name2" %>This is another content.<% endblock %>
#   --
#
#   Returns result: { name: "<% block "name" %>This is content.<% endblock %>",
#                     name2: "<% block "name2" %>This is another content.<% endblock %>" }
#
read_blocks = (src) ->
    blocks  = {}
    tags    = src.match(block_regex)
    if tags
        tags.each (tag) ->
            name    = get_name(tag)
            block   = get_block(tag, src)
            blocks[name]  = block
    return blocks

#
# Replaces blocks content in source with same name block content
# from provided blocks dictionary. Returns updated source.
#
replace_blocks = (src, blocks) ->
    tags = src.match(block_regex)
    if tags
        tags.each (tag) ->
            name    = get_name(tag)
            block   = get_block(tag, src)
            if blocks[name]?
                src = src.replace(block, blocks[name])

    # Remove block tags
    src = src.replace(block_regex, '').replace(endblock_regex, '')

    return src


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

    if parent_src?
        src = parent_src
    src = replace_blocks(src, blocks)

    return src


generate = (name, templates) ->
    #
    # Note: Recursion is not catched
    #
    src = templates[name]
    src = parse_parents(src, templates)
    src = parse_includes(src, templates)


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

