#!/usr/bin/env perl
use warnings;
use strict;
use Test::More;
use Zotero::Markdown;

my $z = Zotero::Markdown->new;
ok($z->repl->isa('MozRepl'), "repl object created ok");
my $eg = "(c|Law 2008 On sociology)";
my $res = $z->parse_citation($eg);
is_deeply($res, {
          'title' => 'On sociology',
          'author' => 'Law',
          'year' => '2008'
        }, "corect citation parse");
my $item_id = $z->search($eg);
ok($item_id);
diag $z->get_available_styles();
done_testing;
