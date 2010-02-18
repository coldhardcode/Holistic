YUI().use("io-base", "json", "event-delegate", function(Y) {
    function updateGroups(person_pk1) {
        Y.all('#user_groups input[name="group_pk1"]').set('checked', false);
        var groups = group_config[person_pk1];
        if ( typeof groups === 'undefined' ) {
            Y.log("No groups for " + person_pk1);
            return;
        }
        for ( var i = 0; i < groups.length; i++ ) {
            Y.one('#group_group' + groups[i].group_pk1).set('checked', true);
        }

    }

    function save_changes(object) {
        var post_body = Y.JSON.stringify({ persons: group_config });
        var post_uri  = Y.one('#user_groups').get('action');

	    Y.io.header('Content-Type', 'application/json');
	    Y.on('io:start', function() { Y.log("io:start"); });
	    Y.on('io:success', function() { Y.log("io:success"); });
	    Y.on('io:end', function() { Y.log("io:end"); });

        Y.io(post_uri,
            {
                method: 'POST',
                data: post_body,
                headers: { 'Content-Type': 'application/json'}
            }
        );
    }

    Y.delegate('change', function(e) {
        var remove    = e.currentTarget.get('checked') !== true; 
        var group_pk1 = e.currentTarget.get('value');
        var list      = Y.all('#user_groups .people input');

        list.each(
            function(node, index, nodeList) {
                if ( node.get('checked') !== true )
                    return;
                var person_pk1 = node.get('value');

                var group_list = Y.all('#user_groups .groups input');
                var selected_list = [];
                group_list.each( function(group_node) {
                    if ( group_node.get('checked') ) {
                        selected_list.push({ group_pk1: group_node.get('value') });
                    }
                } );

                group_config[person_pk1] = selected_list;
            }
        );
        save_changes({ persons: group_config });
    }, '#user_groups', 'input[name="group_pk1"]');

    Y.delegate('change', function(e) {
        var li = e.currentTarget.get('parentNode').get('parentNode');
        if ( e.currentTarget.get('type').toUpperCase() === 'RADIO' )
            li.get('parentNode').get('children').removeClass('selected');
        if ( e.currentTarget.get('checked') === true ) {
            li.addClass('selected');
            updateGroups(e.currentTarget.get('value'));
        } else
            li.removeClass('selected');
    }, '#group_management_users', 'ul.people li input'); 
});

