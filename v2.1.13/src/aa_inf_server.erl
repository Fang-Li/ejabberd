-module(aa_inf_server).

-include("aa_inf_thrift.hrl").
-include("aa_inf_types.hrl").
-include("ejabberd.hrl").
-include("jlib.hrl").
-include_lib("xmerl/include/xmerl.hrl").

-export([start/0, handle_function/2, process/1, stop/1]).
-record(session, {sid, usr, us, priority, info}).


build_packet(<<"xml">>,Content)->
	xml_stream:parse_element(binary_to_list(Content));
build_packet(<<"term">>,Content)->
	{_,_,_,Packet}=binary_to_term(Content),
	Packet.

process({Args})->
	try
		Nodes = list_to_tuple([node()|nodes()]),
		Len = tuple_size(Nodes),
		{_,Seed,_} = now(),	
		Index = (Seed rem Len)+1,
		TaskNode = element(Index,Nodes),
		{aa_inf_server_run,TaskNode}!{push,Args},
		"OK" 
	catch
		_:_->
			Err = erlang:get_stacktrace(),
			"ERROR: "++Err
	end.



run(Args) ->
	try
		?DEBUG("aa_info_server ::: Args ====> ~p",[Args]),
		Packet = build_packet(Args#aaRequest.type,Args#aaRequest.content),
		?DEBUG("aa_info_server ::: Packet ====> ~p",[Packet]),
		From = jlib:string_to_jid(xml:get_tag_attr_s("from", Packet)),
		To = jlib:string_to_jid(xml:get_tag_attr_s("to", Packet)),
		{xmlelement, "message", _Attrs, _Kids} = Packet,
		case ejabberd_router:route(From, To, Packet) of
		    ok -> 
				aa_hookhandler:user_send_packet_handler(From,To,Packet),
				"OK";
    			%%	LUser = To#jid.luser,
    			%%	LServer = To#jid.lserver,
    			%%	PrioRes = get_user_present_resources(LUser, LServer),
			%%	aa_hookhandler:user_send_packet_handler(From,To,Packet),
    			%%	case catch lists:max(PrioRes) of
			%%		{Priority, _R} when is_integer(Priority), Priority >= 0 ->
			%%			%% 在线消息
			%%			"online: "++LUser;
			%%		_ ->
			%%			%% 离线消息
			%%			%% aa_hookhandler:offline_message_hook_handler(From,To,Packet),
			%%			"offline: "++LUser
			%%	end;
		    Err -> "Error: "++Err
		end
	catch
		error:{badmatch, _} -> 
			?INFO_MSG("exception :::> ~p",[erlang:get_stacktrace()]),
			"Error: can only accept <message/>";
		error:{Reason, _} -> 
			?INFO_MSG("exception :::> ~p",[erlang:get_stacktrace()]),
			"Error: " ++ atom_to_list(Reason)
	end.

loop()->
	receive
		{push,Args} ->
			run(Args),
			loop();
		Other ->
			?INFO_MSG("aa_inf_server_run_Other=~p",[Other]),
			loop()
	end.

start()->
	start(5281).

start(Port)->
	LoopPid = erlang:spawn(fun()-> loop() end),
	erlang:register(aa_inf_server_run,LoopPid),
	Handler = ?MODULE,
	?INFO_MSG("aa_inf_server start on ~p port, Handler=~p",[Port,Handler]),
	thrift_socket_server:start([{handler, Handler},
				    {service, aa_inf_thrift},
				    {port, Port},
				    {name, aa_inf_server}]).


stop(Server)->
	thrift_socket_server:stop(Server).

handle_function(Function, Args) ->
	case Function of
		process ->
			{reply, process(Args)};
		_ ->
			error
	end.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% 在 ejabberd_sm 模块移植的方法
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
get_user_present_resources(LUser, LServer) ->
    US = {LUser, LServer},
    case catch mnesia:dirty_index_read(session, US, #session.us) of
		{'EXIT', _Reason} ->
		    [];
		Ss ->
		    [{S#session.priority, element(3, S#session.usr)} || S <- clean_session_list(Ss), is_integer(S#session.priority)]
    end.

clean_session_list(Ss) ->
    clean_session_list(lists:keysort(#session.usr, Ss), []).

clean_session_list([], Res) ->
    Res;
clean_session_list([S], Res) ->
    [S | Res];
clean_session_list([S1, S2 | Rest], Res) ->
    if
	S1#session.usr == S2#session.usr ->
	    if
		S1#session.sid > S2#session.sid ->
		    clean_session_list([S1 | Rest], Res);
		true ->
		    clean_session_list([S2 | Rest], Res)
	    end;
	true ->
	    clean_session_list([S2 | Rest], [S1 | Res])
    end.

