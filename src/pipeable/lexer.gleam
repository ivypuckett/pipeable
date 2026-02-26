import gleam/list
import gleam/string
import pipeable/token.{
  type Position, type Token, Colon, Comma, Dollar, DollarDot, Dot, DurationLit,
  Eof, FilePathLit, IntLit, LBrace, LBracket, LParen, Label, NumLit, Position,
  RBrace, RBracket, RParen, Semicolon, StringLit, Token, UrlLit,
}

pub type LexError {
  LexError(message: String, pos: Position)
}

pub type Lexer {
  Lexer(input: String, chars: List(String), pos: Position)
}

pub fn new(input: String) -> Lexer {
  Lexer(input: input, chars: string.to_graphemes(input), pos: Position(1, 1))
}

pub fn tokenize(lexer: Lexer) -> Result(List(Token), LexError) {
  do_tokenize(lexer, [])
}

fn do_tokenize(
  lexer: Lexer,
  acc: List(Token),
) -> Result(List(Token), LexError) {
  let lexer = skip_whitespace_and_comments(lexer)
  case lexer.chars {
    [] -> Ok(list.reverse([Token(Eof, lexer.pos), ..acc]))
    _ ->
      case next_token(lexer) {
        Ok(#(tok, rest)) -> do_tokenize(rest, [tok, ..acc])
        Error(e) -> Error(e)
      }
  }
}

fn skip_whitespace_and_comments(lexer: Lexer) -> Lexer {
  case lexer.chars {
    [" ", ..rest] ->
      skip_whitespace_and_comments(adv(lexer, rest))
    ["\t", ..rest] ->
      skip_whitespace_and_comments(adv(lexer, rest))
    ["\r", ..rest] ->
      skip_whitespace_and_comments(adv(lexer, rest))
    ["\n", ..rest] ->
      skip_whitespace_and_comments(newline(lexer, rest))
    ["#", ..rest] ->
      skip_whitespace_and_comments(skip_comment(Lexer(..lexer, chars: rest)))
    _ -> lexer
  }
}

fn skip_comment(lexer: Lexer) -> Lexer {
  case lexer.chars {
    [] -> lexer
    ["\n", ..rest] -> newline(lexer, rest)
    [_, ..rest] ->
      skip_comment(Lexer(
        ..lexer,
        chars: rest,
        pos: Position(lexer.pos.line, lexer.pos.col + 1),
      ))
  }
}

fn adv(lexer: Lexer, rest: List(String)) -> Lexer {
  Lexer(..lexer, chars: rest, pos: Position(lexer.pos.line, lexer.pos.col + 1))
}

fn adv_n(lexer: Lexer, rest: List(String), n: Int) -> Lexer {
  Lexer(..lexer, chars: rest, pos: Position(lexer.pos.line, lexer.pos.col + n))
}

fn newline(lexer: Lexer, rest: List(String)) -> Lexer {
  Lexer(..lexer, chars: rest, pos: Position(lexer.pos.line + 1, 1))
}

fn next_token(lexer: Lexer) -> Result(#(Token, Lexer), LexError) {
  let pos = lexer.pos
  case lexer.chars {
    [":", ..rest] -> Ok(#(Token(Colon, pos), adv(lexer, rest)))
    [",", ..rest] -> Ok(#(Token(Comma, pos), adv(lexer, rest)))
    [";", ..rest] -> Ok(#(Token(Semicolon, pos), adv(lexer, rest)))
    ["(", ..rest] -> Ok(#(Token(LParen, pos), adv(lexer, rest)))
    [")", ..rest] -> Ok(#(Token(RParen, pos), adv(lexer, rest)))
    ["[", ..rest] -> Ok(#(Token(LBracket, pos), adv(lexer, rest)))
    ["]", ..rest] -> Ok(#(Token(RBracket, pos), adv(lexer, rest)))
    ["{", ..rest] -> Ok(#(Token(LBrace, pos), adv(lexer, rest)))
    ["}", ..rest] -> Ok(#(Token(RBrace, pos), adv(lexer, rest)))
    ["$", ".", ..rest] -> Ok(#(Token(DollarDot, pos), adv_n(lexer, rest, 2)))
    ["$", ..rest] -> Ok(#(Token(Dollar, pos), adv(lexer, rest)))
    ["\"", ..] -> lex_string(lexer)
    ["~", "/", ..rest] -> {
      let lexer1 = adv_n(lexer, rest, 2)
      let #(path_rest, lexer2) = take_path_chars(lexer1, [])
      Ok(#(Token(FilePathLit("~/" <> path_rest), pos), lexer2))
    }
    [".", "/", ..rest] -> {
      let lexer1 = adv_n(lexer, rest, 2)
      let #(path_rest, lexer2) = take_path_chars(lexer1, [])
      Ok(#(Token(FilePathLit("./" <> path_rest), pos), lexer2))
    }
    ["/", ..rest] -> {
      let lexer1 = adv(lexer, rest)
      let #(path_rest, lexer2) = take_path_chars(lexer1, [])
      Ok(#(Token(FilePathLit("/" <> path_rest), pos), lexer2))
    }
    [".", ..rest] -> Ok(#(Token(Dot, pos), adv(lexer, rest)))
    // Digits
    ["0", ..] | ["1", ..] | ["2", ..] | ["3", ..] | ["4", ..]
    | ["5", ..] | ["6", ..] | ["7", ..] | ["8", ..] | ["9", ..] ->
      lex_number(lexer)
    // Alpha
    ["a", ..] | ["b", ..] | ["c", ..] | ["d", ..] | ["e", ..] | ["f", ..]
    | ["g", ..] | ["h", ..] | ["i", ..] | ["j", ..] | ["k", ..] | ["l", ..]
    | ["m", ..] | ["n", ..] | ["o", ..] | ["p", ..] | ["q", ..] | ["r", ..]
    | ["s", ..] | ["t", ..] | ["u", ..] | ["v", ..] | ["w", ..] | ["x", ..]
    | ["y", ..] | ["z", ..] | ["A", ..] | ["B", ..] | ["C", ..] | ["D", ..]
    | ["E", ..] | ["F", ..] | ["G", ..] | ["H", ..] | ["I", ..] | ["J", ..]
    | ["K", ..] | ["L", ..] | ["M", ..] | ["N", ..] | ["O", ..] | ["P", ..]
    | ["Q", ..] | ["R", ..] | ["S", ..] | ["T", ..] | ["U", ..] | ["V", ..]
    | ["W", ..] | ["X", ..] | ["Y", ..] | ["Z", ..] ->
      lex_word(lexer)
    [ch, ..] ->
      Error(LexError("Unexpected character: " <> ch, pos))
    [] -> Error(LexError("Unexpected end of input", pos))
  }
}

fn lex_string(lexer: Lexer) -> Result(#(Token, Lexer), LexError) {
  let pos = lexer.pos
  case lexer.chars {
    ["\"", ..rest] -> {
      let lexer1 = adv(lexer, rest)
      case lex_string_body(lexer1, []) {
        Ok(#(content, lexer2)) ->
          Ok(#(Token(StringLit(content), pos), lexer2))
        Error(e) -> Error(e)
      }
    }
    _ -> Error(LexError("Expected opening quote", pos))
  }
}

fn lex_string_body(
  lexer: Lexer,
  acc: List(String),
) -> Result(#(String, Lexer), LexError) {
  case lexer.chars {
    [] -> Error(LexError("Unterminated string", lexer.pos))
    ["\\", ch, ..rest] ->
      lex_string_body(adv_n(lexer, rest, 2), [ch, "\\", ..acc])
    ["\"", ..rest] ->
      Ok(#(acc |> list.reverse |> string.concat, adv(lexer, rest)))
    ["\n", ..rest] ->
      lex_string_body(newline(lexer, rest), ["\n", ..acc])
    [ch, ..rest] ->
      lex_string_body(adv(lexer, rest), [ch, ..acc])
  }
}

fn lex_number(lexer: Lexer) -> Result(#(Token, Lexer), LexError) {
  let pos = lexer.pos
  let #(digits, lexer1) = take_digits(lexer, [])
  case lexer1.chars {
    // num followed by dot and digit: 123.45
    [".", "0", ..] | [".", "1", ..] | [".", "2", ..] | [".", "3", ..]
    | [".", "4", ..] | [".", "5", ..] | [".", "6", ..] | [".", "7", ..]
    | [".", "8", ..] | [".", "9", ..] -> {
      let lexer2 = adv(lexer1, list.drop(lexer1.chars, 1))
      let #(frac, lexer3) = take_digits(lexer2, [])
      Ok(#(Token(NumLit(digits <> "." <> frac), pos), lexer3))
    }
    // num followed by dot only: 123.
    [".", ..rest_after_dot] ->
      Ok(#(Token(NumLit(digits <> "."), pos), adv(lexer1, rest_after_dot)))
    // Duration units
    ["m", "s", ..rest] ->
      Ok(#(Token(DurationLit(digits, "ms"), pos), adv_n(lexer1, rest, 2)))
    ["s", ..rest] ->
      Ok(#(Token(DurationLit(digits, "s"), pos), adv(lexer1, rest)))
    // "m" but NOT followed by alpha (to avoid matching "m" in e.g. "myLabel")
    ["m", next, ..] if next != "a" && next != "b" && next != "c"
      && next != "d" && next != "e" && next != "f" && next != "g"
      && next != "h" && next != "i" && next != "j" && next != "k"
      && next != "l" && next != "m" && next != "n" && next != "o"
      && next != "p" && next != "q" && next != "r" && next != "s"
      && next != "t" && next != "u" && next != "v" && next != "w"
      && next != "x" && next != "y" && next != "z"
      && next != "A" && next != "B" && next != "C" && next != "D"
      && next != "E" && next != "F" && next != "G" && next != "H"
      && next != "I" && next != "J" && next != "K" && next != "L"
      && next != "M" && next != "N" && next != "O" && next != "P"
      && next != "Q" && next != "R" && next != "S" && next != "T"
      && next != "U" && next != "V" && next != "W" && next != "X"
      && next != "Y" && next != "Z"
      && next != "0" && next != "1" && next != "2" && next != "3"
      && next != "4" && next != "5" && next != "6" && next != "7"
      && next != "8" && next != "9"
    ->
      Ok(#(
        Token(DurationLit(digits, "m"), pos),
        adv(lexer1, list.drop(lexer1.chars, 1)),
      ))
    ["m"] ->
      Ok(#(
        Token(DurationLit(digits, "m"), pos),
        Lexer(..lexer1, chars: [], pos: Position(lexer1.pos.line, lexer1.pos.col + 1)),
      ))
    ["h", ..rest] ->
      Ok(#(Token(DurationLit(digits, "h"), pos), adv(lexer1, rest)))
    ["d", ..rest] ->
      Ok(#(Token(DurationLit(digits, "d"), pos), adv(lexer1, rest)))
    _ -> Ok(#(Token(IntLit(digits), pos), lexer1))
  }
}

fn lex_word(lexer: Lexer) -> Result(#(Token, Lexer), LexError) {
  let pos = lexer.pos
  let #(word, lexer1) = take_alnum(lexer, [])
  case word {
    "https" | "http" | "ssh" ->
      case lexer1.chars {
        [":", "/", "/", ..rest] -> {
          let lexer2 = adv_n(lexer1, rest, 3)
          let #(path, lexer3) = take_path_chars(lexer2, [])
          Ok(#(Token(UrlLit(word <> "://" <> path), pos), lexer3))
        }
        _ -> Ok(#(keyword_or_label(word, pos), lexer1))
      }
    _ -> Ok(#(keyword_or_label(word, pos), lexer1))
  }
}

fn keyword_or_label(word: String, pos: Position) -> Token {
  case word {
    "use" -> Token(token.Use, pos)
    "type" -> Token(token.TypeKw, pos)
    "artifact" -> Token(token.Artifact, pos)
    "job" -> Token(token.Job, pos)
    "let" -> Token(token.Let, pos)
    "maxVersions" -> Token(token.MaxVersions, pos)
    "cacheFor" -> Token(token.CacheFor, pos)
    "url" -> Token(token.UrlType, pos)
    "filepath" -> Token(token.FilepathType, pos)
    "duration" -> Token(token.DurationType, pos)
    "int" -> Token(token.IntType, pos)
    "num" -> Token(token.NumType, pos)
    "string" -> Token(token.StringType, pos)
    _ -> Token(Label(word), pos)
  }
}

fn take_digits(lexer: Lexer, acc: List(String)) -> #(String, Lexer) {
  case lexer.chars {
    ["0" as ch, ..rest] | ["1" as ch, ..rest] | ["2" as ch, ..rest]
    | ["3" as ch, ..rest] | ["4" as ch, ..rest] | ["5" as ch, ..rest]
    | ["6" as ch, ..rest] | ["7" as ch, ..rest] | ["8" as ch, ..rest]
    | ["9" as ch, ..rest] ->
      take_digits(adv(lexer, rest), [ch, ..acc])
    _ -> #(acc |> list.reverse |> string.concat, lexer)
  }
}

fn take_alnum(lexer: Lexer, acc: List(String)) -> #(String, Lexer) {
  case lexer.chars {
    [ch, ..rest] -> {
      case is_alnum(ch) {
        True -> take_alnum(adv(lexer, rest), [ch, ..acc])
        False -> #(acc |> list.reverse |> string.concat, lexer)
      }
    }
    _ -> #(acc |> list.reverse |> string.concat, lexer)
  }
}

fn take_path_chars(lexer: Lexer, acc: List(String)) -> #(String, Lexer) {
  case lexer.chars {
    [ch, ..rest] -> {
      case is_path_char(ch) {
        True -> take_path_chars(adv(lexer, rest), [ch, ..acc])
        False -> #(acc |> list.reverse |> string.concat, lexer)
      }
    }
    _ -> #(acc |> list.reverse |> string.concat, lexer)
  }
}

fn is_alnum(ch: String) -> Bool {
  case ch {
    "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j" | "k" | "l"
    | "m" | "n" | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v" | "w" | "x"
    | "y" | "z" | "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" | "J"
    | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" | "S" | "T" | "U" | "V"
    | "W" | "X" | "Y" | "Z" | "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7"
    | "8" | "9" -> True
    _ -> False
  }
}

fn is_path_char(ch: String) -> Bool {
  case ch {
    "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j" | "k" | "l"
    | "m" | "n" | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v" | "w" | "x"
    | "y" | "z" | "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" | "J"
    | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" | "S" | "T" | "U" | "V"
    | "W" | "X" | "Y" | "Z" | "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7"
    | "8" | "9" | "." | "_" | "~" | ":" | "@" | "!" | "$" | "&" | "'" | "("
    | ")" | "*" | "+" | ";" | "=" | "%" | "-" | "/" -> True
    _ -> False
  }
}
