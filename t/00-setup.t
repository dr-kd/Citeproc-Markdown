#!/usr/bin/env perl
use warnings;
use strict;
use Test::More;
use Zotero::Markdown;
use FindBin qw/$Bin/;
use Path::Class;
use YAML;

my $z = Zotero::Markdown->new(js_dir =>
                         Path::Class::Dir->new("$Bin/../share/js"));
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
diag Dump $z->available_styles;
ok ($z->set_style('Modern Language Association'),
    'set style to one that exists'); # die on fail
# I prefer 'Oryx compact (dev)'
diag Dump $z->run("csl_util_encode(mySys.retrieveItem($item_id))");
done_testing;
