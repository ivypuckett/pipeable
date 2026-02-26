import gleam/int
import gleam/list
import gleam/result
import pipeable/ast.{
  type Accessor, type Arg, type ArtifactField, type File, type Invocation,
  type LitField, type Literal, type ObjLitField, type ObjectField,
  type ParamField, type Path, type PipeStep, type Statement, type TypeExpr,
  type AccessSegment, AccessorArg, ArrayLiteral, ArrayType, ArtifactStatement, CacheForField,
  DollarAccess, DotAccess, DurationLiteral, DurationPrim, FieldSegment, File,
  FilePath, FilePathLiteral, FilepathPrim, IndexSegment, IntLiteral, IntPrim,
  Invocation, LetStatement, LitAccessor, LitLiteral, LiteralArg,
  MaxVersionsField, NoArg, NumLiteral, NumPrim, ObjLitField, ObjectField,
  ObjectLiteral, ObjectType, ParamField, PipeStep, PrimType, StringLiteral,
  StringPrim, TupleLitArg, TupleLiteral, TupleType, TypeRef, TypeStatement,
  UrlLiteral, UrlPath, UrlPrim, UseStatement, JobStatement,
}
import pipeable/token.{
  type Position, type Token, type TokenKind, Artifact, CacheFor, Colon, Comma,
  Dollar, DollarDot, Dot, DurationLit, DurationType, Eof, FilePathLit,
  FilepathType, IntLit, IntType, Job, LBrace, LBracket, LParen, Label, Let,
  MaxVersions, NumLit, NumType, Position, RBrace, RBracket, RParen, Semicolon,
  StringLit, StringType, Token, TypeKw, UrlLit, UrlType, Use,
}

pub type ParseError {
  ParseError(message: String, pos: Position)
}

pub type Parser {
  Parser(tokens: List(Token))
}

pub fn new(tokens: List(Token)) -> Parser {
  Parser(tokens: tokens)
}

pub fn parse(parser: Parser) -> Result(File, ParseError) {
  parse_file(parser)
}

// --- Helpers ---

fn peek(parser: Parser) -> TokenKind {
  case parser.tokens {
    [Token(kind, _), ..] -> kind
    [] -> Eof
  }
}

fn peek_pos(parser: Parser) -> Position {
  case parser.tokens {
    [Token(_, pos), ..] -> pos
    [] -> Position(0, 0)
  }
}

fn expect(
  parser: Parser,
  expected: TokenKind,
) -> Result(#(Token, Parser), ParseError) {
  case parser.tokens {
    [Token(kind, _pos) as tok, ..rest] if kind == expected ->
      Ok(#(tok, Parser(tokens: rest)))
    [Token(_, pos), ..] ->
      Error(ParseError(
        "Expected " <> token_kind_to_string(expected),
        pos,
      ))
    [] ->
      Error(ParseError(
        "Expected " <> token_kind_to_string(expected) <> " but got EOF",
        Position(0, 0),
      ))
  }
}

fn advance(parser: Parser) -> #(Token, Parser) {
  case parser.tokens {
    [tok, ..rest] -> #(tok, Parser(tokens: rest))
    [] -> #(Token(Eof, Position(0, 0)), parser)
  }
}

fn token_kind_to_string(kind: TokenKind) -> String {
  case kind {
    Use -> "use"
    TypeKw -> "type"
    Artifact -> "artifact"
    Job -> "job"
    Let -> "let"
    MaxVersions -> "maxVersions"
    CacheFor -> "cacheFor"
    UrlType -> "url"
    FilepathType -> "filepath"
    DurationType -> "duration"
    IntType -> "int"
    NumType -> "num"
    StringType -> "string"
    Colon -> ":"
    Comma -> ","
    Semicolon -> ";"
    LParen -> "("
    RParen -> ")"
    LBracket -> "["
    RBracket -> "]"
    LBrace -> "{"
    RBrace -> "}"
    Dollar -> "$"
    DollarDot -> "$."
    Dot -> "."
    IntLit(_) -> "integer"
    NumLit(_) -> "number"
    StringLit(_) -> "string literal"
    DurationLit(_, _) -> "duration"
    UrlLit(_) -> "URL"
    FilePathLit(_) -> "file path"
    Label(_) -> "label"
    Eof -> "EOF"
  }
}

