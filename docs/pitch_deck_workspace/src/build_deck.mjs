import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  Presentation,
  PresentationFile,
  row,
  column,
  grid,
  layers,
  panel,
  text,
  image,
  rule,
  fill,
  hug,
  fixed,
  wrap,
  grow,
  fr,
  auto,
} from "@oai/artifact-tool";

const workspace = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
process.chdir(workspace);

const W = 1920;
const H = 1080;

const C = {
  bg: "#15100D",
  bg2: "#201711",
  paper: "#F5E0B8",
  paper2: "#D7B77A",
  ink: "#2A1711",
  red: "#B84835",
  green: "#76D28C",
  green2: "#9BE7AA",
  amber: "#F0A84B",
  muted: "#B99F7C",
  line: "#6C4A32",
  darkPanel: "#241811",
};

const font = "Microsoft YaHei";
const uiImageDataUrl = `data:image/png;base64,${(await fs.readFile("scratch/assets/radio_ers_ui.png")).toString("base64")}`;
const dayMapDataUrl = `data:image/png;base64,${(await fs.readFile("scratch/assets/daytime_square_map.png")).toString("base64")}`;

const presentation = Presentation.create({
  slideSize: { width: W, height: H },
});

function t(value, opts = {}) {
  return text(value, {
    width: opts.width ?? fill,
    height: opts.height ?? hug,
    name: opts.name,
    style: {
      fontFace: font,
      fontSize: opts.size ?? 30,
      color: opts.color ?? C.paper,
      bold: opts.bold ?? false,
      italic: opts.italic ?? false,
      lineSpacing: opts.lineSpacing ?? 1.08,
    },
  });
}

function smallLabel(value, color = C.green) {
  return panel(
    {
      width: hug,
      height: hug,
      padding: { x: 18, y: 8 },
      fill: "#1B261B",
      borderRadius: "rounded-full",
    },
    t(value, { size: 22, color, bold: true, width: hug }),
  );
}

function slideBase(children, opts = {}) {
  const slide = presentation.slides.add();
  slide.compose(
    panel(
      {
        name: "slide-bg",
        width: fill,
        height: fill,
        fill: opts.fill ?? C.bg,
        padding: opts.padding ?? { x: 86, y: 66 },
      },
      column({ name: "slide-root", width: fill, height: fill, gap: opts.gap ?? 30 }, children),
    ),
    { frame: { left: 0, top: 0, width: W, height: H }, baseUnit: 8 },
  );
  return slide;
}

function titleBlock(kicker, title, subtitle) {
  return column({ name: "title-block", width: fill, height: hug, gap: 14 }, [
    t(kicker, { name: "kicker", size: 24, color: C.green, bold: true }),
    t(title, { name: "slide-title", size: 58, color: C.paper, bold: true }),
    subtitle
      ? t(subtitle, { name: "slide-subtitle", size: 26, color: C.muted, width: wrap(1320) })
      : null,
  ].filter(Boolean));
}

function note(value) {
  return t(value, { size: 22, color: C.muted });
}

function artifactPanel(children, opts = {}) {
  return panel(
    {
      name: opts.name,
      width: opts.width ?? fill,
      height: opts.height ?? fill,
      fill: opts.fill ?? C.darkPanel,
      padding: opts.padding ?? { x: 30, y: 24 },
      borderRadius: "rounded-lg",
    },
    children,
  );
}

function bullets(items, opts = {}) {
  return column(
    { name: opts.name, width: opts.width ?? fill, height: hug, gap: opts.gap ?? 14 },
    items.map((item, idx) =>
      row({ name: `bullet-${idx}`, width: fill, height: hug, gap: 14 }, [
        t("•", { width: fixed(24), size: opts.size ?? 26, color: opts.dotColor ?? C.green, bold: true }),
        t(item, { size: opts.size ?? 26, color: opts.color ?? C.paper, width: fill }),
      ]),
    ),
  );
}

