import {
  Presentation,
  PresentationFile,
  column,
  text,
  panel,
  fill,
  hug,
} from "@oai/artifact-tool";
import { fileURLToPath } from "node:url";
import path from "node:path";
import fs from "node:fs/promises";

process.chdir(path.resolve(path.dirname(fileURLToPath(import.meta.url)), ".."));
const p = Presentation.create({ slideSize: { width: 1920, height: 1080 } });
const s = p.slides.add();
s.compose(
  panel(
    { name: "bg", width: fill, height: fill, fill: "#17110F", padding: 80 },
    column({ name: "root", width: fill, height: fill, gap: 20 }, [
      text("测试标题", {
        name: "title",
        width: fill,
        height: hug,
        style: { fontSize: 80, bold: true, color: "#F7E6C4", fontFace: "Microsoft YaHei" },
      }),
      text("测试正文", {
        name: "body",
        width: fill,
        height: hug,
        style: { fontSize: 36, color: "#E4CFA8", fontFace: "Microsoft YaHei" },
      }),
    ]),
  ),
  { frame: { left: 0, top: 0, width: 1920, height: 1080 }, baseUnit: 8 },
);
const pptx = await PresentationFile.exportPptx(p);
await pptx.save("output/test.pptx");
const png = await p.export({ format: "png" });
console.log(png.constructor.name, Object.getOwnPropertyNames(Object.getPrototypeOf(png)));
await fs.writeFile("scratch/test.png", Buffer.from(await png.arrayBuffer()));
