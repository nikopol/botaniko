package botaniko::plugin;

use Modern::Perl;
use Class::Unload;

use botaniko::logger;
use botaniko::tools;
use botaniko::config;

use base 'Exporter';
our @EXPORT = qw(plugins plugin unplugin plugged);

our $PLUGNAME = 'core';

my %plugins;

sub plugins { sort keys %plugins }
sub plugged { shift ~~ plugins() }

sub plugin {
	$PLUGNAME = lc shift;
	$plugins{$PLUGNAME} and return error "$PLUGNAME already loaded";
	trace INFO=>"loading plugin $PLUGNAME";
	my $pm = 'botaniko/plugin/'.$PLUGNAME.'.pm';
	eval { require $pm } and return $plugins{$PLUGNAME} = 1;
	Class::Unload->unload( 'botaniko::plugin::'.$PLUGNAME );
	error "error loading $PLUGNAME : $@";
}

sub unplugin {
	my $name = lc shift;
	trace INFO=>"unloading plugin $name";
	my $pm = 'botaniko/plugin/'.$name.'.pm';
	botaniko::unasync $name;
	botaniko::hook::unhook $name;
	botaniko::command::uncommand $name;
	my $class = 'botaniko::plugin::'.$name;
	Class::Unload->unload( $class ) or return error "unable to unload $class";
	delete $plugins{$name};
}

1
