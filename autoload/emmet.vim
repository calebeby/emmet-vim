function! emmet#isExpandable()
  return 1
endfunction

function! emmet#tokenize(chars)
  let tokens = [{'type': 'node', 'contents': ''}]
  let pairs = {
        \    '{': {'type': 'contents', 'ends': '}'},
        \    '(': {'type': 'group', 'ends': ')'},
        \    '[': {'type': 'attributes', 'ends': ']'}
        \ }
  let waitingFor = ''
  let nodeFinished = 0
  for char in a:chars
    if char == waitingFor
      let waitingFor = ''
    elseif has_key(pairs, char)
      let waitingFor = pairs[char].ends
      call add(tokens, {'type': pairs[char].type, 'contents': ''})
    elseif char == '+'
      let nodeFinished = 1
    elseif char == '>'
      call add(tokens, {'type': 'down', 'contents': '>'})
      let nodeFinished = 1
    elseif char == '^'
      call add(tokens, {'type': 'up', 'contents': '^'})
      let nodeFinished = 1
    else
      if nodeFinished
        call add(tokens, {'type': 'node', 'contents': ''})
        let nodeFinished = 0
      endif
      let tokens[-1].contents .= char
    endif
  endfor
  return tokens
endfunction

function! emmet#combine(tokens)
  let nodes = []
  for token in a:tokens
    if token.type == 'node'
      let node = {'name': token.contents, 'type': 'node', 'contents': []}
      call add(nodes, node)
    elseif token.type == 'down' || token.type == 'up'
      call add(nodes, token)
    elseif token.type == 'contents'
      call add(nodes[-1].contents, {'type': 'text', 'contents': token.contents})
    else
      let nodes[-1][token.type] = token.contents
    endif
  endfor
  return nodes
endfunction

function! emmet#addToLevel(item, level, tree)
  let tree = a:tree
  if a:level == 0
    if type(tree) != 3
      let tree = []
    endif
    call add(tree, a:item)
  else
    let tree[-1].contents = emmet#addToLevel(a:item, a:level - 1, tree[-1].contents)
  endif
  return tree
endfunction

function! emmet#parse(nodes)
  let ast = []
  let level = 0

  for node in a:nodes
    if node.type == 'up'
      let level = level - 1
    elseif node.type == 'down'
      let level = level + 1
    else
      let ast = emmet#addToLevel(node, level, ast)
    endif
  endfor

  return ast
endfunction

function! emmet#isMultiline(children)
  for child in a:children
    if child.type == 'node'
      return 1
    endif
  endfor
  return 0
endfunction

function! emmet#buildElements(ast, indentlevel)
  if a:indentlevel > 0
    let indent = '	'
  else
    let indent = ''
  endif
  let elements = []
  let i = 0
  for node in a:ast
    let i = i + 1
    if node.type == 'text'
      call add(elements, node.contents)
    else
      if emmet#isMultiline(node.contents)
        let children = '' . indent . emmet#buildElements(node.contents, a:indentlevel + 1) . ''
      else
        let children = emmet#buildElements(node.contents, a:indentlevel)
      endif
      if has_key(node, 'attributes')
        let attributes = ' ' . node.attributes
      else
        let attributes = ''
      endif
      echo len(a:ast)
      call add(elements,
            \ '<' . node.name . attributes.'>' .
            \ children .
            \ '</' . node.name . '>')
    endif
  endfor
  return join(elements, '')
endfunction

function! emmet#expand()
  let line = getline(a:firstline)
  normal! cc
  let ast = emmet#tokenize(split(line, '\zs'))
  let ast = emmet#combine(ast)
  let ast = emmet#parse(ast)
  let html = emmet#buildElements(ast, 1)
  return html
endfunction
