-module(aa_hookhandler).
-behaviour(gen_server).

-include("ejabberd.hrl").
-include("jlib.hrl").
-include_lib("xmerl/include/xmerl.hrl").

-define(HTTP_HEAD,"application/x-www-form-urlencoded").

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

sm_register_connection_hook_handler(SID, JID, Info) -> 
	?INFO_MSG("@@@@@@@@@@@@@@@@ sm_register_connection_hook_handler :::> {SID,JID,Info}=~p",[{SID,JID,Info}]),
	ok.
sm_remove_connection_hook_handler(SID, JID, Info) -> 
	?INFO_MSG("@@@@@@@@@@@@@@@@ sm_remove_connection_hook_handler :::> {SID,JID,Info}=~p",[{SID,JID,Info}]),
	ok.
user_available_hook_handler(JID) -> 
	?INFO_MSG("@@@@@@@@@@@@@@@@ user_available_hook_handler :::> JID=~p",[JID]),
	ok.

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
	?INFO_MSG("~p ==== ~p ",[liangc_debug_offline_message,List]),
	List.

%% 获取消息包中的文本消息，用于离线消息推送服务
get_text_message_form_packet_result( Body )->
	{xmlelement,"body",_,[{xmlcdata,MessageBody}]} = Body,
	ResultMessage = binary_to_list(MessageBody),
	ResultMessage.	

