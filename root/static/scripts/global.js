YUI().use("event-delegate", "io-form", "node", function(Y) {
    Y.delegate('click',
        function(e) { e.target.ancestor('form').submit(); },
        document.body, 'form a.submit_button'
    );

    Y.delegate('submit',
        function(e) {
            Y.log('Wee');
            e.halt();

            var form = e.target;
            Y.io(
                form.get('action'),
                {
                    method: 'POST',
                    form: {
                        id: form
                    },
                    on: {
                        success: function(id, o) {
                            form.setContent( o.responseText );
                        },
                        failure: function() { Y.log("Oh no"); }
                    }
                }
            );
        },
        document.body, 'form.rest'
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
