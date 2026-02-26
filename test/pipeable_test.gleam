import gleam/int
import gleam/io
import gleam/list
import pipeable/ast.{
  type File, type Statement, AccessorArg, ArrayLiteral, ArrayType,
  ArtifactStatement, CacheForField, DollarAccess, DotAccess, DurationLiteral,
  FieldSegment, File, FilePath, IndexSegment, IntLiteral, IntPrim, Invocation,
  JobStatement, LetStatement, LitLiteral, MaxVersionsField, NoArg,
  ObjLitField, ObjectField, ObjectLiteral, ObjectType, ParamField, PipeStep,
  PrimType, StringLiteral, StringPrim, TupleLiteral, TupleType, TypeRef,
  TypeStatement, UrlPath, UrlPrim, UseStatement,
}
import pipeable/lexer
import pipeable/parser
import pipeable/token.{DurationLit, Eof, FilePathLit, IntLit, NumLit,
  StringLit, Token, UrlLit,
}

pub fn main() {
  let results = [
    run("lex_simple_tokens", lex_simple_tokens),
    run("lex_string", lex_string),
    run("lex_number_and_duration", lex_number_and_duration),
    run("lex_url", lex_url),
    run("lex_file_path", lex_file_path),
    run("lex_comments", lex_comments),
    run("parse_use_url", parse_use_url),
    run("parse_use_filepath", parse_use_filepath),
    run("parse_type_prim", parse_type_prim),
    run("parse_type_array", parse_type_array),
    run("parse_type_tuple", parse_type_tuple),
    run("parse_type_object", parse_type_object),
    run("parse_type_ref", parse_type_ref),
    run("parse_artifact", parse_artifact),
    run("parse_job_simple", parse_job_simple),
    run("parse_job_with_params", parse_job_with_params),
    run("parse_let_int", parse_let_int),
    run("parse_let_string", parse_let_string),
    run("parse_let_duration", parse_let_duration),
    run("parse_accessor_dollar", parse_accessor_dollar),
    run("parse_accessor_dot", parse_accessor_dot),
    run("parse_tuple_literal", parse_tuple_literal),
    run("parse_array_literal", parse_array_literal),
    run("parse_object_literal", parse_object_literal),
    run("parse_multiple_statements", parse_multiple_statements),
    run("parse_full_program", parse_full_program),
  ]

  let passed = list.filter(results, fn(r) { r })
  let total = list.length(results)
  let pass_count = list.length(passed)

  io.println("")
  io.println(
    int.to_string(pass_count)
    <> "/"
    <> int.to_string(total)
    <> " tests passed.",
  )
  case pass_count == total {
    True -> io.println("All tests passed!")
    False -> io.println("SOME TESTS FAILED")
  }
}

fn run(name: String, test_fn: fn() -> Bool) -> Bool {
  case test_fn() {
    True -> {
      io.println("  PASS: " <> name)
      True
    }
    False -> {
      io.println("  FAIL: " <> name)
      False
    }
  }
}

fn parse_ok(input: String) -> Result(File, String) {
  case lexer.new(input) |> lexer.tokenize {
    Ok(tokens) ->
      case parser.new(tokens) |> parser.parse {
        Ok(file) -> Ok(file)
        Error(e) -> Error("Parse error: " <> e.message)
      }
    Error(e) -> Error("Lex error: " <> e.message)
  }
}

fn first_stmt(file: File) -> Statement {
  case file.statements {
    [s, ..] -> s
    [] -> panic as "no statements"
  }
}

// ---- Lexer Tests ----

fn lex_simple_tokens() -> Bool {
  case lexer.new(": , ; ( ) [ ] { }") |> lexer.tokenize {
    Ok(tokens) -> list.length(tokens) == 10
    Error(_) -> False
  }
}

fn lex_string() -> Bool {
  case lexer.new("\"hello world\"") |> lexer.tokenize {
    Ok([Token(StringLit(val), _), Token(Eof, _)]) -> val == "hello world"
    _ -> False
  }
}