// 1. Cover
{
  const slide = presentation.slides.add();
  slide.compose(
    panel(
      { name: "cover-bg", width: fill, height: fill, fill: C.bg, padding: 0 },
      grid(
        {
          name: "cover-root",
          width: fill,
          height: fill,
          columns: [fr(0.95), fr(1.05)],
          rows: [fr(1)],
          columnGap: 54,
          padding: { x: 86, y: 72 },
        },
        [
          column({ name: "cover-copy", width: fill, height: fill, gap: 28 }, [
            smallLabel("独立游戏项目立项书"),
            t("明日播报", { name: "cover-title", size: 112, color: C.paper, bold: true }),
            t("一款“用收音机播出明天”的俯视角 Rogue-lite 策略生存游戏", {
              name: "cover-subtitle",
              size: 35,
              color: C.paper2,
              width: wrap(760),
            }),
            rule({ name: "cover-rule", width: fixed(280), stroke: C.red, weight: 6 }),
            t("白天狩猎与采集，夜晚把线索组合成明日播报。玩家不是等待世界变化，而是亲手制造明天的资源、危险和 Boss。", {
              name: "cover-promise",
              size: 29,
              color: C.muted,
              width: wrap(780),
            }),
            t("暂定名 / Godot 4.6 / 2026", { name: "cover-meta", size: 20, color: "#8C755D" }),
          ]),
          panel(
            {
              name: "cover-image-frame",
              width: fill,
              height: fill,
              fill: "#0E0A08",
              padding: 0,
              borderRadius: "rounded-lg",
            },
            image({
              name: "radio-ui-concept",
              dataUrl: uiImageDataUrl,
              width: fill,
              height: fill,
              fit: "cover",
              alt: "收音机 ERS 界面概念图",
            }),
          ),
        ],
      ),
    ),
    { frame: { left: 0, top: 0, width: W, height: H }, baseUnit: 8 },
  );
}

// 2. One sentence
slideBase([
  titleBlock("01 / 核心命题", "不是选择明天，而是播出明天", "项目的核心差异化不是“随机事件”，而是玩家用线索元素主动组合明天。"),
  grid(
    { name: "three-pillars", width: fill, height: fixed(360), columns: [fr(1), fr(1), fr(1)], columnGap: 28 },
    [
      artifactPanel(column({ width: fill, height: fill, gap: 18 }, [
        t("白天", { size: 34, color: C.green, bold: true }),
        t("狩猎变异怪物获得“残响”，采集地图资源升级设施与自身。", { size: 28, color: C.paper }),
      ])),
      artifactPanel(column({ width: fill, height: fill, gap: 18 }, [
        t("夜晚", { size: 34, color: C.green, bold: true }),
        t("回到庇护所，把残响喂给收音机，捕获新的明日线索。", { size: 28, color: C.paper }),
      ])),
      artifactPanel(column({ width: fill, height: fill, gap: 18 }, [
        t("明天", { size: 34, color: C.green, bold: true }),
        t("组合线索生成资源区、特殊环境、精英事件或 Boss 战场。", { size: 28, color: C.paper }),
      ])),
    ],
  ),
  t("一句话卖点：末日后的每个夜晚，玩家用收音机编辑第二天的地图。", { size: 32, color: C.paper2, bold: true }),
]);

// 3. Why it has hook
slideBase([
  titleBlock("02 / 传播钩子", "收音机让“明天”成为可玩的对象", "一个日常物件 + 一个末日规则 + 一个可验证的玩法结果。"),
  grid({ width: fill, height: fill, columns: [fr(1.25), fr(0.75)], columnGap: 44 }, [
    column({ width: fill, height: fill, gap: 24 }, [
      t("每晚零点，收音机会播报明天。", { size: 46, bold: true, color: C.paper }),
      t("但玩家可以用白天取得的残响、磁带、电池和线索，把播报剪辑成另一种明天。", {
        size: 32,
        color: C.paper2,
        width: wrap(1050),
      }),
      bullets([
        "森林 + 岩浆 → 灰烬林：快速采木，但会烧伤并提高 Heat。",
        "废仓库 + 铜线 → 线缆仓库：铜线暴露，但伏击风险上升。",
        "广播塔 + 校时 + 残响 → 报时者 Boss 事件。"
      ], { size: 27, color: C.paper }),
    ]),
    artifactPanel(column({ width: fill, height: fill, gap: 20 }, [
      t("投资人能快速理解的独特点", { size: 30, color: C.green, bold: true }),
      t("不是“又一款生存肉鸽”，而是围绕“播报明天”形成内容生产、玩家策略和宣传语的统一核心。", {
        size: 27,
        color: C.paper,
      }),
      rule({ width: fill, stroke: C.line, weight: 2 }),
      t("宣传句", { size: 22, color: C.muted, bold: true }),
      t("你不是在等明天。\n你是在播出明天。", { size: 40, color: C.red, bold: true }),
    ])),
  ]),
]);

