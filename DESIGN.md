Features details.

## Hot Reload Plugins

First, save all methods (about 7w+ in count) to some place.

```ruby
@old_methods = { klass => { meth_name => [older_meth, old_meth] } }
@singleton_old_methods = ...
```

Hook every objects' `method_added(sym)`, then `push` the new methods
to a stack.

```ruby
@old_methods[klass][meth.name] << meth
```

Everytime when we do uninstall or reload, restore the old methods from
the stack in a reversed order.

```ruby
scripts.reverse_each do |name, side_effects, _|
  side_effects.reverse_each do |t, obj, meth|
    case t
    when :i
      restore_old (klass = obj), meth
    when :s
      singleton_restore_old obj, meth
    end
    puts "  - #{obj}#{{ i: '#', s: '.' }[t]}#{meth}"
  end.clear
end
```

In production mode, store them as internal (Scripts.rvdata2).

## Database Extension

There are two types of databases: internal (rvdata2) and external (may be
stored as YAML/CSV/JSON).

As to the external one, define a method to read them.

```ruby
DB.load(file, ext = File.extname(file))
```

In production mode, store them as internal.

```ruby
save_data obj, "Data/#{klass.name}.rvdata2"
```

Interesting things come: we could do hot-reload on databases. Everytime
the data files change, execute a script to reflect them to runtime.

```ruby
on_array_commit do |type, a, b|
  case type
  when :insert
    $data_xxx.insert a, b
  when :remove
    $data_xxx.delete a
    $game_xxx...
  when :replace
    $data_xxx[a] = b
    $game_xxx...
  end
end
```

It works if the basic form of data is array (like `[RPG::Item]`).
A more generic hot-reload script should be introduced to deal with
singleton data (like `RPG::System`).

```ruby
on_singleton_commit do |new_data|
  $data_xxx = new_data
  $game_xxx...
end
```
