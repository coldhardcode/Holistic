YUI().use("event-delegate", "node", function(Y) {
    Y.delegate('click',
        function(e) { e.target.ancestor('form').submit(); },
        document.body, 'form img'
    );

    // webkit has native placeholder support
    if ( Y.UA.webkit ) return;

    Y.all('form').each( function() {
        var form = this;
        form.all('input[placeholder]').each( function() {
            if ( this.get('value') === '' ||
                 this.get('value') === this.getAttribute('placeholder') 
            ) {
                this.addClass('placeholder');
                this.set('value', this.getAttribute('placeholder'));
            }

            this.on('focus', function() {
                if ( this.get('value') === this.getAttribute('placeholder') ) {
                    this.toggleClass('placeholder');
                    this.set('value', '');
                }
            });
            this.on('blur', function() {
                if ( this.get('value').length < 1 ) {
                    this.toggleClass('placeholder');
                    this.set('value', this.getAttribute('placeholder'));
                }
            });
        });
        form.on('submit', function() {
            form.all('input[placeholder]').each( function() {
                if ( this.get('value') === this.getAttribute('placeholder') )
                    this.set('value', '');
            } );
        });
    });
});
