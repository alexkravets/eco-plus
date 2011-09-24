(function() {
  var block_end_regex, block_start_regex, clear_blocks, eco, findit, fs, generate, get_name, include_regex, name_regex, parent_regex, parse_includes, parse_parents, read_blocks, replace_blocks;
  require('sugar');
  eco = require('eco');
  fs = require('fs');
  findit = require('findit');
  name_regex = /"(\w|\d|_|\/)+"/;
  block_start_regex = /<% ?block "(\w|\d|_)+" ?%>/g;
  block_end_regex = /<% ?endblock ?%>/g;
  parent_regex = /^<% ?parent "(\w|\d|_|\/)+" ?%>/g;
  include_regex = /<% ?include "(\w|\d|_|\/)+" ?%>/g;
  get_name = function(tag) {
    return name_regex.exec(tag)[0].replace('"', '').replace('"', '');
  };
  parse_includes = function(src, templates) {
    var tags;
    tags = src.match(include_regex);
    while (tags != null) {
      tags.each(function(tag) {
        var include_src, name;
        name = get_name(tag);
        if (templates[name] != null) {
          include_src = templates[name];
        } else {
          include_src = "<p>Error: Template <b>" + name + "</b> not found.</p>";
        }
        return src = src.replace(tag, include_src);
      });
      tags = src.match(include_regex);
    }
    return src;
  };
  read_blocks = function(src) {
    var blocks, tags;
    blocks = {};
    tags = src.match(block_start_regex);
    if (tags) {
      tags.each(function(tag) {
        var content, end, name, start;
        name = get_name(tag);
        start = src.search(tag);
        end = start + src.substring(start).search(block_end_regex);
        content = src.substring(start, end).replace(tag, '');
        return blocks[name] = content;
      });
    }
    return blocks;
  };
  replace_blocks = function(src, blocks) {
    var tags;
    tags = src.match(block_start_regex);
    if (tags) {
      tags.each(function(tag) {
        var content, end, name, start;
        name = get_name(tag);
        start = src.search(tag);
        end = start + src.substring(start).search(block_end_regex);
        content = src.substring(start, end).replace(tag, '');
        if (blocks[name] != null) {
          return src = src.replace(content, blocks[name]);
        }
      });
    }
    return src;
  };
  clear_blocks = function(src) {
    return src.replace(block_start_regex, '').replace(block_end_regex, '');
  };
  parse_parents = function(src, templates) {
    var blocks, name, parent_blocks, parent_src, tags;
    blocks = read_blocks(src);
    tags = src.match(parent_regex);
    while (tags != null) {
      name = get_name(tags.first());
      if (templates[name] != null) {
        parent_src = templates[name];
      } else {
        parent_src = "<p>Error: Template <b>" + name + "</b> not found.</p>";
      }
      parent_blocks = read_blocks(parent_src);
      blocks = Object.merge(parent_blocks, blocks);
      tags = parent_src.match(parent_regex);
    }
    if (parent_src != null) {
      src = parent_src;
    }
    src = replace_blocks(src, blocks);
    return src = clear_blocks(src);
  };
  generate = function(name, templates) {
    var src;
    src = templates[name];
    src = parse_parents(src, templates);
    return src = parse_includes(src, templates);
  };
  module.exports = {
    render: function(name, context, templates) {
      var html, src;
      if (templates[name] != null) {
        src = generate(name, templates);
        try {
          html = eco.render(src, context);
        } catch (err) {
          html = "Error: Template <b>" + name + "</b> <i>" + err + "</i>";
        }
      } else {
        html = "Error: Template <b>" + name + "</b> not found.";
      }
      return html;
    },
    templates: function(path) {
      var templates;
      templates = {};
      findit.sync(path, function(f) {
        var name, src;
        if (f.endsWith('.html')) {
          name = f.remove(path + '/').remove('.html');
          src = fs.readFileSync(f, 'utf-8');
          return templates[name] = src;
        }
      });
      return templates;
    },
    render_js: function(templates, context) {
      var funcs, src;
      funcs = [];
      Object.each(templates, function(name, src) {
        var f;
        if (name.has('/_') || name.startsWith('_')) {
          try {
            f = eco.compile(src);
          } catch (err) {
            f = function() {
              return console.log("Eco template '" + name + "' has compilation problem: " + err);
            };
          }
          return funcs.push("'" + name + "': " + (f.toString()));
        }
      });
      return src = "var __templates = { " + (funcs.join(", ")) + " };\nvar render = function(name, context){\n  if (context == null) { context = {}; }\n  context.conf = " + (JSON.stringify(context)) + ";\n  if (__templates[name] == null) { return 'Template <b>' + name + '</b> not found.'; }\n  return __templates[name](context);\n}";
    }
  };
}).call(this);
