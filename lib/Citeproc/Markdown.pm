package Citeproc::Markdown;
use warnings;
use strict;
use 5.010;
use Moo;

use MozRepl;
use JSON::Any;
use Path::Class;
use File::ShareDir;
use Try::Tiny;
use URI;
use URI::Escape::JavaScript qw/unescape/;

# load javascript required for citation management
sub BUILD {
    my ($self) = @_;
    $self->run_file('citeproc.js');
}

has citations => (is => 'ro', default => sub {{}} );

has json_encoder => ( is => 'ro', default => sub { JSON::Any->new } );

has repl => (is => 'ro', lazy => 1, builder     => '_build_repl',);

has js_dir => (is => 'ro', default => sub {
                   return Path::Class::Dir
                       ->new(File::ShareDir::module_dir(__PACKAGE__))
                           ->subdir('js');
               } );

sub _build_repl {
    my $repl = MozRepl->new();
    $repl->setup_log([qw/error fatal/]) unless $ENV{DEBUG};
    $repl->setup({
        client  => {extra_client_args => {timeout => 6000} },
    } );

    return $repl;
}

sub run {
    my ($self, @commands) = @_;
    my $result;
    $result = $self->repl->execute($_) for @commands;
    $result =~ s/^"|"$//g;
    try {
        return $self->json_encoder->jsonToObj($result)
        } catch {
            warn "JSON ERROR: '$_'" if $ENV{DEBUG};
            return $result;
        };
}

sub run_file {
    my ($self, $filename) = @_;
    local $/="\n\n"; # adjust input record sep;
    # to split into code paragraphs in an attempt to keep mozrepl happy
    my @code = $self->js_dir->file($filename)->slurp;
    return $self->run(@code);
}

sub parse_citation {
    my ($self, $cite ) = @_;
    return $self->citations->{$cite}
        if exists $self->citations->{$cite};
    my $rx = $self->citation_regex;
    $cite =~ /$rx/;
    my %parse;
    @parse{qw/author title year/} = @+{qw/author title year/};
    $self->citations->{$cite} = { %parse };
    return $self->citations->{$cite};
}


has citation_regex => ( is => 'ro',
                        default => sub {
                            qr/\((?<suppress>c|c)\| # suppress author if 's'
                                (?<author>.*?)\s+   # author
                                (?<year>\d+)\s+     # year
                                (?<title>.*?)\)/x;  # title fragment
                        });

sub search {
    my ($self, $cite) = @_;
    my %c = %{$self->parse_citation($cite)};
    my $cite_data =
        $self->json_encoder->objToJson([@c{qw/author title year/}]);
    my $results = $self->run("getItemIdDynamic($cite_data)");
    if (ref($results)) {
        warn "More than one result returned for $cite.  Using the first one.\n";
        return $results->[0];
    }
    else {
        return $results
    }
}

has available_styles => ( is => 'ro', lazy => 1,
                       builder => '_build_available_styles');

sub _build_available_styles {
    my ($self) = @_;
    my $js = '
        var styles = zotero.Styles.getVisible();
        var style_info = [];
        for each ( var s in styles) {
            style_info.push( { "id" : s.styleID, "name" : s.title } );
        }
        JSON.stringify(style_info);
        ';

    my $styles = $self->run($js);
    my %styles;
    foreach my $s (@$styles) {
        $styles{$s->{name}} = $s->{id};
    }
    return \%styles;
}

sub set_style {
    my ($self, $style) = @_;
    die "Style '$style' does not exist\n"
        unless exists $self->available_styles->{$style};
    my $uri = URI->new($self->available_styles->{$style});
    my $id = ($uri->path_segments)[-1];
    # clears the bibliography and sets the style for the current bib.
    my $result = $self->run("instantiateCiteProc('$id')");
    return $result;
}

sub add_citation {
    my ($self, @refs) = @_;
    my @cites;
    my @cite_ids;
    foreach my $r (@refs) {
        my $res = $self->parse_citation($r);
        my $id = $self->search($r);
        push @cite_ids, $id;
        push @cites, { id => $id };
    }

    $self->run("updateItems("
                   . $self->json_encoder->objToJson(\@cite_ids)
                   . ")");

    my $cc = $self->json_encoder->objToJson(
        { citationItems => \@cites,
          properties     => { noteIndex => 1}
      });
    my $cite_key =  $self->run("appendCitationCluster($cc)");
    return $cite_key;
}

sub extract_citation_list {
    my ($self, $cite_str) = @_;
    my $regex = $self->citation_regex;
    my (@cites) = $cite_str =~ /(\([cs]\|.*?\))/g;
    return @cites;
}

