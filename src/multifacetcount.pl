use strict;
use warnings;
use utf8;

my $headers = undef;
my $header_count = 0;

my $facetcount = {};
# {
#   "value a" => {
#     "count" => 1,
#     "values" => { ... }
#   },
#   "value b" => {
#     "count" => 1,
#     "values" => { ... }
#   },
#   }
# }

my $record_count = 0;

# Ctrl-C で中断して結果を表示するためのハンドラ
my $interrupted = '';
sub interrupt {
    $interrupted = 1;
}
$SIG{INT} = \&interrupt;

{
    my $line = <STDIN>;
    $line =~ s/\n\z//g;
    my @cols = split(/\t/, $line, -1);

    $record_count++;

    $headers = \@cols;
    $header_count = scalar @cols;
}

while (my $line = <STDIN>) {
    $line =~ s/\n\z//g;
    my @cols = split(/\t/, $line, -1);

    $record_count++;

    # 行にタブの数が少ない場合に列を付け足す
    for (my $i = $header_count - @cols; $i > 0; $i--) {
        push(@cols, "");
    }

    my $fc = $facetcount;
    for (my $i = 0; $i < $header_count; $i++) {
        my $v = $cols[$i];
        if (defined($fc->{$v})) {
            $fc->{$v}->{count}++;
        } else {
            if ($i == $header_count - 1) {
                $fc->{$v} = {count => 1 };
            } else {
                $fc->{$v} = {count => 1, values => {} };
            }
        }
        $fc = $fc->{$v}->{values}
    }

    if ($record_count % 10000 == 0) {
        print STDERR "Record: $record_count ...\n";
    }

    if ($interrupted) {
        last;
    }
}

for (my $i = 0; $i < $header_count; $i++) {
    my $c = $headers->[$i];
    print "\t" if $i > 0;
    print "$c-num\t$c-value\t$c-count\t$c-ratio";
}
print "\n";

sub printResult {
    my ($head, $sum, $fc, $level) = @_;
    my @words = keys(%$fc);
    @words = sort { my $r = $fc->{$b}->{count} <=> $fc->{$a}->{count}; if ($r == 0) { $r = $a cmp $b; }; $r } @words;
    if ($level == 0) {
        my $i = 1;
        foreach my $word (@words) {
            my $count = $fc->{$word}->{count};
            my $h = [@$head, $i, $word, $count, sprintf("%6.2f%%", 100 * $count / $sum)];
            print join("\t", @$h) . "\n";
            $i++;
        }
    } else {
        my $i = 1;
        foreach my $word (@words) {
            my $count = $fc->{$word}->{count};
            my $h = [@$head, $i, $word, $count, sprintf("%6.2f%%", 100 * $count / $sum)];
            printResult($h, $count, $fc->{$word}->{values}, $level - 1);
            $i++;
        }
    }
}

printResult([], $record_count, $facetcount, $header_count - 1);
