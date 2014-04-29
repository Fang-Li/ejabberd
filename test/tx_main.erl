-module(tx_main).

-include_lib("exmpp/include/exmpp.hrl").
-include_lib("exmpp/include/exmpp_client.hrl").

-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% ====================================================================
%% API functions
%% ====================================================================
-export([
	start_link/0,
	start/1,
	talking/1
]).

-record(robot,{name,pid,send=0,recv=0}).
-record(log,{id,total,n=0}).

-record(state, {
	  session,
	  name,
	  passwd="",
	  domain="gamepro.com",
	  host="192.168.1.37",
	  port=5222,
	  n=0
}).

-define(RN,"robot-").
%% timer
-define(T,5000).

talking(N)->
	lists:foreach(fun(K)->
		[#robot{pid=Pid}] = mnesia:dirty_read(robot,K),
		gen_server:cast(Pid,{timer,Pid,N})
	end,mnesia:dirty_all_keys(robot)).

connect()->
	Robot_List = mnesia:dirty_all_keys(robot),
	log4erl:info("~p ; waiting connection counter : ~p~n",[calendar:local_time(), length(Robot_List)]),
	lists:foreach(fun(Key)->
		[Robot] = mnesia:dirty_read(robot,Key),
		log4erl:debug("Robot:::> ~p",[Robot]),
		Pid = Robot#robot.pid,
		gen_server:cast(Pid,connect)
	end,Robot_List),
	log4erl:info("~p ; all connected : ~p~n",[calendar:local_time(), length(Robot_List)]).

start(T) ->
	application:start(exmpp),
	log4erl:debug("tx_main line=~p :::> T=~p~n",[?LINE,T]),
	ID = calendar:local_time(),
	mnesia:dirty_write(#log{id=ID,total=T}),
	log4erl:debug("task begin at : ~p",[ID]),
	io:format("~p ; ~p create process begin:~p ; total=~p~n",[?FILE,?LINE,calendar:local_time(),T]),
	create_robot(0,T),
	io:format("~p ; ~p create process end:~p ; total=~p~n",[?FILE,?LINE,calendar:local_time(),T]),
	connect().
create_robot(I,Total) when I=/=Total ->
	log4erl:debug("tx_main line=~p :::> I=~p ; Total=~p~n",[?LINE,I,Total]),
	%% 启动一个可监控进程,此处回调 start_link/0 完成初始化
	{ok,Pid} = tx_main_sup:start_child(),
	log4erl:debug("PPPPPPPPPPPPPPPPP========== ~p",[Pid]),
	create_robot(I+1,Total);
create_robot(I,I)->
	ok.

start_link() ->
	try
		%% 此处回调 init/1 完成初始化
		Name = get_name(),
		{ok,Pid} = gen_server:start_link(?MODULE,[Name],[]),
		mnesia:dirty_write(#robot{name=Name,pid=Pid}),
		log4erl:debug("-- file=~p;line=~p;name=~p;pid=~p --",[?FILE,?LINE,Name,Pid]),
		{ok,Pid}
	catch
		_:X ->
			Exception = {X,erlang:get_stacktrace()},
			log4erl:error("ERROR ::> ~p",[Exception]),
			{error,Exception}
	end.

get_name()->
	{I1,I2,I3}=os:timestamp(),
	?RN++integer_to_list(I1)++integer_to_list(I2)++integer_to_list(I3).

login(Name,I)->
	State = #state{},
	#state{domain=Domain,host=Host,passwd=Passwd,port=Port}=State,
	try
		MySession = exmpp_session:start(),
		MyJID = exmpp_jid:make(Name,Domain),
		%% Method = password | digest | "PLAIN" | "ANONYMOUS" | "DIGEST-MD5" | string()
		exmpp_session:auth_method(MySession,"PLAIN"),		
		exmpp_session:auth_basic(MySession,MyJID,Passwd),
		{ok,_StreamId} = exmpp_session:connect_TCP(MySession,Host,Port,[{timeout,120*1000}]),	
		exmpp_session:login(MySession),
		Presence = exmpp_presence:set_status(exmpp_presence:available(),"Echo Ready"),
		exmpp_session:send_packet(MySession,Presence),
		log4erl:debug("start tx_main ok :::>Name=~p; login and presence",[Name]),
		{ok,State#state{session=MySession,name=Name}}
	catch
		ERR:INFO ->
			log4erl:error("LOGIN:::> ERR=~p,INFO=~p,STACK=~p",[ERR,INFO,erlang:get_stacktrace()]),	
			case I>5 of
				true ->
					[Robot] = mnesia:dirty_read(robot,Name),
					gen_server:cast(Robot#robot.pid,stop);
				_ ->
					timer:sleep(1000),
					log4erl:info("relogin ::::> Name=~p,I=~p",[Name,I]),
					login(Name,I+1)
			end
			
	end.

%% ====================================================================
%% Behavioural functions 
%% ====================================================================

%% init/1
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:init-1">gen_server:init/1</a>
-spec init(Args :: term()) -> Result when
	Result :: {ok, State} | {ok, State, Timeout} | {ok, State, hibernate} | {stop, Reason :: term()} | ignore,
	State :: term(),
	Timeout :: non_neg_integer() | infinity.
%% ====================================================================
init([Name|L]) ->
	{ok,#state{name=Name}}.
	%%login(Name).
%%loop(MSession)->
%%	receive 
%%		stop ->
%%			ok;
%%		Record ->
%%			log4erl:debug("Record ::::> ~p",[Record]),
%%			loop(MSession)
%%	after 5000 ->
%%			log4erl:debug("hert beat ..."),
%%		      	loop(MSession)
%%	end.


%% handle_call/3
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:handle_call-3">gen_server:handle_call/3</a>
-spec handle_call(Request :: term(), From :: {pid(), Tag :: term()}, State :: term()) -> Result when
	Result :: 	  {reply, Reply, NewState}
			| {reply, Reply, NewState, Timeout}
			| {reply, Reply, NewState, hibernate}
			| {noreply, NewState}
			| {noreply, NewState, Timeout}
			| {noreply, NewState, hibernate}
			| {stop, Reason, Reply, NewState}
			| {stop, Reason, NewState},
	Reply :: term(),
	NewState :: term(),
	Timeout :: non_neg_integer() | infinity,
	Reason :: term().
%% ====================================================================
handle_call(Request, From, State) ->
    Reply = ok,
    {reply, Reply, State}.


%% handle_cast/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:handle_cast-2">gen_server:handle_cast/2</a>
-spec handle_cast(Request :: term(), State :: term()) -> Result when
	Result :: {noreply, NewState}
			| {noreply, NewState, Timeout}
			| {noreply, NewState, hibernate}
			| {stop, Reason :: term(), NewState},
	NewState :: term(),
	Timeout :: non_neg_integer() | infinity.
%% ====================================================================
handle_cast(connect, State) ->
	log4erl:debug("Connect ::>~p",[State]),
	{ok,S} = login(State#state.name,0),
	{noreply, S};
%% 在这里完成定时
handle_cast({timer,Pid,N}, State) ->
	gen_server:cast(Pid,{loop,Pid,0}),		
	{noreply, State#state{n=N}};
handle_cast({loop,Pid,NUM}, State) ->
	timer:sleep(?T),
	%% TODO 在这判断是否有必要执行新的任务
	All = mnesia:dirty_all_keys(robot),
	Len = length(All),
	Num = case Len of
		L when L > 1 ->
			{I1,I2,I3} = os:timestamp(),
			Str = integer_to_list(I1)++integer_to_list(I2)++integer_to_list(I3),
			I = ( list_to_integer(Str) rem L )+1,
			case element(I,list_to_tuple(All)) of 
				Target when Target=/=State#state.name ->
					Domain = State#state.domain,
					{jid,From,_,_,_} = exmpp_jid:make(State#state.name,Domain),
					{jid,To,_,_,_}   = exmpp_jid:make(Target,Domain),
					Message0 = exmpp_message:chat("Hello girls ,are free tonight"),
					Message1 = exmpp_xml:set_attribute(Message0, <<"from">>, From),
					Message2 = exmpp_xml:set_attribute(Message1, <<"to">>, To),
					Message3 = exmpp_xml:set_attribute(Message2, <<"id">>, Str),
					Message4 = exmpp_xml:set_attribute(Message3, <<"msgtype">>, "normalchat"),
					Message5 = exmpp_xml:set_attribute(Message4, <<"type">>, "chat"),
					log4erl:debug("SEND==~p",[Message5]),
					exmpp_session:send_packet(State#state.session,Message5),
					log4erl:info("SEND ::::> ID=~p",[Str]),
					F = fun()->
						[Robot] = mnesia:read(robot,State#state.name),
						Send = Robot#robot.send,	
						mnesia:write(Robot#robot{send=(Send+1)})
					end,
					mnesia:transaction(F),
					NUM+1;
				_ ->
					NUM
			end;
		_ ->
			NUM
	end,
	case State#state.n of
		0 ->
			gen_server:cast(Pid,{loop,Pid,Num});	
		X ->
			case X > Num of
				true ->
					gen_server:cast(Pid,{loop,Pid,Num});
				_ ->
					skip
			end
	end,
	{noreply, State};

handle_cast(stop, State) ->
	{stop, normal, State}.


%% handle_info/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:handle_info-2">gen_server:handle_info/2</a>
-spec handle_info(Info :: timeout | term(), State :: term()) -> Result when
	Result :: {noreply, NewState}
			| {noreply, NewState, Timeout}
			| {noreply, NewState, hibernate}
			| {stop, Reason :: term(), NewState},
	NewState :: term(),
	Timeout :: non_neg_integer() | infinity.
%% ====================================================================
handle_info(Record=#received_packet{packet_type=message,raw_packet=Packet,type_attr=Type}, State) when Type=/= "error" ->
	log4erl:debug("Message=~p",[Packet]),
	From = exmpp_xml:get_attribute(Packet, <<"to">>, <<"unknown">>),
	To = exmpp_xml:get_attribute(Packet, <<"from">>, <<"unknown">>),
	Id = exmpp_xml:get_attribute(Packet, <<"id">>, <<"unknown">>),
	log4erl:info("RECEIVE::> ID=~p",[Id]),
	%% TODO 先测收和发的效率问题
	%% case exmpp_xml:get_attribute(Packet, <<"msgtype">>, <<"unknow">>) of
	%% 	<<"normalchat">> ->
	%% 		Message0 = exmpp_message:chat("fine"),
	%% 		Message1 = exmpp_xml:set_attribute(Message0, <<"from">>, From),
	%% 		Message2 = exmpp_xml:set_attribute(Message1, <<"to">>, To),
	%% 		Message3 = exmpp_xml:set_attribute(Message2, <<"id">>, Id),
	%% 		Message4 = exmpp_xml:set_attribute(Message3, <<"msgtype">>, "msgStatus"),
	%% 		Message5 = exmpp_xml:set_attribute(Message4, <<"type">>, "normal"),
	%% 		log4erl:debug("ACK==~p",[Message5]),
	%% 		exmpp_session:send_packet(State#state.session,Message5);
	%% 	_Other ->
	%% 		skip
	%% 		%% log4erl:debug("revice message : msgtype=~p",[_Other])
	%% end,
	%% <message id='10001' from='y@y.y' to='x@x.x' msgtype='msgStatus' type='normal'>...</message>
	F = fun()->
		[Robot] = mnesia:read(robot,State#state.name),
		%% log4erl:info("TTTTTTTTTT name=~p,Robot=~p",[State#state.name,Robot]),
		Recv = Robot#robot.recv,	
		mnesia:write(Robot#robot{recv=(Recv+1)})
	end,
	mnesia:transaction(F),
    	{noreply, State};
handle_info(Record,State) when Record#received_packet.packet_type =/= 'message' ->
	log4erl:debug("Record=~p",[Record]),
	{noreply,State};
handle_info({'EXIT',Pid,Why},State)->
	log4erl:info("[EEEE] {'EXIT',Pid,Why,name}=~p",[{'EXIT',Pid,Why,State#state.name}]),
	{noreply,State}.


%% terminate/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:terminate-2">gen_server:terminate/2</a>
-spec terminate(Reason, State :: term()) -> Any :: term() when
	Reason :: normal
			| shutdown
			| {shutdown, term()}
			| term().
%% ====================================================================
terminate(Reason, State) ->
    ok.


%% code_change/3
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:code_change-3">gen_server:code_change/3</a>
-spec code_change(OldVsn, State :: term(), Extra :: term()) -> Result when
	Result :: {ok, NewState :: term()} | {error, Reason :: term()},
	OldVsn :: Vsn | {down, Vsn},
	Vsn :: term().
%% ====================================================================
code_change(OldVsn, State, Extra) ->
    {ok, State}.


%% ====================================================================
%% Internal functions
%% ====================================================================


