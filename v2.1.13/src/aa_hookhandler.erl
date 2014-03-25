-module(aa_hookhandler).
-behaviour(gen_server).

-include("ejabberd.hrl").
-include("jlib.hrl").
-include_lib("xmerl/include/xmerl.hrl").

-define(HTTP_HEAD,"application/x-www-form-urlencoded").
-define(TIME_OUT,1000*5).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% ====================================================================
%% API functions
%% ====================================================================

-export([
	 start_link/0,
	 user_send_packet_handler/3,
	 offline_message_hook_handler/3,
	 roster_in_subscription_handler/6,
	 user_receive_packet_handler/4,
	 sm_register_connection_hook_handler/3,
	 sm_remove_connection_hook_handler/3,
	 user_available_hook_handler/1
	]).

-record(dmsg,{mid,pid}).

sm_register_connection_hook_handler(SID, JID, Info) -> ok.
sm_remove_connection_hook_handler(SID, JID, Info) -> ok.
user_available_hook_handler(JID) -> ok.

start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Message 有时是长度大于1的列表，所以这里要遍历
%% 如果列表中有多个要提取的关键字，我就把他们组合成一个 List
%% 大部分时间 List 只有一个元素
feach_message([Element|Message],List) ->
	case Element of 
		{xmlelement,"body",_,_} ->
			feach_message(Message,[get_text_message_form_packet_result(Element)|List]);
		_ ->
			feach_message(Message,List)
	end;
feach_message([],List) ->
	List.

%% 获取消息包中的文本消息，用于离线消息推送服务
get_text_message_from_packet( Packet )->
	{xmlelement,"message",_,Message } = Packet,
	%% Message 结构不固定，需要遍历
	List = feach_message(Message,[]),
	?DEBUG("~p ==== ~p ",[liangc_debug_offline_message,List]),
	List.

%% 获取消息包中的文本消息，用于离线消息推送服务
get_text_message_form_packet_result( Body )->
	{xmlelement,"body",_,[{xmlcdata,MessageBody}]} = Body,
	ResultMessage = binary_to_list(MessageBody),
	ResultMessage.	

