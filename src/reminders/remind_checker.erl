-module(remind_checker).
-behaviour(gen_server).

%%% This module checks periodically which users have reminders to be sent,
%%% according to their holiday configuration, and calls remind_router with the user
%%% and holiday data.

-export([start_link/0,

         check_holidays/0,

         init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2]).

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
  Interval = hp_config:get(checker_interval),
  {ok, _} = timer:send_interval(Interval, check_holidays),
  {ok, []}.

handle_call(_Request, _From, State) ->
  {noreply, State}.

handle_cast(_Request, State) ->
  {noreply, State}.

handle_info(check_holidays, State) ->
  check_holidays(),
  {noreply, State};

handle_info(_Msg, State) ->
  {noreply, State}.

%%% exported only for tests
check_holidays() ->
  lager:info("Running holiday checker."),
  {ok, Results} = db_reminder:get_scheduled(),
  lists:foreach(fun ({User, Channel, Holiday}) ->
                    remind_router:send(User, Channel, maps:get(date, Holiday))
                end,
                Results),
  ok.
