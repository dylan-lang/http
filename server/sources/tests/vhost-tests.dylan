Module: koala-test-suite

define test vhost-initialization-test ()
  // Verify that the only required init args are name and document-root.
  let vhost = make(<virtual-host>,
                   name: "name",
                   document-root: as(<directory-locator>, "dir"));
  check-equal("vhost dsp-root defaults to value of document-root",
              vhost.dsp-root, vhost.document-root);
end test vhost-initialization-test;


define suite vhost-test-suite ()
  test vhost-initialization-test;
end suite vhost-test-suite;
