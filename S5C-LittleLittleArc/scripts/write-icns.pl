#!/usr/bin/perl
use strict;
use warnings;

my ($parts_dir, $destination) = @ARGV;
die "Usage: write-icns.pl PARTS_DIR DESTINATION\n" unless defined $parts_dir && defined $destination;

my @entries = (
    ["icp4", 16],
    ["icp5", 32],
    ["icp6", 64],
    ["ic07", 128],
    ["ic08", 256],
    ["ic09", 512],
    ["ic10", 1024],
);

my $body = "";
for my $entry (@entries) {
    my ($type, $size) = @$entry;
    my $path = "$parts_dir/$size.png";
    open my $input, "<:raw", $path or die "Could not read $path: $!\n";
    local $/;
    my $data = <$input>;
    close $input;
    $body .= $type . pack("N", 8 + length($data)) . $data;
}

open my $output, ">:raw", $destination or die "Could not write $destination: $!\n";
print {$output} "icns", pack("N", 8 + length($body)), $body;
close $output;
