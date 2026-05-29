package h3d.col;

/**
 * 球体碰撞体（Sphere Collider）
 *
 * 由球心 (x,y,z) 和半径 r 定义的球体。
 * 是最简单的 3D 碰撞体之一，碰撞检测计算效率最高。
 *
 * 常用于：
 * - 粗略碰撞检测（快速滤除不可能相交的对象）
 * - 包围球（Bounding Sphere）
 * - 爆炸/范围检测
 */
class Sphere extends Collider {

	public var x : Float;  // 球心 X
	public var y : Float;  // 球心 Y
	public var z : Float;  // 球心 Z
	public var r : Float;  // 半径

	public inline function new(x=0., y=0., z=0., r=1.) {
		load(x, y, z, r);
	}

	public inline function load(sx=0., sy=0., sz=0., sr=0.) {
		this.x = sx;
		this.y = sy;
		this.z = sz;
		this.r = sr;
	}

	public inline function getCenter() {
		return new Point(x, y, z);
	}

	/**
	 * 计算点到球面的有符号距离
	 * 负值表示点在球体内
	 */
	public inline function distance( p : Point ) {
		var d = distanceSq(p);
		return d < 0 ? -Math.sqrt(-d) : Math.sqrt(d);
	}

	/**
	 * 计算点到球面的距离平方
	 * 负值表示点在球体内
	 */
	public inline function distanceSq( p : Point ) {
		var dx = p.x - x;
		var dy = p.y - y;
		var dz = p.z - z;
		return dx * dx + dy * dy + dz * dz - r * r;
	}

	/** 判断点是否在球体内部 */
	public inline function contains( p : Point ) {
		return distanceSq(p) < 0;
	}

	/**
	 * 射线与球体相交检测
	 * 使用二次方程求解：t^2 + 2bt + c = 0
	 * 其中 b = (P0-O)·D, c = |P0-O|^2 - r^2
	 * @return 相交距离（负值表示无相交）
	 */
	public function rayIntersection( r : Ray, bestMatch : Bool ) : Float {
		var mx = r.px - x;
		var my = r.py - y;
		var mz = r.pz - z;
		var b = mx * r.lx + my * r.ly + mz * r.lz;
		var c = mx * mx + my * my + mz * mz - this.r * this.r;
		if ( c > 0.0 && b > 0.0 )
			return -1;
		var d = b * b - c;
		if ( d < 0.0 )
			return -1;
		var t = -b - Math.sqrt(d);
		return t < 0.0 ? 0.0 : t;
	}

	public inline function inFrustum( f : Frustum, ?m : h3d.Matrix ) {
		if( m != null ) return inFrustumMatrix(f,m);
		return f.hasSphere(this);
	}

	/** 带矩阵变换的视锥体检测（中心变换 + 半径缩放） */
	function inFrustumMatrix( f : Frustum, m : h3d.Matrix ) {
		var oldX = x, oldY = y, oldZ = z, oldR = r;
		var v = getCenter();
		v.transform(m);
		x = v.x;
		y = v.y;
		z = v.z;
		var scale = m.getScale();
		r *= Math.abs(Math.max(Math.max(scale.x, scale.y), scale.z));
		var res = f.hasSphere(this);
		x = oldX;
		y = oldY;
		z = oldZ;
		r = oldR;
		return res;
	}

	/** 用矩阵变换球体（中心 + 半径缩放） */
	public function transform( m : h3d.Matrix ) {
		var s = m.getScale();
		var smax = hxd.Math.max(hxd.Math.max(hxd.Math.abs(s.x), hxd.Math.abs(s.y)), hxd.Math.abs(s.z));
		r *= smax;
		var pt = new h3d.col.Point(x,y,z);
		pt.transform(m);
		x = pt.x;
		y = pt.y;
		z = pt.z;
	}

	/** 判断两个球体是否相交 */
	public inline function inSphere( s : Sphere ) {
		return new Point(x,y,z).distanceSq(new Point(s.x,s.y,s.z)) < (s.r + r)*(s.r + r);
	}

	public function toString() {
		return "Sphere{" + getCenter()+","+ hxd.Math.fmt(r) + "}";
	}

	public inline function dimension() {
		return r;
	}

	/** 获取球面上离给定点最近的点 */
	public inline function closestPoint( p : h3d.col.Point ) {
		var d = p.sub(getCenter()).normalized().scaled(r);
		return d.add(getCenter());
	}

	public inline function clone() {
		var s = new Sphere();
		s.x = x;
		s.y = y;
		s.z = z;
		s.r = r;
		return s;
	}

	#if !macro
	/** 创建网格用于调试可视化 */
	public function makeDebugObj() : h3d.scene.Object {
		var prim = h3d.prim.Sphere.defaultUnitSphere();
		var mesh = new h3d.scene.Mesh(prim);
		mesh.scale(r);
		mesh.setPosition(x,y,z);
		return mesh;
	}
	#end

}