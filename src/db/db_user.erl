-module(db_user).

-export([create_holiday_user/3,
         create_github_user/2,
         get/1,
         delete/1,
         get_with_password/1,
         get_verification/1,
         reset_verification/2,
         get_password_reset/1,
         reset_password/2,
         set_password/2,
         set_verified/1,
         user_keys/0]).

-behaviour(sumo_doc).

-export([sumo_schema/0, sumo_sleep/1, sumo_wakeup/1]).
-export([new/3]).

-spec sumo_wakeup(sumo:model()) -> post().
sumo_wakeup(Data) ->
  maps:to_list(Data).

-spec sumo_sleep(post()) -> sumo:model().
sumo_sleep(Post) ->
  maps:from_list(Post).

-spec sumo_schema() -> sumo:schema().
sumo_schema() ->
  sumo:new_schema(user, [
    sumo:new_field(id, [id, auto_increment, not_null]),
    sumo:new_field(email, string, [{string, 100}, not_null, unique]),
    sumo:new_field(name, string, [not_null]),
    sumo:new_field(password, string, []),
    sumo:new_field(auth_type, string, []),
    sumo:new_field(verified, boolean, []),
    sumo:new_field(verification_code, string, [{string, 30}]),
    sumo:new_field(verification_sent_at, []),
    sumo:new_field(password_reset_code, string, [{string, 30}]),
    sumo:new_field(password_reset_sent_at, []),
    ]).

new(Email, Name, Password) ->
  #{email => Email,
    name => Name,
    password => Password}.

%% needed so atoms exist.
user_keys () -> [email, password, name].

create_holiday_user(Email, Name, Password) ->
  Q = <<"INSERT INTO users(email, name, password, auth_type) "
        "VALUES($1, $2, $3, 'holiday') RETURNING email, name ">>,
  case db:query(Q, [Email, Name, Password]) of
    {ok, [Result | []]} -> {ok, Result};
    {error, unique_violation} -> {error, user_already_exists}
  end.

create_github_user(Email, Name) ->
  Q = <<"INSERT INTO users(email, name, auth_type, verified)"
        "VALUES($1, $2, 'github', true) RETURNING email, name ">>,
  case db:query(Q, [Email, Name]) of
    {ok, [Result | []]} -> {ok, Result};
    {error, unique_violation} -> {error, user_already_exists}
  end.

get(Email) ->
  Q = <<"SELECT email, name FROM users WHERE email = $1">>,
  case db:query(Q, [Email]) of
    {ok, []} -> {error, not_found};
    {ok, [User | []]} -> {ok, User}
  end.

get_with_password(Email) ->
  Q = <<"SELECT email, name, verified, password FROM users "
        "WHERE email = $1 AND auth_type = 'holiday'">>,
  case db:query(Q, [Email]) of
    {ok, []} -> {error, not_found};
    {ok, [User | []]} -> {ok, User}
  end.

get_verification(Email) ->
  Q = <<"SELECT verified, verification_code, "
        "EXTRACT (EPOCH FROM (now() at time zone 'utc')) - EXTRACT (EPOCH FROM verification_sent_at) as sent_seconds_ago "
        "FROM users WHERE email = $1 AND auth_type = 'holiday'">>,
  case db:query(Q, [Email]) of
    {ok, []} -> {error, not_found};
    {ok, [User | []]} -> {ok, User}
  end.

reset_verification(Email, VerificationCode) ->
  Q = <<"UPDATE users SET verification_code = $1, verification_sent_at = (now() at time zone 'utc') "
        "WHERE email = $2 ">>,
  db:query(Q, [VerificationCode, Email]).

set_verified(Email) ->
  Q = <<"UPDATE \"users\" SET verified = true WHERE email = $1">>,
  db:query(Q, [Email]).

reset_password(Email, VerificationCode) ->
  Q = <<"UPDATE users SET password_reset_code = $1, password_reset_sent_at = (now() at time zone 'utc') "
        "WHERE email = $2 ">>,
  db:query(Q, [VerificationCode, Email]).

get_password_reset(Email) ->
  Q = <<"SELECT password_reset_code, "
        "EXTRACT (EPOCH FROM (now() at time zone 'utc')) - EXTRACT (EPOCH FROM password_reset_sent_at) as sent_seconds_ago "
        "FROM users WHERE email = $1 AND auth_type = 'holiday'">>,
  case db:query(Q, [Email]) of
    {ok, []} -> {error, not_found};
    {ok, [User | []]} -> {ok, User}
  end.

set_password(Email, Password) ->
  Q = <<"UPDATE users SET password_reset_code = NULL, password = $1 "
        "WHERE email = $2 ">>,
  db:query(Q, [Password, Email]).

delete(Email) ->
  Q = <<"DELETE FROM users WHERE email = $1">>,
  db:query(Q, [Email]).