// --- File ---

fn parse_file(parser: Parser) -> Result(File, ParseError) {
  parse_statements(parser, [])
}

fn parse_statements(
  parser: Parser,
  acc: List(Statement),
) -> Result(File, ParseError) {
  case peek(parser) {
    Eof -> Ok(File(statements: list.reverse(acc)))
    _ ->
      case parse_statement(parser) {
        Ok(#(stmt, rest)) -> parse_statements(rest, [stmt, ..acc])
        Error(e) -> Error(e)
      }
  }
}

// --- Statement ---

fn parse_statement(parser: Parser) -> Result(#(Statement, Parser), ParseError) {
  case peek(parser) {
    Use -> parse_use(parser)
    TypeKw -> parse_type_decl(parser)
    Artifact -> parse_artifact_decl(parser)
    Job -> parse_job_decl(parser)
    Let -> parse_let_decl(parser)
    _ ->
      Error(ParseError(
        "Expected statement (use, type, artifact, job, or let)",
        peek_pos(parser),
      ))
  }
}

// --- Use ---

fn parse_use(parser: Parser) -> Result(#(Statement, Parser), ParseError) {
  use #(_, parser) <- result.try(expect(parser, Use))
  use #(label, parser) <- result.try(expect_label(parser))
  use #(_, parser) <- result.try(expect(parser, Colon))
  use #(path, parser) <- result.try(parse_path(parser))
  Ok(#(UseStatement(label: label, path: path), parser))
}

fn expect_label(parser: Parser) -> Result(#(String, Parser), ParseError) {
  case parser.tokens {
    [Token(Label(name), _), ..rest] -> Ok(#(name, Parser(tokens: rest)))
    [Token(_, pos), ..] ->
      Error(ParseError("Expected label", pos))
    [] ->
      Error(ParseError("Expected label but got EOF", Position(0, 0)))
  }
}

fn parse_path(parser: Parser) -> Result(#(Path, Parser), ParseError) {
  case parser.tokens {
    [Token(UrlLit(url), _), ..rest] ->
      Ok(#(UrlPath(value: url), Parser(tokens: rest)))
    [Token(FilePathLit(path), _), ..rest] ->
      Ok(#(FilePath(value: path), Parser(tokens: rest)))
    [Token(_, pos), ..] -> Error(ParseError("Expected URL or file path", pos))
    [] -> Error(ParseError("Expected path but got EOF", Position(0, 0)))
  }
}

// --- Type Declaration ---

fn parse_type_decl(parser: Parser) -> Result(#(Statement, Parser), ParseError) {
  use #(_, parser) <- result.try(expect(parser, TypeKw))
  use #(label, parser) <- result.try(expect_label(parser))
  use #(_, parser) <- result.try(expect(parser, Colon))
  use #(type_expr, parser) <- result.try(parse_type_expr(parser))
  Ok(#(TypeStatement(label: label, type_expr: type_expr), parser))
}

fn parse_type_expr(parser: Parser) -> Result(#(TypeExpr, Parser), ParseError) {
  case peek(parser) {
    UrlType -> {
      let #(_, parser) = advance(parser)
      Ok(#(PrimType(UrlPrim), parser))
    }
    FilepathType -> {
      let #(_, parser) = advance(parser)
      Ok(#(PrimType(FilepathPrim), parser))
    }
    DurationType -> {
      let #(_, parser) = advance(parser)
      Ok(#(PrimType(DurationPrim), parser))
    }
    IntType -> {
      let #(_, parser) = advance(parser)
      Ok(#(PrimType(IntPrim), parser))
    }
    NumType -> {
      let #(_, parser) = advance(parser)
      Ok(#(PrimType(NumPrim), parser))
    }
    StringType -> {
      let #(_, parser) = advance(parser)
      Ok(#(PrimType(StringPrim), parser))
    }
    LBracket -> parse_array_type(parser)
    LParen -> parse_tuple_type(parser)
    LBrace -> parse_object_type(parser)
    Label(_) -> {
      use #(name, parser) <- result.try(expect_label(parser))
      Ok(#(TypeRef(label: name), parser))
    }
    _ ->
      Error(ParseError("Expected type expression", peek_pos(parser)))
  }
}

fn parse_array_type(parser: Parser) -> Result(#(TypeExpr, Parser), ParseError) {
  use #(_, parser) <- result.try(expect(parser, LBracket))
  use #(inner, parser) <- result.try(parse_type_expr(parser))
  use #(_, parser) <- result.try(expect(parser, RBracket))
  Ok(#(ArrayType(inner: inner), parser))
}

fn parse_tuple_type(parser: Parser) -> Result(#(TypeExpr, Parser), ParseError) {
  use #(_, parser) <- result.try(expect(parser, LParen))
  use #(first, parser) <- result.try(parse_type_expr(parser))
  use #(rest, parser) <- result.try(parse_comma_type_exprs(parser, []))
  // Optional trailing comma
  let parser = skip_optional(parser, Comma)
  use #(_, parser) <- result.try(expect(parser, RParen))
  Ok(#(TupleType(elements: [first, ..list.reverse(rest)]), parser))
}

fn parse_comma_type_exprs(
  parser: Parser,
  acc: List(TypeExpr),
) -> Result(#(List(TypeExpr), Parser), ParseError) {
  case peek(parser) {
    Comma ->
      case peek_at(parser, 1) {
        RParen -> Ok(#(acc, parser))
        _ -> {
          let #(_, parser) = advance(parser)
          use #(expr, parser) <- result.try(parse_type_expr(parser))
          parse_comma_type_exprs(parser, [expr, ..acc])
        }
      }
    _ -> Ok(#(acc, parser))
  }
}

fn parse_object_type(
  parser: Parser,
) -> Result(#(TypeExpr, Parser), ParseError) {
  use #(_, parser) <- result.try(expect(parser, LBrace))
  use #(first, parser) <- result.try(parse_object_field(parser))
  use #(rest, parser) <- result.try(parse_comma_object_fields(parser, []))
  let parser = skip_optional(parser, Comma)
  use #(_, parser) <- result.try(expect(parser, RBrace))
  Ok(#(
    ObjectType(fields: [first, ..list.reverse(rest)]),
    parser,
  ))
}

fn parse_object_field(
  parser: Parser,
) -> Result(#(ObjectField, Parser), ParseError) {
  use #(label, parser) <- result.try(expect_label(parser))
  use #(_, parser) <- result.try(expect(parser, Colon))
  use #(type_expr, parser) <- result.try(parse_type_expr(parser))
  Ok(#(ObjectField(label: label, type_expr: type_expr), parser))
}

fn parse_comma_object_fields(
  parser: Parser,
  acc: List(ObjectField),
) -> Result(#(List(ObjectField), Parser), ParseError) {
  case peek(parser) {
    Comma ->
      case peek_at(parser, 1) {
        RBrace -> Ok(#(acc, parser))
        _ -> {
          let #(_, parser) = advance(parser)
          use #(field, parser) <- result.try(parse_object_field(parser))
          parse_comma_object_fields(parser, [field, ..acc])
        }
      }
    _ -> Ok(#(acc, parser))
  }
}

// --- Artifact Declaration ---

fn parse_artifact_decl(
  parser: Parser,
) -> Result(#(Statement, Parser), ParseError) {
  use #(_, parser) <- result.try(expect(parser, Artifact))
  use #(label, parser) <- result.try(expect_label(parser))
  use #(type_label, parser) <- result.try(expect_label(parser))
  use #(_, parser) <- result.try(expect(parser, Colon))
  use #(_, parser) <- result.try(expect(parser, LBrace))
  use #(fields, parser) <- result.try(parse_artifact_fields(parser))
  let parser = skip_optional(parser, Comma)
  use #(_, parser) <- result.try(expect(parser, RBrace))
  Ok(#(
    ArtifactStatement(label: label, type_label: type_label, fields: fields),
    parser,
  ))
}

fn parse_artifact_fields(
  parser: Parser,
) -> Result(#(List(ArtifactField), Parser), ParseError) {
  use #(first, parser) <- result.try(parse_artifact_field(parser))
  use #(rest, parser) <- result.try(parse_comma_artifact_fields(parser, []))
  Ok(#([first, ..list.reverse(rest)], parser))
}

fn parse_artifact_field(
  parser: Parser,
) -> Result(#(ArtifactField, Parser), ParseError) {
  case peek(parser) {
    MaxVersions -> {
      let #(_, parser) = advance(parser)
      use #(_, parser) <- result.try(expect(parser, Colon))
      case parser.tokens {
        [Token(IntLit(val), _), ..rest] ->
          case int.parse(val) {
            Ok(n) -> Ok(#(MaxVersionsField(value: n), Parser(tokens: rest)))
            Error(_) ->
              Error(ParseError("Invalid integer", peek_pos(parser)))
          }
        _ -> Error(ParseError("Expected integer", peek_pos(parser)))
      }
    }
    CacheFor -> {
      let #(_, parser) = advance(parser)
      use #(_, parser) <- result.try(expect(parser, Colon))
      case parser.tokens {
        [Token(DurationLit(val, unit), _), ..rest] ->
          Ok(#(
            CacheForField(value: val, unit: unit),
            Parser(tokens: rest),
          ))
        _ -> Error(ParseError("Expected duration", peek_pos(parser)))
      }
    }
    _ ->
      Error(ParseError(
        "Expected artifact field (maxVersions or cacheFor)",
        peek_pos(parser),
      ))
  }
}

fn parse_comma_artifact_fields(
  parser: Parser,
  acc: List(ArtifactField),
) -> Result(#(List(ArtifactField), Parser), ParseError) {
  case peek(parser) {
    Comma ->
      case peek_at(parser, 1) {
        RBrace -> Ok(#(acc, parser))
        _ -> {
          let #(_, parser) = advance(parser)
          use #(field, parser) <- result.try(parse_artifact_field(parser))
          parse_comma_artifact_fields(parser, [field, ..acc])
        }
      }
    _ -> Ok(#(acc, parser))
  }
}

// --- Job Declaration ---

fn parse_job_decl(parser: Parser) -> Result(#(Statement, Parser), ParseError) {
  use #(_, parser) <- result.try(expect(parser, Job))
  use #(label, parser) <- result.try(expect_label(parser))
  let #(params, parser) = case peek(parser) {
    LBrace -> {
      case parse_job_params(parser) {
        Ok(#(p, rest)) -> #(p, rest)
        Error(_) -> #([], parser)
      }
    }
    _ -> #([], parser)
  }
  use #(_, parser) <- result.try(expect(parser, Colon))
  use #(body, parser) <- result.try(parse_job_body(parser))
  Ok(#(
    JobStatement(label: label, params: params, body: body),
    parser,
  ))
}

fn parse_job_params(
  parser: Parser,
) -> Result(#(List(ParamField), Parser), ParseError) {
  use #(_, parser) <- result.try(expect(parser, LBrace))
  use #(first, parser) <- result.try(parse_param_field(parser))
  use #(rest, parser) <- result.try(parse_comma_param_fields(parser, []))
  let parser = skip_optional(parser, Comma)
  use #(_, parser) <- result.try(expect(parser, RBrace))
  Ok(#([first, ..list.reverse(rest)], parser))
}

fn parse_param_field(
  parser: Parser,
) -> Result(#(ParamField, Parser), ParseError) {
  use #(label, parser) <- result.try(expect_label(parser))
  use #(_, parser) <- result.try(expect(parser, Colon))
  use #(type_expr, parser) <- result.try(parse_type_expr(parser))
  Ok(#(ParamField(label: label, type_expr: type_expr), parser))
}

fn parse_comma_param_fields(
  parser: Parser,
  acc: List(ParamField),
) -> Result(#(List(ParamField), Parser), ParseError) {
  case peek(parser) {
    Comma ->
      case peek_at(parser, 1) {
        RBrace -> Ok(#(acc, parser))
        _ -> {
          let #(_, parser) = advance(parser)
          use #(field, parser) <- result.try(parse_param_field(parser))
          parse_comma_param_fields(parser, [field, ..acc])
        }
      }
    _ -> Ok(#(acc, parser))
  }
}

fn parse_job_body(
  parser: Parser,
) -> Result(#(List(PipeStep), Parser), ParseError) {
  use #(first, parser) <- result.try(parse_pipe_step(parser))
  use #(rest, parser) <- result.try(parse_comma_pipe_steps(parser, []))
  use #(_, parser) <- result.try(expect(parser, Semicolon))
  Ok(#([first, ..list.reverse(rest)], parser))
}

fn parse_comma_pipe_steps(
  parser: Parser,
  acc: List(PipeStep),
) -> Result(#(List(PipeStep), Parser), ParseError) {
  case peek(parser) {
    Comma -> {
      let #(_, parser) = advance(parser)
      use #(step, parser) <- result.try(parse_pipe_step(parser))
      parse_comma_pipe_steps(parser, [step, ..acc])
    }
    _ -> Ok(#(acc, parser))
  }
}

fn parse_pipe_step(
  parser: Parser,
) -> Result(#(PipeStep, Parser), ParseError) {
  use #(first, parser) <- result.try(parse_invocation(parser))
  use #(rest, parser) <- result.try(parse_more_invocations(parser, []))
  Ok(#(PipeStep(invocations: [first, ..list.reverse(rest)]), parser))
}

fn parse_more_invocations(
  parser: Parser,
  acc: List(Invocation),
) -> Result(#(List(Invocation), Parser), ParseError) {
  case peek(parser) {
    Label(_) -> {
      use #(inv, parser) <- result.try(parse_invocation(parser))
      parse_more_invocations(parser, [inv, ..acc])
    }
    _ -> Ok(#(acc, parser))
  }
}

fn parse_invocation(
  parser: Parser,
) -> Result(#(Invocation, Parser), ParseError) {
  use #(label, parser) <- result.try(expect_label(parser))
  let #(arg, parser) = parse_optional_arg(parser)
  Ok(#(Invocation(label: label, arg: arg), parser))
}

fn parse_optional_arg(parser: Parser) -> #(Arg, Parser) {
  case peek(parser) {
    LParen ->
      case parse_tuple_lit(parser) {
        Ok(#(lit, rest)) -> #(TupleLitArg(fields: get_tuple_fields(lit)), rest)
        Error(_) -> #(NoArg, parser)
      }
    Dollar -> {
      let #(_, rest) = advance(parser)
      #(AccessorArg(accessor: DollarAccess), rest)
    }
    DollarDot -> {
      case parse_accessor_dot(parser) {
        Ok(#(acc, rest)) -> #(AccessorArg(accessor: acc), rest)
        Error(_) -> #(NoArg, parser)
      }
    }
    IntLit(_) | NumLit(_) | StringLit(_) | DurationLit(_, _) | UrlLit(_)
    | FilePathLit(_) | LBracket | LBrace ->
      case parse_literal(parser) {
        Ok(#(lit, rest)) -> #(LiteralArg(literal: lit), rest)
        Error(_) -> #(NoArg, parser)
      }
    Label(_) ->
      // Check if it looks like a label arg (not the start of a new invocation)
      // A label arg is consumed only if the next-next token isn't another label
      // Actually, in the grammar: Invocation <- Label (_ Arg)? and Arg includes Label
      // But PipeStep <- Invocation+ means we need to be careful.
      // A bare Label as Arg would make the next parse_invocation fail, so we
      // leave bare labels to be parsed as new invocations. Label args only occur
      // when explicitly intended — hard to distinguish without more context.
      // For now, don't consume labels as args to avoid ambiguity with chained invocations.
      #(NoArg, parser)
    _ -> #(NoArg, parser)
  }
}

fn get_tuple_fields(lit: Literal) -> List(LitField) {
  case lit {
    TupleLiteral(fields) -> fields
    _ -> []
  }
}

// --- Accessor ---

fn parse_accessor_dot(
  parser: Parser,
) -> Result(#(Accessor, Parser), ParseError) {
  use #(_, parser) <- result.try(expect(parser, DollarDot))
  use #(path, parser) <- result.try(parse_access_path(parser))
  Ok(#(DotAccess(path: path), parser))
}

fn parse_access_path(
  parser: Parser,
) -> Result(#(List(AccessSegment), Parser), ParseError) {
  use #(first, parser) <- result.try(parse_access_segment(parser))
  use #(rest, parser) <- result.try(parse_dot_segments(parser, []))
  Ok(#([first, ..list.reverse(rest)], parser))
}

fn parse_access_segment(
  parser: Parser,
) -> Result(#(AccessSegment, Parser), ParseError) {
  case parser.tokens {
    [Token(Label(name), _), ..rest] ->
      Ok(#(FieldSegment(name: name), Parser(tokens: rest)))
    [Token(IntLit(val), _), ..rest] ->
      case int.parse(val) {
        Ok(n) -> Ok(#(IndexSegment(index: n), Parser(tokens: rest)))
        Error(_) ->
          Error(ParseError("Invalid index", peek_pos(parser)))
      }
    _ ->
      Error(ParseError("Expected field name or index", peek_pos(parser)))
  }
}

fn parse_dot_segments(
  parser: Parser,
  acc: List(AccessSegment),
) -> Result(#(List(AccessSegment), Parser), ParseError) {
  case peek(parser) {
    Dot -> {
      let #(_, parser) = advance(parser)
      use #(seg, parser) <- result.try(parse_access_segment(parser))
      parse_dot_segments(parser, [seg, ..acc])
    }
    _ -> Ok(#(acc, parser))
  }
}

// --- Let Declaration ---

fn parse_let_decl(parser: Parser) -> Result(#(Statement, Parser), ParseError) {
  use #(_, parser) <- result.try(expect(parser, Let))
  use #(label, parser) <- result.try(expect_label(parser))
  use #(_, parser) <- result.try(expect(parser, Colon))
  use #(lit, parser) <- result.try(parse_literal(parser))
  Ok(#(LetStatement(label: label, value: lit), parser))
}

// --- Literals ---

fn parse_literal(
  parser: Parser,
) -> Result(#(Literal, Parser), ParseError) {
  case parser.tokens {
    [Token(DurationLit(val, unit), _), ..rest] ->
      Ok(#(DurationLiteral(value: val, unit: unit), Parser(tokens: rest)))
    [Token(NumLit(val), _), ..rest] ->
      Ok(#(NumLiteral(value: val), Parser(tokens: rest)))
    [Token(IntLit(val), _), ..rest] ->
      case int.parse(val) {
        Ok(n) -> Ok(#(IntLiteral(value: n), Parser(tokens: rest)))
        Error(_) ->
          Error(ParseError("Invalid integer", peek_pos(parser)))
      }
    [Token(StringLit(val), _), ..rest] ->
      Ok(#(StringLiteral(value: val), Parser(tokens: rest)))
    [Token(UrlLit(val), _), ..rest] ->
      Ok(#(UrlLiteral(value: val), Parser(tokens: rest)))
    [Token(FilePathLit(val), _), ..rest] ->
      Ok(#(FilePathLiteral(value: val), Parser(tokens: rest)))
    _ ->
      case peek(parser) {
        LParen -> parse_tuple_lit(parser)
        LBracket -> parse_array_lit(parser)
        LBrace -> parse_object_lit(parser)
        _ ->
          Error(ParseError("Expected literal", peek_pos(parser)))
      }
  }
}

fn parse_tuple_lit(
  parser: Parser,
) -> Result(#(Literal, Parser), ParseError) {
  use #(_, parser) <- result.try(expect(parser, LParen))
  use #(first, parser) <- result.try(parse_lit_field(parser))
  use #(rest, parser) <- result.try(parse_comma_lit_fields(parser, []))
  let parser = skip_optional(parser, Comma)
  use #(_, parser) <- result.try(expect(parser, RParen))
  Ok(#(TupleLiteral(fields: [first, ..list.reverse(rest)]), parser))
}

fn parse_array_lit(
  parser: Parser,
) -> Result(#(Literal, Parser), ParseError) {
  use #(_, parser) <- result.try(expect(parser, LBracket))
  use #(fields, parser) <- result.try(parse_array_lit_fields(parser))
  use #(_, parser) <- result.try(expect(parser, RBracket))
  Ok(#(ArrayLiteral(fields: fields), parser))
}

fn parse_array_lit_fields(
  parser: Parser,
) -> Result(#(List(LitField), Parser), ParseError) {
  case peek(parser) {
    RBracket -> Ok(#([], parser))
    _ -> {
      use #(first, parser) <- result.try(parse_lit_field(parser))
      use #(rest, parser) <- result.try(parse_comma_lit_fields(parser, []))
      let parser = skip_optional(parser, Comma)
      Ok(#([first, ..list.reverse(rest)], parser))
    }
  }
}

fn parse_object_lit(
  parser: Parser,
) -> Result(#(Literal, Parser), ParseError) {
  use #(_, parser) <- result.try(expect(parser, LBrace))
  use #(first, parser) <- result.try(parse_obj_lit_field(parser))
  use #(rest, parser) <- result.try(parse_comma_obj_lit_fields(parser, []))
  let parser = skip_optional(parser, Comma)
  use #(_, parser) <- result.try(expect(parser, RBrace))
  Ok(#(
    ObjectLiteral(fields: [first, ..list.reverse(rest)]),
    parser,
  ))
}

fn parse_obj_lit_field(
  parser: Parser,
) -> Result(#(ObjLitField, Parser), ParseError) {
  use #(label, parser) <- result.try(expect_label(parser))
  use #(_, parser) <- result.try(expect(parser, Colon))
  use #(field, parser) <- result.try(parse_lit_field(parser))
  Ok(#(ObjLitField(label: label, value: field), parser))
}

fn parse_comma_obj_lit_fields(
  parser: Parser,
  acc: List(ObjLitField),
) -> Result(#(List(ObjLitField), Parser), ParseError) {
  case peek(parser) {
    Comma ->
      case peek_at(parser, 1) {
        RBrace -> Ok(#(acc, parser))
        _ -> {
          let #(_, parser) = advance(parser)
          use #(field, parser) <- result.try(parse_obj_lit_field(parser))
          parse_comma_obj_lit_fields(parser, [field, ..acc])
        }
      }
    _ -> Ok(#(acc, parser))
  }
}

fn parse_lit_field(
  parser: Parser,
) -> Result(#(LitField, Parser), ParseError) {
  case peek(parser) {
    Dollar -> {
      let #(_, parser) = advance(parser)
      Ok(#(LitAccessor(accessor: DollarAccess), parser))
    }
    DollarDot -> {
      use #(acc, parser) <- result.try(parse_accessor_dot(parser))
      Ok(#(LitAccessor(accessor: acc), parser))
    }
    _ -> {
      use #(lit, parser) <- result.try(parse_literal(parser))
      Ok(#(LitLiteral(literal: lit), parser))
    }
  }
}

fn parse_comma_lit_fields(
  parser: Parser,
  acc: List(LitField),
) -> Result(#(List(LitField), Parser), ParseError) {
  case peek(parser) {
    Comma ->
      case peek_at(parser, 1) {
        RParen | RBracket | RBrace -> Ok(#(acc, parser))
        _ -> {
          let #(_, parser) = advance(parser)
          use #(field, parser) <- result.try(parse_lit_field(parser))
          parse_comma_lit_fields(parser, [field, ..acc])
        }
      }
    _ -> Ok(#(acc, parser))
  }
}

// --- Utilities ---

fn skip_optional(parser: Parser, kind: TokenKind) -> Parser {
  case parser.tokens {
    [Token(k, _), ..rest] if k == kind -> Parser(tokens: rest)
    _ -> parser
  }
}

fn peek_at(parser: Parser, index: Int) -> TokenKind {
  case list.drop(parser.tokens, index) {
    [Token(kind, _), ..] -> kind
    [] -> Eof
  }
}
