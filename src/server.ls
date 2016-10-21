body-parser = require(\body-parser)
server = require(\express)()

{ convert-form, serialize-form } = require('./convert')

server.use(body-parser.json())

server.post \/convert, (request, response) ->
  try
    request.body |> convert-form |> serialize-form(response)
  catch ex
    response.statusCode = 400
    response.write(ex.message)
    response.write('\n')
    response.write(ex.stack)
    response.end()

server.listen(8686)

