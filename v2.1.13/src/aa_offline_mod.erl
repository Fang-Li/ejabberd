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

sm_register_connection_hook_handler(SID, JID, Info) -> ok.

user_available_hook_handler(JID) -> send_offline_msg(JID).

send_offline_msg(JID) ->
	try 
		%% JID={jid,"cc","test.com","Smack","cc","test.com","Smack"} 
		{jid,User,Domain,_,_,_,_} = JID,
		KEY = User++"@"++Domain++"/offline_msg",
		?INFO_MSG("@@@@ send_offline_msg :::> KEY=~p >>>>>>>>>>>>>>>>>>>>>>>",[KEY]),
		R = gen_server:call(?MODULE,{range_offline_msg,KEY}),
		%% TODO 这里，如果发送失败了，是需要重新发送的，但是先让他跑起来
		?INFO_MSG("@@@@ send_offline_msg :::> KEY=~p ; R.size=~p~n",[KEY,length(R)]),
		lists:foreach(fun(ID)->
			try	
				case gen_server:call(?MODULE,{ecache_cmd,["GET",ID]}) of
					Obj when erlang:is_list(Obj) ->
						[Bin] = Obj,	
						{FF,TT,PP} = erlang:binary_to_term(Bin),
						Rtn = case ejabberd_router:route(FF, TT, PP) of
						    ok -> ok; 
						    Err -> "Error: "++Err
						end,
						?INFO_MSG("@ SEND :::::> KEY=~p; ID=~p ",[KEY,ID]);
					Other ->	
						ZREM_R = gen_server:call(?MODULE,{ecache_cmd,["ZREM",KEY,ID]}),
						?INFO_MSG("@ SEND [DEL]::::> KEY=~p; ID=~p; ERR=~p; ZREM_R=~p",[KEY,ID,Other,ZREM_R])	
				end
			catch
				E:I ->
					?INFO_MSG("~p ; ~p",[E,I])	
			end,
			ok
		end,R) ,
		?INFO_MSG("@@@@ send_offline_message ::>KEY=~p  <<<<<<<<<<<<<<<<<",[KEY]) 
	catch 
		_:_->
			Err = erlang:get_stacktrace(),
			?INFO_MSG("@@ send_offline_message ERROR::> ~p ",[Err])
	end,
	ok.


sm_remove_connection_hook_handler(SID, JID, Info) -> ok.

%% 离线消息事件
%% 保存离线消息
offline_message_hook_handler(#jid{user=FromUser}=From, #jid{user=User,server=Domain}=To, Packet) ->
	Type = xml:get_tag_attr_s("type", Packet),
	ID = xml:get_tag_attr_s("id", Packet),
	IS_GROUP = aa_group_chat:is_group_chat(To),
	if IS_GROUP==false,FromUser=/="messageack",User=/="messageack",Type=/="error",Type=/="groupchat",Type=/="headline" ->
			SYNCID = ID++"@"++Domain,
			%% Time = xml:get_tag_attr_s("msgTime", Packet),
			%% ?INFO_MSG("ERROR++++++++++++++++ Time=~p;~n~nPacket=~p",[Time,Packet]),
			%% {ok,TimeStamp} = getTime(Time),
			%% TODO 7天以后过期
			%% Exp = ?EXPIRE+TimeStamp,
			KEY = User++"@"++Domain++"/offline_msg",
			?INFO_MSG("::::store_offline_msg::::>type=~p;KEY=~p",[Type,KEY]),
			gen_server:call(?MODULE,{store_offline_msg,KEY,SYNCID});
		true ->
			ok
	end.

%% ====================================================================
%% Behavioural functions 
%% ====================================================================
-record(state, { ecache_node, ecache_mod=ecache_server, ecache_fun=cmd }).

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
	Conn = conn_ecache_node(),
	{ok,_,Node} = Conn,
	{ok, #state{ecache_node=Node}}.

handle_cast(Msg, State) -> {noreply, State}.
handle_call({clear_offline_msg,KEY,ID},_From, State) -> 
	?DEBUG("##### clear_offline_msg at ack :::> Key=~p ; ID=~p",[KEY,ID]),
	R = ecache_cmd(["ZREM",KEY,ID],State),
	{reply,R,State};
handle_call({range_offline_msg,KEY},_From, State) -> 
	%% 倒序: zrevrange
	%% 正序: zrange
	[_,DR] = string:tokens(KEY,"@"),
	[D|_] = string:tokens(DR,"/"),
	Max_offline = case ejabberd_config:get_local_option({max_offline,D}) of N when is_integer(N),N > 0 -> N; _ -> -1 end,
	Size = ecache_cmd(["ZCARD",KEY],State),
	?DEBUG("Domain=~p ; Max_offline=~p ; Size=~p",[D,Max_offline,Size]),
	case Size >= Max_offline of 
		true when Max_offline > 0 ->
			DEL_list = ecache_cmd(["ZRANGE",KEY,erlang:integer_to_list(Max_offline),"-1"],State),
			lists:foreach(fun(DID)->
				ecache_cmd(["DEL",DID],State), 
				ecache_cmd(["ZREM",KEY,DID],State) 
			end,DEL_list);
		_ ->
			skip
	end,

	R = ecache_cmd(["ZRANGE",KEY,"0",erlang:integer_to_list(Max_offline)],State),
	?DEBUG("##### range_offline_msg :::> Key=~p ; R=~p",[KEY,R]),
	{reply,R,State};
handle_call({store_offline_msg,KEY,ID},_From, State) -> 
	SCORE = integer_to_list(index_score()),
	?DEBUG("##### store_offline_msg :::> Key=~p ; Time=~p ; ID=~p",[KEY,SCORE,ID]),
	R = ecache_cmd(["ZADD",KEY,SCORE,ID],State),
	?DEBUG("##### store_offline_msg :::> R=~p",[R]),
	{reply,R,State};
handle_call({ecache_cmd,Cmd},_From, State) -> 
	?DEBUG("##### ecache_cmd_on_offline_mod :::> Cmd=~p",[Cmd]),
	{reply,ecache_cmd(Cmd,State),State}.

ecache_cmd(Cmd,#state{ecache_node=Node,ecache_mod=Mod,ecache_fun=Fun}=State) ->
	R = rpc:call(Node,Mod,Fun,[{Cmd}]),
	%% ?DEBUG("==== ecache_cmd ===> Cmd=~p ; R=~p",[Cmd,R]),
	R.

handle_info(Info, State) -> {noreply, State}.
terminate(Reason, State) -> ok.
code_change(OldVsn, State, Extra) -> {ok, State}.
%% ====================================================================
%% Internal functions
%% ====================================================================
timestamp() ->  
	{M, S, _} = os:timestamp(),
	M * 1000000 + S.
getTime(Time) when is_binary(Time) ->
	{ok,erlang:binary_to_integer(Time)};
getTime(Time) when is_list(Time) ->
	{ok,erlang:list_to_integer(Time)};
getTime([]) ->
	{ok,timestamp()}.
index_score()-> {M,S,T} = now(),  M*1000000000000+S*1000000+T.
conn_ecache_node() ->
	try
		[Domain|_] = ?MYHOSTS, 
		N = ejabberd_config:get_local_option({ecache_node,Domain}),
		{ok,net_adm:ping(N),N}
	catch
		E:I ->
			Err = erlang:get_stacktrace(),
			log4erl:error("error ::::> E=~p ; I=~p~n Error=~p",[E,I,Err]),
			{error,E,I}
	end.
