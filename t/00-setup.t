#!/usr/bin/env perl
use warnings;
use strict;
use Test::More;
use Zotero::Markdown;
use FindBin qw/$Bin/;
use Path::Class;
use YAML;

# boilerplate for Test::Builder
use utf8;
my $builder = Test::More->builder;
binmode $builder->output,         ":utf8";
binmode $builder->failure_output, ":utf8";
binmode $builder->todo_output,    ":utf8";


my $z = Zotero::Markdown->new(js_dir =>
                         Path::Class::Dir->new("$Bin/../share/js"));

ok($z->repl->isa('MozRepl'), "repl object created ok");
my @egs = ( '(c|Law 2008 On sociology)',
            '(c|Greenhalgh 2005 Diffusion)',
            '(c|Anonymous 2005 strives)',
            '(c|Anonymous 2005 stitching)',
            '(c|Dooley 1999 process)(c|Dooley 2003 modeling)',
        );

ok ($z->set_style('Chicago Manual of Style (author-date)'),
    'set style to one that exists'); # die on fail

my $tested_parse;
my @citation_ids;
foreach my $eg (@egs) {
    my $res = $z->parse_citation($eg);
    is_deeply($res, {
        'title' => 'On sociology',
        'author' => 'Law',
        'year' => '2008'
    }, "corect citation parse") unless $tested_parse;
    $tested_parse = 1;
    my @cite_group = $z->extract_citation_list($eg);
    $z->add_citation(@cite_group);
}

my $bib = $z->make_bibliography();
diag Dump $bib;

done_testing;
