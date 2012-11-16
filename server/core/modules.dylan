module: httpi

/// Modules

define constant $module-map :: <table> = make(<string-table>);
define constant $module-directory :: <string> = "modules";

// Modules are loaded from <server-root>/modules.
//
define function module-pathname
    (module-name :: <string>)
 => (path :: <string>)
  let module = as(<file-locator>, 
    format-to-string("%s/%s", $module-directory, module-name));
  as(<string>, merge-locators(module, server-root(*server*)))
end function module-pathname;

define function load-module
    (module-name :: <string>)
  let path = module-pathname(module-name);
  log-info("Loading module '%s' from %s...", module-name, path);
  let handle = load-library(path);
  $module-map[module-name] := handle;
end function load-module;

/*
 * unload-library isn't implemented yet in the operating-system module,
 * and since there's no real need for this method I'm commenting it out
 * for now.  -cgay 2004.05.06
define function unload-module
    (module-name :: <string>)
  let handle = element($module-map, module-name, default: #f);
  if (handle)
    log-info("Unloading module %s...", module-name);
    FreeLibrary(handle);
  else
    log-info("Couldn't unload module '%s'.  Module not found.", module-name);
  end;
  log-warning("Unloading modules is not yet implemented.");
end function unload-module;
*/
