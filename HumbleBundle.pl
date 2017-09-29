#!/home/bwood/perl5/perlbrew/perls/perl-5.22.0/bin/perl -w

use strict;
use warnings;
use Modern::Perl;
use JSON::Parse 'parse_json';
use Data::Dumper;
use LWP::UserAgent ();
use Digest::MD5 qw(md5_hex);
use Config::Simple;

my $cfg;
my @cfgParams = qw(sessionCookie);

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

for my $order ( @{$ordersList} ) {
    say $order->{gamekey};

    my $getOrderURL = 'https://www.humblebundle.com/api/v1/order/' . $order->{gamekey};
    my $orderResponse = $ua->get($getOrderURL, Cookie => $cookie );

    my $orderDetails;
    if ( $orderResponse->is_success  ) {
        $orderDetails = parse_json $orderResponse->decoded_content;
    }
    say $orderDetails->{product}->{human_name};
}
die 'The End';


# TODO Replace this bit with actually downloading the JSON file from the API
#my $str = do { local $/; <STDIN> };

my $data;
for my $book ( @{$data->{subproducts}} ) {

    if ( @{$book->{downloads}} ) {
        ( my $filename = $book->{human_name} ) =~ s/\s+/_/g;

        $filename =~ s/(:|,|_\|\|)/_-/g;
        $filename =~ s/('|!)//g;
        $filename =~ s/&/and/g;
        say "  Working on $filename -";

        for my $file ( @{$book->{downloads}->[0]->{download_struct}} ) {

            my $ext = lc $file->{name};
            say "    Working on $ext -";

            my $url = $file->{url}->{web};

            say   "      downloading";
            $ua->show_progress(1);
            my $fileResponse = $ua->get($url);
            die $fileResponse->status_line if !$fileResponse->is_success;

            my $downloadedFile = $fileResponse->decoded_content( charset => 'none' );
            my $md5HEX = md5_hex($downloadedFile);

            if ( $md5HEX eq $file->{md5} ) {
                say "      md5 values match";

                my $fullFilename = $filename . '.' . $ext;
                my $save = "/home/bwood/Dropbox/Books/Hacking_Reloaded_-_Humble_Bundle/$fullFilename";

                unless(open SAVE, '>'.$save) {
                    die "      Cannot create save file '$save'\n";
                }
                say "      Saving file: $save\n";
                print SAVE $downloadedFile;
                close SAVE;
            } else {
                say "      md5 values does not match!";
                say "        " . $file->{md5} . " - md5 from JSON";
                say "        $md5HEX - downloaded File";
            }
        }
    die;

    }

}