fn lex_number_and_duration() -> Bool {
  case lexer.new("42 3.14 10s 500ms 2h") |> lexer.tokenize {
    Ok(tokens) -> {
      case tokens {
        [
          Token(IntLit("42"), _),
          Token(NumLit("3.14"), _),
          Token(DurationLit("10", "s"), _),
          Token(DurationLit("500", "ms"), _),
          Token(DurationLit("2", "h"), _),
          Token(Eof, _),
        ] -> True
        _ -> False
      }
    }
    Error(_) -> False
  }
}

fn lex_url() -> Bool {
  case lexer.new("https://example.com/path") |> lexer.tokenize {
    Ok([Token(UrlLit(url), _), Token(Eof, _)]) ->
      url == "https://example.com/path"
    _ -> False
  }
}

fn lex_file_path() -> Bool {
  case lexer.new("~/config ./local /absolute") |> lexer.tokenize {
    Ok([
      Token(FilePathLit(a), _),
      Token(FilePathLit(b), _),
      Token(FilePathLit(c), _),
      Token(Eof, _),
    ]) -> a == "~/config" && b == "./local" && c == "/absolute"
    _ -> False
  }
}

fn lex_comments() -> Bool {
  case lexer.new("42 # this is a comment\n43") |> lexer.tokenize {
    Ok([Token(IntLit("42"), _), Token(IntLit("43"), _), Token(Eof, _)]) ->
      True
    _ -> False
  }
}

// ---- Parser Tests ----

