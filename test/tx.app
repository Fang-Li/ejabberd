{application, tx,[
	{description, "test xmpp server of ejabberd."},
  	{vsn, "0.1.0"},
  	{modules, [ 
		tx_app,
		tx_main_sup,
		tx_robot
	]},
  	{registered, [ tx_main_sup ]},
  	{applications, [kernel, stdlib]},
  	{env, []},
  	{mod, {tx_app, []}}
]}.
