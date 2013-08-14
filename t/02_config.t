use Test::More tests => 11;
use YAML qw(LoadFile DumpFile);
use File::Temp qw(tempfile);

BEGIN { use_ok('botaniko::config'); }
use botaniko::config qw(cfg chancfg loadcfg cfg_default chancfg_default set_chan_default flatcfg);

my ($fh, $cfgfile) = tempfile(); 

my $initcfg = { a => 'b' };
my $chan = 'mychan';
my $shortkey = 'foo';
my $longkey  = 'bar.foo.qux';
my $cfgvar = 'something';

DumpFile($cfgfile => $initcfg);

# loadcfg
ok(loadcfg(config=>$cfgfile), "config file loading");

# cfg
is_deeply(cfg(), $initcfg);
is(cfg($shortkey => $cfgvar), $cfgvar, 'short key');
is(LoadFile($cfgfile)->{$shortkey}, $cfgvar);
is(cfg($longkey => $cfgvar), $cfgvar, 'long key');

# chancfg
chancfg($chan, $shortkey, $cfgvar);
is(cfg("channels.$chan.$shortkey"), $cfgvar);
chancfg("#$chan", $shortkey, 'hash');
is(cfg("channels.$chan.$shortkey"), 'hash');

# cfg_default
cfg_default($shortkey => 'foo');
is(cfg($shortkey), $cfgvar);
cfg_default('some' => 'thing');
is(cfg('some'), 'thing');

# flatcfg
is_deeply(flatcfg({foo=>{bar=>42}}, '', {}), { 'foo.bar' => 42 });
