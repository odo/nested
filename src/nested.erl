-module (nested).

-export([
    put/3, putf/1,
    get/2, getf/1,
    get/3, getf/2,
    update/3, updatef/1,
    remove/2, removef/1,
    keys/2, keysf/1
]).

get(Path, Map) ->
    GetFun = getf(Path),
    GetFun(Map).

getf(Path) ->
    fun(Map) -> getf_internal(Path, Map) end.

getf_internal([Key|PathRest], Map) ->
    getf_internal(PathRest, maps:get(Key, Map));
getf_internal([], Value) ->
    Value.

get(Path, Map, Default) ->
    GetFun = getf(Path, Default),
    GetFun(Map).

getf(Path, Default) ->
    fun(Map) -> getf_internal(Path, Map, Default) end.

getf_internal([Key|PathRest], Map, Default) ->
    getf_internal(PathRest, maps:get(Key, Map, Default), Default);
getf_internal([], Value, _) ->
    Value.

update(Path, ValueOrFun, Map) ->
    SetFun = updatef(Path),
    SetFun(ValueOrFun, Map).

updatef(Path) ->
    fun(ValueOrFun, Map) ->
        try updatef_internal(Path, ValueOrFun, Map)
        catch
            error:{error, {no_map, PathRest, Element}} ->
                PathLength  = length(Path) - length(PathRest),
                PathToThrow = lists:sublist(Path, PathLength),
                erlang:error({no_map, PathToThrow, Element})
        end
    end.

updatef_internal([Key|PathRest], ValueOrFun, Map) when is_map(Map) ->
    maps:update(Key, updatef_internal(PathRest, ValueOrFun, maps:get(Key, Map)), Map);
updatef_internal([], Fun, OldValue) when is_function(Fun) ->
    Fun(OldValue);
updatef_internal([], Value, _) ->
    Value;
updatef_internal(Path, _, Element) ->
    erlang:error({error, {no_map, Path, Element}}).


put(Path, Value, Map) ->
    PutFun = putf(Path),
    PutFun(Value, Map).

putf(Path) ->
    fun(Value, Map) -> putf_internal(Path, Value, Map) end.

putf_internal([Key|PathRest], Value, Map) ->
    SubMap =
    case maps:is_key(Key, Map) andalso is_map(maps:get(Key, Map)) of
       true ->  maps:get(Key, Map);
       false -> #{}
    end,
    maps:put(Key, putf_internal(PathRest, Value, SubMap), Map);
putf_internal([], Value, _) ->
    Value.

remove(Path, Map) ->
    RemoveFun = removef(Path),
    RemoveFun(Map).

removef(Path) ->
    fun(Map) -> removef_internal(Path, Map) end.

removef_internal([], _) ->
    throw({bad_path, []});
removef_internal([LastKey], Map) ->
    maps:remove(LastKey, Map);
removef_internal([Key|PathRest], Map) ->
    case maps:is_key(Key, Map) of
        true ->
            maps:put(Key, removef_internal(PathRest, maps:get(Key, Map)), Map);
        false ->
            Map
    end.

keys(Path, Map) ->
    KeysFun = keysf(Path),
    KeysFun(Map).

keysf(Path) ->
    fun(Map) -> keysf_internal(Path, Map) end.

keysf_internal([Key|PathRest], Map) ->
    keysf_internal(PathRest, maps:get(Key, Map));
keysf_internal([], Map) ->
    maps:keys(Map).


-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

get_test() ->
    ?assertEqual(test_map(), get([], test_map())),
    ?assertEqual(3, get([three_side], test_map())),
    ?assertEqual(2, get([three, two_side], test_map())),
    ?assertEqual( #{one => target, one_side => 1}, get([three, two], test_map())),
    ?assertEqual(target, get([three, two, one], test_map())).

get_fails_test() ->
    ?assertException(error, bad_key, get([unknown], test_map())),
    ?assertException(error, bad_key, get([three, unknown], test_map())),
    ?assertException(error, badarg,  get([three, two, one, unknown], test_map())).

get_with_default_test() ->
    ?assertEqual(test_map(), get([], test_map(), default)),
    ?assertEqual(3, get([three_side], test_map(), default)),
    ?assertEqual(2, get([three, two_side], test_map(), default)),
    ?assertEqual( #{one => target, one_side => 1}, get([three, two], test_map(), default)),
    ?assertEqual(target, get([three, two, one], test_map(), default)),
    ?assertEqual(default, get([unknown], test_map(), default)),
    ?assertEqual(default, get([three, unknown], test_map(), default)).

get_with_default_fails_test() ->
    ?assertException(error, badarg,  get([three, two, one, unknown], test_map(), default)).

update_test() ->
    ?assertEqual(3, update([], 3, test_map())),
    ?assertEqual(#{three => 3, three_side => 3}, update([three], 3, test_map())),
    ?assertEqual(
       #{three => #{two => 2, two_side => 2}, three_side => 3},
       update([three, two], 2, test_map())
    ),
    ?assertEqual(
       #{three => #{two => #{one => target, one_side => 11}, two_side => 2}, three_side => 3},
       update([three, two, one_side], fun(E) -> E + 10 end, test_map())
    ).

update_fails_test() ->
    ?assertException(error, bad_key, update([unknown], 1, test_map())),
    ?assertException(error, bad_key, update([three, unknown], 1, test_map())),
    ?assertException(error, {no_map, [foo,bar], []}, update([foo, bar, buz], 1, #{foo => #{bar => []}})).

put_test() ->
    ?assertEqual(3, put([], 3, test_map())),
    ?assertEqual(#{three => 3, three_side => 3}, put([three], 3, test_map())),
    ?assertEqual(#{three => #{two => 2, two_side => 2}, three_side => 3}, put([three, two], 2, test_map())),
    ?assertEqual(
        #{unknown => 1, three => #{two => #{one => target, one_side => 1}, two_side => 2}, three_side => 3},
        put([unknown], 1, test_map())
    ),
    ?assertEqual(
        #{three => #{two => #{one => target, one_side => 1, eleven => #{twelve => 12}}, two_side => 2}, three_side => 3},
        put([three, two, eleven, twelve], 12, test_map())
    ),
    ?assertEqual(
        #{three => #{two => #{one => #{minus_one => -1}, one_side => 1}, two_side => 2}, three_side => 3},
        put([three, two, one, minus_one], -1, test_map())
    ).

remove_test() ->
    ?assertEqual(
        #{three => #{two_side => 2}, three_side => 3},
        remove([three, two], test_map())
    ),
    ?assertEqual(
        #{three => #{two => #{one_side => 1}, two_side => 2}, three_side => 3},
        remove([three, two, one], test_map())
    ),
    ?assertEqual(
       test_map(),
        remove([unknown, path], test_map())
    ),
    ?assertEqual(
       test_map(),
        remove([three, unknown_key], test_map())
    ).

remove_fail_test() ->
    ?assertException(throw, {bad_path, []}, remove([], test_map())).

keys_test() ->
    ?assertEqual(
       [three, three_side],
        keys([], test_map())
    ),
    ?assertEqual(
       [one, one_side],
        keys([three, two], test_map())
    ).


test_map() ->
    L1 = #{one   => target, one_side => 1},
    L2 = #{two   => L1,     two_side => 2},
         #{three => L2,     three_side => 3}.

-endif.

