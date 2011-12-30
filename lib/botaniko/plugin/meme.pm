package botaniko::plugin::meme;

use strict;
use warnings;
use 5.010;
use GD;

use botaniko::config;
use botaniko::logger;
use botaniko::tools;
use botaniko::command;
use botaniko::hook;

my %SIZES = ( #width,height,margin,fontsize,border
	small  => [640,480,20,20,2],
	medium => [800,600,30,40,5],
	large  => [1024,768,40,60,5],
	huge   => [1600,1200,50,80,5],
);

cfg_default	'plugins.meme' => {
	size    => 'medium',
	font    => '/fonts/font.ttf',
	savedir => '/webserver/path/',
	geturl  => 'http://host/path/',
	tweet   => 1,
};

command
	meme => {
		help => "meme img=url text top | text bottom [size=small|medium|large|huge] [#notweet]",
		bin  => sub {
			my( $qry, $imgurl, $size, $font, $tweet ) = getoptions( \@_,
				img   => undef,
				size  => cfg('plugins.meme.size'),
				font  => cfg('plugins.meme.font'),
				tweet => cfg('plugins.meme.tweet'),
			);
			return ['you forgot img=url'] unless $imgurl;
			return ['unknown size'] unless exists $SIZES{$size};
			return ['you forgot the text'] unless $qry && @$qry;
			return ['font not found'] unless -r $font;
			
			$qry = join(' ',@$qry);
			if( $qry =~ /#notweet/i ) {
				$tweet = 0;
				$qry   =~ s/#notweet//gi;
			}	
			my( $tt, $bt ) = split /\|/,$qry;
			$tt =~ s/(^\s+|\s+$)//g if $tt;
			$bt =~ s/(^\s+|\s+$)//g if $bt;
			( $bt, $tt ) = ( $tt, undef ) if $tt && !$bt;

			trace DEBUG=>"loading $imgurl";
			my $r = useragent->get($imgurl);
			return [ 'image url returned '.$r->message().' ('.$r->code().')' ]
				unless $r->is_success;
			my $type = $r->headers->content_type;
			return [ 'unsupported type ($type)' ]
				unless $type =~ m/image/ && $type =~ /jpe?g|png/;
			my $src = GD::Image->new($r->decoded_content());
			return [ 'invalid image' ] 
				unless $src;
			
			my( $srcw, $srch ) = ( $src->width(), $src->height() );
			trace DEBUG=>"image $srcw x $srch loaded";

			my( $w, $h, $m, $fontsize, $b ) = @{$SIZES{$size}};
			( $w, $h ) = ( $h, $w ) if $srch > $srcw;
			my( $mt, $mb, $ml, $mr ) = ( $m ) x 4;

			my $img = GD::Image->new($w,$h,1);
			my $black = $img->colorAllocate(0,0,0);
			my $white = $img->colorAllocate(255,255,255);
			$img->filledRectangle(0,0,$w-1,$h-1,$black);

			if( $tt ) {
				my @bounds = GD::Image->stringFT(0,$font,$fontsize,0,0,0,$tt);
				my $tw = $bounds[2]-$bounds[0];
				my $th = $bounds[1]-$bounds[5];
				my $tx = ($w/2)-($tw/2);
				my $ty = (($m+$th)/2)+($th/2);
				$img->stringFT($white,$font,$fontsize,0,$tx,$ty,$tt);
				$mt = $th+$m;
			}

			if( $bt ) {
				my @bounds = GD::Image->stringFT(0,$font,$fontsize,0,0,0,$bt);
				my $tw = $bounds[2]-$bounds[0];
				my $th = $bounds[1]-$bounds[5];
				my $tx = ($w/2)-($tw/2);
				my $ty = $h - (($m+$th)/2)+($th/2);
				$img->stringFT($white,$font,$fontsize,0,$tx,$ty,$bt);
				$mb = $th+$m;
			}

			my $cf = ($h-($mt+$mb))/$srch;
			$ml = ($w-($srcw*$cf))/2;
			$img->copyResampled($src,$ml,$mt,0,0,int($srcw*$cf),int($srch*$cf),$srcw,$srch);
			$img->rectangle($ml-$b,$mt-$b,$ml+int($srcw*$cf)+$b-1,$mt+int($srch*$cf)+$b-1,$white);

			my $out  = commander.'_'.time().'.jpg';
			my $path = cfg('plugins.meme.savedir').$out;
			trace DEBUG=>"saving $path";
			open(my $fh,'>',$path) || return ['error opening '.$out ];
			binmode $fh;
			print $fh $img->jpeg;
			close $fh;
			
			my $url = cfg('plugins.meme.geturl').$out;
			if( $tweet ) {
				my $msg = $tt ? "$tt, $bt" : $bt;
				fire TOTWEET=>$msg.' '.$url;
			}

			[ 'saved in '.cfg('plugins.meme.geturl').$out ]
			
		}
	};

1
