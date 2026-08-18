ObjC.import("Foundation");

function run() {
  const current = Application.currentApplication();
  current.includeStandardAdditions = true;

  const value = $.NSBundle.mainBundle.objectForInfoDictionaryKey("S5CTargetURL");
  if (!value) {
    throw new Error("This web launcher does not contain a target URL.");
  }

  const targetURL = ObjC.unwrap(value);
  const components = $.NSURLComponents.componentsWithString(targetURL);
  const scheme = components && components.scheme ? ObjC.unwrap(components.scheme).toLowerCase() : "";
  const host = components && components.host ? ObjC.unwrap(components.host) : "";
  const user = components && components.user ? ObjC.unwrap(components.user) : "";
  const password = components && components.password ? ObjC.unwrap(components.password) : "";
  if ((scheme !== "http" && scheme !== "https") || !host || user || password) {
    throw new Error("This web launcher contains an unsupported URL.");
  }

  current.openLocation(ObjC.unwrap(components.string));
}
