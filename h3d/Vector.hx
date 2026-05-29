package h3d;
using hxd.Math;

/**
 * 三维向量（3D Vector）
 * 包含 x、y、z 三个 Float 分量的向量类
 * 每次返回 Vector 时都会创建新副本（值类型语义）
 */
class VectorImpl #if apicheck implements h2d.impl.PointApi<Vector,Matrix> #end {

	/** X 分量（也可用作颜色 R 分量） */
	public var x : Float;
	/** Y 分量（也可用作颜色 G 分量） */
	public var y : Float;
	/** Z 分量（也可用作颜色 B 分量） */
	public var z : Float;

	// -- 通用 API

	public inline function new( x = 0., y = 0., z = 0. ) {
		this.x = x;
		this.y = y;
		this.z = z;
	}

	/** 计算到另一个向量的距离 */
	public inline function distance( v : Vector ) {
		return Math.sqrt(distanceSq(v));
	}

	/** 计算到另一个向量的距离平方（避免开方，更高效） */
	public inline function distanceSq( v : Vector ) {
		var dx = v.x - x;
		var dy = v.y - y;
		var dz = v.z - z;
		return dx * dx + dy * dy + dz * dz;
	}

	/** 向量减法：返回 this - v */
	public inline function sub( v : Vector ) {
		return new Vector(x - v.x, y - v.y, z - v.z);
	}

	/** 向量加法：返回 this + v */
	public inline function add( v : Vector ) {
		return new Vector(x + v.x, y + v.y, z + v.z);
	}

	/** 向量缩放：返回 this * v */
	public inline function scaled( v : Float ) {
		return new Vector(x * v, y * v, z * v);
	}

	/** 判断是否与另一向量完全相等 */
	public inline function equals( v : Vector ) {
		return x == v.x && y == v.y && z == v.z;
	}

	/**
	 * 向量叉积（Cross Product）
	 * 注意：Heaps 使用左手坐标系
	 * 结果向量垂直于 this 和 v 组成的平面
	 */
	public inline function cross( v : Vector ) {
		return new Vector(y * v.z - z * v.y, z * v.x - x * v.z,  x * v.y - y * v.x);
	}

	/** 向量点积（Dot Product）：结果是标量 */
	public inline function dot( v : Vector ) {
		return x * v.x + y * v.y + z * v.z;
	}

	/** 长度平方（避免开方，更高效） */
	public inline function lengthSq() {
		return x * x + y * y + z * z;
	}

	/** 向量长度 */
	public inline function length() {
		return lengthSq().sqrt();
	}

	/**
	 * 原地归一化
	 * 将向量长度缩放为 1（单位向量）
	 * 如果向量长度接近零，则不做处理
	 */
	public inline function normalize() {
		var k = lengthSq();
		if( k < hxd.Math.EPSILON2 ) k = 0 else k = k.invSqrt();
		x *= k;
		y *= k;
		z *= k;
	}

	/**
	 * 返回归一化的新向量副本
	 * 原向量不变
	 */
	public inline function normalized() {
		var k = lengthSq();
		if( k < hxd.Math.EPSILON2 ) k = 0 else k = k.invSqrt();
		return new Vector(x * k, y * k, z * k);
	}

	/**
	 * 将法线向量压缩到 [0,1] 范围（用于纹理存储）
	 * 法线分量通常在 [-1,1]，压缩后变为 [0,1]
	 */
	public inline function packNormal() {
		x = x * 0.5 + 0.5;
		y = y * 0.5 + 0.5;
		z = z * 0.5 + 0.5;
	}

	/**
	 * 将压缩的法线解压回 [-1,1] 范围
	 * `packNormal` 的逆操作
	 */
	public inline function unpackNormal() {
		x = x * 2.0 - 1.0;
		y = y * 2.0 - 1.0;
		z = z * 2.0 - 1.0;
	}

	/**
	 * 调整法线强度后归一化
	 * @param strength 法线强度系数
	 */
	public inline function normalStrength(strength : Float) {
		var k = 1.0 / strength;
		x *= k;
		y *= k;
		normalize();
	}

	/** 设置向量的 x、y、z 分量 */
	public inline function set(x=0.,y=0.,z=0.) {
		this.x = x;
		this.y = y;
		this.z = z;
	}

	/** 从另一个向量复制分量值 */
	public inline function load(v : Vector) {
		this.x = v.x;
		this.y = v.y;
		this.z = v.z;
	}

	/** 原地缩放：this *= f */
	public inline function scale( f : Float ) {
		x *= f;
		y *= f;
		z *= f;
	}

	/**
	 * 线性插值（Linear Interpolation）
	 * this = lerp(v1, v2, k)，k=0 时等于 v1，k=1 时等于 v2
	 */
	public inline function lerp( v1 : Vector, v2 : Vector, k : Float ) {
		this.x = Math.lerp(v1.x, v2.x, k);
		this.y = Math.lerp(v1.y, v2.y, k);
		this.z = Math.lerp(v1.z, v2.z, k);
	}

	/** 逐分量取最小值：this = min(this, v) */
	public inline function min( v : Vector ) {
		this.x = Math.min(this.x, v.x);
		this.y = Math.min(this.y, v.y);
		this.z = Math.min(this.z, v.z);
	}

	/** 逐分量取最大值：this = max(this, v) */
	public inline function max( v : Vector ) {
		this.x = Math.max(this.x, v.x);
		this.y = Math.max(this.y, v.y);
		this.z = Math.max(this.z, v.z);
	}

	/**
	 * 用 4x4 矩阵变换该向量（原地变换）
	 * 相当于：result = M * [x,y,z,1]^T，取前三个分量
	 */
	public inline function transform( m : Matrix ) {
		var px = x * m._11 + y * m._21 + z * m._31 + m._41;
		var py = x * m._12 + y * m._22 + z * m._32 + m._42;
		var pz = x * m._13 + y * m._23 + z * m._33 + m._43;
		x = px;
		y = py;
		z = pz;
	}

	/**
	 * 用 4x4 矩阵变换该向量（返回新向量）
	 * 原向量不变
	 */
	public inline function transformed( m : Matrix ) {
		var px = x * m._11 + y * m._21 + z * m._31 + m._41;
		var py = x * m._12 + y * m._22 + z * m._32 + m._42;
		var pz = x * m._13 + y * m._23 + z * m._33 + m._43;
		return new Vector(px,py,pz);
	}

	/**
	 * 用 3x3 矩阵变换该向量（原地变换，不含平移）
	 * 用于法线变换等不需要平移的场景
	 */
	public inline function transform3x3( m : Matrix ) {
		var px = x * m._11 + y * m._21 + z * m._31;
		var py = x * m._12 + y * m._22 + z * m._32;
		var pz = x * m._13 + y * m._23 + z * m._33;
		x = px;
		y = py;
		z = pz;
	}

	/**
	 * 用 3x3 矩阵变换该向量（返回新向量，不含平移）
	 */
	public inline function transformed3x3( m : Matrix ) {
		var px = x * m._11 + y * m._21 + z * m._31;
		var py = x * m._12 + y * m._22 + z * m._32;
		var pz = x * m._13 + y * m._23 + z * m._33;
		return new Vector(px,py,pz);
	}

	/** 创建该向量的副本 */
	public inline function clone() {
		return new Vector(x,y,z);
	}

	/** 转为四维向量（w 默认为 0） */
	public inline function toVector4() {
		return new h3d.Vector4(x,y,z);
	}

	/** 转为二维点（丢弃 Z 分量） */
	public inline function to2D() {
		return new h2d.col.Point(x,y);
	}

	/** 格式化的字符串表示 */
	public function toString() {
		return '{${x.fmt()},${y.fmt()},${z.fmt()}}';
	}

	// --- 通用 API 结束

	/**
	 * 反射向量计算
	 * 计算向量在法线 n 上的反射
	 * 公式：R = V - 2(V·N)N
	 */
	public inline function reflect( n : Vector ) {
		var k = 2 * this.dot(n);
		return new Vector(x - k * n.x, y - k * n.y, z - k * n.z);
	}

	/**
	 * 投影变换
	 * 使用投影矩阵（如透视投影矩阵）将向量从世界空间变换到裁剪空间
	 * 包含透视除法（除以 w 分量）
	 */
	public inline function project( m : Matrix ) {
		var px = x * m._11 + y * m._21 + z * m._31 + m._41;
		var py = x * m._12 + y * m._22 + z * m._32 + m._42;
		var pz = x * m._13 + y * m._23 + z * m._33 + m._43;
		var iw = 1 / (x * m._14 + y * m._24 + z * m._34 + m._44);
		x = px * iw;
		y = py * iw;
		z = pz * iw;
	}

	// ==================== 颜色相关函数 ====================
	// Vector 也可以用作 RGB 颜色值，x/r 代表红色，y/g 代表绿色，z/b 代表蓝色

	public var r(get, set) : Float;  // 红色通道（别名 x）
	public var g(get, set) : Float;  // 绿色通道（别名 y）
	public var b(get, set) : Float;  // 蓝色通道（别名 z）

	inline function get_r() return x;
	inline function get_g() return y;
	inline function get_b() return z;
	inline function set_r(v) return x = v;
	inline function set_g(v) return y = v;
	inline function set_b(v) return z = v;

	/** 从 ARGB 整数设置颜色分量（归一化到 [0,1]） */
	public inline function setColor( c : Int ) {
		r = ((c >> 16) & 0xFF) / 255;
		g = ((c >> 8) & 0xFF) / 255;
		b = (c & 0xFF) / 255;
	}

	/**
	 * 从 HSL（色相-饱和度-亮度）模型生成颜色
	 * @param hue 色相（弧度）
	 * @param saturation 饱和度 [0,1]
	 * @param brightness 亮度 [0,1]
	 */
	public function makeColor( hue : Float, saturation : Float = 1., brightness : Float = 0.5 ) {
		hue = Math.ufmod(hue, Math.PI * 2);
		var c = (1 - Math.abs(2 * brightness - 1)) * saturation;
		var x = c * (1 - Math.abs((hue * 3 / Math.PI) % 2. - 1));
		var m = brightness - c / 2;
		if( hue < Math.PI / 3 ) {
			r = c; g = x; b = 0;
		} else if( hue < Math.PI * 2 / 3 ) {
			r = x; g = c; b = 0;
		} else if( hue < Math.PI ) {
			r = 0; g = c; b = x;
		} else if( hue < Math.PI * 4 / 3 ) {
			r = 0; g = x; b = c;
		} else if( hue < Math.PI * 5 / 3 ) {
			r = x; g = 0; b = c;
		} else {
			r = c; g = 0; b = x;
		}
		r += m;
		g += m;
		b += m;
	}

	/** 将 RGB 颜色转换为 ARGB 整数格式 */
	public inline function toColor() {
		return 0xFF000000 | (Std.int(r.clamp() * 255 + 0.499) << 16) | (Std.int(g.clamp() * 255 + 0.499) << 8) | Std.int(b.clamp() * 255 + 0.499);
	}

	/** 将 RGB 转换为 HSL（色相-饱和度-亮度）颜色空间 */
	public function toColorHSL() {
	    var max = hxd.Math.max(hxd.Math.max(r, g), b);
		var min = hxd.Math.min(hxd.Math.min(r, g), b);
		var h, s, l = (max + min) / 2.0;

		if(max == min)
			h = s = 0.0; // 无彩色（灰色）
		else {
			var d = max - min;
			s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
			if(max == r)
				h = (g - b) / d + (g < b ? 6.0 : 0.0);
			else if(max == g)
				h = (b - r) / d + 2.0;
			else
				h = (r - g) / d + 4.0;
			h *= Math.PI / 3.0;
		}

		return new h3d.Vector(h, s, l);
	}

	/** 将 RGB 转换为 HSV（色相-饱和度-明度）颜色空间 */
	public function toColorHSV() {
	    var max = hxd.Math.max(hxd.Math.max(r, g), b);
		var min = hxd.Math.min(hxd.Math.min(r, g), b);
		var h, s, v = max;

		if(max == min)
			h = s = 0.0; // 无彩色（灰色）
		else {
			var d = max - min;
			s = d / v;
			if(max == r)
				h = (g - b) / d + (g < b ? 6.0 : 0.0);
			else if(max == g)
				h = (b - r) / d + 2.0;
			else
				h = (r - g) / d + 4.0;
			h *= Math.PI / 3.0;
		}

		return new h3d.Vector(h, s, v);
	}

}

