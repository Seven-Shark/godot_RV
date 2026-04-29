import * as mod from "@oai/artifact-tool";

console.log(
  Object.keys(mod)
    .filter((key) =>
      key.toLowerCase().includes("presentation") ||
      key.toLowerCase().includes("export") ||
      key.toLowerCase().includes("render"),
    )
    .sort(),
);
console.log(Object.getOwnPropertyNames(mod.PresentationFile || {}));
console.log(Object.getOwnPropertyNames(mod.Presentation || {}));
console.log(Object.getOwnPropertyNames(mod.Presentation.prototype || {}));
console.log(String(mod.Presentation.prototype.export).slice(0, 800));
console.log(String(mod.Presentation.prototype.inspect).slice(0, 800));
