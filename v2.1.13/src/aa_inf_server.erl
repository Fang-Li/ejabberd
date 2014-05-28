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

process({#aaRequest{sn=SN}=Args})->
	try
		Packet = build_packet(Args#aaRequest.type,Args#aaRequest.content),
		Nodes = [node()|nodes()],
		EjabberdNodes = list_to_tuple([N||N<-Nodes,string:str(atom_to_list(N),"ejabberd")=:=1]),
		Len = tuple_size(EjabberdNodes),
		{_,Seed,_} = now(),	
		Index = (Seed rem Len)+1,
		TaskNode = element(Index,EjabberdNodes),
		?INFO_MSG("aa_info_server_process :::> SN=~p ; TaskNode=~p ; Index=~p ; Len=~p ; Seed=~p",[SN,TaskNode,Index,Len,Seed]),
		{aa_inf_server_run,TaskNode}!{push,Packet},
		"OK" 
	catch
		_:_->
			Err = erlang:get_stacktrace(),
			?ERROR_MSG("aa_info_server_process exception :::> SN=~p ; Err=~p",[SN,Err]),
			"ERROR: "++Err
	end.



run(Packet) ->
	try
		?DEBUG("aa_info_server ::: Packet ====> ~p",[Packet]),
		From = jlib:string_to_jid(xml:get_tag_attr_s("from", Packet)),
		To = jlib:string_to_jid(xml:get_tag_attr_s("to", Packet)),
		{xmlelement, "message", _Attrs, _Kids} = Packet,
		case ejabberd_router:route(From, To, Packet) of
			ok -> aa_hookhandler:user_send_packet_handler(From,To,Packet);
			Err -> "Error: "++Err
		end
	catch
		_:Clazz -> 
			?ERROR_MSG("exception :::> Packet=~p",[Packet]), 
			?ERROR_MSG("exception :::> clazz=~p ; err=~p",[Clazz,erlang:get_stacktrace()]) 
	end.

loop()->
	receive
		{push,Packet} ->
			run(Packet),
			loop();
		Other ->
			?INFO_MSG("aa_inf_server_run_Other=~p",[Other]),
			loop()
	end.

start()->
	start(5281).

start(Port)->
	try
		LoopPid = erlang:spawn(fun()-> loop() end),
		RegRtn = erlang:register(aa_inf_server_run,LoopPid),
		?INFO_MSG("aa_inf_server start looppid=~p ; reg=~p",[LoopPid,RegRtn])
	catch	
		_:_->
			?ERROR_MSG("aa_inf_server start reg_err :::> ~p",[erlang:get_stacktrace()])
	end,
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