// 4. Loop
slideBase([
  titleBlock("03 / 核心循环", "玩家每天都在做两件事：赚钱给收音机，攒料修自己", null),
  grid({ width: fill, height: fixed(360), columns: [fr(1), fr(1), fr(1), fr(1)], columnGap: 18 }, [
    artifactPanel(column({ width: fill, height: fill, gap: 16 }, [
      t("1 白天狩猎", { size: 31, color: C.green, bold: true }),
      t("击杀变异怪物，获得残响、怪物材料和特殊线索。", { size: 25 }),
    ])),
    artifactPanel(column({ width: fill, height: fill, gap: 16 }, [
      t("2 白天采集", { size: 31, color: C.green, bold: true }),
      t("采集木材、铁片、铜线、电池、食物等基础资源。", { size: 25 }),
    ])),
    artifactPanel(column({ width: fill, height: fill, gap: 16 }, [
      t("3 夜晚调频", { size: 31, color: C.green, bold: true }),
      t("把残响投入收音机，获得新的地点、环境、资源、信号元素。", { size: 25 }),
    ])),
    artifactPanel(column({ width: fill, height: fill, gap: 16 }, [
      t("4 明日兑现", { size: 31, color: C.green, bold: true }),
      t("组合线索改变地图，并进入自己制造出来的机会与麻烦。", { size: 25 }),
    ])),
  ]),
  t("循环价值：狩猎驱动 ERS，采集驱动成长，ERS 反过来改变下一轮狩猎与采集。", {
    size: 31,
    color: C.paper2,
    bold: true,
  }),
]);

// 5. Resource loop
slideBase([
  titleBlock("04 / 资源产销循环", "两条产线，汇入同一个明日编辑器", "怪物产出“残响”驱动收音机；地图物件产出材料驱动成长。"),
  grid({ width: fill, height: fill, columns: [fr(1), fr(1), fr(1)], rows: [fr(1), fr(1)], columnGap: 24, rowGap: 22 }, [
    artifactPanel(column({ width: fill, height: fill, gap: 12 }, [
      t("白天狩猎", { size: 30, color: C.green, bold: true }),
      t("击杀变异怪物", { size: 28, bold: true }),
      t("产出：残响、怪物材料、特殊线索", { size: 24, color: C.paper2 }),
    ])),
    artifactPanel(column({ width: fill, height: fill, gap: 12 }, [
      t("夜晚收音机", { size: 30, color: C.green, bold: true }),
      t("投入残响", { size: 28, bold: true }),
      t("产出：地点、环境、资源、生物、信号元素", { size: 24, color: C.paper2 }),
    ])),
    artifactPanel(column({ width: fill, height: fill, gap: 12 }, [
      t("明日改写", { size: 30, color: C.green, bold: true }),
      t("组合线索", { size: 28, bold: true }),
      t("产出：资源区、危险区、精英事件、Boss 战场", { size: 24, color: C.paper2 }),
    ])),
    artifactPanel(column({ width: fill, height: fill, gap: 12 }, [
      t("白天采集", { size: 30, color: C.green, bold: true }),
      t("采集独立物件", { size: 28, bold: true }),
      t("产出：木材、铁片、铜线、磁带、电池、食物", { size: 24, color: C.paper2 }),
    ])),
    artifactPanel(column({ width: fill, height: fill, gap: 12 }, [
      t("设施与合成", { size: 30, color: C.green, bold: true }),
      t("消耗基础材料", { size: 28, bold: true }),
      t("产出：更强工具、固定设施升级、线索保存能力", { size: 24, color: C.paper2 }),
    ])),
    artifactPanel(column({ width: fill, height: fill, gap: 12 }, [
      t("下一次白天", { size: 30, color: C.green, bold: true }),
      t("进入自己制造的地图", { size: 28, bold: true }),
      t("更高收益伴随更高风险，循环继续推进阶段目标。", { size: 24, color: C.paper2 }),
    ])),
  ]),
  t("核心闭环：狩猎买“明天的可能性”，采集买“活到明天的能力”。", { size: 30, color: C.paper2, bold: true }),
]);

