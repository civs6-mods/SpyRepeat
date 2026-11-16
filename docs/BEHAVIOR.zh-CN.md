# 循环规则与暂停行为

## 暂停与手动安排

- 游戏提供可选晋升时暂停；使用实际晋升指令查询，避免硬编码原版升级次数。处理晋升后，选中该间谍，点击单位操作栏的循环按钮恢复。如果原目标被引擎判定不可用，请先手动指派合法任务，再开启循环。
- 遇到需要逃跑的任务结果时暂停，逃跑路线仍在游戏原界面选择。不会代选路线或自动关闭结果弹窗。
- 原任务不合法、城市归属变化、间谍调动或离开地图时暂停，在单位按钮的悬浮提示中显示原因。临时失效也需要手动恢复，不会在条件变化后突然续派。
- 被捕、阵亡和旅行可能都表现为离开地图，本 Mod 不推断具体原因，提示查看原间谍界面。
- 同一城市内手动换成另一个可重复任务，会更新循环任务；主动调往其他城市会暂停，需要重新安排后开启。
- 若游戏为归来的间谍分配了新单位 ID，需要为新单位重新开启；旧记录不会按名字自动绑定。
- 状态和每回合续派保护存入玩家属性，随游戏存档保存。每名间谍每回合最多提交一次自动续派。

通过原生任务确认记录任务类型和目标；不会自动挑选城市、分配任务权重或做晋升选择。获取来源属于准备行动，循环选项禁用并说明原因。


## 界面适配

扩展游戏的任务简报、间谍选择器和间谍总览 Lua 上下文，不替换原 XML、不修改任务或晋升数值。其他 Mod 若替换相同 Lua 上下文，可能互相覆盖。晋升沿用游戏及 HD 的原界面。

设置确认失败时停止续派；关闭失败显示「重试关闭」。回合交接和游戏忙碌期间暂停确认计时，续派前重新检查间谍和目标。

## 接口参考

独立编写，接口行为参考公开源码：

- [HD 间谍晋升界面](https://github.com/XHH-Coco/Civ6HarmonyInDiversity/blob/master/UI/Replacement/HD_PKSpyUnitPromotionPopup.lua)
- [HD 单位面板的晋升指令查询](https://github.com/XHH-Coco/Civ6HarmonyInDiversity/blob/master/UI/Replacement/DL_UnitPanel.lua)
- [HD 状态保存操作](https://github.com/XHH-Coco/Civ6HarmonyInDiversity/blob/master/Gameplay/HD_StateUtils.lua)
- [CQUI / Better Espionage Screen](https://github.com/Azurency/CQUI_Community-Edition/tree/master/Integrations/BES)