/**
 * 三维向量的抽象类型
 * 使用 `@:forward` 代理到 `VectorImpl`
 * 支持运算符重载：a+b, a-b, a*b(矩阵), a*b(标量), a*=b
 * 每次返回 Vector 时都会创建新副本（值类型语义）
 */
@:forward abstract Vector(VectorImpl) from VectorImpl to VectorImpl {

	public inline function new( x = 0., y = 0., z = 0. ) {
		this = new VectorImpl(x,y,z);
	}

	// 运算符重载
	@:op(a - b) public inline function sub(v:Vector) return this.sub(v);
	@:op(a + b) public inline function add(v:Vector) return this.add(v);
	@:op(a *= b) public inline function transform(m:Matrix) this.transform(m);
	@:op(a * b) public inline function transformed(m:Matrix) return this.transformed(m);

	// 待废弃的兼容方法
	public inline function toPoint() return this.clone();
	public inline function toVector() return this.clone();

	@:op(a *= b) public inline function scale(v:Float) this.scale(v);
	@:op(a * b) public inline function scaled(v:Float) return this.scaled(v);
	@:op(a * b) static inline function scaledInv( f : Float, v : Vector ) return v.scaled(f);

	/**
	 * 从 ARGB 颜色值创建向量
	 * 将 24-bit RGB 颜色转换为 [0,1] 范围的向量
	 * @param c ARGB 格式的颜色值（只使用低 24 位）
	 * @param scale 缩放系数（默认为 1）
	 */
	public static inline function fromColor( c : Int, scale : Float = 1.0 ) {
		var s = scale / 255;
		return new Vector(((c>>16)&0xFF)*s,((c>>8)&0xFF)*s,(c&0xFF)*s);
	}

	/** 从浮点数数组创建向量 */
	public static inline function fromArray(a : Array<Float>) {
		var r = new Vector();
		if(a.length > 0) r.x = a[0];
		if(a.length > 1) r.y = a[1];
		if(a.length > 2) r.z = a[2];
		return r;
	}

}