// 6. Daytime map
slideBase([
  titleBlock("05 / 白天实机逻辑", "固定正方形地图，变化发生在物件与敌人上", "地图骨架不变，ERS 改变的是上面的资源、怪物、线索点、危险环境和 Boss 条件。"),
  grid({ width: fill, height: fill, columns: [fr(1.18), fr(0.82)], columnGap: 34 }, [
    panel(
      { width: fill, height: fill, fill: "#0E0F10", padding: 0, borderRadius: "rounded-lg" },
      image({
        name: "daytime-square-map",
        dataUrl: dayMapDataUrl,
        width: fill,
        height: fill,
        fit: "contain",
        alt: "白天固定正方形地图实机玩法示意图",
      }),
    ),
    column({ width: fill, height: fill, gap: 18 }, [
      artifactPanel(column({ width: fill, height: hug, gap: 10 }, [
        t("固定地图", { size: 30, color: C.green, bold: true }),
        t("正方形地图边界与基础地形保持稳定，降低制作和理解成本。", { size: 24 }),
      ]), { height: hug }),
      artifactPanel(column({ width: fill, height: hug, gap: 10 }, [
        t("独立物件", { size: 30, color: C.green, bold: true }),
        t("树木、铜线、电池、广播残骸、怪物都作为独立节点生成和替换。", { size: 24 }),
      ]), { height: hug }),
      artifactPanel(column({ width: fill, height: hug, gap: 10 }, [
        t("ERS 落地", { size: 30, color: C.green, bold: true }),
        t("夜晚组合线索后，第二天改变地图上的对象池与分布。", { size: 24 }),
      ]), { height: hug }),
    ]),
  ]),
]);

// 7. Daytime controls
slideBase([
  titleBlock("06 / 白天操作", "轻操作 + 强判断：停下来才有收益，停太久就会暴露", "白天的核心不是清图，而是在时间、声纹和撤离压力下，把明天需要的东西带回去。"),
  grid({ width: fill, height: fill, columns: [fr(1), fr(1.05)], columnGap: 36 }, [
    artifactPanel(column({ width: fill, height: fill, gap: 16 }, [
      t("玩家基础操作", { size: 32, color: C.green, bold: true }),
      bullets([
        "移动 / 慢行：速度与声纹之间取舍。",
        "站定攻击：停下进入攻击架势，自动瞄准优先目标。",
        "采集 / 拆解：按 E 交互，可中断，收益分阶段结算。",
        "闪避 / 诱饵：快速脱离或用噪音转移敌人。",
        "扫描线索点：获得 ERS 元素，但扫描时暴露自己。",
      ], { size: 25 }),
    ])),
    column({ width: fill, height: fill, gap: 18 }, [
      t("白天六类行为", { size: 40, color: C.paper, bold: true }),
      bullets([
        "狩猎：击杀怪物，获得残响与怪物材料。",
        "采集：获得设施升级和合成所需基础资源。",
        "侦察：发现地点、环境、信号等线索元素。",
        "拆解：高耗时高噪音，换取高级材料。",
        "布置：放置诱饵、路障、标记，制造短期优势。",
        "撤离：把收益带回庇护所，进入夜晚决策。",
      ], { size: 27 }),
      t("白天给夜晚提供素材；夜晚改写下一次白天。", { size: 30, color: C.paper2, bold: true }),
    ]),
  ]),
]);

