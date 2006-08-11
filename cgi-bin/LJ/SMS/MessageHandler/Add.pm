package LJ::SMS::MessageHandler::Add;

use base qw(LJ::SMS::MessageHandler);

use strict;
use Carp qw(croak);

sub handle {
    my ($class, $msg) = @_;

    my $u = $msg->from_u
        or die "no from_u for Add message";

    my $text = $msg->body_text;
    $text =~ s/^\s*add\s+(\S+).*/$1/i;

    my $fr_user = LJ::canonical_username($text)
        or die "Invalid format for username: $text";

    my $fr_u = LJ::load_user($fr_user)
        or die "Invalid user: $fr_user";

    $u->add_friend($fr_u)
        or die "Unable to add friend for 'Add' request";

    # mark the requesting (source) message as processed
    # -- we'd die before now if there was an error
    $msg->status('success');
}

sub owns {
    my ($class, $msg) = @_;
    croak "invalid message passed to MessageHandler"
        unless $msg && $msg->isa("LJ::SMS::Message");

    return $msg->body_text =~ /^\s*add\s+/i ? 1 : 0;
}

1;
