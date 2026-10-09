# Apex 宣传台（ApexPromoter）

面向独立开发者与小团队的品牌推广工作台：管理品牌与产品资料、生成平台化推广文案、导入素材、排期发布并复盘效果。本地优先，不收集任何平台账号凭证。

## 完全免费

**本应用完全免费，无内购、无订阅、无专业版。** 所有功能对所有人开放：

- 内置 Kingtop 自研产品家族，全部免费可推广：
  - **Apex 系列**：PhysicsApex / MathApex / ChemApex / BioApex / ChinApex / EngApex / PolApex / HistApex / GeogApex
  - **WordPulse**：英语词汇复习
  - **Top 系列**：ChinTop（语文）/ MathTop（数学）/ EngTop（英语）
- 建立自己的品牌与产品同样免费，与内置产品享有完整能力。

内置产品的推广文案末尾始终附带官网与下载地址；生成的任何内容发布前都需人工确认。

## 主要功能

1. 品牌中心：品牌语气、禁用词与产品资料集中管理，支持从官网一键导入资料。
2. 客户洞察：区分「已验证事实」与「待验证假设」，只有已验证洞察才会进入生成文案。
3. 推广目标与计划：7 天 / 30 天计划，按平台轮换批量生成推广项目。
4. 创作工作台：纯文字、图文、视频三种发布包，导出或经系统分享发布。
5. 发布队列与复盘：曝光、互动、点击、下载的手工记录与下一周期建议。

## 开发

- iOS 17+，SwiftUI + SwiftData，工程由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 生成：

```bash
xcodegen
xcodebuild -project ApexPromoter.xcodeproj -scheme ApexPromoter \
  -destination 'generic/platform=iOS Simulator' build
```

- 测试：`ApexPromoterTests`（单元）与 `ApexPromoterUITests`（UI）。
- 上架前核对清单见 `docs/release/app-store-checklist.md`。
