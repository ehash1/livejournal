package LJ::Widget::ThemeChooser;

use strict;
use base qw(LJ::Widget);
use Carp qw(croak);
use Class::Autouse qw( LJ::S2Theme LJ::Customize );

sub ajax { 1 }
sub authas { 1 }
sub need_res { qw( stc/widgets/themechooser.css ) }

sub render_body {
    my $class = shift;
    my %opts = @_;

    my $u = $class->get_effective_remote();
    die "Invalid user." unless LJ::isu($u);

    my $remote = LJ::get_remote();
    my $getextra = $u->user ne $remote->user ? "?authas=" . $u->user : "";
    my $getsep = $getextra ? "&amp;" : "?";

    # filter criteria
    my $cat = defined $opts{cat} ? $opts{cat} : "";
    my $layoutid = defined $opts{layoutid} ? $opts{layoutid} : 0;
    my $designer = defined $opts{designer} ? $opts{designer} : "";
    my $search = defined $opts{search} ? $opts{search} : "";
    my $filter_available = defined $opts{filter_available} ? $opts{filter_available} : 0;
    my $page = $opts{page} || 1;
    my $show = $opts{show} || 12;

    my $filterarg = $filter_available ? "&amp;filter_available=1" : "";
    my $showarg = $show != 12 ? "&amp;show=$opts{show}" : "";

    my $viewing_featured = !$cat && !$layoutid && !$designer;

    my %cats = LJ::Customize->get_cats($u);
    my $ret .= "<div class='theme-selector-content pkg'>";
    $ret .= "<script>Customize.ThemeChooser.confirmation = \"" . $class->ml('widget.themechooser.confirmation') . "\";</script>";

    my @getargs;
    my @themes;
    if ($cat eq "all") {
        push @getargs, "cat=all";
        @themes = LJ::S2Theme->load_all($u);
    } elsif ($cat eq "custom") {
        push @getargs, "cat=custom";
        @themes = LJ::S2Theme->load_by_user($u);
    } elsif ($cat eq "purchased") {
        push @getargs, "cat=purchased";
        @themes = LJ::S2Theme->load_purchased($u);
    } elsif ($cat) {
        push @getargs, "cat=$cat";
        @themes = LJ::S2Theme->load_by_cat($cat);
    } elsif ($layoutid) {
        push @getargs, "layoutid=$layoutid";
        @themes = LJ::S2Theme->load_by_layoutid($layoutid, $u);
    } elsif ($designer) {
        push @getargs, "designer=" . LJ::eurl($designer);
        @themes = LJ::S2Theme->load_by_designer($designer);
    } elsif ($search) {
        push @getargs, "search=" . LJ::eurl($search);
        @themes = LJ::S2Theme->load_by_search($search, $u);
    } else { # category is "featured"
        @themes = LJ::S2Theme->load_by_cat("featured");
    }

    if ($filter_available) {
        push @getargs, "filter_available=$filter_available";
        @themes = LJ::S2Theme->filter_available($u, @themes);
    }

    if ($show != 12) {
        push @getargs, "show=$show";
    }

    @themes = LJ::Customize->remove_duplicate_themes(@themes);

    # sort themes with custom at the end, then alphabetically
    @themes =
        sort { $a->is_custom <=> $b->is_custom }
        sort { lc $a->name cmp lc $b->name } @themes;

    LJ::run_hooks("modify_theme_list", \@themes, user => $u, cat => $cat);

    # remove any themes from the array that are not defined or whose layout or theme is not active
    for (my $i = 0; $i < @themes; $i++) {
        my $layout_is_active = LJ::run_hook("layer_is_active", $themes[$i]->layout_uniq);
        my $theme_is_active = LJ::run_hook("layer_is_active", $themes[$i]->uniq);

        unless ((defined $themes[$i]) &&
            (!defined $layout_is_active || $layout_is_active) &&
            (!defined $theme_is_active || $theme_is_active)) {

            splice(@themes, $i, 1);
            $i--; # we just removed an element from @themes
        }
    }

    my $current_theme = LJ::Customize->get_current_theme($u);
    my $index_of_first_theme = $show ne "all" ? $show * ($page - 1) : 0;
    my $index_of_last_theme = $show ne "all" ? ($show * $page) - 1 : scalar @themes - 1;
    my @themes_this_page = @themes[$index_of_first_theme..$index_of_last_theme];

    if ($cat eq "all") {
        $ret .= "<h3>" . $class->ml('widget.themechooser.header.all') . "</h3>";
    } elsif ($cat eq "custom") {
        $ret .= "<h3>" . $class->ml('widget.themechooser.header.custom') . "</h3>";
    } elsif ($cat) {
        $ret .= "<h3>$cats{$cat}->{text}</h3>";
    } elsif ($layoutid) {
        my $layout_name = LJ::Customize->get_layout_name($layoutid, user => $u);
        $ret .= "<h3>$layout_name</h3>";
    } elsif ($designer) {
        $ret .= "<h3>$designer</h3>";
    } elsif ($search) {
        $ret .= "<h3>" . $class->ml('widget.themechooser.header.search', {'term' => LJ::ehtml($search)}) . "</h3>";
    } else { # category is "featured"
        $ret .= "<h3>$cats{featured}->{text}</h3>";
    }

    $ret .= $class->print_paging(
        themes => \@themes,
        show => $show,
        page => $page,
        getargs => \@getargs,
        getextra => $getextra,
        location => "top",
    );

    $ret .= "<div class='themes-area'>";
    my @purchased = LJ::S2Theme->load_purchased ($u);
    @themes_this_page = grep { $_ } @themes_this_page;
    if (!@themes_this_page && $cat eq 'purchased') {
        $ret .= LJ::Lang::ml('widget.themechooser.no_paurchased_themes');
    }
    foreach my $theme (@themes_this_page) {
        next unless defined $theme;

        my $is_bought = 0;
        my $shop_theme = LJ::Pay::Theme->load_by_s2lid ($theme->s2lid);
        if ($theme->is_buyable) {
            $is_bought = 1 if grep { $shop_theme && $_->s2lid == $shop_theme->s2tid } @purchased;
            next if $shop_theme && $shop_theme->is_bought_out && !$is_bought;
            next if $shop_theme && $shop_theme->is_disabled && !$is_bought;
        }

        # figure out the type(s) of theme this is so we can modify the output accordingly
        my %theme_types;
        if ($theme->themeid) {
            $theme_types{current} = 1 if $theme->themeid == $current_theme->themeid;
        } elsif (!$theme->themeid && !$current_theme->themeid) {
            $theme_types{current} = 1 if $theme->layoutid == $current_theme->layoutid;
        }
        $theme_types{upgrade} = 1 if !$is_bought && !$filter_available && !$theme->available_to($u);
        $theme_types{special} = 1 if LJ::run_hook("layer_is_special", $theme->uniq);
        $theme_types{shop_item} = 1 if !$is_bought && !$theme_types{current} && $theme->is_buyable;

        
        my ($theme_class, $theme_options, $theme_icons) = ("", "", "");
        
        $theme_icons .= "<div class='theme-icons'>" if $theme_types{upgrade} || $theme_types{special};
        if ($theme_types{current}) {
            my $no_layer_edit = LJ::run_hook("no_theme_or_layer_edit", $u);

            $theme_class .= " current";
            $theme_options .= "<strong><a href='$LJ::SITEROOT/customize/options.bml$getextra'>" . $class->ml('widget.themechooser.theme.customize') . "</a></strong>";
            if (! $no_layer_edit && $theme->is_custom && !$theme_types{upgrade}) {
                if ($theme->layoutid && !$theme->layout_uniq) {
                    $theme_options .= "<br /><strong><a href='$LJ::SITEROOT/customize/advanced/layeredit.bml?id=" . $theme->layoutid . "'>" . $class->ml('widget.themechooser.theme.editlayoutlayer') . "</a></strong>";
                }
                if ($theme->themeid && !$theme->uniq) {
                    $theme_options .= "<br /><strong><a href='$LJ::SITEROOT/customize/advanced/layeredit.bml?id=" . $theme->themeid . "'>" . $class->ml('widget.themechooser.theme.editthemelayer') . "</a></strong>";
                }
            }
        }
        if ($theme_types{upgrade}) {
            $theme_class .= " upgrade";
            $theme_options .= "<br />" if $theme_options;
            $theme_options .= LJ::run_hook("customize_special_options", $u, $theme);
            $theme_icons .= LJ::run_hook("customize_special_icons", $u, $theme);
        }
        if ($theme_types{special}) {
            $theme_class .= " special" if $viewing_featured && LJ::run_hook("should_see_special_content", $u);
            $theme_icons .= LJ::run_hook("customize_available_until", $theme);
        }
        if ($theme_types{shop_item}) {
            $theme_class .= " shop-item";
            $theme_options .= LJ::run_hook("customize_shop_item_options", $u, $theme);
        }
        $theme_icons .= "</div><!-- end .theme-icons -->" if $theme_icons;

        my $theme_layout_name = $theme->layout_name;
        my $theme_designer = $theme->designer;

        $ret .= "<div class='theme-item$theme_class'><div class='theme-item-in'>";
        $ret .= "<img src='" . $theme->preview_imgurl . "' class='theme-preview' alt='' />";
        $ret .= "<h4>" . $theme->name . "</h4>";

        my $preview_redirect_url;
        if ($theme->themeid) {
            $preview_redirect_url = "$LJ::SITEROOT/customize/preview_redirect.bml$getextra${getsep}themeid=" . $theme->themeid;
        } else {
            $preview_redirect_url = "$LJ::SITEROOT/customize/preview_redirect.bml$getextra${getsep}layoutid=" . $theme->layoutid;
        }
        $ret .= "<a href='$preview_redirect_url' target='_blank' class='theme-preview-link' title='" . $class->ml('widget.themechooser.theme.preview') . "'>";

        $ret .= "<img src='$LJ::IMGPREFIX/customize/preview-theme.gif?v=12565' class='theme-preview-image' alt='' /></a>";
        $ret .= $theme_icons;

        my $layout_link = "<a href='$LJ::SITEROOT/customize/$getextra${getsep}layoutid=" . $theme->layoutid . "$filterarg$showarg' class='theme-layout'><em>$theme_layout_name</em></a>";
        my $special_link_opts = "href='$LJ::SITEROOT/customize/$getextra${getsep}cat=special$filterarg$showarg' class='theme-cat'";
        $ret .= "<p class='theme-desc'>";
        if ($theme_designer) {
            my $designer_link = "<a href='$LJ::SITEROOT/customize/$getextra${getsep}designer=" . LJ::eurl($theme_designer) . "$filterarg$showarg' class='theme-designer'>$theme_designer</a>";
            if ($theme_types{special}) {
                if (my %opts = $theme->sponsor_url_opts) {
                    my $aopts = '';
                    while (my ($k, $v) = each %opts) {
                        $aopts .= "$k='" . LJ::ehtml($v) . "' ";
                    }
                    $designer_link = "<a $aopts>$theme_designer</a>";
                }
                $ret .= $class->ml('widget.themechooser.theme.specialdesc', {'aopts' => $special_link_opts, 'designer' => $designer_link});
            } else {
                $ret .= $class->ml('widget.themechooser.theme.desc', {'layout' => $layout_link, 'designer' => $designer_link});
            }
        } elsif ($theme_layout_name) {
            $ret .= $layout_link;
        }
        $ret .= "</p>";

        if ($theme_options) {
            $ret .= "<div class='theme-options'>" . $theme_options . "</div>";
        } else { # apply theme form
            $ret .= $class->start_form( class => "theme-form" );
            $ret .= $class->html_hidden(
                apply_themeid => $theme->themeid,
                apply_layoutid => $theme->layoutid,
            );
            $ret .= $class->html_submit(
                apply => $class->ml('widget.themechooser.theme.apply'),
                { raw => "class='theme-button' id='theme_btn_" . $theme->layoutid . $theme->themeid . "'" },
            );
            $ret .= $class->end_form;
        }
        $ret .= "</div></div><!-- end .theme-item -->";
    }
    $ret .= "</div><!-- end .themes-area --->";

    $ret .= $class->print_paging(
        themes => \@themes,
        show => $show,
        page => $page,
        getargs => \@getargs,
        getextra => $getextra,
        location => "bottom",
    );

    $ret .= "</div><!-- end .theme-selector-content -->";

    return $ret;
}

