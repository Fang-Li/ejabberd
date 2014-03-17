-module(aa_session).
-export([
	find/1	
]).
-record(session, {sid, usr, us, priority, info}).


find(Username)->
	Keys = mnesia:dirty_all_keys(session),
	lists:foreach(fun(K)->
		[Session] = mnesia:dirty_read(session,K),
		{U,_} = Session#session.us,
		case Username=:=U of 
			true->
				io:format("~p~n",[Session]);
			false->
				skip
		end
	end,Keys).
