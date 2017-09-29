-module(hp_auth).

-export([token_encode/1,
         token_decode/1,
         password_hash/1,
         password_match/2,
         authenticate/2,
         verification_code/1]).

password_hash(Value) ->
  erlpass:hash(Value).

password_match(Value, Hash) ->
  erlpass:match(Value, Hash).

%% Return the user data if exits and password match.
authenticate(Email, Password) ->
  case db_user:get_with_password(Email) of
    {ok, #{verified := false}} ->
      {error, not_verified};
    {ok, User = #{password := Hash}} ->
      case password_match(Password, Hash) of
        true ->
          {ok, maps:remove(password, User)};
        false ->
          {error, unauthorized}
      end;
    _ -> {error, unauthorized}
  end.

token_encode(Data) ->
  Expiration = hp_config:get(token_expiration),
  Secret = hp_config:get(token_secret),
  jwt:encode(<<"HS256">>, maps:to_list(Data), Expiration, Secret).

token_decode(Token) ->
  Secret = hp_config:get(token_secret),
  {ok, Map} = jwt:decode(Token, Secret),
  Map2 = maps:fold(fun (K, V, Acc) ->
                       K2 = binary_to_existing_atom(K, latin1),
                       Acc#{K2 => V}
                   end, #{}, Map),
  {ok, Map2}.

%% remove?
verification_code(Email) ->
  {YY, MM, DD} = erlang:date(),
  Date = io_lib:format(<<"~B-~2..0B-~2..0B">>, [YY, MM, DD]),
  Value = <<Email/binary,Date/binary>>,
  Secret = hp_config:get(token_secret),
  base64:encode(crypto:hmac(sha256, Secret, Value)).
