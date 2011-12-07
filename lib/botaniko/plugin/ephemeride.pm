#package botaniko::plugin::ephemeride;

use strict;
use warnings;
use 5.010;
use Astro::Sunrise;
use Time::Timezone;

use botaniko::config;
use botaniko::logger;
use botaniko::command;

cfg_default 'plugins.ephemeride' => {
	latitude  => 48.86, #paris/fr
	longitude => 2.33,
};

command ephemeride => {
	help => 'ephemeride [yyyy-mm-dd]',
	root => 0,
	bin  => sub {
		my($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
		if( @_ && shift =~ m|^(\d{4})[-/]?(\d{2})[-/]?(\d{2})$| ) {
			$year = $1;
			$mon  = $2;
			$mday = $3;
		} else {
			$year += 1900;
		}
		my $offset = tz_local_offset()/3600;
		my($sunrise,$sunset) = sunrise(
			$year,
			$mon,
			$mday,
			cfg('plugins.ephemeride.longitude'),
			cfg('plugins.ephemeride.latitude'),
			$offset
		);
		[ 'for the '.$year.'-'.$mon.'-'.$mday.', the sunrise is at '.$sunrise.' and the sunset at '.$sunset ]
	}
};

1
