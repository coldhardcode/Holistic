YUI().use('node', 'anim', 'io-base', 'json', 'event-delegate', function(Y) {
    var form = Y.one('#time_markers');
    var dt_verifier = form.one('input[name="dt_verifier_uri"]').get('value');
    form.one('input[name="dt_marker"]').on('blur', function(e) {
        e.preventDefault();

        var date_field = this;
        var date       = this.get('value');
        Y.log('Verifying: ' + date);
        var complete = function(ident, o, args ) {
            var data = Y.JSON.parse(o.responseText);
            if ( data.date[0] ) {
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
