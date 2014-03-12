-module(aa_offline_mod).
-behaviour(gen_server).

-include("ejabberd.hrl").
-include("jlib.hrl").
-include_lib("xmerl/include/xmerl.hrl").

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% 离线消息对象
-record(offline_msg, {us, timestamp, expire, from, to, packet}).
-define(EXPIRE,60*60*24*7).

%% ====================================================================
%% API functions
%% ====================================================================

-export([
	 start_link/0,
	 offline_message_hook_handler/3,
	 sm_register_connection_hook_handler/3,
	 sm_remove_connection_hook_handler/3,
	 user_available_hook_handler/1
]).

start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

getTime(Time) when is_binary(Time) ->
	{ok,erlang:binary_to_integer(Time)};
getTime(Time) when is_list(Time) ->
	{ok,erlang:list_to_integer(Time)}.

sm_register_connection_hook_handler(SID, JID, Info) -> 
	ok.

user_available_hook_handler(JID) ->
	%% JID={jid,"cc","test.com","Smack","cc","test.com","Smack"} 
	{jid,User,Domain,_,_,_,_} = JID,
	KEY = User++"@"++Domain++"/offline_msg",
	?INFO_MSG("@@@@@@@@@@@@@@@@ sm_register_connection_hook_handler :::> {SID,JID,Info}=~p;KEY=~p",[JID,KEY]),
	R = gen_server:call(?MODULE,{range_offline_msg,KEY}),
	?INFO_MSG("@@@@@@@@@@@@@@@@ sm_register_connection_hook_handler :::> Result=~p~n~n",[R]),
	%% TODO 这里，如果发送失败了，是需要重新发送的，但是先让他跑起来
	{ok,ML} = R,
	lists:foreach(fun(OfflineMsg)->
		Msg = erlang:binary_to_term(OfflineMsg),
		#offline_msg{from=From,to=To,packet=Packet}=Msg,
		Rtn = case ejabberd_router:route(From, To, Packet) of
		    ok -> ok; 
		    Err -> "Error: "++Err
		end,
		?INFO_MSG("send_offline_message ::> From=~p; To=~p; Packet=~p ",[From,To,Packet]),
		ok
	end,ML),	
	%% XXX 这里的删除逻辑有待修正
	Clear = gen_server:call(?MODULE,{clear_offline_msg,KEY}),
	?INFO_MSG("clear_offline_message ::> ~p",[Clear]),
	ok.


sm_remove_connection_hook_handler(SID, JID, Info) -> 
	?INFO_MSG("@@@@@@@@@@@@@@@@ sm_remove_connection_hook_handler :::> {SID,JID,Info}=~p",[{SID,JID,Info}]),
	ok.


%% 离线消息事件
%% 保存离线消息
%% msgTime="1394444235"
offline_message_hook_handler(From, To, Packet) ->
	Type = xml:get_tag_attr_s("type", Packet),
	if
		(Type =/= "error") and (Type =/= "groupchat") and (Type =/= "headline") ->
			Time = xml:get_tag_attr_s("msgTime", Packet),
			?INFO_MSG("ERROR++++++++++++++++ Time=~p;~n~nPacket=~p",[Time,Packet]),
			{ok,TimeStamp} = getTime(Time),
			%% 7天以后过期
			Exp = ?EXPIRE+TimeStamp,
			{jid,User,Domain,_,_,_,_} = To,
			KEY = User++"@"++Domain++"/offline_msg",
			?INFO_MSG("::::store_offline_msg::::>type=~p;time=~p;timestamp=~p;~n~nKEY=~p~n~n",[Type,Time,TimeStamp,KEY]),
			Offline_Msg = #offline_msg{ timestamp = TimeStamp,
				     expire = Exp,
				     from = From,
				     to = To,
				     packet = Packet},		
			BinaryMsg = erlang:term_to_binary(Offline_Msg),
			gen_server:call(?MODULE,{store_offline_msg,KEY,integer_to_list(TimeStamp),BinaryMsg});
		true ->
			ok
	end.

%% ====================================================================
%% Behavioural functions 
%% ====================================================================
-record(state, {host,port=9090}).

init([]) ->
	?INFO_MSG("INIT_START_OFFLINE_MOD >>>>>>>>>>>>>>>>>>>>>>>> ~p",[liangchuan_debug]),  
	lists:foreach(
	  fun(Host) ->
		ejabberd_hooks:add(offline_message_hook, Host, ?MODULE, offline_message_hook_handler, 40),
		ejabberd_hooks:add(sm_remove_connection_hook, Host, ?MODULE, sm_remove_connection_hook_handler, 40),
		ejabberd_hooks:add(sm_register_connection_hook, Host, ?MODULE, sm_register_connection_hook_handler, 60),
		ejabberd_hooks:add(user_available_hook, Host, ?MODULE, user_available_hook_handler, 40)
	  end, ?MYHOSTS),
	?INFO_MSG("INIT_END_OFFLINE_MOD <<<<<<<<<<<<<<<<<<<<<<<<< ~p",[liangchuan_debug]),
	[Domain|_] = ?MYHOSTS, 
	[{ip,THost},{port,TPort}] = ejabberd_config:get_local_option({sync_packet,Domain}),
	{ok, #state{port=TPort,host=THost}}.

handle_cast(Msg, State) -> {noreply, State}.
handle_call({clear_offline_msg,KEY},_From, State) -> 
	{ok,C0} = thrift_client_util:new(State#state.host,State#state.port, ecache_thrift, []),	
	{C1, R} =  thrift_client:call(C0, cmd, [["DEL",KEY]]),
	thrift_client:close(C1),
	{reply,R,State};
handle_call({range_offline_msg,KEY},_From, State) -> 
	%% 倒序: zrevrange
	%% 正序: zrange
	{ok,C0} = thrift_client_util:new(State#state.host,State#state.port, ecache_thrift, []),	
	{C1, R} =  thrift_client:call(C0, cmd, [["ZRANGE",KEY,"0","-1"]]),
	thrift_client:close(C1),
	{reply,R,State};
handle_call({store_offline_msg,KEY,TimeStamp,Msg},_From, State) -> 
	{ok,C0} = thrift_client_util:new(State#state.host,State#state.port, ecache_thrift, []),	
	{C1, R} =  thrift_client:call(C0, cmd, [["ZADD",KEY,TimeStamp,Msg]]),
	thrift_client:close(C1),
	{reply,R,State}.
handle_info(Info, State) -> {noreply, State}.
terminate(Reason, State) -> ok.
code_change(OldVsn, State, Extra) -> {ok, State}.
%% ====================================================================
%% Internal functions
%% ====================================================================
timestamp() ->  
	{M, S, _} = os:timestamp(),  
	M * 1000000 + S.