// 5. ERS system
slideBase([
  titleBlock("07 / ERS 系统", "线索元素组合：低成本做出高变化", "用标签化元素驱动地图变化，避免完全程序生成失控。"),
  grid({ width: fill, height: fill, columns: [fr(0.95), fr(1.05)], columnGap: 38 }, [
    artifactPanel(column({ width: fill, height: hug, gap: 18 }, [
      t("元素类型", { size: 32, color: C.green, bold: true }),
      bullets([
        "地点：森林、废仓库、水渠、广播塔",
        "环境：雾、岩浆、腐化、停电",
        "资源：木材、铜线、磁带、食物",
        "生物：听觉者、巢群、精英怪",
        "信号：残响、校时、回波、静默",
      ], { size: 25 }),
    ]), { height: fixed(520) }),
    column({ width: fill, height: fill, gap: 18 }, [
      artifactPanel(column({ width: fill, height: hug, gap: 12 }, [
        t("森林 + 岩浆 + 木材", { size: 30, color: C.paper, bold: true }),
        t("灰烬林：炭化木材采集更快，但灼烧地形与 Heat 上升。", { size: 25, color: C.paper2 }),
      ]), { height: hug }),
      artifactPanel(column({ width: fill, height: hug, gap: 12 }, [
        t("广播塔 + 残响", { size: 30, color: C.paper, bold: true }),
        t("回波塔：次日可获得额外线索，但电台更容易注意玩家。", { size: 25, color: C.paper2 }),
      ]), { height: hug }),
      artifactPanel(column({ width: fill, height: hug, gap: 12 }, [
        t("广播塔 + 校时 + 残响", { size: 30, color: C.paper, bold: true }),
        t("报时者：主动召出阶段 Boss 或推进 Boss 前置事件。", { size: 25, color: C.paper2 }),
      ]), { height: hug }),
    ]),
  ]),
]);

// 6. Boss
slideBase([
  titleBlock("08 / Boss 设计", "Boss 不是倒计时出现，而是被玩家播出来", "玩家可以主动召出 Boss，也可以用不同组合改变战场、机制和掉落。"),
  grid({ width: fill, height: fill, columns: [fr(1), fr(1)], columnGap: 36 }, [
    column({ width: fill, height: fill, gap: 20 }, [
      t("第一阶段示例：报时者", { size: 42, color: C.paper, bold: true }),
      bullets([
        "基础组合：广播塔 + 校时 + 残响",
        "林间变体：森林 + 校时 + 残响",
        "仓库变体：废仓库 + 校时 + 残响",
        "灰烬变体：灰烬林 + 校时 + 残响",
      ], { size: 27 }),
      note("主线组合给明确提示；变体组合提供策略和重玩价值。"),
    ]),
    artifactPanel(column({ width: fill, height: fill, gap: 18 }, [
      t("设计价值", { size: 32, color: C.green, bold: true }),
      bullets([
        "Boss 是阶段考试，不只是血厚怪。",
        "玩家准备好再触发，减少挫败。",
        "同一 Boss 可通过战场变体带来不同奖励。",
        "ERS 与战斗目标绑定，系统存在感更强。",
      ], { size: 26 }),
    ])),
  ]),
]);

// 7. Stage progression
slideBase([
  titleBlock("09 / 阶段体验", "难度提升不是数值膨胀，而是玩家能力升级", "每个阶段给玩家一种新的“明天编辑能力”。"),
  grid({ width: fill, height: fixed(430), columns: [fr(1), fr(1), fr(1)], columnGap: 26 }, [
    artifactPanel(column({ width: fill, height: fill, gap: 18 }, [
      t("阶段 1：听懂明天", { size: 32, color: C.green, bold: true }),
      t("玩家学会狩猎、采集、喂收音机、使用简单组合改变地图。", { size: 26 }),
      t("目标：击败第一个播报异常 Boss。", { size: 24, color: C.paper2, bold: true }),
    ])),
    artifactPanel(column({ width: fill, height: fill, gap: 18 }, [
      t("阶段 2：拼装明天", { size: 32, color: C.green, bold: true }),
      t("开放多元素组合、精英怪、区域风险和更明显的副作用。", { size: 26 }),
      t("目标：连续数日设计 Boss 前置局面。", { size: 24, color: C.paper2, bold: true }),
    ])),
    artifactPanel(column({ width: fill, height: fill, gap: 18 }, [
      t("阶段 3：广播反噬", { size: 32, color: C.green, bold: true }),
      t("电台开始识别玩家，改写行为会被反制或积累长期后果。", { size: 26 }),
      t("目标：关闭、取代或逃离主广播源。", { size: 24, color: C.paper2, bold: true }),
    ])),
  ]),
]);