sub print_paging {
    my $class = shift;
    my %opts = @_;

    my $themes = $opts{themes};
    my $page = $opts{page};
    my $show = $opts{show};
    my $location = $opts{location};

    my $max_page = $show ne "all" ? POSIX::ceil(scalar(@$themes) / $show) || 1 : 1;

    my $getargs = $opts{getargs};
    my $getextra = $opts{getextra};

    my $q_string = join("&amp;", @$getargs);
    my $q_sep = $q_string ? "&amp;" : "";
    my $getsep = $getextra ? "&amp;" : "?";

    my $url = "$LJ::SITEROOT/customize/$getextra$getsep$q_string$q_sep";

    my $ret;

    $ret .= "<div class='theme-paging theme-paging-$location'>";
    unless ($page == 1 && $max_page == 1) {
        if ($page - 1 >= 1) {
            $ret .= "<span class='item'><a href='${url}page=1' class='theme-page'>&lt;&lt;</a></span>";
            $ret .= "<span class='item'><a href='${url}page=" . ($page - 1) . "' class='theme-page'>&lt;</a></span>";
        } else {
            $ret .= "<span class='item'>&lt;&lt;</span>";
            $ret .= "<span class='item'>&lt;</span>";
        }

        my @pages;
        foreach my $pagenum (1 .. $max_page) {
            push @pages, $pagenum, $pagenum;
        }
        my $currentpage = LJ::Widget::ThemeNav->html_select(
            { name => "page",
            id => "page_dropdown_$location",
            selected => $page, },
            @pages,
        );

        $ret .= $class->start_form;
        $ret .= "<span class='item'>" . $class->ml('widget.themechooser.page') . " ";
        $ret .= $class->ml('widget.themechooser.page.maxpage', { currentpage => $currentpage, maxpage => $max_page }) . " ";
        $ret .= "<noscript>" . LJ::Widget::ThemeNav->html_submit( page_dropdown_submit => $class->ml('widget.themechooser.btn.page') ) . "</noscript></span>";
        $ret .= $class->end_form;

        if ($page + 1 <= $max_page) {
            $ret .= "<span class='item'><a href='${url}page=" . ($page + 1) . "' class='theme-page'>&gt;</a></span>";
            $ret .= "<span class='item'><a href='${url}page=$max_page' class='theme-page'>&gt;&gt;</a></span>";
        } else {
            $ret .= "<span class='item'>&gt;</span>";
            $ret .= "<span class='item'>&gt;&gt;</span>";
        }

        $ret .= "<span class='item'>|</span>";
    }

    my @shows = qw( 6 6 12 12 24 24 48 48 96 96 all All );

    $ret .= $class->start_form;
    $ret .= "<span class='item'>" . $class->ml('widget.themechooser.show') . " ";
    $ret .= LJ::Widget::ThemeNav->html_select(
        { name => "show",
        id => "show_dropdown_$location",
        selected => $show, },
        @shows,
    ) . " ";
    $ret .= "<noscript>" . LJ::Widget::ThemeNav->html_submit( show_dropdown_submit => $class->ml('widget.themechooser.btn.show') ) . "</noscript></span>";
    $ret .= $class->end_form;

    $ret .= " <span id='paging_msg_area_$location'></span>";
    $ret .= "</div>";

    return $ret;
}

