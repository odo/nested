
![Code Climate](http://img.shields.io/badge/code_climate-17.3-brightgreen.svg?style=flat-square)
# nested

{<sub>{<sub>{<sub>{<sub>{}</sub>}</sub>}{<sub>{<sub>{}</sub>}</sub>}</sub>}</sub>}

a library to handle nested Erlang maps

## requirements
Erlang/OTP 17.3 or newer

## building

```
git clone git@github.com:odo/nested.git
cd nested
./rebar compile
erl -pz ebin
```

## usage

### get

get the value of an existing key:

```erlang
1> Map = #{two => #{one => target, one_side => 1}, two_side => 2}.
#{two => #{one => target,one_side => 1},two_side => 2}
2> nested:get([two, one], Map).
target
```
or use a default in case the key does not exist:


```erlang
1> Map = #{two => #{one => target, one_side => 1}, two_side => 2}.
#{two => #{one => target,one_side => 1},two_side => 2}
2> nested:get([two, some_unknown_key], Map, default).
default
```

### put
put some value under a key that might or might not exist:

```erlang
1> Map = #{two => #{one => target, one_side => 1}, two_side => 2}.
#{two => #{one => target,one_side => 1},two_side => 2}
2> nested:put([two, one], i_got_you, Map).
#{two => #{one => i_got_you,one_side => 1},two_side => 2}
```

If there are more keys than in the original map, nested maps are created:

```erlang
3> nested:put([two, down, the, rabbit, hole], 42, Map).
#{two => #{down => #{the => #{rabbit => #{hole => 42}}},one => target,one_side => 1},
  two_side => 2}
```

### update

replace an exiting value:

```erlang
1> Map = #{two => #{one => target, one_side => 1}, two_side => 2}.
#{two => #{one => target,one_side => 1},two_side => 2}
2> nested:update([two, one_side], 7, Map).
#{two => #{one => target,one_side => 7},two_side => 2}
```

instead of a value, you can pass a function with arity 1 which is passed the old value:

```erlang
3> nested:update([two_side], fun(E) -> E*2 end, Map).
#{two => #{one => target,one_side => 1},two_side => 4}
```

If you really mean to set the value to a fun you have to wrap it in an update fun:

```erlang
4> nested:update([two_side], fun(_) -> fun(A, B) -> {A, B} end end, Map).
#{two => #{one => target,one_side => 1},
  two_side => #Fun<erl_eval.12.106461118>}
```
### remove

delete a key:

```erlang
1> Map = #{two => #{one => target, one_side => 1}, two_side => 2}.
#{two => #{one => target,one_side => 1},two_side => 2}
2>  nested:remove([two, one_side], Map).
#{two => #{one => target},two_side => 2}
```

if the path does not exist, nothing changes:

```erlang
1> Map = #{two => #{one => target, one_side => 1}, two_side => 2}.
#{two => #{one => target,one_side => 1},two_side => 2}
2> nested:remove([two, unknow, path], Map).
#{two => #{one => target,one_side => 1},two_side => 2}
```

### keys
list the keys in a sup map:

```erlang
1> Map = #{two => #{one => target, one_side => 1}, two_side => 2}.
#{two => #{one => target,one_side => 1},two_side => 2}
2>  nested:keys([two], Map).
[one,one_side]
```

### getf/1, getf/2, updatef/1, putf/1, removef/1, keysf/1

you can use this variants to get a function with the path in the context:

```erlang
1> Map = #{two => #{one => target, one_side => 1}, two_side => 2}.
#{two => #{one => target,one_side => 1},two_side => 2}
2> TwoOneSelector = nested:getf([two, one]).
#Fun<nested.0.8958893>
3> TwoOneSelector(Map).
target
4> TwoOneUpdater = nested:updatef([two, one]).
#Fun<nested.1.8958893>
5> TwoOneUpdater(new_value, Map).
#{two => #{one => new_value,one_side => 1},two_side => 2}
```

## tests

`./rebar eunit`
