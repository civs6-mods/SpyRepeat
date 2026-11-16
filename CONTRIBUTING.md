# 参与开发 / Contributing

欢迎提交问题、翻译、测试和 Lua/UI 改进。Please open an issue or pull request in this repository.

## 问题报告 / Bug reports

提供游戏及 DLC 版本、HD 版本（如使用）、启用的 Mod、复现步骤、期望和实际结果。UI 问题请附截图、分辨率及 UI 比例；脚本问题请附相关 Lua.log 或 Modding.log 错误片段。不要提交凭证或无关个人信息。

Include game/DLC and mod versions, reproduction steps, expected and actual behavior, and relevant log excerpts. For UI issues, include a screenshot, resolution and UI scale.

## 验证 / Validation

按 README 运行校验、回归和打包。`tests/` 使用实际 Lua 源码及模拟的游戏接口；UI 或引擎行为改动还应进行实机检查，注明已验证的环境和未覆盖的场景。

Run the README verification, regression and packaging commands. UI or engine-facing changes also need real-game checks with the tested setup and limitations documented.

修改 `mod/` 时保留其字节和换行约定；发布新版本时同步版本号和 `release-manifest.json`，不要通过删除校验绕过差异。勿提交 `node_modules`、生成的 `dist`、游戏存档或完整本机日志。

For runtime changes, preserve file line-ending conventions and update version metadata and release hashes intentionally. Do not bypass verification or commit dependencies, generated packages, saves or full local logs. Keep pull requests focused and describe behavior changes and validation.
