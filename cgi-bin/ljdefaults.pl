#!/usr/bin/perl
#
# Do not edit this file.  You should edit ljconfig.pl, which you should have at
# cgi-bin/ljconfig.pl.  If you don't, copy it from doc/ljconfig.pl.txt to cgi-bin
# and edit it there.  This file only provides backup default values for upgrading.
#

{
    package LJ;

    $HOME = $ENV{'LJHOME'};
    $HTDOCS = "$HOME/htdocs";
    $BIN = "$HOME/bin";
    $TEMP = "$HOME/temp";
    $VAR = "$HOME/var";

    $SITEROOT ||= "http://www.$DOMAIN:8011";
    $IMGPREFIX ||= "$SITEROOT/img";    

    # where the directory is at (in old installations it could be at /directory.sbml)
    $DIRURI = "/directory.bml";

    # path to sendmail and any necessary options
    $SENDMAIL ||= "/usr/sbin/sendmail -t";

    # where we set the cookies (note the period before the domain)
    $COOKIE_DOMAIN ||= ".$DOMAIN";
    $COOKIE_PATH   ||= "/";

    ## default portal options
    @PORTAL_COLS = qw(main right moz) unless (@PORTAL_COLS);

    $PORTAL_URI ||= "/portal/";           # either "/" or "/portal/"    

    $PORTAL_LOGGED_IN ||= {'main' => [ 
                                     [ 'update', 'mode=full'],
                                     ],
                         'right' => [ 
                                      [ 'goat', '', ],
                                      [ 'stats', '', ],
                                      [ 'bdays', '', ],
                                      ] };
    $PORTAL_LOGGED_OUT ||= {'main' => [ 
                                      [ 'update', 'mode='],
                                      ],
                          'right' => [ 
                                       [ 'newtolj', '', ],
                                       [ 'login', '', ],
                                       [ 'stats', '', ],
                                       [ 'randuser', '', ],
                                       ],
                          'moz' => [
                                    [ 'login', '', ],
                                    ],
                          };

   
    $MAX_HINTS_LASTN ||= 100;
    $MAX_SCROLLBACK_LASTN ||= 400;

    $RECENT_SPAN ||= 14;

    # set default capability limits if the site maintainer hasn't.
    {
        my %defcap = (
                      'checkfriends' => 1,
                      'checkfriends_interval' => 60,
                      'friendsviewupdate' => 30,
                      'makepoll' => 1,
                      'maxfriends' => 500,
                      'moodthemecreate' => 1,
                      'styles' => 1,
                      'textmessage' => 1,
                      'todomax' => 100,
                      'todosec' => 1,
                      'userdomain' => 0,
                      'useremail' => 0,
                      'userpics' => 5,
                      'findsim' => 1,
                      );
        foreach my $k (keys %defcap) {
            next if (defined $LJ::CAP_DEF{$k});
            $LJ::CAP_DEF{$k} = $defcap{$k};	    
        }
    }

    # set default userprop limits if site maintainer hasn't
    {
        my %defuser = (
                       's1_lastn_style' => 1,
                       's1_friends_style' => 6,
                       's1_calendar_style' => 2,
                       's1_day_style' => 5,
                       );
        foreach my $k (keys %defuser) {
            next if (defined $LJ::USERPROP_DEF{$k});
            $LJ::USERPROP_DEF{$k} = $defuser{$k};
        }
    }
}

# no dependencies.
# <LJDEP>
# </LJDEP>

return 1;
