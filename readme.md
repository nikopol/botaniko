# botaniko 1.0

is an IRC Bot "qui plante... ou pas"
© niko - under the [artistic license](http://www.perlfoundation.org/artistic_license_1_0)
beta version.

## Features

- multi channels
- write easily your own plugins (see below and lib/botaniko/plugin/\*.pm)
- plugin twitter: management of a twitter account (retweet catched url and notice in irc its own timeline)
- plugin url: keep trace of all URLs published on a channel by indexing them in
  ElasticSearch.

## Requirements

- [ElasticSearch](http://www.elasticsearch.org/overview/#installation)
- Perl modules (see Makefile.PL)

## Quick Start

Make sure ElasticSearch is started (or add -nodb)

	#show available options
	bin/botaniko -help

	#first start
	bin/botaniko -dbinit -c=mychannel -s=myircserver -n=mybotnick -pass=mypassphrase

	#usual start
	bin/botaniko

## Core Commands

Note that all commands have to be sent to the bot, either via publics or
privates messages.

### Basics

- `help [command]`: get some help on a command
- `mute`: turn off all outputs
- `unmute`: turn on all outputs
- `uptime`
- `version`
- `search query [from=0] [count=5] [type=tweet|url|...]`: search in the DB

### Admins

These commands require an admin access, granted by sending your passphrase to
your bot: `/msg mybot mypassphrase`.

- `join #mychan`: join a channel
- `leave #mychan`: leave a channel
- `load plugin`: load a plugin
- `unload plugin`: unload a plugin
- `reload plugin`: reload a plugin
- `plugins`: list loaded plugins
- `set key [[=] value]`: get or set a configuration variable
- `quit`

## Configuration

The first time you’ll launch your bot, it’ll create a `botaniko.yml` file in the
current directory. You can then use this file to configure it, but you’ll have
to restart your bot for the changes to take effect. You may prefer to use the
`set` command to set some variables without restarting the bot.

## Plugins


### Ephemeride

Load the plugin with `load ephemeride`. You can now get some info on the current
day like in an [almanac](https://en.wikipedia.org/wiki/Almanac), or optionally
for a date given as an argument.

#### Configuration

By default, the plugin will use the latitude and longitude of Paris, France. You change this:

	set plugins.ephemeride.latitude = 48.86
	set plugins.ephemeride.longitude = 2.33

#### Commands

	ephemeride [yyy-mm-dd]


### Say

Load the plugin with `load say`. It let you make your bot say something on any
channel (you need to be admin).

#### Commands

    say <channel> <the message>


### Scraper

Load the plugin with `load scraper`. It allows you and others to capture some
text from a Web page with a regex.

#### Configuration

By default, the bot will prefix all matches with `=> `. You can change this with:

	set plugins.scraper.prefix = *

#### Commands

- `scrap name url rule`: Create or update a scrape. `name` is its name, `url` is
  the page URL, and `rule` is a regular expression. For example, here is a quick
  rule to get the number of articles in the English version of Wikipedia:

        scrap wk https://en.wikipedia.org/wiki/Special:Statistics Content pages.*?>([^<]+)</td

  This register the scrap as `wk`.
- `scrap name`. Execute a scrap (e.g. `scrap wk`).  The bot will
  print all matches (there’s only one in the example above).
- `scrap -name`. Delete the scrap known as `name`.
- `scrap`. List all recorded scraps.

### Twitter

Load the plugin with `load twitter`.

#### Configuration

This plugin needs to be configured before usage. Don’t worry, it’s easy and
you’ll have to do that only once.  First, make sure you have a Twitter account
for your bot (you may want to [create][twitter-sign-up] a dedicated one). Then,
you’ll have to create an app. Go [here][twitter-app], login with your bot’s
account, fill the required fields, and submit the form. Then, go to the
“Settings” tab and under “Application Type” check “Read and Write”. Go back
to the “Details” tab, and click on “Create my access token” at the bottom.
All you have to do now is to copy the tokens in your bot config:

	set plugins.twitter.name                = your_bot_account_name
	set plugins.twitter.consumer_key        = your_consumer_key
	set plugins.twitter.consumer_secret     = your_consumer_secret
	set plugins.twitter.access_token        = your_access_token
	set plugins.twitter.access_token_secret = your_access_token_secret

[twitter-sign-up]: https://twitter.com/signup
[twitter-app]: https://dev.twitter.com/apps/new

All the tweets from users you follow will be notified in all irc channels by default. to disable the output in a specific channel:

	set channels.mychan.plugins.twitter.echo = 0

#### Commands

- `[un]follow some_user`: (un)follow an user (requires admin access)
- `follower [regex]`: list the followers of your bot, optionally filtered by a
  regex.
  filter.
- `following [regex]`: list the accounts your bot is following, optionally
  filtered by a regex.
- `dm user message`: send a direct message.

### URL

Load the plugin with `load url`. This plugin doesn’t provide any additional
command. It watches for URLs mentionned in a chan, on Twitter or in an RSS feed,
and store them in ElasticSearch. If someone mention an URL that has already been
mentionned before, it warn the user, and print the delay between the last
mention and now. It also tweets each URL on its Twitter account if
`plugins.url.tweet_url` is set (default), and can optionally download and store
images in a local directory. You can post an old link without being warned by
using `#oldlink` in your message. You can also avoid the automatic tweet by using
`#notweet`.

#### Configuration

	#to disable user url check in a specific chan:
	set channels.mychan.plugins.url.test_url = 0
	#to disable url publication on twitter in a specific chan:
	set channels.mychan.plugins.url.tweet_url = 0
	#if an url is an image, it can be stored with the option:
	set channels.rtgi.plugins.url.store_image = /var/wwww/botaniko/images/
	set channels.rtgi.plugins.url.chmod = 0666


### Wikipedia

Load the plugin with `load wikipedia`. It adds a `wikipedia` command that can be
used to search for any subject on Wikipedia:

    wikipedia something

#### Configuration

	#change the default language
	set plugins.wikipedia.loc = en


### Meme

Load the plugin with `load meme`. This plugin allows you to make an image with a top and/or a bottom text.

#### Configuration

	#setup the path to the font to use
	set plugins.meme.font = /usr/share/fonts/TTF/DroidSans-Bold.ttf
	#setup where computed images are stored
	set plugins.meme.savedir = /var/www/meme/
	#setup rights for computed images
	set plugins.meme.chmod = 0666
	#setup the "root" urls of computed images
	set plugins.meme.geturl = http://mydomain.com/meme/
	#setup default size
	set plugins.meme.size = medium
	#setup this if meme url must be twitted
	set plugins.meme.tweet = 1

#### Commands

- `meme img=url text1[|text2] [size=small|medium|large|huge] [fontsize=size1[|size2]]`: generate a meme and return its url


### Moc

Load the plugin with `load moc`.


### RSS

Load the plugin with `load rss`. It allows you to subscribe your bot to rss feeds. News are notified in all irc channels by default.

#### Configuration

	#disable rss notification in a specific channel
	set channels.mychan.plugins.rss.echo = 0

#### Commands

- `rss add myfeed http://myfeed.com/url [user=name password=pwd]`: subscribe to a rss feed
- `rss rm myfeed`: unsubscribe
- `rss list`: list all rss feeds
- `rss read myfeed [count=5]`: read a rss feed



## Writing a plugin

you can easily setup a default configuration, hook events,
add commands, and delay/repeat code.
your plugin must be a module under `botaniko::plugin::`.
see lib/botaniko/plugin/\*.pm to see samples.

to setup a default conf:

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
		enabled => 1
	};

to read conf:

	if( chancfg($chan,'plugins.quiz.enabled') ) {
		send_channel $chan=>'quiz v'.cfg('plugins.quiz.version')
	}

to hook an event:

available event are (with given parameters):
- `CONNECT    $cnx`
- `DISCONNECT $cnx`
- `MSG        $msg,$user, $from, $chan`
- `JOIN       $chan`
- `PART       $chan`
- `QUIT       $chan`
- `USERJOIN   $user, $chan`
- `USERPART   $user, $chan, $msg`
- `USERQUIT   $user, $msg`
- `NICKCHANGE $old, $new`
- `TWEET      $msg, $user`

example:

	use botaniko::hook;
	use botaniko::irc;
	hook MSG => sub{
		my($msg,$user,$from,$chan) = @_;
		send_channel $chan => "$user: are you sure?";
	};

to add a command:

	package botaniko::plugin::calc;
	use botaniko::command;
	command calc => {
		help => 'evaluate a formula', #help for this command
		root => 0,                    #admin only ?
		bin  => sub{
			my $formula = join(' ',@_);
			$formula =~ s/[^\d\.\+\-\/\*\(\)]//g;
			my $e = eval { $formula };
			#you have to return an arrayref of strings
			#to send to the channel
			defined $e 
				? [ "result: $e" ]
				: [ pickone("unable to compute your stuff","check your syntax","what?!" ];
		}
	};

to async code:

	use botaniko 'async';
	use botaniko::irc;
	async(
		id       => 'helloworld',  #timer id
		cb       => sub{
			send_channel all=>"it's ".(scalar localtime)." !";
		},
		delay    => 0,      #delay in second before starting
		interval => 3600,   #repeat interval in seconds,
		                    #set to undef to run one time only
	);

