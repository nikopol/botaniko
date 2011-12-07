package botaniko::db;

use strict;
use warnings;
use 5.010;
use POSIX 'strftime';
use ElasticSearch;

use botaniko::config;
use botaniko::logger;

use constant IDXNAME=>'botaniko';

use base 'Exporter';
our @EXPORT = qw(dbinit dbindex dbsearch dbsearchterm);

my $es;

sub dbinit {
	return trace( ERROR=>'db elasticsearch is not configured' )
		unless my $cfg = cfg 'db';
	return trace( ERROR=>'db elasticsearch disabled' )
		if delete $cfg->{disabled};

	my $MAPPINGS = {
		url => { properties => {
			date    => { type=>'date', format=>'yyyy-MM-dd HH:mm:ss' },
			name    => { type=>'string', index=>'not_analyzed' },
			url     => { type=>'string', index=>'not_analyzed' },
			text    => { type=>'string' },
			meta    => { type=>'string' },
			title   => { type=>'string' },
			chan    => { type=>'string', index=>'not_analyzed' },
			from    => { type=>'string', index=>'not_analyzed' },
		} },
		tweet => { properties => {
			date    => { type=>'date', format=>'yyyy-MM-dd HH:mm:ss' },
			name    => { type=>'string', index=>'not_analyzed' },
			text    => { type=>'string' },
			meta    => { type=>'string' },
			created => { type=>'string', index=>'not_analyzed' },
		} },
	};

	my $init  = delete $cfg->{init};
	my $reidx = delete $cfg->{reindex};
	my $optim = delete $cfg->{optimize};
	$es  = ElasticSearch->new( %$cfg );
	my $esv = eval { $es->current_server_version };
	return trace( ERROR=>'elasticsearch does not answer, it might be deaf' )
		unless $esv;
	trace DEBUG=>"connected to elasticsearch $esv->{number} at $cfg->{servers}";
	if( $init ) {
		cfg 'db.init'=>0;
		trace NOTICE=>'initializing elasticsearch index';
		trace DEBUG=>'deleting index';
		$es->delete_index( index=>IDXNAME, ignore_missing=>1 );
		trace DEBUG=>'creating index';
		$es->create_index(
			index    => IDXNAME,
			settings => {
				number_of_shards => 1,
				analysis => {
					analyzer => {
						default => {
							type      => 'custom',
							tokenizer => 'standard',
							filter    =>  [ 'asciifolding', 'lowercase' ],
						},
					},
				},
			},
			mappings => $MAPPINGS,
		);
	} elsif( $reidx ) {
		for( keys %$MAPPINGS ) {
			trace DEBUG=>'updating $_ mapping';
			$es->put_mapping(
				index    => IDXNAME,
				type     => $_,
				mapping  => { $_ => $MAPPINGS->{$_} }
			);
		}
		trace DEBUG=>'reindexing';
		my $scroll = $es->scrolled_search(
			search_type => 'scan',
			scroll      => '5m'
		);
		$es->reindex(source=>$scroll);
	} elsif( $optim ) {
		trace DEBUG=>'optimizing index';
		$es->optimize_index(
			index   => IDXNAME,
			flush   => 1,
			refresh => 1,
		);
	}
	1
}

sub dbindex {
	my( $type, $data ) = @_;
	return unless $es;
	trace DEBUG=>'indexing '.$type.' '.$data->{text};
	eval { $es->index(
		index => IDXNAME,
		type  => $type,
		data  => {
			%$data,
			date => strftime("%Y-%m-%d %H:%M:%S",localtime(time))
		}
	) } or trace ERROR=>"ES $@"
}

sub dbsearch {
	my( $type, $qry, $from, $size ) = @_;
	return trace( WARN=>'db disabled' ) unless $es;
	eval { $es->refresh_index( index => IDXNAME ) };
	trace DEBUG=>'searching '.($type?$type.' ':'').$qry;
	eval { $es->search(
		index => IDXNAME,
		type  => $type,
		sort  => [ {'date'=>{order=>'desc'}} ],
		from  => $from || 0,
		size  => $size || 50,
		query => {
			query_string => {
				query => $qry
			},
		}
	) } or trace ERROR=>"ES $@"
}

sub dbsearchterm {
	my( $type, $term, $qry ) = @_;
	return trace( WARN=>'db disabled' ) unless $es;
	trace DEBUG=>'searching terms '.(ref($type) eq 'ARRAY'?join(',',@$type):$type).' '.$qry;
	eval { $es->search(
		index => IDXNAME,
		sort  => [ {'date'=>{order=>'asc'}} ],
		type  => $type,
		query => {
			term => {
				$term => $qry
			},
		}
	) } or trace ERROR=>"ES $@"
}

1
