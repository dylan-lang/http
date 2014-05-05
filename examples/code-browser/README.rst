Build the code-browser and start it from the top level directory
of the http git repository:

    dylan-compiler -build code-browser
    mkdir logs
    ./_build/bin/code-browser --config `pwd`/examples/code-browser/config.xml

The server will be running on port 8080.

Go to one of these URLs:

* /symbol/<library-name>
* /symbol/<library-name>/<module-name>
* /symbol/<library-name>/<module-name>/<definition-name>
* /search?search=xxx  (seems to have problems)

