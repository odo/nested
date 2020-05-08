%%%-------------------------------------------------------------------
%%% @doc
%%% @end
%%%-------------------------------------------------------------------
-module (nested).
-include_lib("eunit/include/eunit.hrl").

-export([is_key/2, get/2, get/3, put/3, update/3, update_with/3,
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

%%--------------------------------------------------------------------
%% @doc Associates key path with value Value and inserts the 
%% association into Map2. If key key path already exists in map Map1, 
%% the old associated value is replaced by value Value. The function 
%% returns a new map containing the new association and the old path
%% associations in Map1.
%% The call fails with a {badmap,Map} exception if Map1 is not a map.
%% @end
%%--------------------------------------------------------------------
-spec put(path(), term(), map()) -> map().
put(   [K], Val, Map) when is_map(Map) -> Map#{K => Val};
put([K|Kx], Val, Map) when is_map(Map) -> 
    case Map of
        #{K := SubMap} -> maps:put(K, put(Kx, Val, SubMap), Map);
        _              -> maps:put(K, put(Kx, Val,    #{}), Map)
    end;
put(    [], Val, Map) when is_map(Map) -> Val;
put(     _, _, NoMap)                  -> error({badmap, NoMap}).

put_test() ->
    % Tests conditions when path matches a value in map
    ?assertEqual(              0 , put(       [], 0,    #{a=>1})),
    ?assertEqual(#{ a=>2        }, put(      [a], 2,    #{a=>1})),
    ?assertMatch(#{m0:=0        }, put(     [m0], 0, test_map())),
    ?assertMatch(#{m0:=#{ m1:=0}}, put([m0,  m1], 0, test_map())),
    ?assertMatch(#{m0:=#{'?':=0}}, put([m0, '?'], 0, test_map())),
    % Tests conditions when path does not match a value in map 
    ?assertMatch(#{ a:=1,  b:=3 }, put(      [b], 3,    #{a=>1})),
    ?assertMatch(#{m0:=#{ m1:=0}}, put([m0,  m1], 0,        #{})),
    % Tests conditions when the map input is not a map
    ?assertException(error, {badmap,x}, put([], 0, x)).

%%--------------------------------------------------------------------
%% @doc If the key path exists in Map1, the old associated value is 
%% replaced by value Value. The function returns a new map Map2 
%% containing the new associated value.
%% The call fails with a {badmap,Map} exception if Map1 is not a map, 
%% or with a {badkey,Key} exception if no value is associated with 
%% Key.
%% @end
%%--------------------------------------------------------------------
-spec update(path(), term(), map()) -> map().
update(   [K], V, M) -> maps:update(K,            V,                  M);
update([K|Kx], V, M) -> maps:update(K, update(Kx, V, maps:get(K, M)), M);
update(    [], V, M) when is_map(M) -> V;
update( _, _, NoMap)                -> error({badmap, NoMap}).

update_test() ->
    % Tests conditions when path matches a value in map
    ?assertEqual(             0 , update(      [], 0,    #{a=>1})),
    ?assertEqual(#{ a=>       2}, update(     [a], 2,    #{a=>1})),
    ?assertMatch(#{m0:=0       }, update(    [m0], 0, test_map())),
    ?assertMatch(#{m0:=#{m1:=0}}, update([m0, m1], 0, test_map())),
    % Tests conditions when path does not match a value in map 
    ?assertException(error, {badkey,'?'}, 
                     update([    '?'], 0, test_map())),
    ?assertException(error, {badkey,'?'}, 
                     update([m0, '?'], 0, test_map())),
    % Tests conditions when the map input is not a map
    ?assertException(error, {badmap,x}, update([], 0, x)).

%%--------------------------------------------------------------------
%% @doc Update a value in a Map1 associated with a key path by calling 
%% Fun on the old value to get a new value. An exception {badkey,Key} 
%% is generated a Key is not present during the path.
%% The function should be of arity 2 where the 1st input is the key 
%% path and the 2nd the actual value.
%% @end
%%--------------------------------------------------------------------
-spec update_with(path(), function(), map()) -> map().
update_with([K|Kx], F, M) when is_map(M) -> 
    update_with([K|Kx], F, M, [K|Kx]);
update_with([], F,     M) when is_map(M) -> F([], M);
update_with( _, _, NoMap)                -> error({badmap, NoMap}).

update_with([K|Kx], F, M, Path) -> 
    maps:update(K, update_with(Kx, F, maps:get(K, M), Path), M);
update_with(    [], F, V, Path) -> 
    F(Path, V).

update_with_test() ->
    % Tests conditions when path matches a value in map
    Fun = fun(_,_) -> 0 end,
    ?assertEqual(      0 , update_with(  [], Fun,    #{a=>1})),
    ?assertEqual(#{ a=>0}, update_with( [a], Fun,    #{a=>1})),
    ?assertMatch(#{m0:=0}, update_with([m0], Fun, test_map())),
    ?assertMatch(#{m0:=#{m1:=0}}, update_with([m0, m1], Fun, test_map())),
    % Tests conditions when path does not match a value in map 
    ?assertException(error, {badkey,'?'}, 
                     update_with([    '?'], Fun, test_map())),
    ?assertException(error, {badkey,'?'}, 
                     update_with([m0, '?'], Fun, test_map())),
    % Tests conditions when the map input is not a map
    ?assertException(error, {badmap,x}, update_with([], Fun, x)).







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

