// Token types for the Pipeable language lexer

pub type TokenKind {
  // Keywords
  Use
  TypeKw
  Artifact
  Job
  Let

  // Artifact field keywords
  MaxVersions
  CacheFor

  // Primitive type keywords
  UrlType
  FilepathType
  DurationType
  IntType
  NumType
  StringType

  // Symbols
  Colon
  Comma
  Semicolon
  LParen
  RParen
  LBracket
  RBracket
  LBrace
  RBrace
  Dollar
  DollarDot
  Dot

  // Literals
  IntLit(String)
  NumLit(String)
  StringLit(String)
  DurationLit(String, String)
  UrlLit(String)
  FilePathLit(String)

  // Identifiers
  Label(String)

  // Special
  Eof
}

pub type Position {
  Position(line: Int, col: Int)
}

pub type Token {
  Token(kind: TokenKind, pos: Position)
}