%% 离线消息处理器
%% 钩子回调
offline_message_hook_handler(#jid{user=FromUser}=From, #jid{server=Domain}=To, Packet) ->
	try
		?DEBUG("FFFFFFFFFFFFFFFFF===From=~p~nTo=~p~nPacket=~p~n",[From, To, Packet]),
		{xmlelement,"message",Header,_ } = Packet,
		%%这里只推送 msgtype=normalchat 的消息，以下是判断
		D = dict:from_list(Header),
		V = dict:fetch("msgtype", D),
		case V of
			"msgStatus" ->
				ok;
			_->
				if FromUser=/="messageack" ->
					   %% 2014-3-5 : 当消息离线时，要更改存储模块中对应的消息状态
					   MID = case dict:is_key("id", D) of
							 true ->
								 ID = dict:fetch("id", D),
								 ack_task({offline,ID}),
								 ID;
							 _ -> ""
					   end,
					   %% 回调webapp
					   case catch ejabberd_config:get_local_option({ack_from ,Domain}) of
						   true->
							case aa_group_chat:is_group_chat(To) of
								true ->
									skip;
								false ->
							   		offline_message_hook_handler( From, To, Packet, D, MID )
							end,
							ok;
						   _->
							   %% 宠物那边走这个逻辑
							   case V of "normalchat" -> offline_message_hook_handler( From, To, Packet, D, MID ); _-> skip end
					   end;
				   true->
					   ok
				end
		end
	catch
		_:_ -> ok
	end.


offline_message_hook_handler(From, To, Packet,D,ID ) ->
	try
		V = dict:fetch("fileType", D),
		send_offline_message(From ,To ,Packet,V,ID )
	catch
		_:_ -> send_offline_message(From ,To ,Packet,"",ID )
	end,
	ok.

%% 将 Packet 中的 Text 消息 Post 到指定的 Http 服务
%% IOS 消息推送功能
send_offline_message(From ,To ,Packet,Type,MID )->
	{jid,FromUser,Domain,_,_,_,_} = From ,	
	{jid,ToUser,_,_,_,_,_} = To ,	
	%% 取自配置文件 ejabberd.cfg
	HTTPServer =  ejabberd_config:get_local_option({http_server,Domain}),
	%% 取自配置文件 ejabberd.cfg
	HTTPService = ejabberd_config:get_local_option({http_server_service_client,Domain}),
	HTTPTarget = string:concat(HTTPServer,HTTPService),
	Msg = get_text_message_from_packet( Packet ),
	{Service,Method,FN,TN,MSG,T,MSG_ID} = {
				      list_to_binary("service.uri.pet_user"),
				      list_to_binary("pushMsgApn"),
				      list_to_binary(FromUser),
				      list_to_binary(ToUser),
				      list_to_binary(Msg),
				      list_to_binary(Type),
				      list_to_binary(MID)
				     },
	ParamObj={obj,[ 
		       {"service",Service},
		       {"method",Method},
		       {"channel",list_to_binary("9")},
		       {"params",{obj,[{"fromname",FN},{"toname",TN},{"msg",MSG},{"type",T},{"id",MSG_ID}]} } 
		      ]},
	Form = "body="++rfc4627:encode(ParamObj),
	?DEBUG("MMMMMMMMMMMMMMMMM===Form=~p~n",[Form]),
	case httpc:request(post,{ HTTPTarget ,[], ?HTTP_HEAD , Form },[],[] ) of   
		{ok, {_,_,Body}} ->
			case rfc4627:decode(Body) of
				{ok,Obj,_Re} -> 
					case rfc4627:get_field(Obj,"success") of
						{ok,false} ->
							{ok,Entity} = rfc4627:get_field(Obj,"entity"),
							?DEBUG("liangc-push-msg error: ~p~n",[binary_to_list(Entity)]);
						_ ->
							false
					end;
				_ -> 
					false
			end ;
		{error, Reason} ->
			?DEBUG("[~ERROR~] cause ~p~n",[Reason])
	end,
	ok.

%roster_in_subscription(Acc, User, Server, JID, SubscriptionType, Reason) -> bool()
roster_in_subscription_handler(Acc, User, Server, JID, SubscriptionType, Reason) ->
	?DEBUG("~n~p; Acc=~p ; User=~p~n Server=~p ; JID=~p ; SubscriptionType=~p ; Reason=~p~n ", [liangchuan_debug,Acc, User, Server, JID, SubscriptionType, Reason] ),
	{jid,ToUser,Domain,_,_,_,_}=JID,
	?DEBUG("XXXXXXXX===~p",[SubscriptionType]),
	case lists:member(SubscriptionType,[subscribe,subscribed,unsubscribed]) of 
		true -> 
			sync_user(Domain,User,ToUser,SubscriptionType);
		_ ->
			ok
	end,
	true.

%% 好友同步
sync_user(Domain,FromUser,ToUser,SType) ->
	HTTPServer =  ejabberd_config:get_local_option({http_server,Domain}),
	HTTPService = ejabberd_config:get_local_option({http_server_service_client,Domain}),
	HTTPTarget = string:concat(HTTPServer,HTTPService),
	{Service,Method,Channel} = {list_to_binary("service.uri.pet_user"),list_to_binary("addOrRemoveFriend"),list_to_binary("9")},
	{BID,AID,ST} = {list_to_binary(FromUser),list_to_binary(ToUser),list_to_binary(atom_to_list(SType))},
	%% 2013-10-22 : 新的请求协议如下，此处不必关心，success=true 即成功
	%% INPUT {"SubscriptionType":"", "aId":"", "bId":""}
	%% OUTPUT {"success":true,"entity":"OK" }
	PostBody = {obj,[{"service",Service},{"method",Method},{"channel",Channel},{"params",{obj,[{"SubscriptionType",ST},{"aId",AID},{"bId",BID}]}}]},	
	JsonParam = rfc4627:encode(PostBody),
	ParamBody = "body="++JsonParam,
	URL = HTTPServer++HTTPService++"?"++ParamBody,
	?DEBUG("~p: ~p~n ",[liangchuan_debug,URL]),
	Form = lists:concat([ParamBody]),
	case httpc:request(post,{ HTTPTarget, [], ?HTTP_HEAD, Form },[],[] ) of   
		{ok, {_,_,Body}} ->
			case rfc4627:decode(Body) of
				{ok , Obj , _Re } ->
					%% 请求发送出去以后，如果返回 success=false 那么记录一个异常日志就可以了，这个方法无论如何都要返回 ok	
					case rfc4627:get_field(Obj,"success") of
						{ok,false} ->	
							{ok,Entity} = rfc4627:get_field(Obj,"entity"),
							?DEBUG("liangc-sync-user error: ~p~n",[binary_to_list(Entity)]);
						_ ->
							false
					end;
				_ -> 
					false
			end ;
		{error, Reason} ->
			?DEBUG("[~ERROR~] cause ~p~n",[Reason])
	end,
	?DEBUG("[--OKOKOKOK--] ~p was done.~n",[addOrRemoveFriend]),
	ok.

%roster_out_subscription(Acc, User, Server, JID, SubscriptionType, Reason) -> bool()
%roster_out_subscription_handler(Acc, User, Server, JID, SubscriptionType, Reason) ->
%	true.

%user_send_packet(From, To, Packet) -> ok
user_send_packet_handler(#jid{user=FU,server=FD}=From, To, Packet) ->
	?DEBUG("~n************** my_hookhandler user_send_packet_handler >>>>>>>>>>>>>>>~p~n ",[liangchuan_debug]),
	?DEBUG("~n~pFrom=~p ; To=~p ; Packet=~p~n ", [liangchuan_debug,From, To, Packet] ),
	%% From={jid,"cc","test.com","Smack","cc","test.com","Smack"}
	[_,E|_] = tuple_to_list(Packet),
	{jid,_,Domain,_,_,_,_} = To,
	?DEBUG("Domain=~p ; E=~p", [Domain,E] ),
	case E of 
		"message" ->
			case aa_group_chat:is_group_chat(To) of  
				true ->
					?DEBUG("###### send_group_chat_msg ###### From=~p ; Domain=~p",[From,Domain]),
					aa_group_chat:route_group_msg(From,To,Packet);
				false ->
					{_,"message",Attr,_} = Packet,
					?DEBUG("Attr=~p", [Attr] ),
					D = dict:from_list(Attr),
					T = dict:fetch("type", D),
					MT = dict:fetch("msgtype", D),
					%% 只响应 type != normal 的消息
					%% 理论上讲，这个地方一定要有一个ID，不过如果没有，其实对服务器没影响，但客户端就麻烦了
					SRC_ID_STR = case dict:is_key("id", D) of 
							     true -> 
								     dict:fetch("id", D);
							     _ -> ""
						     end,
					?DEBUG("SRC_ID_STR=~p", [SRC_ID_STR] ),
					?DEBUG("Type=~p", [T] ),
					ACK_FROM = case catch ejabberd_config:get_local_option({ack_from ,Domain}) of 
							   true -> true;
							   _ -> false
						   end,
					?DEBUG("ack_from=~p ; Domain=~p ; T=~p ; MT=~p",[ACK_FROM,Domain,T,MT]),
					%% XXX : 第一个逻辑，ack 由服务器向发送方发出响应，表明服务器已经收到此信息
					%% 应答消息，要应答到 from 上
					if ACK_FROM , MT=:="normalchat" ->
						   case dict:is_key("from", D) of 
							   true -> 
								   Attributes = [
										 {"id",os:cmd("uuidgen")--"\n"},
										 {"to",dict:fetch("from", D)},
										 {"from","messageack@"++Domain},
										 {"type","normal"},
										 {"msgtype",""},
										 {"action","ack"}
								   ],
								   Child = [{xmlelement, "body", [], [
										{xmlcdata, list_to_binary("{'src_id':'"++SRC_ID_STR++"','received':'true'}")}
								   ]}],
								   %%Answer = {xmlelement,"message",Attributes, []},
								   Answer = {xmlelement, "message", Attributes , Child},
								   FF = jlib:string_to_jid(xml:get_tag_attr_s("from", Answer)),
								   TT = jlib:string_to_jid(xml:get_tag_attr_s("to", Answer)),
								   ?DEBUG("Answer ::::> FF=~p ; TT=~p ; P=~p ", [FF,TT,Answer] ),
								   case catch ejabberd_router:route(FF, TT, Answer) of
									   ok -> 
										   ?DEBUG("Answer ::::> ~p ", [ok] );
									   _ERROR ->
										   ?DEBUG("Answer ::::> error=~p ", [_ERROR] )
								   end,
								   answer;
							   _ ->
								   ?DEBUG("~p", [skip_01] ),
								   skip
						   end;
					   true ->
						   ?DEBUG("~p", [skip_02] ),
						   skip
					end,
					SYNCID = SRC_ID_STR++"@"++Domain,
					if ACK_FROM,MT=/=[],MT=/="msgStatus",FU=/="messageack" ->
							SyncRes = gen_server:call(?MODULE,{sync_packet,SYNCID,From,To,Packet}),
							?DEBUG("==> SYNC_RES new => ~p ; ID=~p",[SyncRes,SRC_ID_STR]),
							ack_task({new,SYNCID,From,To,Packet});
						ACK_FROM,MT=:="msgStatus" ->
							KK = FU++"@"++FD++"/offline_msg",
							gen_server:call(?MODULE,{ecache_cmd,["DEL",SYNCID]}),
							gen_server:call(?MODULE,{ecache_cmd,["ZREM",KK,SYNCID]}),
							?DEBUG("==> SYNC_RES ack => ACK_USER=~p ; ACK_ID=~p",[KK,SYNCID]),
							ack_task({ack,SYNCID});
						true ->
							skip
					end
			end;
		_ ->
			?DEBUG("~p", [skip_00] ),
			skip
	end,
	?DEBUG("~n************** my_hookhandler user_send_packet_handler <<<<<<<<<<<<<<<~p~n ",[liangchuan_debug]),
	ok.

user_receive_packet_handler(JID, From, To, Packet) ->
	ok.

timestamp() ->  
	{M, S, _} = os:timestamp(),  
	M * 1000000 + S.



%% ====================================================================
%% Behavioural functions 
%% ====================================================================
-record(state, {
	  ecache_node,
	  ecache_mod=ecache_server,
	  ecache_fun=cmd
}).

init([]) ->
	?DEBUG("INIT_START >>>>>>>>>>>>>>>>>>>>>>>> ~p",[liangchuan_debug]),  
	lists:foreach(
	  fun(Host) ->
			  ?INFO_MSG("#### _begin Host=~p~n",[Host]),
			  ejabberd_hooks:add(user_send_packet,Host,?MODULE, user_send_packet_handler ,80),
			  ?INFO_MSG("#### user_send_packet Host=~p~n",[Host]),
			  ejabberd_hooks:add(roster_in_subscription,Host,?MODULE, roster_in_subscription_handler ,90),
			  ?INFO_MSG("#### roster_in_subscription Host=~p~n",[Host]),
			  ejabberd_hooks:add(offline_message_hook, Host, ?MODULE, offline_message_hook_handler, 45),
			  ?INFO_MSG("#### offline_message_hook Host=~p~n",[Host]),
			  ejabberd_hooks:add(user_receive_packet, Host, ?MODULE, user_receive_packet_handler, 45),
			  ?INFO_MSG("#### user_receive_packet Host=~p~n",[Host]),

			  ejabberd_hooks:add(sm_register_connection_hook, Host, ?MODULE, sm_register_connection_hook_handler, 45),
			  ?INFO_MSG("#### sm_register_connection_hook_handler Host=~p~n",[Host]),
			  ejabberd_hooks:add(sm_remove_connection_hook, Host, ?MODULE, sm_remove_connection_hook_handler, 45),
			  ?INFO_MSG("#### sm_remove_connection_hook_handler Host=~p~n",[Host]),
			  ejabberd_hooks:add(user_available_hook, Host, ?MODULE, user_available_hook_handler, 45),
			  ?INFO_MSG("#### user_available_hook_handler Host=~p~n",[Host])

	  end, ?MYHOSTS),
	Conn = conn_ecache_node(),
	?INFO_MSG("INIT_END <<<<<<<<<<<<<<<<<<<<<<<<< Conn=~p",[Conn]),
	{ok,_,Node} = Conn,
	%% 2014-3-4 : 在这个 HOOK 初始化时，启动一个thrift 客户端，同步数据到缓存服务器
	[Domain|_] = ?MYHOSTS, 
	%% 启动5281端口，接收内网回调
	aa_inf_server:start(),
	mnesia:create_table(dmsg,[{attributes,record_info(fields,dmsg)},{ram_copies,[node()]}]),
	{ok, #state{ecache_node=Node}}.

handle_call({ecache_cmd,Cmd}, _F, #state{ecache_node=Node,ecache_mod=Mod,ecache_fun=Fun}=State) ->
	?DEBUG("==== ecache_cmd ===> Cmd=~p",[Cmd]),
	R = rpc:call(Node,Mod,Fun,[{Cmd}]),
	{reply, R, State};
handle_call({sync_packet,K,From,To,Packet}, _F, #state{ecache_node=Node,ecache_mod=Mod,ecache_fun=Fun}=State) ->
	%% insert {K,V} 
	%% reset msgTime
	{M,S,SS} = now(),
	MsgTime = lists:sublist(erlang:integer_to_list(M*1000000000000+S*1000000+SS),1,13),
	{X,E,Attr,Body} = Packet,
	RAttr0 = lists:map(fun({K,V})-> case K of "msgTime" -> skip; _-> {K,V} end end,Attr),
	RAttr1 = lists:append([X||X<-RAttr0,X=/=skip],[{"msgTime",MsgTime}]),
	RPacket = {X,E,RAttr1,Body},
	V = term_to_binary({From,To,RPacket}),
	?DEBUG("==== sync_packet ===> insert K=~p~nV=~p",[K,V]),
	Cmd = ["SET",K,V],
	R = rpc:call(Node,Mod,Fun,[{Cmd}]),
	%% add {K,V} to zset
	aa_offline_mod:offline_message_hook_handler(From,To,Packet),
	{reply, R, State}.
handle_cast(Msg, State) -> {noreply, State}.
handle_info(Info, State) -> {noreply, State}.
terminate(Reason, State) -> ok.
code_change(OldVsn, State, Extra) -> {ok, State}.
%% ====================================================================
%% Internal functions
%% ====================================================================
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

ack_task({new,ID,From,To,Packet})->
	TPid = erlang:spawn(fun()-> ack_task(ID,From,To,Packet) end),
	mnesia:dirty_write(dmsg,#dmsg{mid=ID,pid=TPid});
ack_task({ack,ID})->
	ack_task({do,ack,ID});
ack_task({offline,ID})->
	ack_task({do,offline,ID});
ack_task({do,M,ID})->
	try
		[{_,_,ResendPid}] = mnesia:dirty_read(dmsg,ID),
		ResendPid!M 
	catch 
		_:_-> ack_err
	end.
ack_task(ID,From,To,Packet)->
	?INFO_MSG("ACK_TASK_~p ::::> START.",[ID]),
	receive 
		offline->
			mnesia:dirty_delete(dmsg,ID),
			?INFO_MSG("ACK_TASK_~p ::::> OFFLINE.",[ID]);
		ack ->
			mnesia:dirty_delete(dmsg,ID),
			?INFO_MSG("ACK_TASK_~p ::::> ACK.",[ID])
	after ?TIME_OUT -> 
		?INFO_MSG("ACK_TASK_~p ::::> AFTER",[ID]),
		mnesia:dirty_delete(dmsg,ID),
		offline_message_hook_handler(From,To,Packet)
	end.
