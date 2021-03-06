use strict;
use warnings;
use utf8;

my $format = "";
my $charencoding = "";
my $utf8bom = "";

my $format_result_path = undef;
my $output_path = undef;

while (@ARGV) {
    my $a = shift(@ARGV);
    if ($a eq "--tsv") {
        $format = "tsv";
    } elsif ($a eq "--csv") {
        $format = "csv";
    } elsif (!defined($format_result_path)) {
        $format_result_path = $a;
    } elsif (!defined($output_path)) {
        $output_path = $a;
    } else {
        die "Unknown argument: $a";
    }
}

die "format-wrapper.pl requires argument" unless defined $format_result_path;
die "format-wrapper.pl requires argument" unless defined $output_path;

my $head_size = 100 * 4096;

my $head_buf = "";

my $in = *STDIN;

my $size = $head_size;
while () {
    if ($size <= 0) {
        last;
    }
    my $head_buf2;
    my $l = sysread($in, $head_buf2, $size);
    if ($l == 0) {
        last;
    }
    $size -= $l;
    $head_buf .= $head_buf2;
}

sub guess_format {
    my ($head_buf) = @_;
    if ($head_buf =~ /\t/) {
        return "tsv";
    } elsif ($head_buf =~ /,/) {
        return "csv";
    } else {
        # failed to guess format
        return "tsv";
    }
}

# 文字コードを自動判別する。
# いまのところ、 UTF-8 / SHIFT-JIS のみ
sub guess_charencoding {
    my ($head_buf) = @_;
    my $len = length($head_buf);
    my $utf8_multi = 0;
    my $utf8_flag = 1;
    my $sjis_multi = 0;
    my $sjis_flag = 1;
    for (my $i = 0; $i < $len; $i++) {
        my $b = ord(substr($head_buf, $i, 1));
        if ($utf8_multi > 0) {
            if    ($b >= 0x80 && $b < 0xC0)  { $utf8_multi--; }
            else                             { $utf8_multi = 0; $utf8_flag = ''; }
        } else {
            if    ($b < 0x80)                { ; }
            elsif ($b >= 0xC2 && $b < 0xE0)  { $utf8_multi = 1; }
            elsif ($b >= 0xE0 && $b < 0xF0)  { $utf8_multi = 2; }
            elsif ($b >= 0xF0 && $b < 0xF8)  { $utf8_multi = 3; }
            else                             { $utf8_flag = ''; }
        }
        if ($sjis_multi > 0) {
            if    ($b >= 0x40 && $b <= 0x7E) { $sjis_multi = 0; }
            elsif ($b >= 0x80 && $b <= 0xFC) { $sjis_multi = 0; }
            else                             { $sjis_multi = 0; $sjis_flag = ''; }
        } else {
            if    ($b <= 0x7F)               { ; }
            elsif ($b >= 0x81 && $b <= 0x9F) { $sjis_multi = 1; }
            elsif ($b >= 0xA0 && $b <= 0xDF) { ; }
            elsif ($b >= 0xE0 && $b <= 0xFC) { $sjis_multi = 1; }
            elsif ($b >= 0xFD && $b <= 0xFF) { ; }
            else                             { $sjis_flag = ''; }
        }
    }
    $utf8bom = '0';
    if (!$utf8_flag && $sjis_flag) {
        return ($head_buf, "SHIFT-JIS", $utf8bom);
    } else {
        if ($len >= 3) {
            if (substr($head_buf, 0, 3) eq "\xEF\xBB\xBF") {
                # BOM in UTF-8
                # require `tail -c+4`
                $utf8bom = '1';
            }
        }
        return ($head_buf, "UTF-8", $utf8bom);
    }
}

if ($format eq '') {
    $format = guess_format($head_buf);
}

if ($charencoding eq '') {
    ($head_buf, $charencoding, $utf8bom) = guess_charencoding($head_buf);
}

open(my $format_result_fh, '>', $format_result_path) or die $!;
print $format_result_fh "format:$format charencoding:$charencoding utf8bom:$utf8bom\n";
close($format_result_fh);

open(my $output_fh, '>', $output_path) or dir $!;
syswrite($output_fh, $head_buf);
open(STDOUT, '>&=', fileno($output_fh));

exec("cat");

