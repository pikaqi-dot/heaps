package h3d;

/**
 * 索引缓冲区（Index Buffer）
 *
 * 用于索引绘制（Indexed Drawing）的 GPU 缓冲区抽象。
 * 索引缓冲区定义了绘制三角形时顶点的顺序，允许复用顶点数据。
 *
 * 支持两种索引格式：
 * - 16位索引（INDEX16）：最多 65535 个顶点
 * - 32位索引（INDEX32）：最多 4,294,967,295 个顶点
 *
 * 通过 `@:forward` 代理到 `Buffer` 的基础操作（dispose, isDisposed, uploadBytes）
 */
@:forward(isDisposed, dispose, uploadBytes)
abstract Indexes(Buffer) to Buffer {

	/** 索引数量 */
	public var count(get,never) : Int;

	/**
	 * 创建索引缓冲区
	 * @param count 索引数量
	 * @param is32 是否使用 32 位索引（默认 16 位）
	 */
	public function new(count:Int,is32=false) {
		this = new Buffer(count, is32 ? hxd.BufferFormat.INDEX32 : hxd.BufferFormat.INDEX16, [IndexBuffer]);
	}

	/**
	 * 上传索引数据到 GPU
	 * @param ibuf 源索引缓冲
	 * @param bufPos 源缓冲中的起始位置
	 * @param indices 要上传的索引数量
	 * @param startIndice 目标缓冲区中的起始位置
	 */
	public function uploadIndexes( ibuf : hxd.IndexBuffer, bufPos : Int, indices : Int, startIndice = 0 ) {
		if( startIndice < 0 || indices < 0 || startIndice + indices > this.vertices )
			throw "索引数无效";
		if( @:privateAccess this.format.inputs[0].precision != F16 )
			throw "无法在 32 位缓冲区上上传索引";
		if( indices == 0 )
			return;
		h3d.Engine.getCurrent().driver.uploadIndexData(this, startIndice, indices, ibuf, bufPos);
	}

	inline function get_count() return this.vertices;

	/**
	 * 从 IndexBuffer 分配并上传索引缓冲区
	 * @param i 源索引数据
	 * @param startPos 起始位置
	 * @param length 长度（默认全部）
	 */
	public static function alloc( i : hxd.IndexBuffer, startPos = 0, length = -1 ) : Indexes {
		if( length < 0 ) length = i.length;
		var idx = new Indexes(length);
		idx.uploadIndexes(i, 0, length);
		return idx;
	}

	/** 从通用 Buffer 转换为 Indexes */
	public static function ofBuffer( b : Buffer ) : Indexes {
		return cast b;
	}

}