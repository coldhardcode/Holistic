YUI({
/*
    insertBefore: 'styleoverrides',
*/    
    groups: {
        yui2: {
            combine: true,
            base: 'http://yui.yahooapis.com/2.8.0r4/build/',
            comboBase: 'http://yui.yahooapis.com/combo?',
            root: '2.8.0r4/build/',
            modules:  { yui2_yde: { path: 'yahoo-dom-event/yahoo-dom-event.js' }, yui2_calendar: { path: 'calendar/calendar-min.js', requires: ['yui2_yde', 'yui2_calendarcss'] }, yui2_calendarcss: { path: 'calendar/assets/skins/sam/calendar.css', type: 'css' } }
        }
    }
}).use('json', 'node', 'anim', 'io-base', 'event-delegate', function(Y, result) {
    var form = Y.one('#time_markers');
    var labels       = form.one('select[name="name"]');
    labels.on('change', function() {
        if ( this.get('value') === '___add___' ) {
            var new_name = prompt('Enter new label');
            var node = this.one('optgroup');
            node.insert('<option value="' + new_name + '">' + new_name + '</option>', 1);
            this.set('value', new_name);
        }
    });
    var dt_marker    = form.one('input[name="dt_marker"]');
    var dt_verifier  = form.one('input[name="dt_verifier_uri"]').get('value');
    var calendar_pop = form.one('img.calendar');
    var cal1 = null;
    calendar_pop.on('click', function() {
        if ( cal1 ) {
            cal1.show();
            return;
        }

        var cal_node = calendar_pop.get('parentNode').append('<div id="cal1Cont"></div>');
        Y.use('yui2_calendar', function(Y) {
            cal1 = new YAHOO.widget.Calendar('cal1', 'cal1Cont', { close: true })
            cal1.selectEvent.subscribe( function(type,args,obj) {
                var dates = args[0];
                var date = dates[0];
                var year = date[0], month = date[1], day = date[2];
                dt_marker.set('value', year + '-' + month + '-' + day);
                dt_marker.removeClass('placeholder');
                cal1.hide();
            });
            cal1.render();
        });
    });
    dt_marker.on('blur', function(e) {
        e.preventDefault();

        var date_field = this;
        var date       = this.get('value');

        var complete = function(ident, o, args ) {
            var data = Y.JSON.parse(o.responseText);
            if ( data.date[0] ) {
                this.removeClass('placeholder');
                this.set('value', data.date[0]);
            }
        };
        Y.on('io:complete', complete, date_field);

        Y.io(
            dt_verifier,
            {
                method: 'POST',
                data: Y.JSON.stringify({ date: date, format: '%F', fuzzy: 1 }),
                headers: { 'Content-Type': 'application/json'}
            }
        );
    });
});