fn parse_use_url() -> Bool {
  case parse_ok("use myPlugin : https://example.com/plugin") {
    Ok(file) ->
      case first_stmt(file) {
        UseStatement(label: "myPlugin", path: UrlPath(value: url)) ->
          url == "https://example.com/plugin"
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_use_filepath() -> Bool {
  case parse_ok("use config : ~/myconfig") {
    Ok(file) ->
      case first_stmt(file) {
        UseStatement(label: "config", path: FilePath(value: p)) ->
          p == "~/myconfig"
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_type_prim() -> Bool {
  case parse_ok("type MyUrl : url") {
    Ok(file) ->
      case first_stmt(file) {
        TypeStatement(label: "MyUrl", type_expr: PrimType(UrlPrim)) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_type_array() -> Bool {
  case parse_ok("type Names : [string]") {
    Ok(file) ->
      case first_stmt(file) {
        TypeStatement(
          label: "Names",
          type_expr: ArrayType(inner: PrimType(StringPrim)),
        ) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_type_tuple() -> Bool {
  case parse_ok("type Pair : (int, string)") {
    Ok(file) ->
      case first_stmt(file) {
        TypeStatement(
          label: "Pair",
          type_expr: TupleType(elements: [PrimType(IntPrim), PrimType(StringPrim)]),
        ) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_type_object() -> Bool {
  case parse_ok("type Config : { name: string, count: int }") {
    Ok(file) ->
      case first_stmt(file) {
        TypeStatement(
          label: "Config",
          type_expr: ObjectType(fields: [
            ObjectField(label: "name", type_expr: PrimType(StringPrim)),
            ObjectField(label: "count", type_expr: PrimType(IntPrim)),
          ]),
        ) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_type_ref() -> Bool {
  case parse_ok("type Alias : Config") {
    Ok(file) ->
      case first_stmt(file) {
        TypeStatement(label: "Alias", type_expr: TypeRef(label: "Config")) ->
          True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_artifact() -> Bool {
  case
    parse_ok(
      "artifact logs LogEntry : { maxVersions: 5, cacheFor: 24h }",
    )
  {
    Ok(file) ->
      case first_stmt(file) {
        ArtifactStatement(
          label: "logs",
          type_label: "LogEntry",
          fields: [
            MaxVersionsField(value: 5),
            CacheForField(value: "24", unit: "h"),
          ],
        ) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_job_simple() -> Bool {
  case parse_ok("job build : compile;") {
    Ok(file) ->
      case first_stmt(file) {
        JobStatement(
          label: "build",
          params: [],
          body: [PipeStep(invocations: [Invocation(label: "compile", arg: NoArg)])],
        ) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_job_with_params() -> Bool {
  case parse_ok("job deploy { env: string } : build, push;") {
    Ok(file) ->
      case first_stmt(file) {
        JobStatement(
          label: "deploy",
          params: [ParamField(label: "env", type_expr: PrimType(StringPrim))],
          body: [
            PipeStep(invocations: [Invocation(label: "build", arg: NoArg)]),
            PipeStep(invocations: [Invocation(label: "push", arg: NoArg)]),
          ],
        ) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_let_int() -> Bool {
  case parse_ok("let count : 42") {
    Ok(file) ->
      case first_stmt(file) {
        LetStatement(label: "count", value: IntLiteral(value: 42)) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_let_string() -> Bool {
  case parse_ok("let name : \"hello\"") {
    Ok(file) ->
      case first_stmt(file) {
        LetStatement(label: "name", value: StringLiteral(value: "hello")) ->
          True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_let_duration() -> Bool {
  case parse_ok("let timeout : 30s") {
    Ok(file) ->
      case first_stmt(file) {
        LetStatement(
          label: "timeout",
          value: DurationLiteral(value: "30", unit: "s"),
        ) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_accessor_dollar() -> Bool {
  case parse_ok("job test : run $;") {
    Ok(file) ->
      case first_stmt(file) {
        JobStatement(
          label: "test",
          body: [
            PipeStep(invocations: [
              Invocation(
                label: "run",
                arg: AccessorArg(accessor: DollarAccess),
              ),
            ]),
          ],
          ..,
        ) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_accessor_dot() -> Bool {
  case parse_ok("job test : run $.name.0;") {
    Ok(file) ->
      case first_stmt(file) {
        JobStatement(
          label: "test",
          body: [
            PipeStep(invocations: [
              Invocation(
                label: "run",
                arg: AccessorArg(
                  accessor: DotAccess(path: [
                    FieldSegment(name: "name"),
                    IndexSegment(index: 0),
                  ]),
                ),
              ),
            ]),
          ],
          ..,
        ) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_tuple_literal() -> Bool {
  case parse_ok("let pair : (1, \"two\")") {
    Ok(file) ->
      case first_stmt(file) {
        LetStatement(
          label: "pair",
          value: TupleLiteral(fields: [
            LitLiteral(literal: IntLiteral(value: 1)),
            LitLiteral(literal: StringLiteral(value: "two")),
          ]),
        ) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_array_literal() -> Bool {
  case parse_ok("let nums : [1]") {
    Ok(file) ->
      case first_stmt(file) {
        LetStatement(
          label: "nums",
          value: ArrayLiteral(fields: [LitLiteral(literal: IntLiteral(value: 1))]),
        ) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_object_literal() -> Bool {
  case parse_ok("let cfg : { name: \"test\", count: 5 }") {
    Ok(file) ->
      case first_stmt(file) {
        LetStatement(
          label: "cfg",
          value: ObjectLiteral(fields: [
            ObjLitField(
              label: "name",
              value: LitLiteral(literal: StringLiteral(value: "test")),
            ),
            ObjLitField(
              label: "count",
              value: LitLiteral(literal: IntLiteral(value: 5)),
            ),
          ]),
        ) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_multiple_statements() -> Bool {
  let input =
    "use plugin : https://example.com
type Config : string
let ver : 1"
  case parse_ok(input) {
    Ok(file) -> list.length(file.statements) == 3
    Error(_) -> False
  }
}

fn parse_full_program() -> Bool {
  let input =
    "# A full pipeable program
use docker : https://registry.example.com/docker

type BuildConfig : { target: string, optimize: int }

artifact logs BuildLog : { maxVersions: 10, cacheFor: 24h }

job build { config: BuildConfig } : compile, test, package;

let timeout : 30s
let name : \"my-project\"
"
  case parse_ok(input) {
    Ok(file) -> list.length(file.statements) == 6
    Error(_) -> False
  }
}
