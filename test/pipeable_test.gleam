import gleam/int
import gleam/io
import gleam/list
import pipeable/ast.{
  type File, type Statement, AccessorArg, ArrayLiteral, ArrayType,
  ArtifactStatement, CacheForField, DollarAccess, DotAccess, DurationLiteral,
  FieldSegment, File, FilePath, FilePathLiteral,
  IndexSegment, IntLiteral, IntPrim, Invocation, JobStatement, LetStatement,
  LitAccessor, LitLiteral, MaxVersionsField, NoArg, NumLiteral,
  ObjLitField, ObjectField, ObjectLiteral, ObjectType, ParamField, PipeStep,
  PrimType, StringLiteral, StringPrim, TupleLitArg, TupleLiteral, TupleType,
  TypeRef, TypeStatement, UrlLiteral, UrlPath, UrlPrim, UseStatement,
}
import pipeable/lexer
import pipeable/parser
import pipeable/token.{
  Artifact, Dollar, DollarDot, DurationLit, Eof, FilePathLit, IntLit, Job, Let,
  NumLit, StringLit, Token, TypeKw, UrlLit, Use,
}

pub fn main() {
  let results = [
    // --- Lexer Tests ---
    run("lex_simple_tokens", lex_simple_tokens),
    run("lex_string", lex_string),
    run("lex_number_and_duration", lex_number_and_duration),
    run("lex_url", lex_url),
    run("lex_file_path", lex_file_path),
    run("lex_comments", lex_comments),
    run("lex_dollar_tokens", lex_dollar_tokens),
    run("lex_keywords", lex_keywords),
    run("lex_duration_all_units", lex_duration_all_units),
    run("lex_num_trailing_dot", lex_num_trailing_dot),
    run("lex_string_escaped", lex_string_escaped),
    run("lex_error_unexpected_char", lex_error_unexpected_char),
    run("lex_error_unterminated_string", lex_error_unterminated_string),
    // --- Parser: Use ---
    run("parse_use_url", parse_use_url),
    run("parse_use_filepath", parse_use_filepath),
    run("parse_use_ssh", parse_use_ssh),
    // --- Parser: Type declarations ---
    run("parse_type_prim", parse_type_prim),
    run("parse_type_array", parse_type_array),
    run("parse_type_tuple", parse_type_tuple),
    run("parse_type_object", parse_type_object),
    run("parse_type_ref", parse_type_ref),
    run("parse_type_nested", parse_type_nested),
    run("parse_type_all_prims", parse_type_all_prims),
    // --- Parser: Artifact declarations ---
    run("parse_artifact", parse_artifact),
    run("parse_artifact_single_field", parse_artifact_single_field),
    run("parse_artifact_cache_only", parse_artifact_cache_only),
    // --- Parser: Job declarations ---
    run("parse_job_simple", parse_job_simple),
    run("parse_job_with_params", parse_job_with_params),
    run("parse_job_multi_invocation", parse_job_multi_invocation),
    run("parse_job_multi_step", parse_job_multi_step),
    // --- Parser: Let declarations ---
    run("parse_let_int", parse_let_int),
    run("parse_let_string", parse_let_string),
    run("parse_let_duration", parse_let_duration),
    run("parse_let_url", parse_let_url),
    run("parse_let_filepath", parse_let_filepath),
    run("parse_let_num", parse_let_num),
    // --- Parser: Accessors ---
    run("parse_accessor_dollar", parse_accessor_dollar),
    run("parse_accessor_dot", parse_accessor_dot),
    run("parse_accessor_in_tuple_arg", parse_accessor_in_tuple_arg),
    // --- Parser: Literals ---
    run("parse_tuple_literal", parse_tuple_literal),
    run("parse_tuple_trailing_comma", parse_tuple_trailing_comma),
    run("parse_array_literal", parse_array_literal),
    run("parse_object_literal", parse_object_literal),
    run("parse_object_trailing_comma", parse_object_trailing_comma),
    // --- Parser: Multi-statement ---
    run("parse_multiple_statements", parse_multiple_statements),
    run("parse_full_program", parse_full_program),
    // --- Parser: Error cases ---
    run("parse_error_bad_input", parse_error_bad_input),
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

fn lex_dollar_tokens() -> Bool {
  case lexer.new("$ $.") |> lexer.tokenize {
    Ok([Token(Dollar, _), Token(DollarDot, _), Token(Eof, _)]) -> True
    _ -> False
  }
}

fn lex_keywords() -> Bool {
  // Verify that reserved words produce keyword tokens, not Label tokens.
  case lexer.new("use type artifact job let") |> lexer.tokenize {
    Ok([
      Token(Use, _),
      Token(TypeKw, _),
      Token(Artifact, _),
      Token(Job, _),
      Token(Let, _),
      Token(Eof, _),
    ]) -> True
    _ -> False
  }
}

fn lex_duration_all_units() -> Bool {
  // All five duration units must be recognised.
  case lexer.new("1ms 2s 3m 4h 5d") |> lexer.tokenize {
    Ok([
      Token(DurationLit("1", "ms"), _),
      Token(DurationLit("2", "s"), _),
      Token(DurationLit("3", "m"), _),
      Token(DurationLit("4", "h"), _),
      Token(DurationLit("5", "d"), _),
      Token(Eof, _),
    ]) -> True
    _ -> False
  }
}

fn lex_num_trailing_dot() -> Bool {
  // NumLit <- [0-9]+ "." [0-9]*  — the fraction part is optional.
  case lexer.new("42.") |> lexer.tokenize {
    Ok([Token(NumLit("42."), _), Token(Eof, _)]) -> True
    _ -> False
  }
}

fn lex_string_escaped() -> Bool {
  // The lexer stores escape sequences verbatim (backslash + escaped char).
  // Pipeable source:  "a\b"  →  StringLit containing  a\b
  case lexer.new("\"a\\b\"") |> lexer.tokenize {
    Ok([Token(StringLit(val), _), Token(Eof, _)]) -> val == "a\\b"
    _ -> False
  }
}

fn lex_error_unexpected_char() -> Bool {
  // '@' is only valid inside a path, not at the start of a token.
  case lexer.new("@") |> lexer.tokenize {
    Error(_) -> True
    Ok(_) -> False
  }
}

fn lex_error_unterminated_string() -> Bool {
  case lexer.new("\"hello") |> lexer.tokenize {
    Error(_) -> True
    Ok(_) -> False
  }
}

// ---- Parser Tests: Use ----

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

fn parse_use_ssh() -> Bool {
  case parse_ok("use deploy : ssh://server.example.com") {
    Ok(file) ->
      case first_stmt(file) {
        UseStatement(label: "deploy", path: UrlPath(value: url)) ->
          url == "ssh://server.example.com"
        _ -> False
      }
    Error(_) -> False
  }
}

// ---- Parser Tests: Type Declarations ----

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

fn parse_type_nested() -> Bool {
  // An object type whose field is itself an array type.
  case parse_ok("type T : { items: [string] }") {
    Ok(file) ->
      case first_stmt(file) {
        TypeStatement(
          label: "T",
          type_expr: ObjectType(fields: [
            ObjectField(
              label: "items",
              type_expr: ArrayType(inner: PrimType(StringPrim)),
            ),
          ]),
        ) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_type_all_prims() -> Bool {
  // All six primitive type keywords must parse successfully.
  let inputs = [
    "type T : url",
    "type T : filepath",
    "type T : duration",
    "type T : int",
    "type T : num",
    "type T : string",
  ]
  list.all(inputs, fn(s) {
    case parse_ok(s) {
      Ok(_) -> True
      Error(_) -> False
    }
  })
}

// ---- Parser Tests: Artifact Declarations ----

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

fn parse_artifact_single_field() -> Bool {
  // An artifact with only maxVersions is valid.
  case parse_ok("artifact imgs Image : { maxVersions: 3 }") {
    Ok(file) ->
      case first_stmt(file) {
        ArtifactStatement(
          label: "imgs",
          type_label: "Image",
          fields: [MaxVersionsField(value: 3)],
        ) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_artifact_cache_only() -> Bool {
  // An artifact with only cacheFor is valid.
  case parse_ok("artifact cache FileCache : { cacheFor: 1h }") {
    Ok(file) ->
      case first_stmt(file) {
        ArtifactStatement(
          label: "cache",
          type_label: "FileCache",
          fields: [CacheForField(value: "1", unit: "h")],
        ) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

// ---- Parser Tests: Job Declarations ----

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

fn parse_job_multi_invocation() -> Bool {
  // PipeStep <- Invocation+: two invocations chained in the same step.
  case parse_ok("job test : foo bar;") {
    Ok(file) ->
      case first_stmt(file) {
        JobStatement(
          label: "test",
          params: [],
          body: [
            PipeStep(invocations: [
              Invocation(label: "foo", arg: NoArg),
              Invocation(label: "bar", arg: NoArg),
            ]),
          ],
        ) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_job_multi_step() -> Bool {
  // JobBody <- PipeStep ("," _ PipeStep)*: three comma-separated pipe steps.
  case parse_ok("job ci : build, test, deploy;") {
    Ok(file) ->
      case first_stmt(file) {
        JobStatement(
          label: "ci",
          params: [],
          body: [
            PipeStep(invocations: [Invocation(label: "build", arg: NoArg)]),
            PipeStep(invocations: [Invocation(label: "test", arg: NoArg)]),
            PipeStep(invocations: [Invocation(label: "deploy", arg: NoArg)]),
          ],
        ) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

// ---- Parser Tests: Let Declarations ----

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

fn parse_let_url() -> Bool {
  case parse_ok("let endpoint : https://api.example.com/v1") {
    Ok(file) ->
      case first_stmt(file) {
        LetStatement(
          label: "endpoint",
          value: UrlLiteral(value: "https://api.example.com/v1"),
        ) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_let_filepath() -> Bool {
  case parse_ok("let config : ~/myconfig") {
    Ok(file) ->
      case first_stmt(file) {
        LetStatement(
          label: "config",
          value: FilePathLiteral(value: "~/myconfig"),
        ) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_let_num() -> Bool {
  case parse_ok("let ratio : 3.14") {
    Ok(file) ->
      case first_stmt(file) {
        LetStatement(label: "ratio", value: NumLiteral(value: "3.14")) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

// ---- Parser Tests: Accessors ----

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

fn parse_accessor_in_tuple_arg() -> Bool {
  // Accessor inside a TupleLit arg: run ($.name, 42)
  case parse_ok("job test : run ($.name, 42);") {
    Ok(file) ->
      case first_stmt(file) {
        JobStatement(
          label: "test",
          body: [
            PipeStep(invocations: [
              Invocation(
                label: "run",
                arg: TupleLitArg(fields: [
                  LitAccessor(
                    accessor: DotAccess(path: [FieldSegment(name: "name")]),
                  ),
                  LitLiteral(literal: IntLiteral(value: 42)),
                ]),
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

// ---- Parser Tests: Literals ----

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

fn parse_tuple_trailing_comma() -> Bool {
  // Trailing comma inside a tuple literal must be accepted.
  case parse_ok("let t : (1, 2,)") {
    Ok(file) ->
      case first_stmt(file) {
        LetStatement(
          label: "t",
          value: TupleLiteral(fields: [
            LitLiteral(literal: IntLiteral(value: 1)),
            LitLiteral(literal: IntLiteral(value: 2)),
          ]),
        ) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

fn parse_array_literal() -> Bool {
  // ArrayLit <- "[" _ LitField _ "]"  (exactly one element).
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

fn parse_object_trailing_comma() -> Bool {
  // Trailing comma inside an object literal must be accepted.
  case parse_ok("let o : { x: 1, y: 2, }") {
    Ok(file) ->
      case first_stmt(file) {
        LetStatement(
          label: "o",
          value: ObjectLiteral(fields: [
            ObjLitField(
              label: "x",
              value: LitLiteral(literal: IntLiteral(value: 1)),
            ),
            ObjLitField(
              label: "y",
              value: LitLiteral(literal: IntLiteral(value: 2)),
            ),
          ]),
        ) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

// ---- Parser Tests: Multi-statement / Integration ----

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

// ---- Parser Tests: Error Cases ----

fn parse_error_bad_input() -> Bool {
  // Missing colon between label and path must produce an error.
  case parse_ok("use myPlugin https://example.com") {
    Error(_) -> True
    Ok(_) -> False
  }
}
