package LJ::CProd::Feeds;
use base 'LJ::CProd';

sub applicable {
    my ($class, $u) = @_;

    my $popsyn = LJ::Syn::get_popular_feeds();

    my $friends = LJ::get_friends($u) || {};

    my @pop;
    for (0 .. 99) {
        next if not defined $popsyn->[$_];
        my ($user, $name, $suserid, $url, $count) = @{ $popsyn->[$_] };

        my $suser = LJ::load_userid($suserid);
        return 0 if ($friends->{$suserid} || $suser->{'statusvis'} ne "V");
    }
    return 1;
}

sub render {
    my ($class, $u) = @_;
    my $user = LJ::ljuser($u);
    my $icon = "<div style=\"float: left; padding-right: 5px;\"><img border=\"1\" src=\"$LJ::SITEROOT/img/syndicated24x24.gif\" /></div>";
    my $link = $class->clickthru_link("$LJ::SITEROOT/syn/list.bml","syndicated feeds");
    return qq{
        <p>$icon $user, did you know you can add $link to your friends list, and <i>never</i> leave LiveJournal again for your blogging needs?
    };
}

1;