sub handle_post {
    my $class = shift;
    my $post = shift;
    my %opts = @_;

    my $u = $class->get_effective_remote();
    die "Invalid user." unless LJ::isu($u);

    my $themeid = $post->{apply_themeid}+0;
    my $layoutid = $post->{apply_layoutid}+0;

    # we need to load sponsor's themes for sponsored users
    my $substitue_user = LJ::run_hook("substitute_s2_layers_user", $u);
    my $effective_u = defined $substitue_user ? $substitue_user : $u;
    my $theme;
    if ($themeid) {
        $theme = LJ::S2Theme->load_by_themeid($themeid, $effective_u);
    } elsif ($layoutid) {
        $theme = LJ::S2Theme->load_custom_layoutid($layoutid, $effective_u);
    } else {
        die "No theme id or layout id specified.";
    }

    LJ::Customize->apply_theme($u, $theme);
    LJ::run_hooks('apply_theme', $u);

    return;
}

sub js {
    q [
        initWidget: function () {
            var self = this;

            var filter_links = DOM.getElementsByClassName(document, "theme-cat");
            filter_links = filter_links.concat(DOM.getElementsByClassName(document, "theme-layout"));
            filter_links = filter_links.concat(DOM.getElementsByClassName(document, "theme-designer"));
            filter_links = filter_links.concat(DOM.getElementsByClassName(document, "theme-page"));

            // add event listeners to all of the category, layout, designer, and page links
            // adding an event listener to page is done separately because we need to be sure to use that if it is there,
            //     and we will miss it if it is there but there was another arg before it in the URL
            filter_links.forEach(function (filter_link) {
                var getArgs = LiveJournal.parseGetArgs(filter_link.href);
                if (getArgs["page"]) {
                    DOM.addEventListener(filter_link, "click", function (evt) { Customize.ThemeNav.filterThemes(evt, "page", getArgs["page"]) });
                } else {
                    for (var arg in getArgs) {
                        if (arg == "authas" || arg == "filter_available" || arg == "show") continue;
                        DOM.addEventListener(filter_link, "click", function (evt) { Customize.ThemeNav.filterThemes(evt, arg, getArgs[arg]) });
                        break;
                    }
                }
            });

            // add event listeners to all of the apply theme forms
            var apply_forms = DOM.getElementsByClassName(document, "theme-form");
            apply_forms.forEach(function (form) {
                DOM.addEventListener(form, "submit", function (evt) { self.applyTheme(evt, form) });
            });

            // add event listeners to the preview links
            var preview_links = DOM.getElementsByClassName(document, "theme-preview-link");
            preview_links.forEach(function (preview_link) {
                DOM.addEventListener(preview_link, "click", function (evt) { self.previewTheme(evt, preview_link.href) });
            });

            // add event listener to the page and show dropdowns
            if( $( 'page_dropdown_top' ) ) {
                DOM.addEventListener($('page_dropdown_top'), "change", function (evt) { Customize.ThemeNav.filterThemes(evt, "page", $('page_dropdown_top').value) });
            }
            if( $( 'page_dropdown_bottom' ) ) {
                DOM.addEventListener($('page_dropdown_bottom'), "change", function (evt) { Customize.ThemeNav.filterThemes(evt, "page", $('page_dropdown_bottom').value) });
            }
            DOM.addEventListener($('show_dropdown_top'), "change", function (evt) { Customize.ThemeNav.filterThemes(evt, "show", $('show_dropdown_top').value) });
            DOM.addEventListener($('show_dropdown_bottom'), "change", function (evt) { Customize.ThemeNav.filterThemes(evt, "show", $('show_dropdown_bottom').value) });
        },
        applyTheme: function (evt, form) {
            var given_themeid = form["Widget[ThemeChooser]_apply_themeid"].value + "";
            var given_layoutid = form["Widget[ThemeChooser]_apply_layoutid"].value + "";
            $("theme_btn_" + given_layoutid + given_themeid).disabled = true;
            DOM.addClassName($("theme_btn_" + given_layoutid + given_themeid), "theme-button-disabled");

            this.doPost({
                apply_themeid: given_themeid,
                apply_layoutid: given_layoutid
            });

            Event.stop(evt);
        },
        onData: function (data) {
            Customize.ThemeNav.updateContent({
                method: "GET",
                cat: Customize.cat,
                layoutid: Customize.layoutid,
                designer: Customize.designer,
                search: Customize.search,
                filter_available: Customize.filter_available,
                page: Customize.page,
                show: Customize.show,
                theme_chooser_id: $('theme_chooser_id').value
            });
            Customize.CurrentTheme.updateContent({
                filter_available: Customize.filter_available,
                show: Customize.show
            });
            Customize.LayoutChooser.updateContent({
                ad_layout_id: $('ad_layout_id').value
            });
            alert(Customize.ThemeChooser.confirmation);
        },
        previewTheme: function (evt, href) {
            window.open(href, 'theme_preview', 'resizable=yes,status=yes,toolbar=no,location=no,menubar=no,scrollbars=yes');
            Event.stop(evt);
        },
        onRefresh: function (data) {
            this.initWidget();
        }
    ];
}

1;
