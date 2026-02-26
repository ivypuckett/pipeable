import gleam/int
import gleam/io
import gleam/list
import pipeable/lexer
import pipeable/parser

pub fn main() {
  let input =
    "use myPlugin : https://example.com/plugin
type Config : { name: string, count: int }
let version : 42
"

  case lexer.new(input) |> lexer.tokenize {
    Ok(tokens) ->
      case parser.new(tokens) |> parser.parse {
        Ok(file) ->
          io.println(
            "Parsed "
            <> int.to_string(list.length(file.statements))
            <> " statements successfully.",
          )
        Error(err) ->
          io.println("Parse error: " <> err.message)
      }
    Error(err) ->
      io.println("Lex error: " <> err.message)
  }
}
