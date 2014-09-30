-module (nested).

-export([
    put/3, putf/1,
    get/2, getf/1,
    update/3, updatef/1
]).

get(Path, Map) ->
    GetFun = getf(Path),
    GetFun(Map).

getf(Path) ->
    fun(Map) -> getf(Path, Map) end.

getf([Key|PathRest], Map) ->
    getf(PathRest, maps:get(Key, Map));
getf([], Value) ->
    Value.


update(Path, ValueOrFun, Map) ->
    SetFun = updatef(Path),
    SetFun(ValueOrFun, Map).

updatef(Path) ->
    fun(ValueOrFun, Map) -> updatef(Path, ValueOrFun, Map) end.

updatef([Key|PathRest], ValueOrFun, Map) ->
    maps:update(Key, updatef(PathRest, ValueOrFun, maps:get(Key, Map)), Map);
updatef([], Fun, OldValue) when is_function(Fun) ->
    Fun(OldValue);
updatef([], Value, _) ->
    Value.


put(Path, Value, Map) ->
    PutFun = putf(Path),
    PutFun(Value, Map).

putf(Path) ->
    fun(Value, Map) -> putf(Path, Value, Map) end.

putf([Key|PathRest], Value, Map) ->
    SubMap =
    case maps:is_key(Key, Map) andalso is_map(maps:get(Key, Map)) of
       true ->  maps:get(Key, Map);
       false -> #{}
    end,
    maps:put(Key, putf(PathRest, Value, SubMap), Map);
putf([], Value, _) ->
    Value.


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
    ?assertException(error, bad_key, update([three, unknown], 1, test_map())).

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

test_map() ->
    L1 = #{one   => target, one_side => 1},
    L2 = #{two   => L1,     two_side => 2},
         #{three => L2,     three_side => 3}.

-endif.

