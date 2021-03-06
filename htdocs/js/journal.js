//= require js/entry/likes.js
//= require js/pagescroller.js

DonateButton = {
  buyMore: function(node, ml_message, event) {
    var bubble = jQuery(node).data('buyMoreCachedBubble');

    if (!bubble) {
      bubble = jQuery('<span>' + ml_message + '</span>').bubble({
        target: node
      });

      jQuery(node).data('buyMoreCachedBubble', bubble);
    }

    bubble.bubble('show');

    if (event.stopPropagation) {
      event.stopPropagation();
    } else {
      event.cancelBubble = true;
    }

    return false;
  },

  donate: function( link, url_data, event ) {
    var width = 639,
        height = 230,
        url = link.href,
        popupUrl,
        h;


    LJ.rpc.bind(function(ev) {
      if ( ev.origin && ev.origin !== Site.siteroot ) {
        return;
      }

      if ( ev.data && ev.data.message === 'updateWallet' ) {
        LiveJournal.run_hook( 'update_wallet_balance' );
        jQuery.getJSON(
          LiveJournal.getAjaxUrl('give_tokens') + '?' + url_data + '&mode=js',
          function (result) {
            var $node;

            if ( result.html ) {
              $node = jQuery( link ).closest( '.lj-button' );
              $node.replaceWith( result.html );
            }
          }
        );
      }
    });

    popupUrl = url + ( url.indexOf( '?' ) === -1 ? '?' : '&' ) + 'usescheme=nonavigation';
    h = window.open( 'about:blank', 'donate' , 'toolbar=0,status=0,width=' + width + ',height=' + height + ',scrollbars=yes,resizable=yes');
    h.name = location.href.replace( /#.*$/, '' );

    setTimeout(function() {
      LJ.rpc.initRecipient( h, popupUrl, location.href.replace( /#.*$/, '' ) );
    }, 0);

    if (event.stopPropagation) {
      event.stopPropagation();
    } else {
      event.cancelBubble = true;
    }

    return false;
  }
};

(function () {
  var storage = {
    init: function() {
      this._store = LJ.Storage.getItem('placeholders') || {};
    },

    inStorage: function(link) {
      return this._store.hasOwnProperty(link);
    },

    addUrl: function(link) {
      if ( !this.inStorage(link) ) {
        this._store[link] = true;
        LJ.Storage.setItem('placeholders', this._store);
      }
    }
  };

  storage.init();

  var placeholders = {
    image: {
      selector: '.b-mediaplaceholder-photo',
      loading: 'b-mediaplaceholder-processing',
      init: function() {
        var self = this;
        doc.on('click', this.selector, function(ev) {
          self.handler(this, ev);
        });
      },

      handler: function(el, html) {
        var im = new Image();

        im.onload = im.onerror = jQuery.delayedCallback(this.imgLoaded.bind(this, el, im), 500);
        im.src = el.href;
        el.className += ' ' + this.loading;

        storage.addUrl(el.href);
      },

      imgLoaded: function(el, image) {
        var img = jQuery('<img />').attr('src', image.src),
            $el = jQuery(el),
            href = $el.data('href'),
            imw = $el.data('width'),
            imh = $el.data('height');

        if (imw) {
          img.width(imw);
        }

        if (imh) {
          img.height(imh);
        }

        if (href && href.length > 0) {
          img = jQuery('<a>', { href: href }).append(img);
          $el.next('.b-mediaplaceholder-external').remove();
        }

        $el.replaceWith(img);
      }
    },

    video: {
      handler: function(link, html) {
        link.parentNode.replaceChild(jQuery(unescape(html))[0], link);
      }
    }
  };
  // use replaceChild for no blink scroll effect

  // Placeholder onclick event
  LiveJournal.placeholderClick = function(el, html) {
    var type = (html === 'image') ? html : 'video';

    placeholders[type].handler(el, html);
    return false;
  };

  LiveJournal.register_hook('page_load', function() {
    jQuery('.b-mediaplaceholder').each(function() {
      if (storage.inStorage(this.href)) {
        this.onclick.apply(this);
      }
    });
  });
})();

/**
 * Embed gists from GitHub
 *
 * Parses the page for:
 * '<a href="https://gist.github.com/fcd584d3a351c3e9728b"></a>'
 */
(function($) {
  'use strict';

  var gistBase = '://gist.github.com/',
      gistCss = {
        'clear': 'both'
      };

  function showGist(link) {
    var href  = link.attr('href'),
        head  = $('head'),
        match = href && href.match(/gist.github.com(.*)\/([a-zA-Z0-9]+)/),
        id    = match && match.pop();

    if (!id) {
      console.error('Bad GitHub id');
      return;
    }

    link
      .html('Loading the gist...');

    $.ajax({
      url: 'https' + gistBase + id + '.json',
      dataType: 'jsonp',
      timeout: 10000
    }).done(function(result) {
      if (!result.div || !result.stylesheet) {
        console.error('Data error', result);
      }

      head.append(
        '<link rel="stylesheet" href="https' + gistBase + result.stylesheet + '">'
      );

      var div = $(result.div);
      div.find('a').attr('target', '_blank');
      div.css(gistCss);
      link.replaceWith(div);
    })
    .fail(function(error) {
      link.html('Gist loading error');
    });
  }

  function convertGists(node, isLjCut) {
    // Convert all gist links in node
    node = node || $('body');

    var gists = $('a[href*="' + gistBase + '"]', node);

    gists.each(function(_, element) {
      var link = $(element),
          isFeed,
          expandLink,
          needAutoExpand;

      link.attr('target', '_blank');

      // Insert original content from github if 'data-expand' is defined
      if ( link.attr('data-expand') ) {
        isFeed = /feed|friends/.test(window.location.pathname);
        needAutoExpand = isFeed ? isLjCut : (link.attr('data-expand') === 'true');

        // Add either gist or collapsed gist
        if (needAutoExpand) {

          // Add full gist content
          showGist(link);
        } else {

          // Add collapsed gist

          // Wrap link in span to display braces around it
          var span = document.createElement('span');
          link.after(span);
          $(span).append(link)
                 .toggleClass('b-replaceable-link', true);
          link.on('click', function(e) {
            if (event.ctrlKey || (event.metaKey && LJ.Support.isMac)) {
              return;
            }
            e.preventDefault();
            $(span).after(link)
                   .remove();
            showGist(link);
          });
        }
      }

    });
  }

  $(function() {
    var body = $('body');
    convertGists( body );
    body.on('ljcutshow', function(event, ui) {
      convertGists($(event.target).next(), true );
    });
  });

}(jQuery));
