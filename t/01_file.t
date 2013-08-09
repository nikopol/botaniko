use Test::More tests => 4;
use File::Temp qw(tempfile);

BEGIN { use_ok('botaniko::file'); }
use botaniko::file qw(file);

my ($fh, $fn) = tempfile(); 
my $data = {
    foo => [ 1, 2, 3 ],
    bar => {
        some => { deep => 'stuff' }
    }
};

ok(file($fn, $data), 'data dumping');
is_deeply(file($fn), $data, 'data loading');
truncate $fh, 0;
is_deeply(file($fn), {}, 'empty file');
