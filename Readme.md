# **Eco-plus** is **Eco** extension for **Express**

which adds **include**, **parent** and **block** tags. These *special* tags allow to split templates into several files in the same way Django or Liquid does it.

# Example

*layout.html*

```
<html>
    <head>
        <% block "title" %>**Parent Title**<% endblock %>
    </head>
    <body>
        <% block "main" %>Parent Content<% endblock %>
    </body>
</html>
```

*index.html*

```
<% parent "layout" %>
<% block "title" %><%= block.super %> | Page Title<% endblock %>
<% block "main" %>
  <% include "header" %>
  Page Content
  <% include "footer" %>
<% endblock %>
```

# Installation

Add ```"eco-plus": ">=0.1.2"``` to ```package.json``` dependencies and run ```npm install```:

```
{
  ...
  "dependencies": {
    ...
    "eco-plus": ">=0.1.2"
  },
  ...
}
```

# Express Integration

To integrate Eco-plus into express default **render** method should be overrided. Add these somewhere in **express configuration section**:

```
#
# Setting up and configuring eco-plus to render templates
# We also override default express/http render method
#
ecoplus = require 'eco-plus'

templates_path  = "<path to application templates>"
app.templates   = ecoplus.templates(templates_path)
res             = require('http').ServerResponse.prototype

res.render = (name, context={}) ->
    html = ecoplus.render(name, context, app.templates)
    @send(html)
```

# Support

You're welcome to submit any issues or feature requests.

# License (MIT)

Alex Kravets <santyor@gmail.com>