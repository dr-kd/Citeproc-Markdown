package Zotero::Markdown;

use Moo;
use MozRepl;


=head1 NAME

Zotero::Markown

=head2 DESCRIPTION

Package for handling human readable Author/Date citations in markdown format.
Designed to be good enough for common use cases, not perfect.


=head2 SYNOPSIS

Will scan a plain text document paragraph by paragraph for citations using
a human readableformat to key citations.  Conversion will die without
modifying the document if there are ambiguous citation keys.

Examples of the format are

 (c|{10.1108/14691930310504536} Fletcher 2003 Mapping stakeholder perceptions)
 (c|Law 2008 On sociology)

You can put perl regex elements into the title portion.  e.g. ^ $ .* etc.

=cut

=head2 citations

hashref of citations already seen during document processing, keyed by the
citation text provided by the user.

=cut

has citations => (is => 'ro', default => sub {{}} );


# mozrepl object with zotero object in scope.

has repl => (is => 'ro', lazy => 1, builder     => '_build_repl',);

sub _build_repl {
    my $repl = MozRepl->new();
    $repl->setup;
    my $zotero = 'var zotero = Components.classes["@zotero.org/Zotero;1"] .getService(Components.interfaces.nsISupports).wrappedJSObject;';
    $repl->execute($zotero);
    return $repl;
}

=head2 _run

sends javascript commands to the repl and returns the result.

=cut

sub _run {
    my ($self, @commands) = @_;
    $self->repl->execute($_) for @commands;
}

=head2 parse_citation

=cut

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


=head2 citation_regex

Simple regex for parsing the text string.
TODO.  consider making a proper parser.
TODO.  consider optional doi support.

=cut.

has citation_regex => ( is => 'ro',
                        default => sub {
                            qr/\(c\|               # preamble
                               (?<author>.*?)\s+  # author
                               (?<year>\d+)\s+    # year
                               (?<title>.*?)\)/x; # title fragment
                        });
1;

