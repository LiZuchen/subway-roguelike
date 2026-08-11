# 挤地铁大作战

2D 横板地铁肉鸽游戏。详见 `../GDD.md`（设计文档）和 `../DEVPLAN-ROUND1.md`（开发计划）。

核心循环：挤车厢（5s）→ 到站开门（15s）→ 先下后上（前 5s 只下，后 10s 上下一起）→ 关门 → 下一站。第 5 站玩家必须下车（走进开门侧即可），否则坐过站受罚。

## 玩家属性（设计意图）

| 属性 | 机制 | 当前状态 |
|------|------|----------|
| 体力 | 被挤下车扣 1 格，归零死亡 | 已实现（初始 3 格） |
| 稳定力 | 影响被推搡时的位移 | 已实现（`GameState.stability`） |
| 速度 | 换乘走廊走路速度 | 未实现（暂无走廊场景） |
| 工资 | = HP，迟到扣钱，扣完 game over | 已实现（初始 100 元） |

## 技术栈

- Godot 4.7，GDScript，GL Compatibility 渲染
- 1280×720，不可缩放
- Autoload: `GameState`、`EventBus`

## 项目结构

```
scenes/
  title_screen.tscn / .gd      主菜单
  carriage.tscn / .gd          主游戏场景（所有逻辑在此）
  upgrade_screen.tscn / .gd    升级商店
  result_screen.tscn / .gd     结算画面
scripts/
  global/
    game_state.gd              持久化状态（工资=HP、体力、稳定性）
    event_bus.gd               全局信号
  entities/
    player.gd                  RigidBody2D，WASD 移动，E 抓握
    door.gd                    SlidingDoor — 视觉 Node2D 动画 + StaticBody2D 碰撞分离
    grab_point.gd              抓握点
    passengers/
      base_passenger.gd        RigidBody2D 圆形，Mode: PACKED/EXITING/ENTERING
      office_worker.gd         半径 20，质量 1.0，灰色
      tourist.gd               半径 21，质量 1.8，蓝灰，定期猛转
      auntie.gd                半径 22，质量 2.2，活跃
  systems/
    crowd_physics.gd           人群推挤力、密度计算、车厢晃动
    passenger_spawner.gd       生成/标记/移除乘客
    carriage_state.gd          车门循环（15s 开门）、惯性晃动
  ui/
    hud.gd                     体力、工资、站点显示
    progress_bar.gd            进度条
```

## 关键参数

| 参数 | 值 |
|------|-----|
| 车厢 | 380×240，位于 (450, 240)，墙厚 16 |
| 关门阶段 | 5s |
| 开门阶段 | 15s（前 5s 上车冻结） |
| 初始乘客 | 42 人 |
| 下车人数 | 3-4 人 |
| 上车人数 | 5-7 人 |
| 总站数 | 5 |

## 乘客物理

- 所有乘客和玩家都是 RigidBody2D 圆形，`_integrate_forces` 驱动
- 物理材质: bounce=0.55, friction=0
- 三种模式: PACKED（灰，微动）、EXITING（红，rush 门）、ENTERING（绿，走进来）
- EXITING: mass×2.5, wander_force×3, impulse 800, urgency = 1+time×2/s
- ENTERING: mass×1.2, wander_force×2, impulse 300, 同样 urgency 但进入车厢后衰减
- 下车的人过了车厢边缘删除；不下车的人被挤出则回收为上车

## 车门

- 视觉动画在 `_process` 用 lerp 手动驱动（不用 Tween/AnimatableBody2D）
- 碰撞通过 `collision_layer` 开关（StaticBody2D）
- 开门: 碰撞立即关 → 动画 0.5s，关门: 碰撞立即开 → 动画 0.4s

## 事件信号

- `doors_opened(side)` — -1 左门，+1 右门
- `doors_closed()`
- `carriage_shake(direction, force)`
- `player_fell(stamina_left)` / `player_died()`

## MVP 完成度

已实现:
- 1 条固定线路（5 站，无换乘）
- 3 种乘客（上班族、游客、大妈）
- 早高峰车厢状态（42 人）
- 基础物理推挤（RigidBody2D + 人群推力 + 玩家累计力量）
- 体力 + 工资系统
- 到达结算（准时/迟到判定）
- 1 个升级（健身会员）
- 数据持久化（JSON 存档）
- 车厢惯性晃动
- 扶手抓握

未实现（已计划，后续版本）:
- 换乘走廊、线路选择
- 更多乘客类型（行李箱怪、情侣、看手机低头族）
- 多种车厢状态（下雨、空调坏了、末班车）
- 道具系统（咖啡、雨伞、让座券等）
- 像素美术、音效
- 站台场景（等车、购物）

## 已知偏差（与原计划不同）

- **车厢生存时间**: 原计划 90s/站，实际改为 5s 关门 + 15s 开门循环，节奏更快
- **车门上下客**: 原计划"乘客随机上下"，实际做了"先下后上"的定向物理推挤
- **玩家挤人**: 原计划玩家只被动挨挤，实际加了累计推力（`push_time`）让玩家也能推回去
- **视觉**: 临时方块改为圆形 `_draw()`，不同乘客类型有不同颜色和大小

## 开发约定

- 颜色设值只在 mode-setter 函数中做（`set_exiting`/`set_entering`/`set_packed`），不要在 `_integrate_forces` 每帧设
- 车门碰撞和视觉必须分离，不能用 AnimatableBody2D
- 进入车厢 5s 内不回收被挤出的人（`entering_frozen` 标记）
- 所有操作无需确认，直接执行
