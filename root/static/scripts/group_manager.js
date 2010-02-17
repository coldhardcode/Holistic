YUI().use("event-delegate", function(Y) {
    Y.delegate('change', function(e) {
        var li = e.currentTarget.get('parentNode').get('parentNode');
        li.get('parentNode').get('children').removeClass('selected');

        if ( e.currentTarget.get('checked') === true )
            li.addClass('selected');
    }, '#group_management_users', 'ul.people input[type="radio"]'); 
});

