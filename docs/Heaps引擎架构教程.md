# Heaps 引擎架构教程

> 本文档基于 Heaps 引擎源代码，深入分析其架构设计、模块划分和核心原理。
> 适用于希望理解 Heaps 内部机制的游戏开发者。

---

## 📋 目录

1. [引擎概述](#1-引擎概述)
2. [项目结构总览](#2-项目结构总览)
3. [核心数学模块](#3-核心数学模块)
4. [渲染引擎核心](#4-渲染引擎核心)
5. [着色器系统（HXSL）](#5-着色器系统hxsl)
6. [材质与纹理系统](#6-材质与纹理系统)
7. [相机与投影系统](#7-相机与投影系统)
8. [碰撞检测系统](#8-碰撞检测系统)
9. [动画系统](#9-动画系统)
10. [渲染管线与通道](#10-渲染管线与通道)
11. [常见问题与模式](#11-常见问题与模式)

---

## 1. 引擎概述

### 1.1 什么是 Heaps

Heaps 是一个使用 [Haxe](https://haxe.org/) 编写的跨平台 3D/2D 游戏引擎，由 Nicolas Cannasse（Haxe 语言的创建者）开发。它的设计理念是：

- **高性能**：最小化 GC 压力，大量使用对象池和值类型
- **跨平台**：支持 Vulkan / OpenGL / DirectX 等多个图形 API
- **简洁优雅**：API 设计精简，易于理解
- **GPU 优先**：尽可能将计算推向 GPU

### 1.2 架构层级

```
┌─────────────────────────────────────────┐
│             用户层代码                    │
│  (h3d.scene.Object, h2d.Object 等)       │
├─────────────────────────────────────────┤
│          场景图 / 对象系统                │
│  (h3d.scene.*)                          │
├─────────────────────────────────────────┤
│         渲染通道系统                      │
│  (h3d.pass.*)                           │
├─────────────────────────────────────────┤
│       材质 / 着色器系统                   │
│  (h3d.mat.*, hxsl.*)                    │
├─────────────────────────────────────────┤
│        GPU 资源管理                      │
│  (h3d.Buffer, h3d.mat.Texture, 等)      │
├─────────────────────────────────────────┤
│        图形驱动抽象层                     │
│  (h3d.impl.Driver - GL/Vulkan/DX)       │
├─────────────────────────────────────────┤
│       底层硬件 / 操作系统                 │
└─────────────────────────────────────────┘
```

### 1.3 坐标系约定

Heaps **默认使用左手坐标系**（Left-Handed Coordinate System）：

```
X ──→ 右
Y ──→ 下（屏幕坐标原点在左上角）
Z ──→ 朝向用户（屏幕外）

旋转方向：从轴正方向看，顺时针为正
叉积：左手定则
```

这一选择使得 2D 游戏开发更自然（[0,0] 在屏幕左上角，Y 正方向朝下）。

---

## 2. 项目结构总览

```
heaps/
├── h3d/              # 3D 渲染核心
│   ├── Engine.hx     # 渲染引擎主入口
│   ├── Camera.hx     # 相机系统
│   ├── Matrix.hx     # 4x4 矩阵（变换核心）
│   ├── Vector.hx     # 3D 向量
│   ├── Vector4.hx    # 4D 齐次向量
│   ├── Quat.hx       # 四元数（旋转）
│   ├── Buffer.hx     # GPU 缓冲区
│   ├── Indexes.hx    # 索引缓冲区
│   ├── anim/         # 动画系统
│   ├── col/          # 碰撞检测
│   ├── impl/         # 图形驱动实现
│   ├── mat/          # 材质与纹理
│   ├── pass/         # 渲染通道
│   ├── prim/         # 几何体原语
│   ├── scene/        # 场景图
│   └── shader/       # HXSL 着色器
├── h2d/              # 2D 渲染核心
├── hxd/              # 通用工具库
└── hxsl/             # HXSL 着色器编译器
```

---

## 3. 核心数学模块

Heaps 的数学库是引擎的基础，所有 3D 变换都依赖于此。

### 3.1 4×4 矩阵 [`h3d/Matrix.hx`](h3d/Matrix.hx)

矩阵使用**行主序**（Row-Major）存储，16 个元素命名为 `_RC`（R=行, C=列）：

```
[ _11  _12  _13  _14 ]  行 0
[ _21  _22  _23  _24 ]  行 1
[ _31  _32  _33  _34 ]  行 2
[ _41  _42  _43  _44 ]  行 3 — 平移量
```

**关键设计**：

- **`MatrixImpl`** → 实现类（包含所有方法）
- **`Matrix`** → 抽象包装（`@:forward` 代理 + 运算符重载）

这种分离模式允许值类型语义和运算符重载（如 `m1 * m2`）。

**核心操作**：

| 方法 | 用途 | 说明 |
|------|------|------|
| `initRotationX/Y/Z` | 绕轴旋转 | 角度（弧度） |
| `initRotation` | 欧拉角旋转 | ZYX 顺序 |
| `initRotationAxis` | 绕任意轴旋转 | Rodriques 公式 |
| `initTranslation/Scale` | 平移/缩放 | 仿射变换基础 |
| `multiply` | 4×4 矩阵乘法 | 完整矩阵相乘 |
| `multiply3x4` | 3×4 矩阵乘法 | 假设行3=[0,0,0,1] |
| `initInverse` | 4×4 逆矩阵 | 代数余子式法 |
| `inverse3x4` | 3×4 仿射逆 | R^T \| -R^T*t |
| `getEulerAngles` | 提取欧拉角 | 处理万向锁 |
| `decomposeMatrix` | 分解为 S+Q+T | 动画插值用 |
| `colorHue/Saturate/etc` | 颜色调整 | 颜色矩阵运算 |

### 3.2 三维向量 [`h3d/Vector.hx`](h3d/Vector.hx)

Vector 同时也是 RGB 颜色表示（r/g/b 别名 x/y/z）。

**关键设计模式**：`VectorImpl` + `Vector`（抽象转发）- 同上。

**特殊函数**：

| 函数 | 说明 |
|------|------|
| `packNormal/unpackNormal` | 法线 [−1,1] ↔ [0,1] 压缩 |
| `normalStrength` | 调整法线强度后归一化 |
| `project` | 透视投影（含 w 除法的矩阵变换） |
| `makeColor` | HSL → RGB |
| `toColorHSL/HSV` | RGB → HSL/HSV |

### 3.3 四元数 [`h3d/Quat.hx`](h3d/Quat.hx)

四元数 q = w + xi + yj + zk，其中 w 为实部。

**关键公式**：

- 绕轴旋转：q = cos(θ/2) + sin(θ/2)(uxi + uyj + uzk)
- 共轭（= 逆）：conjugate(q) = (w, -x, -y, -z)
- 矩阵↔四元数：使用**迹（Trace）方法**，分 4 个分支保证数值稳定

**插值选择**：

| 方法 | 速度 | 精度 | 适用场景 |
|------|------|------|----------|
| `lerp` | 快 | 低（不保证恒定角速度） | 性能敏感 |
| `slerp` | 慢 | 高（测地线插值） | 平滑动画 |

---

## 4. 渲染引擎核心

### 4.1 `Engine` 类 [`h3d/Engine.hx`](h3d/Engine.hx)

`Engine` 是渲染的**总入口**，采用单例模式（`getCurrent()`）。

**渲染帧周期**：

```
begin() ──→ [清屏] ──→ [选择着色器] ──→ [选择缓冲] ──→ [绘制] ──→ end()
     ↑                                                        │
     └──────────────────── render() ──────────────────────────┘
```

**驱动选择优先级**（`new()` 构造函数中自动检测）：

```
Vulkan → OpenGL → DirectX 12 → DirectX 11 → 软件渲染
```

**性能计数器**（每帧重置）：

| 计数器 | 说明 |
|--------|------|
| `drawTriangles` | 绘制的三角形总数 |
| `drawCalls` | 绘制调用次数（应尽量降低） |
| `shaderSwitches` | 着色器切换次数 |
| `dispatches` | 计算调度次数 |

### 4.2 渲染目标栈（MRT 支持）

Heaps 使用**链表栈**管理渲染目标，支持：

- **单目标**：`pushTarget(tex)` / `popTarget()`
- **多目标（MRT）**：`pushTargets(textures)`
- **仅深度**：`pushDepth(depthBuffer)`

使用**惰性刷新**（`needFlushTarget` 标志），避免重复设置相同目标。

### 4.3 GPU 内存管理

`h3d.impl.MemoryManager` 负责：

- 缓冲区的分配和释放
- 预分配三角形/四边形索引（`getTriIndexes` / `getQuadIndexes`）
- 上下文丢失时的资源恢复

---

## 5. 着色器系统（HXSL）

### 5.1 HXSL 简介

HXSL（Heaps Shading Language）是 Heaps 的类 GLSL 着色器语言，使用 Haxe 宏在编译时生成 GPU 着色器代码。

**工作流程**：

```
Haxe 类 (hxsl.Shader 子类)
    ↓ @:autoBuild(hxsl.Macros.buildShader())
HXSL 源码 (static var SRC)
    ↓ Haxe 宏
HXL 中间表示 (AST)
    ↓ hxsl/GlslOut, HlslOut, NXGlslOut
GLSL / HLSL / SPIR-V
    ↓ 图形驱动
GPU 执行
```

### 5.2 着色器结构 [`h3d/shader/BaseMesh.hx`](h3d/shader/BaseMesh.hx)

```hxsl
@global var camera : { ... };     // GPU Uniform Buffer（引擎填充）
@param var color : Vec4;          // 可在 Haxe 中设置的参数
@input var input : { ... };       // 顶点输入属性

// 着色器阶段
function __init__()     { ... }   // 顶点初始化（自动排序）
function __init__fragment() { ... } // 片段初始化
function vertex()       { ... }   // 顶点着色器（必选）
function fragment()     { ... }   // 片段着色器（必选）
```

**变量声明**：

| 声明 | 含义 |
|------|------|
| `@global` | 全局统一变量（如相机矩阵、时间） |
| `@param` | 着色器参数（可在 Haxe 代码中设置） |
| `@perObject` | 每个对象的独立数据 |
| `@input` | 顶点输入属性 |
| `var` | 中间变量（自动在 vertex/fragment 间传递） |
| `@range(min,max)` | 参数范围限制 |

### 5.3 运动向量（Motion Vector）系统

`BaseMesh` 内置运动向量计算：

```hxsl
// 计算当前帧和上一帧的 NDC 位置
ndcPosition = projectedPosition.xy / projectedPosition.w;
previousNdcPosition = previousProjectedPosition.xy / previousProjectedPosition.w;

// 去抖动（TAA 需要）
ndcPosition -= camera.jitterOffsets.xy;
previousNdcPosition -= camera.jitterOffsets.zw;

// 运动向量
pixelVelocity = (previousNdcPosition - ndcPosition) * vec2(0.5, -0.5);
```

---

## 6. 材质与纹理系统

### 6.1 材质管线

```
Shader (着色器)
    ↓
Pass (通道 — 如颜色、深度、阴影)
    ↓
Material (材质 — 组合多个 Pass)
    ↓
MeshObject (网格对象)
```

### 6.2 纹理格式

Heaps 支持多种纹理格式，包括压缩格式（DXT/BCn、ETC、ASTC 等）。

**关键类型**：

- `h3d.mat.Texture` — 2D 纹理
- `h3d.mat.TextureArray` — 纹理数组
- `h3d.mat.TextureHandle` — 纹理句柄（采样器）

---

## 7. 相机与投影系统

### 7.1 相机矩阵 [`h3d/Camera.hx`](h3d/Camera.hx)

相机使用三个矩阵：

```
mcam   = 视图矩阵（世界→相机空间）
mproj  = 投影矩阵（相机→裁剪空间）
m      = mcam × mproj（最终变换矩阵）
```

**构建过程**：

```
update():
  1. makeCameraMatrix(mcam)  — LookAt 矩阵（转置版本）
  2. makeFrustumMatrix(mproj) — 透视或正交投影
  3. m = mcam × mproj
  4. frustum.loadMatrix(m)   — 更新视锥体
```

### 7.2 投影矩阵

**透视投影**：

```
m._11 = scale              // scale = zoom / tan(halfFovX)
m._22 = scale * screenRatio
m._33 = zFar / (zFar - zNear)  // 反向：-zNear/(zFar-zNear)
m._34 = 1
m._43 = -(zNear*zFar)/(zFar-zNear)
```

**正交投影**（设置 `orthoBounds` 时）：

```
m._11 = 2 / (xMax - xMin)
m._22 = 2 / (yMax - yMin)
m._33 = 1 / (zMax - zMin)
```

### 7.3 视锥体裁剪

`Frustum` 类通过从投影矩阵提取 6 个平面实现视锥体裁剪，优化渲染性能。

---

## 8. 碰撞检测系统

### 8.1 碰撞体层级 [`h3d/col/Collider.hx`](h3d/col/Collider.hx)

```
Collider (抽象基类)
├── Bounds      (AABB 包围盒)
├── Sphere      (球体)
├── Capsule     (胶囊体)
├── Cylinder    (圆柱体)
├── Polygon     (多边形)
├── OptimizedCollider (a:粗略 + b:精确)
└── GroupCollider (集合批量检测)
```

**统一接口**：

| 方法 | 用途 |
|------|------|
| `rayIntersection(r, bestMatch)` | 射线相交检测（返回距离） |
| `contains(p)` | 点包含检测 |
| `inFrustum(f, m?)` | 视锥体可见性 |
| `inSphere(s)` | 球体相交 |
| `closestPoint(p)` | 最近点 |

### 8.2 射线与 AABB 碰撞（Slab 方法）

[`Ray.hx`](h3d/col/Ray.hx) 使用**Slab 方法**进行光线与 AABB 的快速碰撞检测：

```
对每个轴计算 tmin/tmax
tmin = max(tmin_x, tmin_y, tmin_z)
tmax = min(tmax_x, tmax_y, tmax_z)
相交条件：tmin <= tmax && tmax >= 0
```

### 8.3 优化策略

`OptimizedCollider` 实现**先粗筛后精测**策略：

```
1. 用粗略碰撞体 a（如 AABB）快速测试
2. 如果 a 检测通过，再用精确碰撞体 b（如 Mesh）精确检测
3. 可选的 checkInside 模式支持内部检测
```

---

## 9. 动画系统

### 9.1 动画层级 [`h3d/anim/Animation.hx`](h3d/anim/Animation.hx)

```
Animation (基类)
├── LinearAnimation   (线性关键帧插值)
├── BufferAnimation   (GPU 骨骼动画)
├── SimpleBlend       (简单混合)
├── SmoothTransition  (平滑过渡)
└── ...
```

### 9.2 矩阵分解/重组

动画插值的关键技术是矩阵分解：[`Matrix.decomposeMatrix()`](h3d/Matrix.hx:931)

```
原始矩阵 M = S × R × T
分解后：
  _11 = ScaleX,  _12 = QuatX,  _13 = QuatY
  _21 = QuatZ,   _22 = ScaleY, _23 = QuatW
  _33 = ScaleZ
  _41 = PosX,    _42 = PosY,   _43 = PosZ
```

这样可以将旋转（四元数）、缩放和平移分离，独立插值后重组。

---

## 10. 渲染管线与通道

### 10.1 Pass 系统

渲染通道（Pass）是 Heaps 渲染管线的核心抽象：

```
PassObject (链表节点)
    ↓
PassList (链表管理 — 排序/过滤/恢复)
    ↓
按优先级/材质排序
    ↓
遍历执行渲染
```

**通道过滤**：[`PassList.filter()`](h3d/pass/PassList.hx:132) 使用**双向移动**算法：
- 满足条件的保留在当前列表
- 不满足的移动到丢弃列表
- 下一帧通过 `reset()` 恢复

### 10.2 渲染排序

```haxe
// 按材质对通道进行排序
passList.sort(sortByMaterial);
```

排序使用 `haxe.ds.ListSort.sortSingleLinked`（归并排序）。

---

## 11. 常见问题与模式

### 11.1 对象池模式

Heaps 大量使用对象池减少 GC 压力：

```haxe
// TargetTmp 对象池（Engine.hx）
var targetTmp : TargetTmp;
// 从池中取
if( c == null ) c = new TargetTmp(...);
else { targetTmp = c.next; ... }
// 放回池
c.next = targetTmp;
targetTmp = c;
```

### 11.2 惰性求值 / 缓存失效

使用位掩码跟踪需要重新计算的数据：

```haxe
// Camera.hx
inline static final invMask = 1 << 0;
var initFlag : Int = 0;

function getInverseViewProj() {
    if (isInit(invMask)) {   // 需要重新计算？
        minv.initInverse(m);
        markInit(invMask);    // 标记已计算
    }
    return minv;
}
// update() 时重置所有标记
function update() { initFlag = 0; ... }
```

### 11.3 着色器常量管理

使用 `constBits` 位掩码跟踪着色器常量的修改：

```
constBits 的每一位对应一个常量（整数/布尔/纹理通道）
当常量值改变时，constBits 变化 → 获取新的 ShaderInstance
这样只需在常量改变时才重新生成着色器变体
```

### 11.4 性能优化建议

1. **减少 Draw Call**：合并网格、使用实例化渲染
2. **减少着色器切换**：按材质排序渲染
3. **使用对象池**：避免频繁分配/释放内存
4. **惰性求值**：只在需要时计算（如矩阵求逆）
5. **预分配索引**：使用 `mem.getTriIndexes()` 避免重复创建索引缓冲

---

> 本文档将持续更新。如有疑问或建议，请参考 Heaps 官方文档和源代码。
