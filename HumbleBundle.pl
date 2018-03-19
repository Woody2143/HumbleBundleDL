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

my $max_file_size = 4294967296;  # 4GB, just to pick a number

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

say 'Sorting Bundles';
foreach my $key (sort { $items{$a}->{created} cmp $items{$b}->{created} } (keys %items) ) {
    say $key . ' - ' . $items{$key}->{created} . ' - ' .  $items{$key}->{name};
}

say "\nEnter each desired bundle, one per line, entering an empty line when done:\n";

my @keys;
my $question = 0;
while ($question == 0) {
    print "Which key? ";
    chomp (my $key = <STDIN>);
    if ($key ne "") {
        push @keys, $key;
    } else {
        $question = 1;
    }
}

my @skipped;
my $nDownloaded=0;
my $nSkipped=0;
my $nChecked=0;
my $nCheckFail=0;

for my $key (@keys) {

    my $dir = $saveDir . '/' . $items{$key}{dir};
    if (-e $dir && -d $dir) {
        say "$dir exists";
    } else {
        mkdir $dir or die "ERROR: Cannot create $dir!";
        say "$dir created!";
    }

    say 'Working on bundle: ' . $items{$key}{name} . ' (key ' . $key . ')';

    for my $book ( @{$items{$key}{books}} ) {
        my @downloads = @{$book->{downloads}};
        if ( @downloads ) {
            my $filename = NameCleanUp( $book->{human_name} );

            say "  Working on $filename -";

            for (my $i=0; $i < scalar @downloads; $i++) {
                for my $file ( @{$downloads[$i]->{download_struct}} ) {
                    my $ext = lc $file->{name};
                    if ( $ext eq "stream" ) {
                        say "    Skipping $ext";
                        next;
                    }

                    say "    Working on $ext -";

                    my $url = $file->{url}->{web};
                    my $fullFilename = $filename . '.' . $ext;
                    if ( $url =~ /.*\.zip\?.*/ ) {
                        $fullFilename = $fullFilename . ".zip";
                    }
                    if ( $fullFilename =~ /(480|720|1080)p$/ ) {
                        $fullFilename = $fullFilename . ".mp4";
                    }
                    $fullFilename =~ s/\.pdf \((.+)\)$/.$1.pdf/;
                    my $save = "$dir/$fullFilename";

                    if ( -e $save ) {
                        say "      File Exists!";
                        say "        Checking MD5!";
                        open (my $fh, '<', $save) or die "Can't open '$save': $!";
                        binmode($fh);
                        my $md5 = Digest::MD5->new;
                        while (<$fh>) {
                            $md5->add($_);
                        }
                        close($fh);
                        my $md5FileHEX = $md5->hexdigest;

                        if ( $md5FileHEX eq $file->{md5} ) {
                            say "          MD5 Hash Matches!";
                            $nChecked++;
                            next;
                        } else {
                            say "          MD5 Hash doesn't match! (will redownload)";
                            $nCheckFail++;
                        }
                    }

                    if ($file->{file_size} > $max_file_size) {
                        say "    Skipping $ext because file is too big at " . $file->{human_size};
                        push @skipped, $book;
                        $nSkipped++;
                        next;
                    }

                    say "      downloading";
                    $ua->show_progress(1);
                    my $fileResponse = $ua->get($url);
                    die $fileResponse->status_line if !$fileResponse->is_success;

                    my $downloadedFile = $fileResponse->decoded_content( charset => 'none' );
                    my $md5HEX = md5_hex($downloadedFile);

                    if ( $md5HEX eq $file->{md5} ) {
                        say "      md5 values match";

                        unless(open SAVE, '>'.$save) {
                            die "      Cannot create save file '$save'\n";
                        }
                        say "      Saving file: $fullFilename\n";
                        print SAVE $downloadedFile;
                        close SAVE;
                        $nDownloaded++;
                    } else {
                        say "      md5 values does not match!";
                        say "        " . $file->{md5} . " - md5 from JSON";
                        say "        $md5HEX - downloaded File";
                        die;
                    }
                }
            }
        }
    }
}

# TODO keep track of failed files and report them rather than fail (allows downloading more files on failure)
say "\n$nDownloaded files downloaded successfully.";
say "$nChecked files already existed and have the correct MD5.";
say "$nCheckFail files failed the MD5 check and were redownloaded or skipped.";
if ($nSkipped > 0) {
    say "$nSkipped files skipped due to being too large:";
    for my $book ( @skipped ) {
        my $filename = NameCleanUp( $book->{human_name} );
        say "   $filename";
    }
}

sub NameCleanUp {
    my ($name) = @_;

    ( my $cleanName = $name ) =~ s/^\s+|\s+$//g; # Trim the string

    $cleanName =~ s/\/|\(|\)|:|,| \|\|/ - /g; # Replace slash, paren, colon, comma, and pipe-pipe with a dash
    $cleanName =~ s/\N{U+2018}|\N{U+2019}|\N{U+201A}/'/g; # Replace Unicode single-quote with '
    $cleanName =~ s/\N{U+201C}|\N{U+201D}|\N{U+201F}/"/g; # Replace Unicode double-quote with "
    $cleanName =~ s/\.|!//g;    # Eliminate period and exclamation point
    $cleanName =~ s/&/ and /g;  # Replace ampersand with the word "and"
    $cleanName =~ s/#/ Num /g;  # Replace number sign with the word "Num"
    $cleanName =~ s/\s*-\s*$//; # Remove a trailing dash
    $cleanName =~ s/\s\s+/ /g;  # Collapse consecutive whitespace

    $cleanName =~ s/'//g;       # remove single quotes (comment out to prevent)
    $cleanName =~ s/ /_/g;      # replace space with underscore (comment out to prevent)

    return $cleanName;
}
