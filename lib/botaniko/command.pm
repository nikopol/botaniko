package botaniko::command;

use strict;
use warnings;
use 5.010;
use Digest::SHA1 'sha1_hex';

use botaniko::logger;
use botaniko::config;
use botaniko::plugin;
use botaniko::tools;
use botaniko::irc;

use base 'Exporter';
our @EXPORT = qw(run command);

my $startime = time;

my $commands;
$commands = {
	channels => {
		help => 'channels : list channels',
		root => 1,
		bin  => sub {
			[ channels() ]
		}
	},
	help => {
		help => 'help [command]',
		bin  => sub {
			my( $root, $c ) = @_;
			my $out = [];
			my @cmds = grep { $_ && ($root || !$commands->{$_}->{root}) } sort keys %$commands;
			if( $c ) {
				push @$out, ($c ~~ @cmds) ? $commands->{$c}->{help}||'no help' : 'unknown command'
			} else {
				push( @$out, join(',', splice(@cmds,0,4>@cmds?scalar @cmds:6)) ) while @cmds;
			}
			$out
		}
	},
	join => {
		help => 'join #chan : join a channel',
		root => 1,
		bin  => sub {
			my $chan = shift;
			return ['what channel ?'] unless $chan;
			$chan = '#'.$chan unless $chan =~ m/^#/;
			my @chans = channels;
			return ['i am already in '.$chan] if $chan ~~ @chans;
			join_channel $chan;
			my $auto = cfg 'autojoin';
			$auto = [ $auto ] unless ref($auto) eq 'ARRAY';
			unless( $chan ~~ @$auto ) {
				push @$auto, $chan;
				cfg autojoin=>$auto;
			}
			['joining '.$chan]
		}
	},
	leave => {
		help => 'leave #chan : leave a channels',
		root => 1,
		bin  => sub {
			my $chan = shift;
			return ['what channel ?'] unless $chan;
			$chan = '#'.$chan unless $chan =~ m/^#/;
			my @chans = channels;
			return ['i am not in '.$chan] unless $chan ~~ @chans;
			leave_channel $chan;
			my $auto = cfg 'autojoin';
			$auto = [ $auto ] unless ref($auto) eq 'ARRAY';
			$auto = [ grep { $_ ne $chan } @$auto ];
			cfg autojoin=>$auto;
			['leaving '.$chan]
		}
	},
	load => {
		help => 'load plugin [plugin [...]] : try to load one or more plugins',
		root => 1,
		bin  => sub {
			my $out = [];
			my $auto = cfg 'autoload';
			$auto = [ $auto ] unless ref($auto) eq 'ARRAY';
			for( @_ ) {
				if( plugin $_ ) {
					push @$out, "$_ loaded";
					push( @$auto, $_ ) unless $_ ~~ @$auto;
				} else {
					push @$out, $@;
				}
			}
			cfg autoload=>$auto;
			$out
		}
	},
	mute => {
		help => 'mute : turn off all outputs',
		bin  => sub {
			cfg mute=>1;
			['muted']
		}
	},
	plugins => {
		help => 'plugins : list loaded plugins',
		bin  => sub {
			[ 'loaded plugins: '.join(',',plugins()) ]
		}
	},
	quit => {
		help => 'quit',
		root => 1,
		bin  => sub {
			$botaniko::w->send('user command');
			[pickone(
				'bye',
				'hasta la vista baby!',
				'so long and thanks for the fishes :)',
			)]
		}
	},
	search => {
		help => 'search query [from=0] [count=5] [type=tweet|url|...] : search from db',
		bin  => sub {
			return unless @_;
			my $out = [];
			my @arg;
			my $from = 0;
			my $size = 5;
			my $type;
			for( @_ ) { 
				if( m/^from[:=](\d+)/i )     { $from=0+$1 }
				elsif( m/^count[:=](\d+)/i ) { $size=0+$1 }
				elsif( m/^type[:=](\S+)/i )  { $type=lc $1 }
				else { push @arg, $_ }
			}
			my $qry = join(' ',@arg);
			$qry =~ s/^\s+|\s+$//g;
			return unless $qry;
			$size = 5 if $size<0 || $size>10;
			$from = 0 if $from<0;
			my $r = eval{ dbsearch( $type, $qry, $from, $size ) };
			if( $r && $r->{hits}->{total} ) {
				my $n = $from;
				push( @$out, '#'.($n++).' '.$_->{_source}->{date}.' @'.$_->{_source}->{name}.': '.$_->{_source}->{text} )
					for @{$r->{hits}->{hits}};
				push @$out, '... '.$r->{hits}->{total}.' matches';
			}
			$out
		}
	},
	set => {
		help => 'set variable [value] : get or set a configuration setting',
		root => 1,
		bin  => sub {
			my $k = shift;
			shift @_ if @_ && $_[0] eq '=';
			my $v = @_ ? join(' ',@_) : undef;
			my $regex = $k ? qr/$k/i : qr/./;
			my $cfg = flatcfg;
			my $r = [ sort grep { $_ =~ $regex } keys %$cfg ];
			return [ 'unknown variable' ] unless @$r;
			if( defined $v && 1 == @$r ) {
				$v = 1 if lc($v) eq 'true'  || lc($v) eq 'on';
				$v = 0 if lc($v) eq 'false' || lc($v) eq 'off';
				my $cur = cfg($k);
				if( $cur && ref($cur) eq 'ARRAY' ) {
					$v = map { s/(^\s+|\s+$)//g } split /,/,$v
				}
				$v = sha1_hex($v) if $k eq 'passphrase';
				cfg $k=>$v;
			}
			my %set;
			my $len = 0;
			for( @$r ) {
				$v = $_ =~ /passphrase|secret/ ? ('*' x length($cfg->{$_})) : cfg($_);
				$v .= ' ('.delay(cfg($_)).')' if /^records\..+\.score$/;
				$set{$_} = $v;
				$len = length($_) if length($_) > $len;
			};
			my $out = [];
			push( @$out, substr((' ' x $len).$_,-$len).' = '.(defined $set{$_} ? $set{$_} : 'undefined' ))
				for sort keys %set;
			@$out ? trunc( $out, 10 ) : [ '...no match' ]
		}
	},
	unload => {
		help => 'unload plugin [plugin [...]] : unload one or more plugin',
		root => 1,
		bin  => sub {
			my $out = [];
			my $auto = cfg 'autoload';
			$auto = [ $auto ] unless ref($auto) eq 'ARRAY';
			for my $p ( @_ ) {
				if( unplugin $p ) {
					push @$out, "$p unloaded";
					$auto = [ grep { $p ne $_ } @$auto ];
				} else {
					push @$out, $@;
				}
			}
			cfg autoload=>$auto;
			$out
		}
	},
	unmute => {
		help => 'unmute : turn on all outputs',
		bin  => sub {
			cfg mute=>0;
			['unmuted']
		}
	},
	uptime => {
		help => 'uptime : this session delay',
		bin  => sub { [delay(time-$startime)] }
	},
	version => {
		help => 'version',
		bin  => sub { [ 'BoTaNiK v'.$botaniko::VERSION.' - le bot qui plante ... ou pas' ] }
	},
};


sub command {
	my %list = @_;
	my $plug = $botaniko::plugin::PLUGNAME;
	for( keys %list ) {
		if( exists $commands->{$_} ) {
			trace ERROR=>'command '.$_.' for '.$plug.' already defined';
		} else {
			trace DEBUG=>'adding command '.$_.' for '.$plug;
			my $h = ref($list{$_}) eq 'CODE'
				? { bin=>$list{$_}, help=>'not defined' }
				: $list{$_};
			$commands->{$_} = { %$h, plugin=>$plug };
		}
	}
}

sub uncommand {
	my $plug = shift;
	for( keys %$commands ) {
		if( $commands->{$_}->{plugin} && $commands->{$_}->{plugin} eq $plug ) {
			trace DEBUG=>'remove command '.$_.' for '.$commands->{$_}->{plugin};
			delete $commands->{$_};
		}
	}
}

sub run {
	my( $nick, $from, $what ) = @_;
	$what =~ s/^\s+|\s+$//g;
	my @out;
	if( $what ) {
		trace INFO=>"$nick want $what";
		my @args = split /\s/,$what;
		my $c = shift @args;
		if( $c && exists $commands->{$c} ) {
			if( my $bin = $commands->{$c}->{bin} ) {
				if( $commands->{$c}->{root} && !admin($from) ) {
					push @out,pickone(
						'you are not my master',
						'who do you think you are to ask me that ?',
						'mouhahhaha, dream about it',
						'if you say so',
					)
				} elsif( $c eq 'help' ) {
					@out    = @{ &$bin(admin($from),@args) };
				} else {
					my $hlp = $commands->{help}->{bin};
					my $r   = &$bin(@args);
					@out    = $r ? @$r : ( &$hlp(admin($from),$c) );
				}
			} else {
				trace ERROR=>"no bin provided for command $c";
				push @out, "command got no code";
			}
		} else {
			push @out,pickone(
				'what?!',
				'could you be more explicit ?',
				"you re talking to me ?",
				'this is not implemented yet',
				'what do you mean ?',
			)
		}
	}
	trace( DEBUG=>$_ ) for @out;
	@out
}

