package h2d;

/**
 * 可绘制对象基类
 *
 * 所有在屏幕上渲染内容的 2D 对象的基类。
 * 与 Object 不同，Drawable 的所有属性仅应用于当前对象，
 * 不继承给子对象。
 *
 * 功能：
 * - 颜色叠加（color multiplier）
 * - 纹理平滑（smooth bilinear filtering）
 * - UV 环绕（tileWrap）
 * - 颜色键抠图（colorKey chroma key）
 * - 颜色矩阵变换
 * - 颜色加法
 * - 自定义着色器
 */
class Drawable extends Object {

	/**
	 * 颜色乘数（RGBA，默认 [1,1,1,1]）
	 * 可单独调整每个通道，color.a 控制透明度
	 */
	public var color(default,default) : h3d.Vector4;

	/**
	 * 纹理平滑
	 * true=硬件双线性过滤（缩放更平滑但可能模糊）
	 * false=最近邻采样（保持像素风格）
	 * null=使用 Scene.defaultSmooth 的值
	 */
	public var smooth : Null<Bool>;

	/**
	 * 纹理 UV 环绕模式
	 * 当 UV 超出纹理边界时：
	 * true=重复纹理（Repeat）
	 * false=边缘钳制（Clamp）
	 *
	 * 注意：使用的是底层纹理的大小而不是 Tile 区域，
	 * 所以仅在 Tile 覆盖整个纹理时效果正确
	 */
	public var tileWrap(default, set) : Bool;

	/** 颜色键（Chroma Key），匹配的像素将被丢弃 */
	public var colorKey(default, set) : Null<Int>;

	/** 颜色矩阵变换（参见 adjustColor） */
	public var colorMatrix(get, set) : Null<h3d.Matrix>;

	/** 颜色加法（RGBA 各通道的偏移量） */
	public var colorAdd(get, set) : Null<h3d.Vector>;

	/** 着色器列表 */
	var shaders : hxsl.ShaderList;

	/**
	 * 创建 Drawable 实例
	 * @param parent 可选的父对象
	 */
	function new(parent : h2d.Object) {
		super(parent);
		color = new h3d.Vector4(1, 1, 1, 1);
	}

	function set_tileWrap(b) {
		return tileWrap = b;
	}

	function get_colorAdd() {
		var s = getShader(h3d.shader.ColorAdd);
		return s == null ? null : s.color;
	}

	function set_colorAdd( c : h3d.Vector ) {
		var s = getShader(h3d.shader.ColorAdd);
		if( s == null ) {
			if( c != null ) {
				s = addShader(new h3d.shader.ColorAdd());
				s.color = c;
			}
		} else {
			if( c == null )
				removeShader(s);
			else
				s.color = c;
		}
		return c;
	}

	override function drawFiltered(ctx:RenderContext, tile:Tile) {
		var old = shaders;
		shaders = null;
		super.drawFiltered(ctx, tile);
		shaders = old;
	}

	function set_colorKey(v:Null<Int>) {
		var s = getShader(h3d.shader.ColorKey);
		if( s == null ) {
			if( v != null )
				s = addShader(new h3d.shader.ColorKey(0xFF000000 | v));
		} else {
			if( v == null )
				removeShader(s);
			else
				s.colorKey.setColor(0xFF000000 | v);
		}
		return colorKey = v;
	}

	/**
		Set the `Drawable.colorMatrix` value by specifying which effects to apply.
		Calling `adjustColor()` without arguments will reset the colorMatrix to `null`.
	**/
	public function adjustColor( ?col : h3d.Matrix.ColorAdjust ) : Void {
		if( col == null )
			colorMatrix = null;
		else {
			var m = colorMatrix;
			if( m == null ) {
				m = new h3d.Matrix();
				colorMatrix = m;
			}
			m.identity();
			m.adjustColor(col);
		}
	}

	function get_colorMatrix() {
		var s = getShader(h3d.shader.ColorMatrix);
		return s == null ? null : s.matrix;
	}

	function set_colorMatrix(m:h3d.Matrix) {
		var s = getShader(h3d.shader.ColorMatrix);
		if( s == null ) {
			if( m != null ) {
				s = addShader(new h3d.shader.ColorMatrix());
				s.matrix = m;
			}
		} else {
			if( m == null )
				removeShader(s);
			else
				s.matrix = m;
		}
		return m;
	}

	/**
		Returns the first shader of the given shader class among the drawable shaders.
		@param stype The class of the shader to look up.
	**/
	public function getShader< T:hxsl.Shader >( stype : Class<T> ) : T {
		if (shaders != null) for( s in shaders ) {
			var s = Std.downcast(s, stype);
			if( s != null )
				return s;
		}
		return null;
	}

	/**
		Returns an iterator of all drawable shaders
	**/
	public inline function getShaders() {
		return shaders.iterator();
	}

	/**
		Add a shader to the drawable shaders.

		Keep in mind, that as stated before, drawable children do not inherit Drawable properties, which includes shaders.
	**/
	public function addShader<T:hxsl.Shader>( s : T ) : T {
		if( s == null ) throw "Can't add null shader";
		shaders = hxsl.ShaderList.addSort(s, shaders);
		return s;
	}

	/**
		Remove a shader from the drawable shaders, returns true if found or false if it was not part of our shaders.
	**/
	public function removeShader( s : hxsl.Shader ) {
		var prev = null, cur = shaders;
		while( cur != null ) {
			if( cur.s == s ) {
				if( prev == null )
					shaders = cur.next;
				else
					prev.next = cur.next;
				return true;
			}
			prev = cur;
			cur = cur.next;
		}
		return false;
	}

	override function emitTile( ctx : RenderContext, tile : Tile ) {
		if( tile == null )
			tile = new Tile(null, 0, 0, 5, 5);
		if( !ctx.hasBuffering() ) {
			if( !ctx.drawTile(this, tile) ) return;
			return;
		}
		if( !ctx.beginDrawBatch(this, tile.getTexture()) ) return;

		var alpha = color.a * ctx.globalAlpha;
		var ax = absX + tile.dx * matA + tile.dy * matC;
		var ay = absY + tile.dx * matB + tile.dy * matD;
		var buf = ctx.buffer;
		var pos = ctx.bufPos;
		buf.grow(pos + 4 * 8);

		inline function emit(v:Float) buf[pos++] = v;

		emit(ax);
		emit(ay);
		emit(tile.u);
		emit(tile.v);
		emit(color.r);
		emit(color.g);
		emit(color.b);
		emit(alpha);


		var tw = tile.width;
		var th = tile.height;
		var dx1 = tw * matA;
		var dy1 = tw * matB;
		var dx2 = th * matC;
		var dy2 = th * matD;

		emit(ax + dx1);
		emit(ay + dy1);
		emit(tile.u2);
		emit(tile.v);
		emit(color.r);
		emit(color.g);
		emit(color.b);
		emit(alpha);

		emit(ax + dx2);
		emit(ay + dy2);
		emit(tile.u);
		emit(tile.v2);
		emit(color.r);
		emit(color.g);
		emit(color.b);
		emit(alpha);

		emit(ax + dx1 + dx2);
		emit(ay + dy1 + dy2);
		emit(tile.u2);
		emit(tile.v2);
		emit(color.r);
		emit(color.g);
		emit(color.b);
		emit(alpha);

		ctx.bufPos = pos;
	}

}
