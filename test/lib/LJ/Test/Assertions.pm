#!/usr/bin/perl
##############################################################################

=head1 NAME

LJ::Test::Assertions - Assertion-function library

=head1 SYNOPSIS

  

=head1 REQUIRES

I<Token requires line>

=head1 DESCRIPTION

None yet.

=head1 AUTHOR

Michael Granger <ged@FaerieMUD.org>

Copyright (c) 2004 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF MERCHANTIBILITY AND
FITNESS FOR A PARTICULAR PURPOSE.

=cut

##############################################################################
package LJ::Test::Assertions;
use strict;
use warnings qw{all};


###############################################################################
###  I N I T I A L I Z A T I O N
###############################################################################
BEGIN {
    ### Versioning stuff and custom includes
    use vars qw{$VERSION $RCSID};
    $VERSION    = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };
    $RCSID  = q$Id$;

    # Export functions
    use base qw{Exporter};
    use vars qw{@EXPORT @EXPORT_OK %EXPORT_TAGS};

    @EXPORT     = qw{};
    %EXPORT_TAGS    = (
        assertions => [qw{
            &assert
            &assert_not
            &assert_defined
            &assert_undef
            &assert_no_exception
            &assert_exception
            &assert_exception_type
            &assert_exception_matches
            &assert_equal
            &assert_equals
            &assert_matches
            &assert_ref
            &assert_not_ref
            &assert_instance_of
            &assert_kind_of

            &fail
        }],

        skip => [qw{
            &skip_one
            &skip_all
        }],
    );

    # Create an 'all' Exporter class which is the union of all the others and
    # then add the symbols it contains to @EXPORT_OK
    {
        my %seen;
        push @{$EXPORT_TAGS{all}},
            grep {!$seen{$_}++} @{$EXPORT_TAGS{$_}} foreach keys %EXPORT_TAGS;
    }
    Exporter::export_ok_tags('all');

    # Require modules
    use Data::Compare   qw{Compare};
    use Scalar::Util    qw{blessed dualvar};
    use Data::Dumper    qw{};
    use Carp            qw{croak confess};

    # Observer pattern
    use vars qw{@Observers};
    @Observers = qw{};
}


#####################################################################
### A S S E R T I O N   F A I L U R E   C L A S S
#####################################################################
{
    package LJ::Test::AssertionFailure;
    use Danga::Exceptions qw{};
    use Carp qw{croak confess};
    use base qw{Danga::Exception};

    our $ErrorType = "assertion failure";

    ### Overridden to unwrap frames from the stacktrace.
    sub new {
        my $proto = shift;
        local $Danga::Exception::Depth = $Danga::Exception::Depth + 2;
        return $proto->SUPER::new( @_ );
    }

    ### METHOD: error()
    ### Override the base class's error message to make sense as an exception
    ### failure.
    sub error {
        my $self = shift;

        my ( $priorframe, $testframe );
        my @frames = $self->stacktrace;

        for ( my $i = 0; $i <= $#frames; $i++ ) {
            next unless $frames[$i]->{package} eq 'LJ::Test::Result';
            ( $priorframe, $testframe ) = @frames[ $i-1, $i ];
            last;
        }

        unless ( $priorframe ) {
            ( $priorframe, $testframe ) = @frames[ 0, 1 ];
        }

        return sprintf( "%s\n\tin %s (%s) line %d\n\t(%s).\n",
                        $self->message,
                        $testframe->{subroutine},
                        $priorframe->{filename},
                        $priorframe->{line},
                        scalar localtime($self->timestamp) );
    }

}



#####################################################################
### F O R W A R D   D E C L A R A T I O N S
#####################################################################

sub assert ($;$);
sub assert_not ($;$);
sub assert_defined ($;$);
sub assert_undef ($;$);
sub assert_no_exception (&;$);
sub assert_exception (&;$);
sub assert_exception_type (&$;$);
sub assert_exception_matches (&$;$);
sub assert_equals ($$;$);
sub assert_matches ($$;$);
sub assert_ref ($$;$);
sub assert_not_ref ($;$);
sub assert_instance_of ($$;$);
sub assert_kind_of ($$;$);

sub fail (;$);

sub skip_one (;$);
sub skip_all (;$);



#####################################################################
### O B S E R V E R   F U N C T I O N S
#####################################################################

### METHOD: add_observer( $observer )
### Add the given object, package, or coderef (I<observer>) to the list of
### observers. When an assertion is called, a notification will be sent to the
### registrant. If the specified I<observer> is an object or a package, the
### C<update> method will be called on it. If the observer is a coderef, the
### coderef itself will be called.
sub add_observer {
    shift if $_[0] eq __PACKAGE__; # Allow this to be called as a method, too.
    my $observer = shift or return;
    push @Observers, $observer;
}


### METHOD: remove_observer( $observer )
### Remove the given I<observer> from the list of observers.
sub remove_observer {
    shift if $_[0] eq __PACKAGE__; # Allow calling as a method
    my $observer = shift or return;
    @Observers = grep { "$observer" ne "$_" } @Observers;
}


