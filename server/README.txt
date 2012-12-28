GETTING STARTED
---------------

Not much here yet.  Best bet for learning how to develop a web
application is to look at one of the existing examples.  The
http-server-demo library is probably the best one to start with.



DEVELOPMENT
-----------

Here are a few things you should be aware of if you want to contribute
code for this library.

* Please more-or-less follow the coding conventions in the existing
  code.  That means keeping line lengths to around 90 (80 preferred),
  using the standard indentation for IFs, etc.  It should be fairly
  obvious.  (Famous last words.)

* Please try to write unit tests for the code you add.  I've become a
  big fan of test-driven development.  Writing the tests BEFORE you
  write the code is even better.  There are two test suites:

    + http-server-test-suite -- for server
    + http-protocol-test-suite -- to validate conformance to HTTP standard
      (This doesn't have much in it and should just be integrated with
      http-server-test-suite anyway.  Separate test suites was a bad idea.)

* If you make incompatible changes to the API, update references to
  it.  That means, at the very least, searching for uses of that API
  in all of trunk/libraries and trying to update them.

* It's a good idea to reference RFC 2616 (or other RFCs) when making
  changes to the code related to a particular point in the RFCs.
  Also, if you see a place in the code that doesn't conform to the
  RFCs please take the time to make a note of it.  If all the
  references follow a standard format they'll be easier to find:

    RFC 2616, 5.2

  Right now (April, 2008) conformance to the standard is very poor, but
  I (cgay) plan to start improving it.

* Annotate definitions exported in the public API module with

    // Exported

  above them.  This just makes it less likely for someone to
  accidentally change them incompatibly without meaning to.

* Annotate brokenness that you aren't planning to fix right away with

    // FIXME: ...

  near the code.  Put your name on the comment.

* Annotate missing functionality with "// TODO: ...".  Put your name
  on the comment.

