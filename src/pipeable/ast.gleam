// AST node types for the Pipeable language

pub type File {
  File(statements: List(Statement))
}

pub type Statement {
  UseStatement(label: String, path: Path)
  TypeStatement(label: String, type_expr: TypeExpr)
  ArtifactStatement(
    label: String,
    type_label: String,
    fields: List(ArtifactField),
  )
  JobStatement(
    label: String,
    params: List(ParamField),
    body: List(PipeStep),
  )
  LetStatement(label: String, value: Literal)
}

pub type Path {
  UrlPath(value: String)
  FilePath(value: String)
}

pub type TypeExpr {
  PrimType(kind: PrimTypeKind)
  ArrayType(inner: TypeExpr)
  TupleType(elements: List(TypeExpr))
  ObjectType(fields: List(ObjectField))
  TypeRef(label: String)
}

pub type PrimTypeKind {
  UrlPrim
  FilepathPrim
  DurationPrim
  IntPrim
  NumPrim
  StringPrim
}

pub type ObjectField {
  ObjectField(label: String, type_expr: TypeExpr)
}

pub type ArtifactField {
  MaxVersionsField(value: Int)
  CacheForField(value: String, unit: String)
}

pub type ParamField {
  ParamField(label: String, type_expr: TypeExpr)
}

pub type PipeStep {
  PipeStep(invocations: List(Invocation))
}

pub type Invocation {
  Invocation(label: String, arg: Arg)
}

pub type Arg {
  NoArg
  TupleLitArg(fields: List(LitField))
  AccessorArg(accessor: Accessor)
  LiteralArg(literal: Literal)
  // Note: bare Label args are not supported — see grammar note in parser.gleam.
  // A Label in arg position is always treated as the start of a new Invocation
  // to resolve the PipeStep <- Invocation+ ambiguity unambiguously.
}

pub type Accessor {
  DollarAccess
  DotAccess(path: List(AccessSegment))
}

pub type AccessSegment {
  FieldSegment(name: String)
  IndexSegment(index: Int)
}

pub type Literal {
  IntLiteral(value: Int)
  NumLiteral(value: String)
  StringLiteral(value: String)
  DurationLiteral(value: String, unit: String)
  UrlLiteral(value: String)
  FilePathLiteral(value: String)
  TupleLiteral(fields: List(LitField))
  ArrayLiteral(fields: List(LitField))
  ObjectLiteral(fields: List(ObjLitField))
}

pub type LitField {
  LitLiteral(literal: Literal)
  LitAccessor(accessor: Accessor)
}

pub type ObjLitField {
  ObjLitField(label: String, value: LitField)
}
