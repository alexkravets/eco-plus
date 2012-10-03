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

Copyright (c) 2011 Alex Kravets <a@alexkravets.com>

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