%% 离线消息处理器
%% 钩子回调
offline_message_hook_handler(From, #jid{server=Domain}=To, Packet) ->
        try
                ?INFO_MSG("FFFFFFFFFFFFFFFFF===From=~p~nTo=~p~nPacket=~p~n",[From, To, Packet]),
                {xmlelement,"message",Header,_ } = Packet,
                %%这里只推送 msgtype=normalchat 的消息，以下是判断
                D = dict:from_list(Header),
                V = dict:fetch("msgtype", D),
                case V of
                        "msgStatus" ->
                                ok;
                        _->
                                %% 2014-3-5 : 当消息离线时，要更改存储模块中对应的消息状态
                                MID = case dict:is_key("id", D) of
                                        true ->
                                                ID = dict:fetch("id", D),
                                                SyncRes = gen_server:call(?MODULE,{sync_packet,offline,ID,Packet}),
                                                ?DEBUG("===========> SYNC_RES offline => ~p ; ID=~p",[SyncRes,ID]),
                                                ID;
                                        _ -> ""
                                end,
                                case catch ejabberd_config:get_local_option({ack_from ,Domain}) of
                                        true->
                                                offline_message_hook_handler( From, To, Packet, D, MID );
                                        _->
                                                %% 宠物那边走这个逻辑
                                                case V of "normalchat" -> offline_message_hook_handler( From, To, Packet, D, MID ); _-> skip end
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
	?INFO_MSG("MMMMMMMMMMMMMMMMM===Form=~p~n",[Form]),
	case httpc:request(post,{ HTTPTarget ,[], ?HTTP_HEAD , Form },[],[] ) of   
        	{ok, {_,_,Body}} ->
 			case rfc4627:decode(Body) of
 				{ok,Obj,_Re} -> 
					case rfc4627:get_field(Obj,"success") of
						{ok,false} ->
							{ok,Entity} = rfc4627:get_field(Obj,"entity"),
							?INFO_MSG("liangc-push-msg error: ~p~n",[binary_to_list(Entity)]);
						_ ->
							false
					end;
 				_ -> 
					false
 			end ;
        	{error, Reason} ->
 			?INFO_MSG("[~ERROR~] cause ~p~n",[Reason])
     	end,
	ok.

%roster_in_subscription(Acc, User, Server, JID, SubscriptionType, Reason) -> bool()
roster_in_subscription_handler(Acc, User, Server, JID, SubscriptionType, Reason) ->
	?INFO_MSG("~n~p; Acc=~p ; User=~p~n Server=~p ; JID=~p ; SubscriptionType=~p ; Reason=~p~n ", [liangchuan_debug,Acc, User, Server, JID, SubscriptionType, Reason] ),
	{jid,ToUser,Domain,_,_,_,_}=JID,
	?INFO_MSG("XXXXXXXX===~p",[SubscriptionType]),
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
	?INFO_MSG("~p: ~p~n ",[liangchuan_debug,URL]),
	Form = lists:concat([ParamBody]),
	case httpc:request(post,{ HTTPTarget, [], ?HTTP_HEAD, Form },[],[] ) of   
        	{ok, {_,_,Body}} ->
			case rfc4627:decode(Body) of
				{ok , Obj , _Re } ->
					%% 请求发送出去以后，如果返回 success=false 那么记录一个异常日志就可以了，这个方法无论如何都要返回 ok	
					case rfc4627:get_field(Obj,"success") of
						{ok,false} ->	
							{ok,Entity} = rfc4627:get_field(Obj,"entity"),
							?INFO_MSG("liangc-sync-user error: ~p~n",[binary_to_list(Entity)]);
						_ ->
							false
					end;
				_ -> 
					false
			end ;
        	{error, Reason} ->
			?INFO_MSG("[~ERROR~] cause ~p~n",[Reason])
    	end,
	?INFO_MSG("[--OKOKOKOK--] ~p was done.~n",[addOrRemoveFriend]),
	ok.

%roster_out_subscription(Acc, User, Server, JID, SubscriptionType, Reason) -> bool()
%roster_out_subscription_handler(Acc, User, Server, JID, SubscriptionType, Reason) ->
%	true.

%user_send_packet(From, To, Packet) -> ok
user_send_packet_handler(From, To, Packet) ->
	?INFO_MSG("~n************** my_hookhandler user_send_packet_handler >>>>>>>>>>>>>>>~p~n ",[liangchuan_debug]),
	?INFO_MSG("~n~pFrom=~p ; To=~p ; Packet=~p~n ", [liangchuan_debug,From, To, Packet] ),
	%% From={jid,"cc","test.com","Smack","cc","test.com","Smack"}
	[_,E|_] = tuple_to_list(Packet),
	{jid,_,Domain,_,_,_,_} = To,
	?DEBUG("Domain=~p ; E=~p", [Domain,E] ),
	case E of 
		"message" ->
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
			%% TODO 2014-3-4 : 在这里新建包，状态分::> new -> offline / ack
			%% 我要判断消息是不是一个聊天消息，如果是 ack 消息，则改变消息状态为 ack
			if
				ACK_FROM,MT=/=[],MT=/="msgStatus" ->
					SyncRes = gen_server:call(?MODULE,{sync_packet,new,SRC_ID_STR,Packet}),
					?DEBUG("===========> SYNC_RES new => ~p ; ID=~p",[SyncRes,SRC_ID_STR]);
				ACK_FROM,MT=:="msgStatus",T=:="normal" ->
					SyncRes = gen_server:call(?MODULE,{sync_packet,ack,SRC_ID_STR,Packet}),
					?DEBUG("===========> SYNC_RES ack => ~p ; ID=~p",[SyncRes,SRC_ID_STR]);
				true ->
					skip
			end;
			%% XXX : 这里同时要响应 服务器发给接收端的 ACK 请求，接收端的 answer 信息，在此处理
			%% 如果接收端的 answer 信息不处理，那么缺省时间后，接收端会被迫下线
			%% 2014-2-27 : 
			%% 2014-3-5 : 这里把确认机制放到外部模块来处理，此逻辑正式退役；
			%% ACK_ID = list_to_atom(SRC_ID_STR),
			%% case ejabberd_sm:ack(get,ACK_ID) of 
			%% 	{ok,PPP} ->
			%% 		?DEBUG("xxxx_send_ack_01 do ::::> ACK_ID=~p ; pid=~p ", [ACK_ID,PPP] ),
			%% 		PPP!{ack,ACK_ID};
			%% 	_ ->
			%% 		?DEBUG("xxxx_send_ack_02 skip ::::> ACK_ID=~p ", [ACK_ID] ),
			%% 		skip
			%% end;
		_ ->
			?DEBUG("~p", [skip_00] ),
			skip
	end,
	?INFO_MSG("~n************** my_hookhandler user_send_packet_handler <<<<<<<<<<<<<<<~p~n ",[liangchuan_debug]),
	ok.

user_receive_packet_handler(JID, From, To, Packet) ->
	%% 这个事件，没用，因为 session 管理本身就有 bug
	%% ?INFO_MSG("~n************** my_hookhandler user_receive_packet_handler >>>>>>>>>>>>>>>~p~n ",[liangchuan_debug]),
	%% ?DEBUG("JID=~p ; From=~p ; To=~p ; Packet=~p", [JID, From, To, Packet] ),
	%% ?INFO_MSG("~n************** my_hookhandler user_receive_packet_handler <<<<<<<<<<<<<<<~p~n ",[liangchuan_debug]),
	ok.

timestamp() ->  
	{M, S, _} = os:timestamp(),  
	M * 1000000 + S.



%% ====================================================================
%% Behavioural functions 
%% ====================================================================
-record(state, {t_host,t_port=9090}).

init([]) ->
	?INFO_MSG("INIT_START >>>>>>>>>>>>>>>>>>>>>>>> ~p",[liangchuan_debug]),  
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

		%ejabberd_hooks:add(roster_out_subscription,Host,?MODULE, roster_out_subscription_handler ,90),
		%?INFO_MSG("#### roster_out_subscription Host=~p~n",[Host])
  	  end, ?MYHOSTS),
	?INFO_MSG("INIT_END <<<<<<<<<<<<<<<<<<<<<<<<< ~p",[liangchuan_debug]),
	%% 2014-3-4 : 在这个 HOOK 初始化时，启动一个thrift 客户端，同步数据到缓存服务器
	[Domain|_] = ?MYHOSTS, 
	[{ip,THost},{port,TPort}] = ejabberd_config:get_local_option({sync_packet,Domain}),
	?INFO_MSG("========> THost=~p ; TPort=~p ",[THost,TPort]),
	%% 启动5281端口，接收内网回调
	aa_inf_server:start(),
    {ok, #state{t_host=THost,t_port=TPort}}.

%% K 是一个 string 或 binary
handle_call({sync_packet,KState,K,Packet}, From, State) ->
	%% XXX 这是一个协议，所有入库的消息，都用 bucket_时间戳-秒 为key，1秒1桶分割数据
	Index = "bucket_"++integer_to_list(timestamp()),
	%% XXX 入库数据协议是，{node(),5281,"状态",Packet} , 这个结构固定下来
	%% 其中 node() 和 5281 是回调用的
	V = term_to_binary({node(),5281,KState,Packet}),

	%% TODO 2014-3-4 ::> 这里留一个待处理问题,这个连接需要做成连接池，可以用 mnesia 或者 ets，否则效率不高
	{ok,C0} = thrift_client_util:new(State#state.t_host,State#state.t_port, ecache_thrift, []),	
	%% 插数据
	?DEBUG("==== sync_packet ===> insert key=~p",[K]),
	{C1, R1} =  thrift_client:call(C0, cmd, [["SET",K,V]]),
	%% 插索引
	%% 2014-3-6 : 因为索引会被清，所以只要改编状态就应该新建索引，旧的索引一直都会被清除
	?DEBUG("==== sync_packet ===> index key=~p",[Index]),
	{_, R2} =  thrift_client:call(C1, cmd, [["SADD",Index,K]]),
	thrift_client:close(C1),
	{reply, R1, State}.

handle_cast(Msg, State) -> {noreply, State}.
handle_info(Info, State) -> {noreply, State}.
terminate(Reason, State) -> ok.
code_change(OldVsn, State, Extra) -> {ok, State}.
%% ====================================================================
%% Internal functions
%% ====================================================================
