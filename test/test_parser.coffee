should = require 'should'
parser = require '../src/packrattle/parser'
inspect = require("util").inspect

describe "Parser", ->
  it "intentionally fails", ->
    p = parser.reject
    rv = p.parse("")
    rv.state.pos.should.equal(0)
    rv.message.should.match(/failure/)

  it "matches a literal", ->
    p = parser.string("hello")
    rv = p.parse("cat")
    rv.state.pos.should.equal(0)
    rv.message.should.match(/hello/)
    rv = p.parse("hellon")
    rv.state.pos.should.equal(5)
    rv.match.should.equal("hello")

  it "skips whitespace", ->
    p = parser.string("hello").skip(/\s+/)
    rv = p.parse("    hello")
    rv.state.pos.should.equal(9)
    rv.match.should.eql("hello")

  describe "onMatch", ->
    it "transforms a match", ->
      p = parser.string("hello").onMatch((s) -> s.toUpperCase())
      rv = p.parse("cat")
      rv.state.pos.should.equal(0)
      rv.message.should.match(/hello/)
      rv = p.parse("hellon")
      rv.state.pos.should.equal(5)
      rv.match.should.equal("HELLO")

    it "transforms a match into a constant", ->
      p = parser.string("hello").onMatch("yes")
      rv = p.parse("hello")
      rv.state.pos.should.equal(5)
      rv.match.should.eql("yes")

    it "transforms a match into a failure on exception", ->
      p = parser.string("hello").onMatch((s) -> throw "utter failure")
      rv = p.parse("hello")
      rv.ok.should.equal(false)
      rv.message.should.match(/utter failure/)

  it "transforms the error message", ->
    p = parser.string("hello").onFail("Try a greeting.")
    rv = p.parse("cat")
    rv.state.pos.should.equal(0)
    rv.message.should.eql("Try a greeting.")
    rv = p.parse("hellon")
    rv.state.pos.should.equal(5)
    rv.match.should.equal("hello")

  it "matches with a condition", ->
    p = parser.regex(/\d+/).matchIf((s) -> parseInt(s[0]) % 2 == 0).onFail("Expected an even number")
    rv = p.parse("103")
    rv.state.pos.should.equal(0)
    rv.message.should.match(/even number/)
    rv = p.parse("104")
    rv.state.pos.should.equal(3)
    rv.match[0].should.eql("104")

  it "can negate", ->
    p = parser.string("hello").not()
    rv = p.parse("cat")
    rv.state.pos.should.equal(0)
    rv.match.should.eql("")
    rv = p.parse("hello")
    rv.state.pos.should.equal(0)
    rv.message.should.match(/hello/)

  it "can perform an 'or'", ->
    p = parser.string("hello").or(parser.string("goodbye"))
    rv = p.parse("cat")
    rv.state.pos.should.equal(0)
    rv.message.should.match(/'hello' or 'goodbye'/)
    rv = p.parse("hello")
    rv.state.pos.should.equal(5)
    rv.match.should.equal("hello")
    rv = p.parse("goodbye")
    rv.state.pos.should.equal(7)
    rv.match.should.equal("goodbye")

  describe "then/seq", ->
    it "can do a sequence", ->
      p = parser.string("abc").then(parser.string("123"))
      rv = p.parse("abc123")
      rv.state.pos.should.equal(6)
      rv.match.should.eql([ "abc", "123" ])
      rv = p.parse("abcd")
      rv.state.pos.should.equal(3)
      rv.message.should.match(/123/)
      rv = p.parse("123")
      rv.state.pos.should.equal(0)
      rv.message.should.match(/abc/)

    it "strings together a chained sequence", ->
      p = parser.seq(
        parser.string("abc"),
        parser.string("123").drop(),
        parser.string("xyz")
      )
      rv = p.parse("abc123xyz")
      rv.state.pos.should.equal(9)
      rv.match.should.eql([ "abc", "xyz" ])

    it "skips whitespace inside seq()", ->
      parser.setWhitespace /\s*/
      p = parser.seq("abc", "xyz", "ghk")
      parser.setWhitespace null
      rv = p.parse("abcxyzghk")
      rv.ok.should.equal(true)
      rv.match.should.eql([ "abc", "xyz", "ghk" ])
      rv = p.parse("   abc xyz\tghk")
      rv.ok.should.equal(true)
      rv.match.should.eql([ "abc", "xyz", "ghk" ])

  it "implicitly turns strings into parsers", ->
    p = parser.seq("abc", "123").or("xyz")
    rv = p.parse("abc123")
    rv.state.pos.should.equal(6)
    rv.match.should.eql([ "abc", "123" ])
    rv = p.parse("xyz")
    rv.state.pos.should.equal(3)
    rv.match.should.eql("xyz")

  it "strings together a chained sequence implicitly", ->
    p = [ "abc", parser.drop(/\d+/), "xyz" ]
    rv = parser.parse(p, "abc11xyz")
    rv.state.pos.should.equal(8)
    rv.match.should.eql([ "abc", "xyz" ])

  it "handles regexen", ->
    p = parser.seq(/\s*/, "if")
    rv = p.parse("   if")
    rv.state.pos.should.equal(5)
    rv.match[0][0].should.eql("   ")
    rv.match[1].should.eql("if")
    rv = p.parse("if")
    rv.state.pos.should.equal(2)
    rv.match[0][0].should.eql("")
    rv.match[1].should.eql("if")
    rv = p.parse(";  if")
    rv.state.pos.should.equal(0)
    rv.message.should.match(/if/)
    # try some basic cases too.
    p = parser.regex(/h(i)?/)
    rv = p.parse("no")
    rv.state.pos.should.equal(0)
    rv.message.should.match(/h\(i\)\?/)
    rv = p.parse("hit")
    rv.state.pos.should.equal(2)
    rv.match[0].should.eql("hi")
    rv.match[1].should.eql("i")

  it "parses optionals", ->
    p = [ "abc", parser.optional(/\d+/), "xyz" ]
    rv = parser.parse(p, "abcxyz")
    rv.state.pos.should.equal(6)
    rv.match.should.eql([ "abc", "", "xyz" ])
    rv = parser.parse(p, "abc99xyz")
    rv.state.pos.should.equal(8)
    rv.match[0].should.eql("abc")
    rv.match[1][0].should.eql("99")
    rv.match[2].should.eql("xyz")

  describe "repeat/times", ->
    it "repeats", ->
      p = parser.repeat("hi")
      rv = p.parse("h")
      rv.state.pos.should.equal(0)
      rv.message.should.match(/'hi'/)
      rv = p.parse("hi")
      rv.state.pos.should.equal(2)
      rv.match.should.eql([ "hi" ])
      rv = p.parse("hiho")
      rv.state.pos.should.equal(2)
      rv.match.should.eql([ "hi" ])
      rv = p.parse("hihihi!")
      rv.state.pos.should.equal(6)
      rv.match.should.eql([ "hi", "hi", "hi" ])

    it "repeats with separators", ->
      p = parser.repeat("hi", ",")
      rv = p.parse("hi,hi,hi")
      rv.state.pos.should.equal(8)
      rv.match.should.eql([ "hi", "hi", "hi" ])

    it "skips whitespace in repeat", ->
      parser.setWhitespace /\s*/
      p = parser.repeat("hi", ",")
      rv = p.parse("hi, hi , hi")
      rv.ok.should.equal(true)
      rv.match.should.eql([ "hi", "hi", "hi" ])

    it "skips whitespace in times", ->
      parser.setWhitespace /\s*/
      p = parser.times(3, "hi")
      rv = p.parse("hi hi  hi")
      rv.ok.should.equal(true)
      rv.match.should.eql([ "hi", "hi", "hi" ])

    it "can match exactly N times", ->
      p = parser.string("hi").times(4)
      rv = p.parse("hihihihihi")
      rv.ok.should.equal(true)
      rv.match.should.eql([ "hi", "hi", "hi", "hi" ])
      rv.state.pos.should.equal(8)
      rv = p.parse("hihihi")
      rv.ok.should.equal(false)
      rv.message.should.match(/4 of \('hi'\)/)

    it "drops inside repeat/times", ->
      p = parser.string("123").drop().repeat()
      rv = p.parse("123123")
      rv.ok.should.equal(true)
      rv.match.should.eql([])
      p = parser.string("123").drop().times(2)
      rv = p.parse("123123")
      rv.ok.should.equal(true)
      rv.match.should.eql([])

  it "resolves a lazy parser", ->
    p = parser.seq ":", -> /\w+/
    rv = p.parse(":hello")
    rv.state.pos.should.equal(6)
    rv.match[0].should.eql(":")
    rv.match[1][0].should.eql("hello")

  it "resolves a lazy parser only once", ->
    count = 0
    p = parser.seq ":", ->
      count++
      parser.regex(/\w+/).onMatch (m) -> m[0].toUpperCase()
    rv = p.parse(":hello")
    rv.state.pos.should.equal(6)
    rv.match.should.eql([ ":", "HELLO" ])
    count.should.equal(1)
    rv = p.parse(":goodbye")
    rv.state.pos.should.equal(8)
    rv.match.should.eql([ ":", "GOODBYE" ])
    count.should.equal(1)

  it "only executes a parser once per string/position", ->
    count = 0
    p = parser.seq "hello", /\s*/, parser.string("there").onMatch (x) ->
      count++
      x
    s = parser.newState("hello  there!")
    count.should.equal(0)
    rv = p.parse(s)
    rv.ok.should.equal(true)
    rv.match[2].should.eql("there")
    count.should.equal(1)
    rv = p.parse(s)
    rv.ok.should.equal(true)
    rv.match[2].should.eql("there")
    count.should.equal(1)

  it "consumes the whole string", ->
    p = parser.string("hello")
    rv = p.consume("hello")
    rv.ok.should.equal(true)
    rv.match.should.eql("hello")
    rv = p.consume("hello!")
    rv.ok.should.equal(false)
    rv.state.pos.should.equal(5)
    rv.message.should.match(/end/)

  it "can perform a non-advancing check", ->
    p = parser.seq("hello", parser.check("there"), "th")
    rv = p.parse("hellothere")
    rv.ok.should.equal(true)
    rv.match.should.eql([ "hello", "there", "th" ])
    rv = p.parse("helloth")
    rv.ok.should.equal(false)
    rv.message.should.match(/there/)

  it "can commit to an alternative", ->
    p = parser.seq(parser.string("!").commit(), /\d+/).onFail("! must be a number").or([ "@", /\d+/ ]).onMatch (a) ->
      [ a[0], a[1][0] ]
    rv = p.parse("!3")
    rv.ok.should.equal(true)
    rv.match.should.eql([ "!", "3" ])
    rv = p.parse("@55")
    rv.ok.should.equal(true)
    rv.match.should.eql([ "@", "55" ])
    rv = p.parse("!ok")
    rv.ok.should.equal(false)
    rv.message.should.eql("! must be a number")
