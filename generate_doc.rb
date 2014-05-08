#!/usr/bin/env ruby
# encoding: utf-8

require 'redcarpet'

def read path
  File.read(path)
end

def generate file, content, method
  File.open(file, method) { |f| f.write(content) }
end

def render_html input, output
  html = @markdown.render(read(input))

  generate(output, read('views/top.html'), 'w')
  generate(output, html, 'a')
  generate(output, read('views/bottom.html'), 'a')
end

renderer = Redcarpet::Render::HTML
@markdown = Redcarpet::Markdown.new(renderer, autolink: true, tables: true)

render_html 'README.md', 'public/index.html'
render_html 'BACKWARD_COMPATIBILITY.md', 'public/doc.html'
