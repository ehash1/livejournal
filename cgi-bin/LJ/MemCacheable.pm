package LJ::MemCacheable;

use strict;
use warnings;
use LJ::MemCacheProxy;
use String::CRC32 qw/crc32/;

##
## Mixin class for objects to be stored in Memcache
## See LJ::MemCache and LJ::User::memcache_set_u/memcache_get_u for idea
##
## Derived classes must implement the following methods:
## _memcache_id                 { $_[0]->userid                 }
## _memcache_key_prefix         { "user"                        }
## _memcache_stored_props       { qw/$VERSION name age caps /   }
## _memcache_hashref_to_object  { LJ::User->new_from_row($_[0]) } 
## _memcache_expires            { 24*3600                       }
##
## In many cases you can use aliases for subs, e.g.:
##  *_memcache_hashref_to_object = \&new_from_row;
##

##
## Memcache routines
##
sub _store_to_memcache {
    my $self = shift;

    my ($version, @props) = $self->_memcache_stored_props; 
    my @data = $version;
    foreach my $key (@props) {
        push @data, $self->{$key};
    }
    LJ::MemCacheProxy::set($self->_memcache_key, \@data, $self->_memcache_expires);
}

sub _load_from_memcache {
    my $class = shift;
    my $id = shift;

    my $data = LJ::MemCacheProxy::get($class->_memcache_key($id));
    return unless $data && ref $data eq 'ARRAY';
    
    my ($version, @props) = $class->_memcache_stored_props;
    ## check if memcache contains data with actual version
    return unless $data->[0]==$version;
    my %hash;
    foreach my $i (0..$#props) {
        $hash{ $props[$i] } = $data->[$i+1];
    }
    return $class->_memcache_hashref_to_object(\%hash);
}

## warning: instance or class method. 
## $id may be absent when calling on instance.
sub _remove_from_memcache {
    my $class = shift;
    my $id = shift;
    LJ::MemCacheProxy::delete($class->_memcache_key($id));
}

sub _memcache_key {
    my $class = shift;
    my $id = shift || $class->_memcache_id;
    my $prefix = $class->_memcache_key_prefix;
    if ($id =~ /^\d+$/) {
        return [$id, "$prefix:$id"];
    }
    else{
        return [(crc32($id) >> 16) & 0x7fff, "$prefix:$id"];
    }
}

1;

