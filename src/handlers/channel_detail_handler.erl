-module(channel_detail_handler).

-export([init/3,
         rest_init/2,
         allowed_methods/2,
         resource_exists/2,
         content_types_provided/2,
         content_types_accepted/2,
         is_authorized/2,
         to_json/2,
         from_json/2,
         delete_resource/2]).

init(_Transport, _Req, []) ->
    {upgrade, protocol, cowboy_rest}.

rest_init(Req, _Opts) ->
    {Name, Req2} = cowboy_req:binding(name, Req),
    State = #{name => Name},
    {ok, Req2, State}.

is_authorized(Req, State) ->
    req_utils:is_authorized(bearer, Req, State).

allowed_methods(Req, State) ->
    {[<<"GET">>, <<"HEAD">>, <<"OPTIONS">>, <<"PUT">>, <<"DELETE">>],
     Req, State}.

resource_exists(Req, State = #{user := User, name := Name}) ->
    case db_channel:get(User, Name) of
        {ok, Channel} -> {true, Req, State#{channel => Channel, is_new => false}};
        _ -> {false, Req, State#{is_new => true}}
    end.

content_types_provided(Req, State) ->
    {[{<<"application/json">>, to_json}], Req, State}.

to_json(Req, State = #{channel := Channel}) ->
    Body = hp_json:encode(Channel),
    {Body, Req, State}.

content_types_accepted(Req, State) ->
    {[{<<"application/json">>, from_json}], Req, State}.

%% PUT for create
from_json(Req, State = #{is_new := true,
                         user := User,
                         name := Name}) ->
    {ok, Body, Req2} = cowboy_req:body(Req),

    %% TODO validate input fields
    #{
       <<"type">> := Type,
       <<"configuration">> := Config
     } = hp_json:decode(Body),

    {ok, _} = db_channel:create(User, Name, Type, Config),

    Req3 = cowboy_req:set_resp_body(Body, Req2),
    {true, Req3, State};

%% PUT for update
from_json(Req, State = #{is_new := false,
                         user := User,
                         name := Name,
                         channel := Channel}) ->

    %% only configuration can be updated for now
    {ok, Body, Req2} = cowboy_req:body(Req),
    %% TODO validate input fields
    #{<<"configuration">> := Config} = hp_json:decode(Body),

    ok = db_channel:update(User, Name, Config),

    RespBody = Channel#{configuration := Config},
    Encoded = hp_json:encode(RespBody),
    Req3 = cowboy_req:set_resp_body(Encoded, Req2),
    {true, Req3, State}.

delete_resource(Req, State = #{user := User, name := Name}) ->
    ok = db_channel:delete(User, Name),
    {true, Req, State}.