-module(tx_app).
-behaviour(application).

-export([start/2, stop/1]).

-record(robot,{name,pid,send=0,recv=0}).
-record(log,{id,total,n=0}).
%% ====================================================================
%% API functions
%% ====================================================================
-export([]).

%% ====================================================================
%% Behavioural functions
%% ====================================================================
-spec start(Type :: normal | {takeover, Node} | {failover, Node}, Args :: term()) ->
	{ok, Pid :: pid()}
	| {ok, Pid :: pid(), State :: term()}
	| {error, Reason :: term()}.
start(Type, StartArgs) ->
	application:start(log4erl),
	log4erl:add_file_appender(chat_room1, {".", "test_xmpp", {size, 1000000000}, 4, "txt", info,"%j %T [%L] %l%n"}),  
	catch mnesia:create_schema([node()]),
	mnesia:start(),
	mnesia:create_table(robot,  [{ram_copies,[node()]}, {attributes, record_info(fields, robot)}]),
	mnesia:create_table(log, [{ram_copies,[node()]}, {attributes, record_info(fields, log)}]),
	mnesia:wait_for_tables([robot,status], 5000),
	case tx_main_sup:start_link() of 
		{ok,Pid} ->
			{ok,Pid};
		Other ->
			{error,Other}
	end.

-spec stop(State :: term()) ->  Any :: term().
stop(State) ->
    ok.

%% ====================================================================
%% Internal functions
%% ====================================================================
