%%
%% Autogenerated by Thrift Compiler (1.0.0-dev)
%%
%% DO NOT EDIT UNLESS YOU ARE SURE THAT YOU KNOW WHAT YOU ARE DOING
%%

-module(ecache_thrift).
-behaviour(thrift_service).


-include("ecache_thrift.hrl").

-export([struct_info/1, function_info/2]).

struct_info('i am a dummy struct') -> undefined.
%%% interface
% cmd(This, Request)
function_info('cmd', params_type) ->
  {struct, [{1, {list, string}}]}
;
function_info('cmd', reply_type) ->
  {list, string};
function_info('cmd', exceptions) ->
  {struct, []}
;
function_info(_Func, _Info) -> no_function.

