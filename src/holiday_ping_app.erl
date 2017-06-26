-module(holiday_ping_app).

-behaviour(application).

-export([start/2,
         stop/1]).

start(_StartType, _StartArgs) ->
    Dispatch = cowboy_router:compile([
                                      {'_', [{"/", cowboy_static, {priv_file, holiday_ping, "index.html"}},
                                             {"/assets/[...]", cowboy_static, {priv_dir, holiday_ping, ""}},
                                             {"/api/users", hp_user_handler, []},
                                             {"/api/auth/tokens", hp_token_handler, []},
                                             {"/api/channels", hp_channel_list_handler, []},
                                             {"/api/channels/:id", [{id, int}], hp_channel_detail_handler, []}]}
                                     ]),
    cowboy:start_http(my_http_listener, 100, [{port, 8001}],
                      [{env, [{dispatch, Dispatch}]}]
                     ),
    hp_sup:start_link().

stop(_State) ->
    ok.