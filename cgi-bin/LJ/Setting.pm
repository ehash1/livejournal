package LJ::Setting;
use strict;
use warnings;
use Carp qw(croak);
use LJ::ModuleLoader;

# Autouse all settings
LJ::ModuleLoader->autouse_subclasses("LJ::Setting");
use LJ::Setting::WebmasterTools;
use LJ::Setting::WebmasterTools::Yandex;

# ----------------------------------------------------------------------------

my $is_savebutton_hide = 0;
my $veiwonly_mode = 0;

sub should_render { 1 }
sub disabled { 0 }
sub selected { 0 }
sub tags { () }
sub label { "" }
sub actionlink { "" }
sub helpurl { "" }
sub option { "" }
sub htmlcontrol { "" }
sub htmlcontrol_label { "" }
sub raw_html          { "" }
sub is_savebutton_hide { return $is_savebutton_hide; }
sub hide_savebutton { $is_savebutton_hide = 1; }
sub show_savebutton { $is_savebutton_hide = 0; }
sub is_viewonly_mode { return $veiwonly_mode; }
sub start_viewonly {
    LJ::need_var(no_submit_window => 1);
    $veiwonly_mode = 1;
    hide_savebutton();
}
sub cancel_viewonly {
    $veiwonly_mode = 0;
    show_savebutton();
}


sub handle_post {
    my ( $class, $params, $widget ) = @_;
    delete @$params{qw/lj_form_auth _widget_id _widget_ippu _widget_class/};

    my %res;

    eval {
        %res = $widget->save(LJ::get_remote(), $params);
    };

    return %res;
}

sub form_start {
    my $self = shift;

    return '<form action="javascript: return false" id="settingwindow_form">'
      . '<input type="hidden" name="_widget_class" value="'
      . (  ref($self) || $self )
      . '">'
      # hidden for posting submit button (form can have several submit buttons)
      . '<input type="hidden" id="form_submit" name="submit" value="">' ;
}

sub form_end {
    return '</form>';
}

sub form_auth {
    return LJ::form_auth();
}

sub error_check {
    my ($class, $u, $args) = @_;
    my $val = $class->get_arg($args, "foo");

    die "No 'error_check' configured for settings module '$class'\n";
}

sub as_html {
    my ($class, $u, $errmap) = @_;
    return "No 'as_html' implemented for $class.";
}

sub save {
    my ($class, $u, $postargs, @classes) = @_;
    if ($class ne __PACKAGE__) {
        die "No 'save' implemented for '$class'\n";
    } else {
        die "No classes given to save\n" unless @classes;
    }

    my %posted;  # class -> key -> value
    while (my ($k, $v) = each %$postargs) {
        next unless $k =~ /^LJ__Setting__([a-zA-Z0-9]+)_(\w+)$/;
        my $class = "LJ::Setting::$1";
        my $key = $2;
        $posted{$class}{$key} = $v;
    }

    foreach my $setclass (@classes) {
        my $args = $posted{$setclass} || {};
        $setclass->save($u, $args);
    }
}

# ----------------------------------------------------------------------------

# Don't override:

sub pkgkey {
    my $class = shift;
    $class =~ s/::/__/g;
    return $class . "_";
}

sub errdiv {
    my ($class, $errs, $key) = @_;
    return "" unless $errs;

    # $errs can be a hashref of { $class => LJ::Error::SettingSave::Foo } or a map of
    # { $errfield => $errtxt }.  this converts the former to latter.
    if (my $classerr = $errs->{$class}) {
        $errs = $classerr->field('map');
    }

    my $err = $errs->{$key}   or return "";
    # TODO: red is temporary.  move to css.
    return "<div style='color: red' class='ljinlinesettingerror'>$err</div>";
}

# don't override this.
sub errors {
    my ($class, %map) = @_;

    my $errclass = $class;
    $errclass =~ s/^LJ::Setting:://;
    $errclass = "LJ::Error::SettingSave::" . $errclass;

    eval {
        no strict 'refs';
        @{"${errclass}::ISA"} = ('LJ::Error::SettingSave');
    };

    warn $@ if $@;

    my $eo = eval { $errclass->new(map => \%map) };
    $eo->log;
    $eo->throw;
}