// 8. Player growth
slideBase([
  titleBlock("10 / 玩家成长", "成长不是堆属性，而是扩大解题空间", null),
  grid({ width: fill, height: fill, columns: [fr(1.1), fr(0.9)], columnGap: 42 }, [
    column({ width: fill, height: fill, gap: 22 }, [
      t("玩家从“求生者”变成“明日设计师”", { size: 44, color: C.paper, bold: true }),
      bullets([
        "设施升级：收音机、天线、合成台、储物架、庇护所入口。",
        "工具强化：静音、诱导、干扰、快速采集、战斗终结。",
        "线索能力：保存线索、提高线索品质、预览副作用。",
        "风险管理：Heat / Blight / Nest / Stability 影响长期局势。",
      ], { size: 27 }),
    ]),
    artifactPanel(column({ width: fill, height: fill, gap: 18 }, [
      t("前期关键资源职责", { size: 31, color: C.green, bold: true }),
      t("怪物掉落：残响、怪物材料、特殊合成件。", { size: 25 }),
      t("地图采集：木材、铁片、铜线、磁带、电池、食物。", { size: 25 }),
      rule({ width: fill, stroke: C.line, weight: 2 }),
      t("玩家每天都要权衡：多杀一只怪，还是多采一组材料？", { size: 28, color: C.paper2, bold: true }),
    ])),
  ]),
]);

// 9. Art/UI
slideBase([
  titleBlock("11 / 视觉与交互方向", "末日广播站 + 复古动画 UI，形成高识别度", "收音机、磁带、波形屏、地图板和固定设施槽构成夜晚主界面。"),
  grid({ width: fill, height: fill, columns: [fr(1.15), fr(0.85)], columnGap: 36 }, [
    panel(
      { width: fill, height: fill, fill: "#0E0A08", padding: 0, borderRadius: "rounded-lg" },
      image({
        name: "ui-image",
        dataUrl: uiImageDataUrl,
        width: fill,
        height: fill,
        fit: "cover",
        alt: "收音机 ERS、合成和固定设施界面概念图",
      }),
    ),
    column({ width: fill, height: fill, gap: 22 }, [
      artifactPanel(column({ width: fill, height: hug, gap: 12 }, [
        t("夜晚不是菜单", { size: 31, color: C.green, bold: true }),
        t("而是一个可点击的废弃广播站庇护所。", { size: 25 }),
      ]), { height: hug }),
      artifactPanel(column({ width: fill, height: hug, gap: 12 }, [
        t("固定设施槽", { size: 31, color: C.green, bold: true }),
        t("天线、地图板、发电机、合成台、门栓等固定升级，不做重度沙盒建造。", { size: 25 }),
      ]), { height: hug }),
      artifactPanel(column({ width: fill, height: hug, gap: 12 }, [
        t("可宣传的交互物", { size: 31, color: C.green, bold: true }),
        t("投喂残响、剪磁带、调频、组合线索、播出明天。", { size: 25 }),
      ]), { height: hug }),
    ]),
  ]),
]);

// 10. Demo
slideBase([
  titleBlock("12 / Demo 计划", "先做 30-45 分钟闭环，验证“播出明天”是否成立", null),
  grid({ width: fill, height: fill, columns: [fr(0.9), fr(1.1)], columnGap: 38 }, [
    artifactPanel(column({ width: fill, height: fill, gap: 18 }, [
      t("建议 Demo 内容", { size: 32, color: C.green, bold: true }),
      bullets([
        "天数：7 天",
        "地图：1 张固定骨架地图",
        "敌人：3 种，含 1 个精英/阶段 Boss",
        "资源：6-8 类基础资源",
        "ERS：约 18 个初始组合结果",
        "目标：修复收音机并击败报时者",
      ], { size: 25 }),
    ])),
    column({ width: fill, height: fill, gap: 18 }, [
      t("验证问题", { size: 38, color: C.paper, bold: true }),
      bullets([
        "玩家是否理解“白天拿残响，晚上改明天”？",
        "组合结果是否让人产生“我想试试”的冲动？",
        "灰烬林、回波塔、报时者等结果是否足够有传播性？",
        "狩猎与采集是否形成稳定的双目标压力？",
        "夜晚界面是否有回家和掌控感？",
      ], { size: 28 }),
    ]),
  ]),
]);

