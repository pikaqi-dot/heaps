package h2d;

/**
 * 位图（Bitmap）
 *
 * 在屏幕上显示单个 Tile 的最简单的 Drawable。
 * 适合显示少量图像，对于大量图像请使用 `h2d.SpriteBatch` 或 `h2d.TileGroup`。
 *
 * 功能：
 * - 显示一个 Tile（纹理区域）
 * - 可设置目标宽度/高度（自动保持宽高比）
 * - tile 为 null 时显示粉色占位图
 */
class Bitmap extends Drawable {

	/** 要显示的 Tile。为 null 时显示粉色 5×5 位图 */
	public var tile(default,set) : Tile;

	/**
	 * 目标宽度
	 * 设置后 Tile 将缩放到此宽度（保持宽高比）
	 * 除非同时设置 height
	 */
	public var width(default,set) : Null<Float>;

	/**
	 * 目标高度
	 * 设置后 Tile 将缩放到此高度（保持宽高比）
	 * 除非同时设置 width
	 */
	public var height(default,set) : Null<Float>;

	/**
	 * 创建 Bitmap
	 * @param tile 要显示的 Tile
	 * @param parent 可选的父对象
	 */
	public function new( ?tile : Tile, ?parent : h2d.Object ) {
		super(parent);
		this.tile = tile;
	}

	override function getBoundsRec( relativeTo : Object, out : h2d.col.Bounds, forSize : Bool ) {
		super.getBoundsRec(relativeTo, out, forSize);
		if( tile != null ) {
			if( width == null && height == null )
				addBounds(relativeTo, out, tile.dx, tile.dy, tile.width, tile.height);
			else
				addBounds(relativeTo, out, tile.dx, tile.dy,
					width != null ? width : tile.width * height / tile.height,
					height != null ? height : tile.height * width / tile.width);
		}
	}

	function set_width(w) {
		if( width == w ) return w;
		width = w;
		onContentChanged();
		return w;
	}

	function set_height(h) {
		if( height == h ) return h;
		height = h;
		onContentChanged();
		return h;
	}

	function set_tile(t) {
		if( tile == t ) return t;
		tile = t;
		onContentChanged();
		return t;
	}

	/**
	 * 渲染位图
	 * 处理缩放逻辑：如果设置了 width/height，临时修改 Tile 大小再渲染
	 */
	override function draw( ctx : RenderContext ) {
		if( width == null && height == null ) {
			emitTile(ctx, tile);
			return;
		}
		if( tile == null ) tile = h2d.Tile.fromColor(0xFF00FF);  // 粉色占位
		var ow = tile.width;
		var oh = tile.height;
		@:privateAccess {
			tile.width = width != null ? width : ow * height / oh;
			tile.height = height != null ? height : oh * width / ow;
		}
		emitTile(ctx, tile);
		@:privateAccess {
			tile.width = ow;   // 恢复原始尺寸
			tile.height = oh;
		}
	}

}
