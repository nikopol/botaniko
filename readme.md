botaniko
========

is an IRC Bot "qui plante... ou pas"  
(c) niko - under the [artistic license](http://www.perlfoundation.org/artistic_license_1_0)  
alpha version.  

features
--------

- multi channels
- write easily your own plugins (see below and lib/botaniko/plugin/*.pm)
- plugin twitter : management of a twitter account (retweet catched url and notice in irc its own timeline)
- plugin url : keep trace of all url indexing them

requires
--------

- elasticsearch
- perl modules

quick start
-----------
make sure elasticsearch is started

	#show available options
	bin/botaniko -help 

	#first start
	bin/botaniko -dbinit -c=mychannel -s=myircserver -n=mybotnick -pass=mypassphrase

	#usual start
	bin/botaniko

core commands
-------------

basics:

	- help [command]
	- mute                : turn off all outputs'
	- uptime
	- version
	- search query [from=0] [count=5] [type=tweet|url|...] : search from db
	- unmute              : turn on all outputs

admins: (requires admin access, granted by /msg mybot passphrase)

	- join #mychan        : join channels
	- leave #mychan       : leave channels
	- load plugin         : try to load one or more plugins
	- plugins             : list loaded plugins
	- quit
	- set variable [[=] value] : get or set a configuration variable
	- unload plugin [plugin [...]] : unload one or more plugin

plugin twitter commands
-----------------------

	- follow tweetos
	- follower [regex]              : list followers
	- following [regex]             : list following
	- unfollow tweetos

writing a plugin
----------------

you can easyly setup a default configuration, hook events, 
add commands, and delay/repeat code.  
your plugin must be a module under botaniko::plugin::  
see lib/botaniko/plugin/*.pm to see samples.  

to setup a default conf :

	use botaniko::config;
	#global config
	cfg_default 'plugins.quiz' => {
		version => 1
		quiz    => [
			{ query=>'what is the answer?', answer=>42 }
		]
	};
	#per channel config
	chancfg_default 'plugins.quiz' => {
		playable => 1
	};

to read conf :

	if( chancfg($chan,'plugins.quiz.playable') ) {
		send_channel $chan=>'quiz v'.cfg 'plugins.quiz.version'
	}

to hook an event:

available event are (with given parameters):  
- CONNECT    $cnx  
- DISCONNECT $cnx  
- MSG        $msg,$user,$from,$chan  
- JOIN       $chan  
- QUIT       $chan  
- USERJOIN   $user,$chan  
- USERQUIT   $user,$msg  
- NICKCHANGE $old,$new  
- TWEET      $msg,$user  

	use botaniko::hook;
	use botaniko::irc;
	hook MSG=>sub{
		my($msg,$user,$from,$chan) = @_;
		send_channel $chan => "$user: are you sure?";
	};

to add a command:

	use botaniko::command;
	command time=>{
		help =>"display time",
		root => 0,
		bin=>sub{ [ scalar localtime ] }
	};

to async code:

	use botaniko 'async';
	use botaniko::irc;
	async(
		id       => 'helloworld',
		cb       => sub{ send_channel all=>'hello world!' },
		delay    => 20,
		interval => undef
	);

