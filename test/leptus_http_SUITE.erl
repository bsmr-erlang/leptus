-module(leptus_http_SUITE).

-export([init_per_suite/1]).
-export([end_per_suite/1]).
-export([all/0]).

-export([http_get/1]).
-export([http_404/1]).
-export([http_405/1]).
-export([http_post/1]).
-export([http_put/1]).
-export([http_delete/1]).
-export([http_is_authorized/1]).

-import(helpers, [request/2, request/3, request/4, response_body/1]).


init_per_suite(Config) ->
    Handlers = [
                {leptus_http1, []},
                {leptus_http2, []},
                {leptus_http3, []},
                {leptus_http4, []}
               ],
    {ok, _} = leptus:start_http(Handlers),
    Config.

end_per_suite(_Config) ->
    ok = leptus:stop_http().

all() ->
    [
     http_get, http_404, http_405, http_post, http_put, http_delete,
     http_is_authorized
    ].

http_get(_) ->
    M = <<"GET">>,

    {200, _, C1} = request(M, "/"),
    <<"index">>= response_body(C1),

    {200, _, C2} = request(M, "/hello"),
    <<"hello, world!">> = response_body(C2),

    {200, _, C3} = request(M, "/hello/sina"),
    <<"hello, sina">> = response_body(C3),

    {200, _, C4} = request(M, "/users/1234"),
    <<"aha, this is 1234">> = response_body(C4),

    {200, _, C5} = request(M, "/users/456/interests"),
    <<"art, photography...">> = response_body(C5),

    {200, _, C6} = request(M, "/users/s1n4/interests"),
    <<"Erlang and a lotta things else">> = response_body(C6),

    {404, _, C7} = request(M, "/users/123/interests"),
    <<"not found...">> = response_body(C7),

    B1 = <<"{\"id\":\"asdf\",\"bio\":\"Erlanger\",\"github\":\"asdf\"}">>,
    B2 = <<"{\"id\":\"you\",\"bio\":\"Erlanger\",\"github\":\"you\"}">>,

    {200, _, C8} = request(M, "/users/asdf/profile"),
    B1 = response_body(C8),
    {200, _, C9} = request(M, "/users/you/profile"),
    B2 = response_body(C9),

    B3 = <<129,163,109,115,103,168,119,104,97,116,101,118,101,114>>,
    {200, _, C10} = request(M, "/msgpack/whatever"),
    B3 = response_body(C10).

http_404(_) ->
    {404, _, _} = request(<<"GET">>, "/asd"),
    {404, _, _} = request(<<"GET">>, "/asdf"),
    {404, _, _} = request(<<"GET">>, "/asdfg"),
    {404, _, _} = request(<<"POST">>, "/blah/new"),
    {404, _, _} = request(<<"PUT">>, "/blah/186"),
    {404, _, _} = request(<<"DELETE">>, "/blah/186"),
    {404, _, _} = request(<<"HEAD">>, "/blah/186").

http_405(_) ->
    {405, H1, _} = request(<<"DELETE">>, "/users/876"),
    {405, H2, _} = request(<<"DELETE">>, "/users/s1n4/interests"),
    {405, H3, _} = request(<<"PUT">>, "/user/register"),
    {405, H4, _} = request(<<"POST">>, "/settings/change-password"),
    {405, H5, _} = request(<<"GET">>, "/user/register"),
    {405, H6, _} = request(<<"HEAD">>, "/users/876"),
    {405, H7, _} = request(<<"HEAD">>, "/users/blah/posts/876"),

    F = fun(H) -> proplists:get_value(<<"allow">>, H) end,
    <<"GET, PUT, POST">> = F(H1),
    <<"GET">> = F(H2),
    <<"POST">> = F(H3),
    <<"PUT">> = F(H4),
    <<"POST">> = F(H5),
    <<"GET, PUT, POST">> = F(H6),
    <<"DELETE">> = F(H7).

http_post(_) ->
    M = <<"POST">>,
    B1 = <<"username=asdf&email=asdf@a.<...>.com">>,
    {403, _, C1} = request(M, "/user/register", [], B1),
    <<"Username is already taken.">> = response_body(C1),

    B2 = <<"username=asdfg&email=something@a.<...>.com">>,
    {201, _, C2} = request(M, "/user/register", [], B2),
    <<"Thanks for registration.">> = response_body(C2).

http_put(_) ->
    M = <<"PUT">>,
    B1 = <<"password=lkjhgf&password_confirmation=lkjhg">>,
    {403, _, C1} = request(M, "/settings/change-password", [], B1),
    <<"Passwords didn't match.">> = response_body(C1),

    B2 = <<"password=lkjhgf&password_confirmation=lkjhgf">>,
    {200, _, C2} = request(M, "/settings/change-password", [], B2),
    <<"Your password has been changed.">> = response_body(C2).

http_delete(_) ->
    M = <<"DELETE">>,
    {404, _, _} = request(M, "/users/jack/posts/32601"),
    {404, _, _} = request(M, "/users/jack/posts/3268"),
    {204, _, _} = request(M, "/users/jack/posts/219").

http_is_authorized(_) ->
    A1 = base64:encode(<<"123:456">>),
    A2 = base64:encode(<<"123:986">>),
    A3 = base64:encode(<<"sina:wrote_me">>),
    Auth = fun(D) -> [{<<"Authorization">>, <<"Basic ", D/binary>>}] end,

    {401, _, _} = request(<<"PUT">>, "/users/sina"),
    {401, _, _} = request(<<"PUT">>, "/users/sina", Auth(A1)),
    {401, H, C} = request(<<"POST">>, "/users/sina"),
    {401, H1, C1} = request(<<"POST">>, "/users/sina", Auth(A2)),
    {200, _, _} = request(<<"PUT">>, "/users/sina", Auth(A3)),
    {200, _, _} = request(<<"POST">>, "/users/sina", Auth(A3)),

    <<"application/json">> = proplists:get_value(<<"content-type">>, H),
    <<"{\"error\":\"unauthorized\"}">> = response_body(C),
    <<"application/json">> = proplists:get_value(<<"content-type">>, H1),
    <<"{\"error\":\"unauthorized\"}">> = response_body(C1).
