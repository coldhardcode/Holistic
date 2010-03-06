YUI().use("io-base", "json", "event-key", "event-delegate", function(Y) {
    function refreshTags(uri) {
        var list = Y.one('#taglist');
        var uri  = list.getAttribute('rest');
        Y.io(uri,
            {
                method: 'GET',
                on: {
                    success: function(id, o) {
                        var p = list.get('parentNode');
                        p.setContent(o.responseText);
                        var input = p.one('#taglist input');
                        var handle = Y.on('key', function(e) {
                            e.halt();
                            restAdd( e.target, handle );
                        }, input, 'down:13', Y);
                    }
                }
            }
        );
    }

    function restAdd(element, handle) {
        var uri;
        if ( element.get('value').length < 1 )
            return;

        if ( typeof uri === 'undefined' && element.get('tagName').toUpperCase() === 'INPUT' )
            uri = element.getAttribute('rest');
        Y.log("POST to " + uri);
        Y.io(uri,
            {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                data: Y.JSON.stringify({ tag: element.get('value') }),
                on: {
                    success: function() {
                        if ( handle )
                            handle.detach();
                        refreshTags();
                    }
                }
            }
        );
    }

    function restDelete(element, uri) {
        if ( typeof uri === 'undefined' && element.get('tagName').toUpperCase() === 'A' )
            uri = element.get('href');
        Y.io(uri,
            {
                method: 'DELETE',
                headers: { 'Content-Type': 'application/json'},
                on: { success: function() { refreshTags(); } }
            }
        );
    }

    Y.delegate('click', function(e) {
        e.halt();
        restDelete( e.target );
    }, document.body, 'li.tag a.remove');

    var handle = Y.on('key', function(e) {
        e.halt();
        restAdd( e.target, handle );
        Y.log(e.type + ": " + e.keyCode);
    }, '#taglist li input', 'down:13', Y);

});
