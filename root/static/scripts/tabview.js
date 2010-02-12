YUI({ 
            base: "http://yui.yahooapis.com/3.0.0/build/",
            modules: {
                "tabviewcss": {
                    type: "css",
                    fullpath: "/static/css/tabview.css"
                },
                "tabviewjs": {
                    type: "js",
                    fullpath: "/static/scripts/tabview-core.js",
                    requires: ["node-focusmanager", "tabviewcss"]
                }
 
            },
            timeout: 10000
 
        }).use("tabviewjs", function(Y, result) {
 
            //  The callback supplied to use() will be executed regardless of
            //  whether the operation was successful or not.  The second parameter
            //  is a result object that has the status of the operation.  We can
            //  use this to try to recover from failures or timeouts.
 
            if (!result.success) {
 
                Y.log("Load failure: " + result.msg, "warn", "Example");
 
                //  Show the tabview HTML if the loader failed that way the 
                //  original unskinned tabview will be visible so that the 
                //  user can interact with it either way.
 
                document.documentElement.className = "";
 
            }
 
    });
