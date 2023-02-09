# A DSL Engine

## Introduction

```ruby
require "resyma"
require "date"

#
# Define a new language by creating a subclass of Resyma::Language and
# specifying the syntax in method 'syntax'
#
class LangDate < Resyma::Language
  # syntax of 'syntax': regex >> action
  def syntax
    # e.g. today
    id("today") >> Date.today

    # e.g. 2023/1/1
    (int; id("/"); int; id("/"); int) >> begin
      year = nodes[0].to_ruby
      month = nodes[2].to_ruby
      day = nodes[4].to_ruby
      Date.new(year, month, day)
    end

    # e.g. +1.year
    (numop; numbase; "."; [id("day"), id("month"), id("year")]) >> begin
      op, num, _, unit = nodes
      sig = op.to_literal == "+" ? 1 : -1
      val = num.to_literal.to_i * sig
      case unit.to_literal
      when "day" then Date.today.next_day(val)
      when "month" then Date.today.next_month(val)
      when "year" then Date.today.next_year(val)
      end
    end

    # Recursively interpret
    id("yesterday") >> LangDate.load { -1.day }
    id("tomorrow") >> LangDate.load { +1.day }
  end
end

def date(&block)
  LangDate.load(&block) # Interpret a block as DSL
end

date { today }    #=> #<Date: 2023-02-09 (...)>
date { tomorrow } #=> #<Date: 2023-02-10 (...)>
date { 2024/2/9 } #=> #<Date: 2024-02-09 (...)>
date { +7.day }   #=> #<Date: 2023-02-16 (...)>
date { -3.month } #=> #<Date: 2022-11-09 (...)>
```

`Resyma` is a draft of a DSL engine. We prevent blocks containing DSL from evaluating, apply our matching algorithm to the parse tree, and pass matched nodes to libraries to implement the specific semantics of their DSL. Since semantic restrictions like method definiton are unimportant, the syntax of your DSL can be quite free.

Note that this library is unstable and experimental. Several severe limitations will be described in following sections.

## Define your DSL

Define a new DSL by defining a subclass of `Resyma::Language`.

```ruby
class MyLang << Resyma::Language
  def syntax
    regex >> action
    more...
  end
end
```

`regex` is a DSL defining syntax of your language, and `action` is an arbitrary ruby expression defining semantics of your language. In particular, `regex` is one of following:

- `type`, `type("value")`, `"value"`: match a node by type, value, or both.
- `(a; b; c)`: match a sequence of nodes in order of `a`, `b`, `c`, where every component is a `regex`
- `[a, b, c]`: match one of `a`, `b`, `c`, where every component is a `regex`
- `a..`, `a...`: match `a` zero or more time, or one or more time, where `a` is a `regex`
- `[a]`: optionally match `a`

Comprehensive document is in the plan.

## Limitations

- Parse tree, not AST
  Our algorithm works on parse trees, namely concrete syntax trees, but not AST. However, most of Ruby libraries function only at the AST level. Currently, we derive AST by [parser](https://github.com/whitequark/parser) and convert it to parse tree. It is an unacceptable solution because AST of `parser` describes abstract structures of codes and disregards details like parenthesis or semicolons, which in turn causes malfunction of our algorithm.
- Capturing group
  In regular expression of string, we capture key components by grouping (e.g., `/Hi, (\w+)!/`) for further processing. Without this feature, regular expression is just a boolean function and almost useless. Currently, `Resyma` does not support capturing group, but we can provide users with a complete list of nodes matched with the regular expression. So users can process matched nodes but cannot choose specific nodes.

## More examples

### Nise-TOML

[TOML](https://toml.io/en/) is a configuraton language.

```ruby
require "resyma/nise/toml"

LangTOML.load do

    # This is a nise-TOML document

    title = "TOML Example"

    [owner]
    name = "Tom Preston-Werner"

    [database]
    enabled = true
    ports = [ 8000, 8001, 8002 ]
    data = [ ["delta", "phi"], [3.14] ]
    temp_targets = { cpu: 79.5, case: 72.0 }

    [servers]

    [servers.alpha]
    ip = "10.0.0.1"
    role = "frontend"

    [servers.beta]
    ip = "10.0.0.2"
    role = "backend"
end

#=>   {:title    => "TOML Example",
#      :owner    => {:name => "Tom Preston-Werner"},
#      :database => {:enabled => true,
#                    :ports   => [8000, 8001, 8002],
#                    :data    => [["delta", "phi"], [3.14]],
#                    :temp_targets =>{:cpu => 79.5, :case => 72.0}},
#      :servers  => {:alpha => {:ip => "10.0.0.1", :role => "frontend"},
#                    :beta  => {:ip => "10.0.0.2", :role => "backend"}}}
```

### Timeline

`Timeline` uses DSL defined by the example at the top.

```ruby
require "resyma/nise/date"

LangTimeline.load do
  [2020/8/15] - "First day of class"
  [2020/10/9] - "Test #1"
  [yesterday] - "Research paper due"
  [today]     - "Zzz..."
  [+7.day]    - "Test #2"
  [+2.month]  - "Final project due"
end

#=> [[#<Date: 2020-08-15 (...)>, "First day of class"],
#    [#<Date: 2020-10-09 (...)>, "Test #1"],
#    [#<Date: 2023-02-08 (...)>, "Research paper due"],
#    [#<Date: 2023-02-09 (...)>, "Zzz..."],
#    [#<Date: 2023-02-16 (...)>, "Test #2"],
#    [#<Date: 2023-04-09 (...)>, "Final project due"]]
```

### Rubymoji

```ruby
require "resyma/nise/rubymoji"

rumoji { o^o }         #=> 🙃
rumoji { O.O ?? }      #=> 🤔
rumoji { Zzz.. (x.x) } #=> 😴
```
