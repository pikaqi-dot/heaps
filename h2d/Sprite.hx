package h2d;

#if !heaps_sprite
@:deprecated("h2d.Sprite 已重命名为 h2d.Object，请重命名或使用 -D heaps-sprite 编译器标志")
@:noCompletion
@:dox(hide)
#end
/**
 * 精灵（Sprite）
 *
 * 注意：h2d.Sprite 已重命名为 h2d.Object。
 * Sprite 现在是 Object 的类型别名，保留用于向后兼容。
 *
 * 请直接使用 h2d.Object。
 */
typedef Sprite = Object;