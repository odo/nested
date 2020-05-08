%%%-------------------------------------------------------------------
%%% @doc
%%% @end
%%%-------------------------------------------------------------------
-module (nested).
-include_lib("eunit/include/eunit.hrl").

-export([is_key/2,
    put/3,
    get/2,
    get/3,
    update/3,
    remove/2,
    keys/2,
    append/3
]).


%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc Returns true if the keys path exists, otherwise false.
%% @end
%%--------------------------------------------------------------------
-spec is_key([Keys :: atom()], map()) -> boolean().
is_key([Key], Map) ->
    maps:is_key(Key, Map);

is_key([Key|PathRest], Map) ->
    case Map of
        #{Key := SubMap} -> is_key(PathRest, SubMap);
        _                -> false
    end.

is_key_test() ->
    ?assertEqual(false, is_key([fnord, foo, bar], #{})),
    ?assertEqual(true,  is_key([fnord], #{fnord => 23})),
    ?assertEqual(true,  is_key([three, two, one], test_map())),
    ?assertEqual(false, is_key([three, two, seven], test_map())).



get([Key|PathRest], Map) ->
    get(PathRest, maps:get(Key, Map));

get([], Value) ->
    Value.

get([Key|PathRest], Map, Default) ->
    case maps:get(Key, Map, {?MODULE, Default}) of
        {?MODULE, Default} ->
            Default;
        NestedMap ->
            get(PathRest, NestedMap, Default)
    end;

get([], Value, _) ->
    Value.

update(Path, ValueOrFun, Map) ->
    try updatef_internal(Path, ValueOrFun, Map)
    catch
        error:{error, {no_map, PathRest, Element}} ->
            PathLength  = length(Path) - length(PathRest),
            PathToThrow = lists:sublist(Path, PathLength),
            erlang:error({no_map, PathToThrow, Element})
    end.

updatef_internal([Key|PathRest], ValueOrFun, Map) when is_map(Map) ->
    maps:update(Key, updatef_internal(PathRest, ValueOrFun, maps:get(Key, Map)), Map);
updatef_internal([], Fun, OldValue) when is_function(Fun) ->
    Fun(OldValue);
updatef_internal([], Value, _) ->
    Value;
updatef_internal(Path, _, Element) ->
    erlang:error({error, {no_map, Path, Element}}).


put([Key|PathRest], Value, Map) ->
    SubMap =
    case maps:is_key(Key, Map) andalso is_map(maps:get(Key, Map)) of
       true ->  maps:get(Key, Map);
       false -> #{}
    end,
    maps:put(Key, put(PathRest, Value, SubMap), Map);
put([], Value, _) ->
    Value.

remove([], _) ->
    throw({bad_path, []});
remove([LastKey], Map) ->
    maps:remove(LastKey, Map);
remove([Key|PathRest], Map) ->
    case maps:is_key(Key, Map) of
        true ->
            maps:put(Key, remove(PathRest, maps:get(Key, Map)), Map);
        false ->
            Map
    end.

keys([Key|PathRest], Map) ->
    keys(PathRest, maps:get(Key, Map));
keys([], Map) ->
    maps:keys(Map).

append(Path, Value, Map) ->
    AppendFun =
        fun(List) when is_list(List) ->
                List ++ [Value];
           (_) ->
                error(no_list)
        end,
    update(Path, AppendFun, Map).


%%%===================================================================
%%% Internal functions
%%%===================================================================


%%====================================================================
%% Eunit white box tests
%%====================================================================

% --------------------------------------------------------------------
% TESTS DESCRIPTIONS -------------------------------------------------

% --------------------------------------------------------------------
% SPECIFIC SETUP FUNCTIONS -------------------------------------------

% --------------------------------------------------------------------
% ACTUAL TESTS -------------------------------------------------------

get_test() ->
    ?assertEqual(test_map(), get([], test_map())),
    ?assertEqual(3, get([three_side], test_map())),
    ?assertEqual(2, get([three, two_side], test_map())),
    ?assertEqual( #{one => target, one_side => 1}, get([three, two], test_map())),
    ?assertEqual(target, get([three, two, one], test_map())).

get_fails_test() ->
    ?assertException(error, {badkey,unknown}, get([unknown], test_map())),
    ?assertException(error, {badkey,unknown}, get([three, unknown], test_map())),
    ?assertException(error, {badmap,target},  get([three, two, one, unknown], test_map())).

get_with_default_test() ->
    ?assertEqual(test_map(), get([], test_map(), default)),
    ?assertEqual(3, get([three_side], test_map(), default)),
    ?assertEqual(2, get([three, two_side], test_map(), default)),
    ?assertEqual( #{one => target, one_side => 1}, get([three, two], test_map(), default)),
    ?assertEqual(target, get([three, two, one], test_map(), default)),
    ?assertEqual(default, get([unknown], test_map(), default)),
    ?assertEqual(default, get([three, unknown], test_map(), default)).

get_with_default_fails_test() ->
    ?assertException(error, {badmap,target},  get([three, two, one, unknown], test_map(), default)).

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
    ?assertException(error, {badkey, unknown}, update([unknown], 1, test_map())),
    ?assertException(error, {badkey, unknown}, update([three, unknown], 1, test_map())),
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

append_test() ->
    TestMap = #{outer => #{list => [1], hash => #{}}},
    ?assertEqual(
         #{outer => #{list => [1, 2], hash => #{}}},
        append([outer, list], 2, TestMap)
    ).

append_fail_test() ->
    TestMap = #{outer => #{list => [1], hash => #{}}},
    ?assertException(
        error, no_list,
        append([outer, hash], 2, TestMap)
    ).



% --------------------------------------------------------------------
% SPECIFIC HELPER FUNCTIONS ------------------------------------------

% Creates a simple nested map for testing ---------------------------
test_map() ->
    L1 = #{one   => target, one_side => 1},
    L2 = #{two   => L1,     two_side => 2},
         #{three => L2,     three_side => 3}.

