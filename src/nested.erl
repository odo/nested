%%%-------------------------------------------------------------------
%%% @doc
%%% @end
%%%-------------------------------------------------------------------
-module (nested).
-include_lib("eunit/include/eunit.hrl").

-export([is_key/2, get/2, get/3,
    put/3,
    update/3,
    remove/2,
    keys/2,
    append/3
]).
-export_type([key/0, path/0]).

-type key()  :: term().
-type path() :: [key()].


%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc Returns true if the keys path exists, otherwise false.
%% @end
%%--------------------------------------------------------------------
-spec is_key(path(), map()) -> boolean().
is_key(   [K], Map) when is_map_key(K,Map) -> true;
is_key([K|Kx], Map) when is_map(Map)       -> 
    case Map of
        #{K := SubMap} -> is_key(Kx, SubMap);
        _              -> false
    end;
is_key(    [], Map) when is_map(Map)       -> true;
is_key(   _, NoMap)                        -> error({badmap, NoMap}).

is_key_test() ->
    % Tests conditions when path matches a value in map
    ?assertEqual( true, is_key(           [],            #{})),
    ?assertEqual( true, is_key(      [fnord], #{fnord => 23})),
    ?assertEqual( true, is_key([m0, m1,  m2],     test_map())),
    % Tests conditions when path does not match a value in map
    ?assertEqual(false, is_key(     [m0, v1],            #{})),
    ?assertEqual(false, is_key([m0, m1, '?'],     test_map())),
    % Tests conditions when the map input is not a map
    ?assertException(error, {badmap,x}, get([], x)).

%%--------------------------------------------------------------------
%% @doc Returns the value at the keys path, if path is not found 
%% raises and exception. 
%% @end
%%--------------------------------------------------------------------
-spec get(path(), map()) -> term().
get(   [K], Map) when is_map(Map) ->         maps:get(K, Map) ;
get([K|Kx], Map) when is_map(Map) -> get(Kx, maps:get(K, Map));
get(    [], Map) when is_map(Map) ->                     Map  ;
get(   _, NoMap)                  -> error({badmap, NoMap}).

get_test() ->
    % Tests conditions when path matches a value in map
    ?assertEqual(#{}, get(          [],        #{})),
    ?assertEqual(  1, get(         [a],    #{a=>1})),
    ?assertEqual( v0, get(        [v0], test_map())),
    ?assertEqual( v1, get(    [m0, v1], test_map())),
    ?assertEqual( v2, get([m0, m1, v2], test_map())),
    % Tests conditions when path does not match a value in map 
    ?assertException(error, {badkey,'?'}, get([    '?'], test_map())),
    ?assertException(error, {badkey,'?'}, get([m0, '?'], test_map())),
    % Tests conditions when the map input is not a map
    ?assertException(error, {badmap,x}, get([], x)).

%%--------------------------------------------------------------------
%% @doc Returns the value at the keys path, if path is not found 
%% raises returns the specified default value. 
%% @end
%%--------------------------------------------------------------------
-spec get(path(), map(), Default :: term()) -> term().
get(Path, Map, Default) -> 
    try get(Path, Map) of 
          Result           -> Result
    catch error:{badkey,_} -> Default
    end.

get_with_default_test() ->
    % Tests conditions when path matches a value in map
    ?assertEqual(#{}, get(          [],        #{}, default)),
    ?assertEqual(  1, get(         [a],    #{a=>1}, default)),
    ?assertEqual( v0, get(        [v0], test_map(), default)),
    ?assertEqual( v1, get(    [m0, v1], test_map(), default)),
    ?assertEqual( v2, get([m0, m1, v2], test_map(), default)),
    % Tests conditions when path does not match a value in map 
    ?assertEqual(default, get([    '?'], test_map(), default)),
    ?assertEqual(default, get([m0, '?'], test_map(), default)),
    % Tests conditions when the map input is not a map
    ?assertException(error, {badmap,x}, get([], x)).






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
    M2 = #{m2 => #{}, v2 => v2},
    M1 = #{m1 =>  M2, v1 => v1},
   _M0 = #{m0 =>  M1, v0 => v0}.