sub make_bibliography {
    my ($self) = @_;
    my $bib = $self->run('makeBibliography()');
    foreach (@{$bib->[1]}) {
        $_ = unescape($_);
        $_ =~ s/(<\/div>)/$1<br \/>/s;
    }
        return $bib;
}

sub process_citation {
    my ($self, $cite_str) = @_;
    my @cites = $self->extract_citation_list($cite_str);
    $self->citations->{$cite_str} =
        { final_cite => $self->add_citation(@cites)};
}

1;
__END__
=head1 NAME

Citeproc::Markdown

=head2 DESCRIPTION

Package for handling human readable Author/Date citations in markdown format.
Designed to be good enough for common use cases, not perfect.  Code is also a good start to a more general Zotero/Perl gateway.

=head2 SYNOPSIS

Will scan a plain text document paragraph by paragraph for citations using
a human readable format to key citations.  Conversion will die without
modifying the document if there are ambiguous citation keys.

Requires mozrepl
(L<https://addons.mozilla.org/en-us/firefox/addon/mozrepl/>) installed and
running to the same Firefox, or XULRunner that your Zotero library is
stored in.  Other than that, and a working modern perl ( >= 5.10.0) no
other extensions, firefox or otherwise are required.

Examples of the format are

 (c|Fletcher 2003 Mapping stakeholder perceptions)
 (c|Law 2008 On sociology)
 (s|Law 2008 On sociology)

The final example is to supress author (not yet implemented, but supported
in the regex).  The code will warn if more than one keys are found (maybe
it should die ...)

=head2 TODO

1.  Tests work on my local machine but not elsewhere due to citation library differences and zotero setup.
2.  Tests only work with a running zotero and mozrepl.
3.  Need to write the pandoc integration (need to write some markdown with citations).
4.  Supress author citations not yet supported (but stubbed (s| form of
citation to support this at a later stage.
5.  Consider adding compatible zot4rst citation keys.

However, this module provides the basis for having decent markdown/zotero
integration without the need for intermediate files.  In the final
implementation I suppose there will be two different versions of the script
run C<markdown_cite --draft> that will keep the author cite keys untouched,
and dump the references to a file, and C<markdown_cite --final> that will
replace them with the final CSL generated citations.

=head2 BUILD

Loads the citeproc javascript required for this code to work.

=cut

=head2 json_encoder

JSON::Any object used in data transfer between repl and perl

=cut

=head2 js_dir

sharedir where we keep the javascript required for mozrepl

=cut

=head2 add_citation

takes a list of citation ids, and adds them to the csl processor through
the repl.

=head2 search

Takes a citation string, parses it returns the item id.  Warns if > 1
result is returned.

=head2 citations

hashref of citations seen during document processing, keyed by the
citation text provided by the user.  Used to store citations for publication indexed by writer's citation keys.

=head2 repl

MozRepl object for internal use.  Run script with env var DEBUG=1 for
verbose info, otherwise only warnings and fatals are emitted.  DEBUG=1 will
also catch JSON encoding problems.

=head2 run

sends javascript commands to the repl and returns the result of the last
command.

=head2 run_file

Reads in javascript source code, and sends it to the repl paragraph by
paragraph(delimited by \n\n).  WARNING - be sure to ensure that each
paragraph compiles as a standalone entity.  If not the repl will hang then
time out.

=head2 parse_citation

parses the citation to author title and year hashref

=head2 citation_regex

Simple regex for parsing the text string.
TODO.  consider making a proper parser.
TODO.  consider optional doi support.

=head2 available_styles

Lazy accessor for the available zotero styles.  Returns a hashref: key:
name val: url.

=head2 set_style

Uses instantiateCiteProc in citeproc.js to set the current style.

=head2 extract_citation_list

Takes a list of cites (c|Whatever 1999 Title fragment)(c|Someone 2002 Stuff) etc and splits into an array for further processing.

=head2 make_bibliography

Create the bibliography after all citations have been processed.

=head2 process_citation

Given an in-text citation (could be one or more ([cs]| ... form citations,
append the final_cite key to its hashref to give the in final (publisher)
citation for that chunk of text.

=head2 ACKNOWLEDGEMENTS

Erik Hetzner for the javascript code in zot4rst, which is also used in this
project (with very minor documentation and naming changes).

Frank Bennett for the very useful citeproc documentation
L<http://gsl-nagoya-u.net/http/pub/citeproc-doc.html>, which with Erik's
code enabled me get something that was usable running.

