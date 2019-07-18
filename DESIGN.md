Several features excite us. Let's talk about implementations.

## HMR (Hot Module Replacement)

A _plugin_ is simply treated as some code to eval. Most of them
modify existing classes (by alias-patching). To guarantee the
compatibility of 'traditional plugins', here is the design of
our HMR system.

1. Use Ripper or other tools to parse the code, pull out
   `def` and `alias` expressions with namespace information.
   ```ruby
   class A
     def a() 42 end
     alias b a
   end
   ```
   What we need is
   ```ruby
   class A
     def a ...
     alias b ...
   ```
2. Before each `def`, add some code to store the original
   method.
   ```ruby
   def save sym
     if method_defined? sym
       alias_method new_name = gen_name(sym), sym
       new_name
     end # nil if not defined
   end
   class A
     save :a; def a ... # don't ruin the line numbers
     save :b; alias b ...
   ```
   The `save`s will construct an array of old methods
   ```ruby
   $old_methods = [[A, nil, :a], # scope, auto saved method name, the method name
                   [A, :_b_add8e6, :b]]
   ```
3. Every time when we do _unload_, reverse-restore the old methods.
   ```ruby
   $old_methods.reverse_each do |klass, old, now|
     if old
       klass.class_eval do
         alias_method now, old
         remove_method old
       end
     else
       klass.class_eval do
         remove_method now
       end
     end
   end.clear
   ```

## Extend Database

There are two types of database: internal and external.
Internal databases can be edited in the editor while external ones
are edited in YAML/JSON/CSV or in any other forms. There should be
a _stashed_ workspace to save the changes we've done while game
running. Think of Git.

```ruby
on_commit do |type, data1, data2|
  case type
  when :insert
    $data_xxx.insert(data1, data2)
    $game_xxx...
  when :remove
    $data_xxx.delete_at(data1)
    $game_xxx...
  when :replace
    $data_xxx[data1] = data2
    $game_xxx...
  end
end
```

The difficulty is `$game_xxx` may need being modified to meet
changes we do at `$data_xxx`. After we _stashed_ all changes,
it means we can do _commit_ to flush them into the game.

YAML/JSON/CSV databases are stored as `.rvdata2` when publishing.
It in the other word forces us to store data as strings, numbers,
arrays and hashes. We can make cli/gui to edit the external
databases.

## Console

REPL is awesome, but RGSS lacks it. To capture the real output
and keep game running, the design comes:

* Make an external program, let's call it _irgss.exe_.
  It starts a named pipe and waits for connection.
  This way, the program can also enable the _console raw mode_
  to capture Ctrl-C, Ctrl-L, Ctrl-D, Ctrl-Z etc.
* In the game itself, looking for this pipe on start.
  Then redirect STDOUT to this pipe.
* _irgss.exe_ `- "spr(...)" ->` _game.exe_,
  _game.exe_ `- "#<Sprite:0x12345678>" ->` _irgss.exe_.
  The _irgss.exe_ does't need to have any ruby runtime.
  Keep it simple.

Later we will want to add features to this console.

* Code highlight? Just send "\e[A\e[33m" and so on.
  https://en.wikipedia.org/wiki/ANSI_escape_code
* Task/thread? Vanilla ruby should be ok.
  ```ruby
  a = task { raise 1 }.start
  a.state/a.stdout/a.stderr...
  ```
* Live expression? (from Chrome DevTools)
