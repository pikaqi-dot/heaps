package h2d.col;
import hxd.Math;

/**
 * 2D 点/向量
 *
 * 简单的 2D 位置/向量容器。
 * 使用 PointImpl + Point（抽象转发）模式，
 * 支持值类型语义和运算符重载。
 *
 * 关键方法：
 * - 向量运算：add/sub/dot/cross/length/normalize
 * - 矩阵变换：transform/transformed/transform2x2
 * - 几何：rotate/getRotation/lerp
 * - 转换：toIPoint（转整数点）
 */
class PointImpl #if apicheck implements h2d.impl.PointApi<Point,Matrix> #end {

	/** X 坐标 */
	public var x : Float;
	
	/** Y 坐标 */
	public var y : Float;

	public inline function new(x = 0., y = 0.) {
		this.x = x;
		this.y = y;
	}

	/** 到点 p 的平方距离 */
	public inline function distanceSq( p : Point ) {
		var dx = x - p.x;
		var dy = y - p.y;
		return dx * dx + dy * dy;
	}

	/** 到点 p 的距离 */
	public inline function distance( p : Point ) : Float {
		return Math.sqrt(distanceSq(p));
	}

	public function toString() : String {
		return "{" + Math.fmt(x) + "," + Math.fmt(y) + "}";
	}

	/** 向量减法：返回 this - p */
	public inline function sub( p : Point ) : Point {
		return new Point(x - p.x, y - p.y);
	}

	/** 向量加法：返回 this + p */
	public inline function add( p : Point ) : Point {
		return new Point(x + p.x, y + p.y);
	}

	/** 标量乘法：返回 this × v */
	public inline function scaled( v : Float ) {
		return new Point(x * v, y * v);
	}

	/** 判断与另一点是否相等 */
	public inline function equals( other : Point ) : Bool {
		return x == other.x && y == other.y;
	}

	/** 点积 */
	public inline function dot( p : Point ) : Float {
		return x * p.x + y * p.y;
	}

	/** 长度平方 */
	public inline function lengthSq() {
		return x * x + y * y;
	}

	/** 长度 */
	public inline function length() : Float {
		return Math.sqrt(lengthSq());
	}

	/** 归一化（原地） */
	public inline function normalize() {
		var k = lengthSq();
		if( k < Math.EPSILON2 ) k = 0 else k = Math.invSqrt(k);
		x *= k;
		y *= k;
	}

	/** 归一化（返回新向量） */
	public inline function normalized() {
		var k = lengthSq();
		if( k < Math.EPSILON2 ) k = 0 else k = Math.invSqrt(k);
		return new h2d.col.Point(x*k,y*k);
	}

	/** 设置 x,y */
	public inline function set(x=0.,y=0.) {
		this.x = x;
		this.y = y;
	}

	/** 从另一个点复制 */
	public inline function load( p : h2d.col.Point ) {
		this.x = p.x;
		this.y = p.y;
	}

	/** 标量乘法（原地） */
	public inline function scale( f : Float ) {
		x *= f;
		y *= f;
	}

	/** 克隆 */
	public inline function clone() : Point {
		return new Point(x, y);
	}

	/** 2D 叉积（返回标量，即 z 分量） */
	public inline function cross( p : Point ) {
		return x * p.y - y * p.x;
	}

	/** 线性插值：this = lerp(a, b, k) */
	public inline function lerp( a : Point, b : Point, k : Float ) {
		x = hxd.Math.lerp(a.x, b.x, k);
		y = hxd.Math.lerp(a.y, b.y, k);
	}

	/** 用 2x3 矩阵变换（仿射变换） */
	public inline function transform( m : Matrix ) {
		var mx = m.a * x + m.c * y + m.x;
		var my = m.b * x + m.d * y + m.y;
		this.x = mx;
		this.y = my;
	}

	/** 用 2x3 矩阵变换（返回新点） */
	public inline function transformed( m : Matrix ) {
		var mx = m.a * x + m.c * y + m.x;
		var my = m.b * x + m.d * y + m.y;
		return new Point(mx,my);
	}

	/** 用 2x2 矩阵变换（不含平移） */
	public inline function transform2x2( m : Matrix ) {
		var mx = m.a * x + m.c * y;
		var my = m.b * x + m.d * y;
		this.x = mx;
		this.y = my;
	}

	/** 用 2x2 矩阵变换（返回新点） */
	public inline function transformed2x2( m : Matrix ) {
		var mx = m.a * x + m.c * y;
		var my = m.b * x + m.d * y;
		return new Point(mx,my);
	}

	/** 转换为整数点（带缩放） */
	public inline function toIPoint( scale = 1. ) {
		return new IPoint(Math.round(x * scale), Math.round(y * scale));
	}

	/** 绕原点旋转指定角度 */
	public inline function rotate( angle : Float ) {
		var c = Math.cos(angle);
		var s = Math.sin(angle);
		var x2 = x * c - y * s;
		var y2 = x * s + y * c;
		x = x2;
		y = y2;
	}

	/** 获取与 (1,0) 方向的夹角（弧度），范围 [-π, π] */
	public inline function getRotation() : Float {
		var dot = new h2d.col.Point(1, 0).dot(this.normalized());
		var sign = (x >= 0 && y >= 0) || (x < 0 && y >= 0) ? 1 : -1;
		return sign * hxd.Math.acos(dot);
	}
}

/**
 * 2D 点抽象类型
 * 支持运算符重载：a+b, a-b, a*b(矩阵), a*b(标量)
 */
@:forward abstract Point(PointImpl) from PointImpl to PointImpl {

	public inline function new(x=0.,y=0.) {
		this = new PointImpl(x,y);
	}

	@:op(a - b) public inline function sub(p:Point) return this.sub(p);
	@:op(a + b) public inline function add(p:Point) return this.add(p);
	@:op(a *= b) public inline function transform(m:Matrix) this.transform(m);
	@:op(a * b) public inline function transformed(m:Matrix) return this.transformed(m);

	@:op(a *= b) public inline function scale(v:Float) this.scale(v);
	@:op(a * b) public inline function scaled(v:Float) return this.scaled(v);
	@:op(a * b) static inline function scaledInv( f : Float, p : Point ) return p.scaled(f);

}
