package Zotero::Markdown;
use 5.010;
use Moo;

use MozRepl;
use JSON::Any;

has citations => (is => 'ro', default => sub {{}} );

has repl => (is => 'ro', lazy => 1, builder     => '_build_repl',);

sub _build_repl {
    my $repl = MozRepl->new();
    $repl->setup({# zotero can be slow.
        client  => {extra_client_args => {timeout => 100000} },
    } );
    my $zotero = 'var zotero = Components.classes["@zotero.org/Zotero;1"] .getService(Components.interfaces.nsISupports).wrappedJSObject;';
    $repl->execute($zotero);
    return $repl;
}

sub _run {
    my ($self, @commands) = @_;
    my $result;
    $result = $self->repl->execute($_) for @commands;
    return $result;
}

sub parse_citation {
    my ($self, $cite ) = @_;
    return $self->citations->{$cite}
        if exists $self->citations->{$cite};
    my $rx = $self->citation_regex;
    $cite =~ /$rx/;
    my %parse;
    @parse{qw/author title year/} = @+{qw/author title year/};
    $self->citations->{$cite} = \%parse;
    return $self->citations->{$cite};
}


has citation_regex => ( is => 'ro',
                        default => sub {
                            qr/\(c\|               # preamble
                               (?<author>.*?)\s+  # author
                               (?<year>\d+)\s+    # year
                               (?<title>.*?)\)/x; # title fragment
                        });



1;

__END__
=head1 NAME

Zotero::Markdown

=head2 DESCRIPTION

Package for handling human readable Author/Date citations in markdown format.
Designed to be good enough for common use cases, not perfect.

=head2 SYNOPSIS

Will scan a plain text document paragraph by paragraph for citations using
a human readable format to key citations.  Conversion will die without
modifying the document if there are ambiguous citation keys.

Examples of the format are

 (c|Fletcher 2003 Mapping stakeholder perceptions)
 (c|Law 2008 On sociology)

You can put perl regex elements into the title portion.  e.g. ^, $,
.*

=head2 citations

hashref of citations seen during document processing, keyed by the
citation text provided by the user.  Used to memoize

=head2 repl

MozRepl object for internal use

=head2 _run

sends javascript commands to the repl and returns the result.

=head2 parse_citation

parses the citation to author title and year hashref

=head2 citation_regex

Simple regex for parsing the text string.
TODO.  consider making a proper parser.
TODO.  consider optional doi support.


 