// 11. Production roadmap
slideBase([
  titleBlock("13 / 开发路径", "用小规模系统闭环降低立项风险", "当前项目基于 Godot 4.6，已有数据驱动、建造、敌人 AI、昼夜与感知系统积累。"),
  grid({ width: fill, height: fixed(390), columns: [fr(1), fr(1), fr(1)], columnGap: 26 }, [
    artifactPanel(column({ width: fill, height: fill, gap: 16 }, [
      t("里程碑 A", { size: 31, color: C.green, bold: true }),
      t("核心原型", { size: 38, bold: true }),
      t("单日循环、基础狩猎采集、残响投喂、简单 ERS 组合。", { size: 25 }),
    ])),
    artifactPanel(column({ width: fill, height: fill, gap: 16 }, [
      t("里程碑 B", { size: 31, color: C.green, bold: true }),
      t("可玩 Demo", { size: 38, bold: true }),
      t("7 天流程、报时者 Boss、固定设施升级、UI/反馈打磨。", { size: 25 }),
    ])),
    artifactPanel(column({ width: fill, height: fill, gap: 16 }, [
      t("里程碑 C", { size: 31, color: C.green, bold: true }),
      t("垂直切片", { size: 38, bold: true }),
      t("第二阶段线索组合、精英怪、区域风险、宣传素材与商店页。", { size: 25 }),
    ])),
  ]),
  note("立项策略：先验证独特机制和复玩动机，再扩大内容量。"),
]);

// 12. Ask
slideBase([
  titleBlock("14 / 投资用途", "资金主要买时间：把高概念变成可试玩证据", null),
  grid({ width: fill, height: fill, columns: [fr(1.05), fr(0.95)], columnGap: 40 }, [
    column({ width: fill, height: fill, gap: 24 }, [
      t("本轮建议围绕 Demo / 垂直切片融资", { size: 46, color: C.paper, bold: true }),
      t("融资金额可按团队规模与周期另行测算；本立项书先明确资金投向与可验证成果。", {
        size: 29,
        color: C.paper2,
        width: wrap(960),
      }),
      bullets([
        "玩法原型：ERS 组合、地图生成、Boss 触发、资源循环。",
        "内容制作：首阶段地图、敌人、资源、组合池和报时者 Boss。",
        "视听包装：收音机 UI、夜晚庇护所、复古动画风格探索。",
        "测试验证：核心循环留存、组合理解度、Demo 完成率。",
      ], { size: 27 }),
    ]),
    artifactPanel(column({ width: fill, height: fill, gap: 20 }, [
      t("交付物", { size: 32, color: C.green, bold: true }),
      t("30-45 分钟可玩 Demo", { size: 36, color: C.paper, bold: true }),
      t("一套能被玩家复述的核心机制：", { size: 25 }),
      t("白天赚钱给收音机，晚上播出明天。", { size: 34, color: C.red, bold: true }),
      rule({ width: fill, stroke: C.line, weight: 2 }),
      t("下一步：确定第一阶段 Boss、首批组合池、资源与设施升级表。", { size: 25, color: C.paper2 }),
    ])),
  ]),
]);

const pptxBlob = await PresentationFile.exportPptx(presentation);
await pptxBlob.save("output/output.pptx");

for (let i = 0; i < presentation.slides.count; i += 1) {
  const slide = presentation.slides.getItem(i);
  const png = await presentation.export({ format: "png", slide });
  await fs.writeFile(`scratch/slide-${String(i + 1).padStart(2, "0")}.png`, Buffer.from(await png.arrayBuffer()));
}

const layoutBlob = await presentation.inspect();
await fs.writeFile("scratch/inspect.json", JSON.stringify(layoutBlob, null, 2), "utf8");
