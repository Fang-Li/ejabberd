-module(aa_group_chat).

-include("ejabberd.hrl").
-include("jlib.hrl").

-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-define(HTTP_HEAD,"application/x-www-form-urlencoded").

%% ====================================================================
%% API functions
%% ====================================================================
-export([
	start_link/0,
	route_group_msg/3,
	is_group_chat/1
]).

-record(state, {}).

start() ->
	aa_group_chat_sup:start_child().

stop(Pid)->
	gen_server:cast(Pid,stop).

start_link() ->
	gen_server:start_link(?MODULE,[],[]).

route_group_msg(From,To,Packet)->
	{ok,Pid} = start(),
	?DEBUG("###### route_group_msg_001 ::::> {From,To,Packet}=~p",[{From,To,Packet}]),
	gen_server:call(Pid,{route_group_msg,From,To,Packet}),
	stop(Pid).

%% ====================================================================
%% Behavioural functions 
%% ====================================================================
init([]) ->
	{ok,#state{}}.

handle_call({route_group_msg,#jid{server=Domain}=From,#jid{user=GroupId}=To,Packet}, _From, State) ->
	case get_user_list_by_group_id(Domain,GroupId) of 
		{ok,UserList} ->
			%% -record(jid, {user, server, resource, luser, lserver, lresource}).
			Roster = lists:map(fun(User)-> 
				UID = binary_to_list(User),
				#jid{user=UID,server=Domain,luser=UID,lserver=Domain,resource=[],lresource=[]} 
			end,UserList),
			?DEBUG("###### route_group_msg 002 :::> GroupId=~p ; Roster=~p",[GroupId,Roster]),
			lists:foreach(fun(Target)-> route_msg(From,Target,Packet,GroupId) end,Roster);
		Err ->
			error
	end,	
	{reply,[],State}.

handle_cast(stop, State) ->
	{stop, normal, State}.

handle_info({cmd,Args},State)->
	{noreply,State}.

terminate(Reason, State) ->
    ok.
code_change(OldVsn, State, Extra) ->
    {ok, State}.

%% ====================================================================
%% Internal functions
%% ====================================================================
get_user_list_by_group_id(Domain,GroupId)->
	?DEBUG("###### get_user_list_by_group_id :::> GroupId=~p",[GroupId]),
 	HTTPTarget =  ejabberd_config:get_local_option({http_server,Domain}),
	{Service,Method,GID,SN} = {
			list_to_binary("service.groupchat"),
			list_to_binary("getUserList"),
			list_to_binary(GroupId),
			list_to_binary(os:cmd("uuidgen")--"\n")
	},
	ParamObj={obj,[ {"sn",SN},{"service",Service},{"method",Method},{"params",{obj,[{"groupId",GID}]} } ]},
	Form = "body="++rfc4627:encode(ParamObj),
	?DEBUG("###### get_user_list_by_group_id :::> HTTP_TARGET=~p ; request=~p",[HTTPTarget,Form]),
	try
		case httpc:request(post,{ HTTPTarget ,[], ?HTTP_HEAD , Form },[],[] ) of   
	        	{ok, {_,_,Body}} ->
				DBody = rfc4627:decode(Body),
				{_,Log,_} = DBody,
				?DEBUG("###### get_user_list_by_group_id :::> response=~p",[rfc4627:encode(Log)]),
	 			case DBody of
	 				{ok,Obj,_Re} -> 
						case rfc4627:get_field(Obj,"success") of
							{ok,true} ->
								{ok,Entity} = rfc4627:get_field(Obj,"entity"),
								?DEBUG("###### get_user_list_by_group_id :::> entity=~p",[Entity]),
								{ok,Entity};
							_ ->
								{ok,Entity} = rfc4627:get_field(Obj,"entity"),
								{fail,Entity}
						end;
	 				Error -> 
						{error,Error}
	 			end ;
	        	{error, Reason} ->
	 			?INFO_MSG("[ ERROR ] cause ~p~n",[Reason]),
				{error,Reason}
		end
	catch
		_:_->
			%% TODO 测试时，可以先固定组内成员
			{ok,[<<"e1">>,<<"e2">>,<<"e3">>]}
	end.

route_msg(#jid{user=FromUser}=From,#jid{user=User,server=Domain}=To,Packet,GroupId) ->
	case FromUser=/=User of
		true->
			{X,E,Attr,Body} = Packet,
			ID = os:cmd("uuidgen")--"\n",
			?DEBUG("##### route_group_msg_003 param :::> {User,Domain,GroupId}=~p",[{User,Domain,GroupId}]),
			RAttr0 = lists:map(fun({K,V})-> 
				case K of 
					"to" -> {K,User++"@"++Domain}; 
					"id" -> {K,ID};	
					"msgtype" -> {K,"groupchat"};	
					_-> {K,V} 
				end 
			end,Attr),
			RAttr1 = lists:append(RAttr0,[{"groupid",GroupId}]),
			RPacket = {X,E,RAttr1,Body},
			?DEBUG("###### route_group_msg 003 input :::> {From,To,RPacket}=~p",[{From,To,RPacket}]),
			case ejabberd_router:route(From, To, RPacket) of
				ok ->
					?DEBUG("###### route_group_msg 003 OK :::> {From,To,RPacket}=~p",[{From,To,RPacket}]),
					aa_hookhandler:user_send_packet_handler(From,To,RPacket),
					{ok,ok};
				Err ->
					?DEBUG("###### route_group_msg 003 ERR=~p :::> {From,To,RPacket}=~p",[Err,{From,To,RPacket}]),
					{error,Err}
			end;
		_ ->
			{ok,skip}
	end.

is_group_chat(#jid{server=Domain}=To)->
	DomainTokens = string:tokens(Domain,"."),
	Rtn = case length(DomainTokens) > 2 of 
		true ->
			[G|_] = DomainTokens,
			G=:="group";
		_ ->
			false
	end,
	?DEBUG("##### is_group_chat ::::>To~p ; Rtn=~p",[To,Rtn]),
	Rtn.