### FUNCTION: notify_observers( $type )
### Notify any registered observers that an assertion has been made. The
### I<arguments> will be passed to each observer.
sub notify_observers {
    shift if $_[0] eq __PACKAGE__; # Allow calling as a method

    foreach my $observer ( @Observers ) {
        if ( ref $observer eq 'CODE' ) {
            $observer->( __PACKAGE__, @_ );
        }

        else {
            $observer->update( __PACKAGE__, @_ );
        }
    }
}


sub makeMessage {
    my ( $failureInfo, $fmt, @rawargs ) = @_;
    local $Data::Dumper::Terse = 1;
    my @args = map {
        ref $_
            ? Data::Dumper->Dumpxs([$_], ['_'])
            : (defined $_ ? "$_" : "(undef)")
        } @rawargs;
    my $failureMessage = sprintf( $fmt, @args );

    return $failureInfo
        ? "$failureInfo\n\t$failureMessage"
        : $failureMessage;
}



#####################################################################
### A S S E R T I O N   F U N C T I O N S
#####################################################################

### (ASSERTION) FUNCTION: assert( $value[, $failureInfo] )
### Die with a failure message if the specified value is not true. If the
### optional I<failureInfo> is given, It will precede the failure message.
sub assert ($;$) {
    my ( $assert, $message ) = @_;

    __PACKAGE__->notify_observers( 'assert' );
    $message ||= "Assertion failed: " . (defined $assert ? "'$assert'" : "(undef)");
    throw LJ::Test::AssertionFailure $message unless $assert;
    __PACKAGE__->notify_observers( 'success' );

    return 1;
}

### (ASSERTION) FUNCTION: assert_not( $value[, $failureInfo] )
### Die with a failure message if the specified value B<is> true. If the
### optional I<failureInfo> is given, it will precede the failure message.
sub assert_not ($;$) {
    my ( $assert, $info ) = @_;
    my $message = makeMessage(  $info, "Expected a false value, got '%s'", $assert );
    assert( !$assert, $message );
}

### (ASSERTION) FUNCTION: assert_defined( $value[, $failureInfo] )
### Die with a failure message if the specified value is undefined. If the
### optional I<failureInfo> is given, it will precede the failure message.
sub assert_defined ($;$) {
    my ( $assert, $info ) = @_;
    my $message = makeMessage( $info, "Expected a defined value, got: %s", $assert );
    assert( defined($assert), $message );
}

### (ASSERTION) FUNCTION: assert_undef( $value[, $failureInfo] )
### Die with a failure message if the specified value is defined. If the
### optional I<failureInfo> is given, it will precede the failure message.
sub assert_undef ($;$) {
    my ( $assert, $info ) = @_;
    my $message = makeMessage( $info, "Expected an undefined value, got %s",
                               $assert );
    assert( !defined($assert), $message );
}

### (ASSERTION) FUNCTION: assert_no_exception( \&code[, $failureInfo] )
### Evaluate the specified coderef, and die with a failure message if it
### generates an exception. If the optional I<failureInfo> is given, it will
### precede the failure message.
sub assert_no_exception (&;$) {
    my ( $code, $info ) = @_;

    eval { $code->() };
    ( my $errmsg = $@ ) =~ s{ at .* line \d+\.?\s*$}{};
    my $message = makeMessage( $info, "Exception raised when none expected:\n\t<$errmsg>" );

    assert( ! $@, $message );
}

### (ASSERTION) FUNCTION: assert_exception( \&code[, $failureInfo] )
### Evaluate the specified I<coderef>, and die with a failure message if it does
### not generate an exception. If the optional I<failureInfo> is given, it will
### precede the failure message.
sub assert_exception (&;$) {
    my ( $code, $info ) = @_;

    eval { $code->() };
    assert( $@, makeMessage($info, "No exception raised.") );
}

### (ASSERTION) FUNCTION: assert_exception_type( \&code, $type[, $failureInfo] )
### Evaluate the specified I<coderef>, and die with a failure message if it does
### not generate an exception which is an object blessed into the specified
### I<type> or one of its subclasses (ie., the exception must return true to
### C<$exception->isa($type)>.  If the optional I<failureInfo> is given, it will
### precede the failure message.
sub assert_exception_type (&$;$) {
    my ( $code, $type, $info ) = @_;

    eval { $code->() };
    assert $@, makeMessage($info, "Expected an exception of type '$type', but none was raised.");

    my $message = makeMessage( $info, "Exception thrown, but was wrong type" );
    assert_kind_of( $type, $@, $message );
}

### (ASSERTION) FUNCTION: assert_exception_matches( \&code, $regex[, $failureInfo] )
### Evaluate the specified I<coderef>, and die with a failure message if it does
### not generate an exception which matches the specified I<regex>.  If the
### optional I<failureInfo> is given, it will precede the failure message.
sub assert_exception_matches (&$;$) {
    my ( $code, $regex, $info ) = @_;

    eval { $code->() };
    assert $@, makeMessage($info, "Expected an exception which matched <$regex>, but none was raised.");
    my $err = "$@";

    my $message = makeMessage( $info, "Exception thrown, but message didn't match" );
    assert_matches( $regex, $err, $message );
}


