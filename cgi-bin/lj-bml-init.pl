package LJ;
use strict;

use lib "$ENV{LJHOME}/cgi-bin";
use POSIX qw(ENOENT);
use LJ::Config;
LJ::Config->load;
use LJ::Request;

foreach (@LJ::LANGS, @LJ::LANGS_IN_PROGRESS) {
    BML::register_isocode(substr($_, 0, 2), $_);
    BML::register_language($_);
}

# set default path/domain for cookies
BML::set_config("CookieDomain" => $LJ::COOKIE_DOMAIN);
BML::set_config("CookiePath"   => $LJ::COOKIE_PATH);

BML::register_hook("startup", sub {
    my $uri = "bml" . LJ::Request->uri;
    unless ($uri =~ s/\.bml$//) {
        $uri .= ".index";
    }
    $uri =~ s!/!.!g;
    LJ::Request->notes("codepath" => $uri);
});

BML::register_hook("codeerror", sub {
    my $msg = shift;

    my $err = LJ::errobj($msg)       or return;
    $err->log;
    $msg = $err->as_html;

    chomp $msg;
    $msg .= " \@ $LJ::SERVER_NAME" if $LJ::SERVER_NAME;
    warn "$msg\n";

    my $remote = LJ::get_remote();
    if (($remote && $remote->show_raw_errors) || $LJ::IS_DEV_SERVER) {
        return "<pre>" . LJ::ehtml("[Error: $msg]") . "</pre>";
    } else {
        return $LJ::MSG_ERROR || "Sorry, there was a problem.";
    }
});

if ($LJ::UNICODE) {
    BML::set_config("DefaultContentType", "text/html; charset=utf-8");
}

# register BML multi-language hook
BML::register_hook("ml_getter", \&LJ::Lang::get_text);

# include file handling
BML::register_hook('include_getter', sub {
    # simply call LJ::load_include, as it does all the work of hitting up
    # memcache/db for us and falling back to disk if necessary...
    my ($file, $source) = @_;
    $$source = LJ::load_include($file);
    return 1;
});

# Allow scheme override to be defined as a code ref or an explicit string value
BML::register_hook('default_scheme_override', sub {
    my $current_scheme = shift;

    my $override = $LJ::BML_SCHEME_OVERRIDE{$current_scheme};
    return LJ::conf_test($override) if defined $override;

    return LJ::conf_test($LJ::SCHEME_OVERRIDE);
});

# extra perl to insert at the beginning of a code block
# compilation
BML::register_hook("codeblock_init_perl", sub {
    return q{
        *errors = *BMLCodeBlock::errors;
        *warnings = *BMLCodeBlock::warnings;
    };
});

# now apply any local behaviors which may be defined
eval { require "lj-bml-init-local.pl" };
die $@ if $@ && $! != ENOENT;

1;
