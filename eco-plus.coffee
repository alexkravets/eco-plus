require 'sugar'
eco      = require 'eco'
fs       = require 'fs'
findit   = require 'findit'

prefix = '(?:=|-)'
quoted = (pattern, idx=1) -> "(\"|\')#{pattern}\\#{idx}"
single_tag = (name, prefix='') ->
    new RegExp("<%#{prefix}\\s*#{name}\\s*%>", 'g')
arg_tag = (name, argpattern='.*', prefix='') ->
    new RegExp("<%#{prefix}\\s*#{name}\\s+#{quoted(argpattern)}\\s*%>", 'g')

patterns =
    block: arg_tag('block', '(\\w|\\d|_)+')
    endblock: single_tag('endblock')
    parent: arg_tag('parent', '(\\w|\\d|_|\\/)+')
    block_super: single_tag('block\\.super', prefix)
    include: arg_tag('include', '(\\w|\\d|_|\\/)+', prefix)

#
# Get name from tag: <% block "main" %> name is gonna be "main"
#
get_name = (tag) ->
    name_regex = /("|')((?:\w|\d|_|\/)+)\1/
    return name_regex.exec(tag)[2]


#
#
#
parse_includes = (src, templates) ->
    tags = src.match(patterns.include)
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
    endblock_start  = tail.search(patterns.endblock)
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
    tags    = src.match(patterns.block)
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
    tags = src.match(patterns.block)
    if tags
        tags.each (tag) ->
            name    = get_name(tag)
            block   = get_block(tag, src)
            if blocks[name]?
                src = src.replace(block, blocks[name])

    # Remove block tags
    src = src.replace(patterns.block, '').replace(patterns.endblock, '')

    return src

parse_parents = (src, templates) ->
    [src, blocks] = parse_parents_inner(src, templates)
    return src


parse_parents_inner = (src, templates) ->
    # Read in a map of block_name => block_src and look for a parent
    # declaration
    blocks = read_blocks(src)
    tags = src.match(patterns.parent)
    if not tags
        return [src, blocks]

    parent_name = get_name tags.first()
    if templates[parent_name]?
        parent_src = templates[parent_name]
    else
        parent_src = "<p>Error: Template <b>#{ parent_name }</b> not found.</p>"

    # Recursively process parent templates to determine what their blocks look
    # like so we can use them in any super blocks.
    [src, parent_blocks] = parse_parents_inner(parent_src, templates)
    updated_blocks = {}
    for name, block of blocks
        # Look for parent inclusions and try to sub in parent blocks
        while block.match(patterns.block_super)
            match = block.match(patterns.block_super).first()
            parent_blocks[name] or ''
            block = block.replace(match, parent_blocks[name] or '')
        updated_blocks[name] = block
    blocks = updated_blocks

    # Override parent blocks with child blocks
    if parent_src?
        src = parent_src
    src = replace_blocks(src, blocks)
    return [src, blocks]


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