### (ASSERTION) FUNCTION: assert_equal( $wanted, $tested[, $failureInfo] )
### Die with a failure message if the specified wanted value doesn't equal the
### specified tested value. The comparison is done with Data::Compare, so
### arbitrarily complex data structures may be compared, as long as they contain
### no GLOB, CODE, or REF references. If the optional I<failureInfo> is
### given, it will precede the failure message.
sub assert_equal ($$;$) {
    my ( $wanted, $tested, $info ) = @_;

    my $message = makeMessage( $info, "Values not equal: wanted '%s', got '%s' instead",
                               $wanted, $tested );
    assert( Compare($wanted, $tested), $message );
}
*assert_equals = *assert_equal;


### (ASSERTION) FUNCTION: assert_matches( $wantedRegexp, $testedValue[, $failureInfo] )
### Die with a failure message if the specified tested value doesn't match
### the specified wanted regular expression. If the optional I<failureInfo> is
### given, it will precede the failure message.
sub assert_matches ($$;$) {
    my ( $wanted, $tested, $info ) = @_;

    if ( ! blessed $wanted || ! $wanted->isa('Regexp') ) {
        $wanted = qr{$wanted};
    }

    my $message = makeMessage( $info, "Tested value '%s' did not match wanted regex '%s'",
                               $tested, $wanted );
    assert( ($tested =~ $wanted), $message );
}

### (ASSERTION) FUNCTION: assert_ref( $wantedType, $testedValue[, $failureInfo] )
### Die with a failure message if the specified testedValue is not of the
### specified wantedType. The wantedType can either be a ref-type like 'ARRAY'
### or 'GLOB' or a package name for testing object classes.  If the optional
### I<failureInfo> is given, it will precede the failure message.
sub assert_ref ($$;$) {
    my ( $wantedType, $testValue, $info ) = @_;

    my $message = makeMessage( $info, "Expected a %s reference, got <%s>",
                               $wantedType, $testValue );

    assert( ref $testValue &&
            (ref $testValue eq $wantedType || UNIVERSAL::isa($wantedType, $testValue)),
            $message );
}


### (ASSERTION) FUNCTION: assert_not_ref( $testedValue[, $failureInfo] )
### Die with a failure message if the specified testedValue is a reference of
### any kind. If the optional I<failureInfo> is given, it will precede the
### failure message.
sub assert_not_ref ($;$) {
    my ( $testValue, $info ) = @_;

    my $message = makeMessage( $info, "Expected a simple scalar, got <%s>", $testValue );
    assert( !ref $testValue, $message );
}


### (ASSERTION) FUNCTION: assert_instance_of( $wantedClass, $testedValue[, $failureInfo] )
### Die with a failure message if the specified testedValue is not an instance
### of the specified wantedClass. If the optional I<failureInfo> is given, it will
### precede the failure message.
sub assert_instance_of ($$;$) {
    my ( $wantedClass, $testValue, $info ) = @_;

    my $message = makeMessage( $info, "Expected an instance of '%s', got a non-object <%s>",
                               $wantedClass, $testValue );
    assert( blessed $testValue, $message );

    $message = makeMessage( $info, "Expected an instance of '%s'", $wantedClass );
    assert_equals( $wantedClass, ref $testValue, $message );
}


### (ASSERTION) FUNCTION: assert_kind_of( $wantedClass, $testedValue[, $failureInfo] )
### Die with a failure message if the specified testedValue is not an instance
### of the specified wantedClass B<or> one of its derivatives. If the optional
### I<failureInfo> is given, it will precede the failure message.
sub assert_kind_of ($$;$) {
    my ( $wantedClass, $testValue, $info ) = @_;

    my $message = makeMessage( $info, "Expected an instance of '%s' or a subclass, got <%s>",
                               $wantedClass, $testValue );
    assert( blessed $testValue, $message );
    assert( $testValue->isa($wantedClass), $message );
}


### (ASSERTION) FUNCTION: fail( [$failureInfo] )
### Die with a failure message unconditionally. If the optional I<failureInfo>
### is given, it will precede the failure message.
sub fail (;$) {
    my $message = shift || "Failed (no reason given)";
    __PACKAGE__->notify_observers( 'assert' );
    throw LJ::Test::AssertionFailure $message;
}


### (SKIP) FUNCTION: skip_one( [$message] )
### Skip the rest of this test, optionally outputting a message as to why the
### rest of the test was skipped.
sub skip_one (;$) {
    my $message = shift || '';
    die bless \$message, 'SKIPONE';
}


### (SKIP) FUNCTION: skip_all( [$message] )
### Skip all the remaining tests, optionally outputting a message as to why the
### they were skipped.
sub skip_all (;$) {
    my $message = shift || '';
    die bless \$message, 'SKIPALL';
}




### Destructors
DESTROY {}
END {}


1;


