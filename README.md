build2xlsform
=============

introduction
------------
**build2xlsform** is a simple library and webservice that takes [ODK Build](//github.com/getodk/build) form data and converts it to [XLSForm](http://xlsform.org/)-compatible XLSX files. It supports all features in ODK Build and is actively maintained to keep it such. In minor instances, this exceeds XLSForm's own expressivity of XForms features, and in such cases we export lossy information and leave a message in a 'Warnings' spreadsheet. It is currently actively deployed on the [production Build instance](http://build.getodk.org).

compilation
-----------
The project depends on **nodejs**; we officially support versions 5 and 6. Make sure you have node and npm [correctly installed](https://nodejs.org/en/download/) for your platform.

Once you have that, you should be able to simply `make` to trigger a build. The Makefile handles running `npm install`, but if you into issues performing that step on your own is a good troubleshooting start.

running
-------
Run `node lib/server.js` to run the build2xlsform service. It runs on port 8686 by default, and on this port the development version of ODK Build will automatically proxy requests through to the service.

project
-------
All the relevant code is in `/src`. There are only two files:

* `convert.ls` is a three-part library file which handles the actual conversion.
    * `convert-question()` takes a single question and translates the original Build data objects into an intermediate data object format that's ready for serialization to a tabular format. It's largely useless outside the context of this library, and is exposed primarily for unit testing.
    * `convert-form()` takes the entire Build form as a data object, converts all questions with `convert-question()`, determines the appropriate schema for a tabular output, and generates the final workbook sheets as objects and arrays.
    * `gen-settings()` is a simple function that takes form data and returns a basic settings spreadsheet with just a form title and form id.
    * `serialize-form()` takes the output of `convert-form()` (or indeed any sheet data compatible with `node-xlsx`) and a nodejs stdlib `HttpResponse` object, and handles the conversion from data objects to XLSX binary, serialization out, and stream lifecycle.
* `server.ls` is a dead-simple **express** webserver that exposes a single HTTP endpoint at `POST /convert`, takes JSON as the POST-body (with a request `Content-Type` of `application/json`), and responds with an attachment-disposition binary stream of the XLSX result.

Tests are located in `/spec/src`. Each test file has some notes at the top indicating how it's organized. You can run the tests with `make test`. This will also recompile any main project files you may have changed.

about livescript
----------------
[Livescript](http://livescript.net/) is a language that largely resembles and compiles down to Javascript. For the most part it should be very readable to any coder; here are a few tips to avoid stumbling:

* `\sometext` is just syntactic sugar for `'sometext'`. It's used in the codebase to cut down on symbolic clutter, as we throw a lot of string literals around.
* `a |> b` is syntactic sugar for `b(a)`. As well, `a |> b(c)` is shorthand for `b(c, a)`. We use this here and there to make nested chains of function calls easier to read and understand. It's generally known as the 'forward piping' operator.
* As with Python, Livescript is whitespace-significant, and uses indentation to signify code blocks.

integration with odkbuild
-------------------------
The Build webapp expects to be able to find this service when it `POST`s to `/convert`. On the production Build instance in Apache, we accomplish this by capturing `<Location /convert>` and using `ProxyPass` to forward the request on to an instance of `build2xlsform` running on a local port.

contributing
------------
Please submit pull requests for any code you'd like to push. As you do so, please keep in mind:

* The project is meant to be as purely-functional as possible, as is ideal for data handling and transformation. Avoid mutable or global state, and don't introduce heavy object-oriented approaches without very good reason.
* Please do run the tests before submission, and augment them as necessary.
* Please ensure that any changes you make adhere to both the [ODK Build](https://github.com/clint-tseng/odkbuild/blob/master/public/javascripts/control.js#L206) property schema, as well as the XLSForm [reference spec](http://xlsform.org/ref-table/).

license
-------

Apache 2.0