# gets a key out of the $args hash, which can be either \%POST or a class-specific one
sub get_arg {
    my ($class, $args, $which) = @_;
    my $key = $class->pkgkey;
    return $args->{"${key}$which"} || $args->{$which} || "";
}

# called like:
#   LJ::Setting->error_map($u, \%POST, @multiple_setting_classnames)
# or:
#   LJ::Setting::SpecificOption->error_map($u, \%POST)
# returns:
#   undef if no errors found,
#   LJ::SettingErrors object if any errors.
sub error_map {
    my ($class, $u, $post, @classes) = @_;
    if ($class ne __PACKAGE__) {
        croak("Can't call error_map on LJ::Setting subclass with \@classes set.") if @classes;
        @classes = ($class);
    }

    my %errors;
    foreach my $setclass (@classes) {
        my $okay = eval {
            $setclass->error_check($u, $post);
        };
        next if $okay;
        $errors{$setclass} = $@;
    }
    return undef unless %errors;
    return \%errors;
}

# save all of the settings that were changed
# $u: user whose settings we're changing
# $post: reference to %POST hash
# $all_settings: reference to array of all settings that are on this page
# returns any errors and the post args for each setting
sub save_all {
    shift if $_[0] eq __PACKAGE__;
    my ($u, $post, $all_settings) = @_;
    my %posted;  # class -> key -> value
    my %returns;

    while (my ($k, $v) = each %$post) {
        # matches both:
        # LJ__Setting__Example_field (for LJ::Setting::Example)
        # LJ__Setting__Example__Example2_field (for LJ::Setting::Example::Example2)
        next unless $k =~ /^LJ__Setting__([a-zA-Z0-9]+)(__[a-zA-Z0-9]+)?_(\w+)$/;
        my $class = "LJ::Setting::$1";
        $class .= $2 if defined $2;
        my $key = $3;
        $class =~ s/__/::/g;
        $posted{$class}{$key} = $v;
    }

    foreach my $class (@$all_settings) {
        my $post_args = $posted{$class};
        $post_args ||= {};
        my $save_errors;
        if ($post_args) {
            my $sv = eval {
                $class->save($u, $post_args);
            };
            if (my $err = $@) {
                require Data::Dumper;
                $save_errors = $err->field('map') if ref $err;
            }
        }

        $returns{$class}{save_errors} = $save_errors;
        $returns{$class}{post_args} = $post_args;
    }

    return \%returns;
}

sub save_had_errors {
    my $class = shift;
    my $save_rv = shift;
    return 0 unless ref $save_rv;

    my @settings = @_; # optional, for specific settings
    @settings = keys %$save_rv unless @settings;

    foreach my $setting (@settings) {
        my $errors = $save_rv->{$setting}->{save_errors} || {};
        return 1 if %$errors;
    }

    return 0;
}

sub errors_from_save {
    my $class = shift;
    my $save_rv = shift;

    return $save_rv->{$class}->{save_errors};
}

sub args_from_save {
    my $class = shift;
    my $save_rv = shift;

    return $save_rv->{$class}->{post_args};
}

sub ml {
    my ($class, $code, $vars) = @_;

    # can pass in a string and check 2 places in order:
    # 1) setting.foo.text => general .setting.foo.text (overridden by current page)
    # 2) setting.foo.text => general setting.foo.text  (defined in en(_LJ).dat)

    # whether passed with or without a ".", eat that immediately
    $code =~ s/^\.//;

    # 1) try with a ., for current page override in 'general' domain
    # 2) try without a ., for global version in 'general' domain
    foreach my $curr_code (".$code", $code) {
        my $string = LJ::Lang::ml($curr_code, $vars);
        return "" if $string eq "_none";
        return $string unless LJ::Lang::is_missing_string($string);
    }

    # return the class name if we didn't find anything
    $class =~ /.+::(\w+)$/;
    return $1;
}

package LJ::Error::SettingSave;
use base 'LJ::Error';

sub user_caused { 1 }
sub fields      { qw(map); }  # key -> english  (keys are LJ::Setting:: subclass-defined)

sub as_string {
    my $self = shift;
    my $map   = $self->field('map');
    return join(", ", map { $_ . '=' . $map->{$_} } sort keys %$map);
}

1;
