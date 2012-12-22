#!/usr/bin/env perl
use warnings;
use strict;
use Test::More;
# use 5.010;
use Zotero::Markdown;
my $z = Zotero::Markdown->new;
ok($z->repl);
my $eg = "(c|Law 2008 On sociology)";
my $res = $z->parse_citation($eg);
$DB::single=1;
is_deeply($res, {
          'title' => 'On sociology',
          'author' => 'Law',
          'year' => '2008'
        }, "corect citation parse");
done_testing;
