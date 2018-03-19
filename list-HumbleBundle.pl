#!/usr/bin/env perl

use strict;
use warnings;
use Modern::Perl;
use JSON::Parse 'parse_json';
use Data::Dumper;
use LWP::UserAgent ();
use Digest::MD5 qw(md5 md5_hex);
use Config::Simple;
use File::Copy;

binmode(STDOUT, ":utf8");

my $cfg;
my @cfgParams = qw(sessionCookie saveDir);

if ( -f '.humbleBundle.cfg' ) {
    print "\nReading config file .humbleBundle.cfg \n\n";
    $cfg = new Config::Simple('.humbleBundle.cfg');
} else {
    print "\nConfig file, .humbleBundle.cfg, missing!\n";
    exit 1;
}

for my $param (@cfgParams) {
   die "Please check your config file, $param is not set!" if (! $cfg->param($param));
}

my $session = $cfg->param('sessionCookie');
my $saveDir = $cfg->param('saveDir');

my $max_file_size = 6294967296;  # 4GB, just to pick a number

my $ua = LWP::UserAgent->new();
#$ua->default_header('X-Requested-By' => 'hb_android_app');
#$ua->add_handler("request_send",  sub { shift->dump; return });
#$ua->add_handler("response_done", sub { shift->dump; return });

my $getAllOrdersURL = 'https://www.humblebundle.com/api/v1/user/order';

my $cookie = '_simpleauth_sess="' . $session . '"';

my $allOrdersResponse = $ua->get($getAllOrdersURL, Cookie => $cookie );

my $ordersList;
if ( $allOrdersResponse->is_success  ) {
    $ordersList = parse_json $allOrdersResponse->decoded_content;
}

my %items;

say 'Getting Bundles ';

for my $order ( @{$ordersList} ) {
    my $getOrderURL = 'https://www.humblebundle.com/api/v1/order/' . $order->{gamekey};
    my $orderResponse = $ua->get($getOrderURL, Cookie => $cookie );

    my $orderDetails;
    if ( $orderResponse->is_success  ) {
        $orderDetails = parse_json $orderResponse->decoded_content;
    }

    my $dirName = NameCleanUp( $orderDetails->{product}->{human_name} );

    $items{$order->{gamekey}} = {
        name    => $orderDetails->{product}->{human_name},
        created => $orderDetails->{created},
        dir     => $dirName,
        books   => $orderDetails->{subproducts}
    };
}

foreach my $key (sort { $items{$a}->{created} cmp $items{$b}->{created} } (keys %items) ) {
    my $dir = $saveDir . '/' . $items{$key}{dir};

    say 'Bundle: ' . $items{$key}{name} . ' (key ' . $key . ')';

    for my $book ( @{$items{$key}{books}} ) {
        my @downloads = @{$book->{downloads}};
        if ( @downloads ) {
            my $filename = NameCleanUp( $book->{human_name} );
            say "  $filename -";

            for (my $i=0; $i < scalar @downloads; $i++) {
                for my $file ( @{$downloads[$i]->{download_struct}} ) {
                    my $ext = lc $file->{name};
                    my $url = $file->{url}->{web};
                    my $fullFilename = $filename . '.' . $ext;
                    if ( defined $file->{file_size} ) {
                        if ( $url =~ /.*\.zip\?.*/ ) {
                            $fullFilename = $fullFilename . ".zip";
                        }
                        if ( $fullFilename =~ /(480|720|1080)p$/ ) {
                            $fullFilename = $fullFilename . ".mp4";
                        }
                    }
                    my $save = "$dir/$fullFilename";

                    say "    $fullFilename " . $file->{human_size};
                }
            }
        }
    }
}

sub NameCleanUp {
    my ($name) = @_;

    ( my $cleanName = $name ) =~ s/\s+/_/g; # Could make space replacement optional

    $cleanName =~ s/\/|\)|:|,|_\|\|/_-/g;
    $cleanName =~ s/\(/-_/g;
    $cleanName =~ s/\N{U+2018}|\N{U+2019}|\N{U+201A}/'/g;
    $cleanName =~ s/\N{U+201C}|\N{U+201D}|\N{U+201F}/"/g;
    $cleanName =~ s/\.|!|//g;
    $cleanName =~ s/'//g; # Could make quote removal optional
    $cleanName =~ s/&/and/g;
    $cleanName =~ s/#/Num_/g;
    $cleanName =~ s/_-$//;

    return $cleanName;
}
