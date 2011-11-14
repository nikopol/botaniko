package botaniko::file;

use Modern::Perl;
use YAML::XS qw(DumpFile LoadFile);

use base 'Exporter';
our @EXPORT = qw(file);

sub file {
	my( $file, $data ) = @_;
	defined( $data )
		? DumpFile( $file => $data )
		: LoadFile( $file ) or {}
}

1
