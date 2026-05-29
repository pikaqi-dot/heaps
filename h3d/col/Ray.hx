package h3d.col;
import hxd.Math;

/**
 * 3D 射线（Ray）
 *
 * 表示从起点出发沿一定方向无限延伸的射线。
 * 用于：
 * - 鼠标拾取（Ray Casting）
 * - 碰撞检测
 * - 可见性测试
 *
 * 射线参数方程：P(t) = P0 + t * D
 * 其中 P0 为起点 (px,py,pz)，D 为归一化方向 (lx,ly,lz)
 */
@:allow(h3d.col)
class Ray {

	public var px : Float;  // 起点 X
	public var py : Float;  // 起点 Y
	public var pz : Float;  // 起点 Z
	public var lx : Float;  // 方向 X
	public var ly : Float;  // 方向 Y
	public var lz : Float;  // 方向 Z

	public inline function new() {
	}

	public inline function clone() {
		var r = new Ray();
		r.px = px;
		r.py = py;
		r.pz = pz;
		r.lx = lx;
		r.ly = ly;
		r.lz = lz;
		return r;
	}

	public inline function load( r : Ray ) {
		px = r.px;
		py = r.py;
		pz = r.pz;
		lx = r.lx;
		ly = r.ly;
		lz = r.lz;
	}

	/** 归一化方向向量 */
	function normalize() {
		var l = lx * lx + ly * ly + lz * lz;
		if( l == 1. ) return;
		if( l < Math.EPSILON2 ) l = 0 else l = Math.invSqrt(l);
		lx *= l;
		ly *= l;
		lz *= l;
	}

	/**
	 * 用矩阵变换射线
	 * 起点使用完整 4x4 变换（含平移），方向使用 3x3 变换（不含平移）
	 * 变换后重新归一化方向
	 */
	public inline function transform( m : h3d.Matrix ) {
		var p = new h3d.Vector(px, py, pz);
		p.transform(m);
		px = p.x;
		py = p.y;
		pz = p.z;
		var l = new h3d.Vector(lx, ly, lz);
		l.transform3x3(m);
		lx = l.x;
		ly = l.y;
		lz = l.z;
		normalize();
	}

	public inline function getPos() {
		return new Point(px, py, pz);
	}

	public inline function getDir() {
		return new Point(lx, ly, lz);
	}

	/** 获取射线上距离起点 distance 处的点 */
	public inline function getPoint( distance : Float ) {
		return new Point(px + distance * lx, py + distance * ly, pz + distance * lz);
	}

	public function toString() {
		return "Ray{" + getPos() + "," + getDir() + "}";
	}

	/**
	 * 计算射线到平面的有符号距离
	 * @return 距离值；如果射线与平面平行则返回 -1
	 */
	public inline function distance( p : Plane ) : Float {
		var d = lx * p.nx + ly * p.ny + lz * p.nz;
		var nd = p.d - (px * p.nx + py * p.ny + pz * p.nz);
		return Math.abs(d) < Math.EPSILON ? (Math.abs(nd) < Math.EPSILON ? 0. : -1) : nd / d;
	}

	/**
	 * 计算射线与平面的交点
	 * @param p 平面
	 * @return 交点，如果平行则返回 null
	 */
	public inline function intersect( p : Plane ) : Null<Point> {
		var d = lx * p.nx + ly * p.ny + lz * p.nz;
		var nd = p.d - (px * p.nx + py * p.ny + pz * p.nz);
		if( Math.abs(d) < Math.EPSILON )
			return Math.abs(nd) < Math.EPSILON ? new Point(px, py, pz) : null;
		else {
			var k = nd / d;
			return new Point(px + lx * k, py + ly * k, pz + lz * k);
		}
	}

	/**
	 * 用投影矩阵检测射线是否与视锥体相交
	 * 将射线的两个端点投影到 NDC 空间，然后检测是否在 [-1,1] 范围内
	 * 使用 AABB 盒的 Slab 方法
	 */
	public inline function collideFrustum( mvp : Matrix ) {
		var a = new h3d.Vector(px, py, pz);
		a.project(mvp);
		var b = new h3d.Vector(px + lx, py + ly, pz + lz);
		b.project(mvp);
		var lx = b.x - a.x;
		var ly = b.y - a.y;
		var lz = b.z - a.z;

		var dx = 1 / lx;
		var dy = 1 / ly;
		var dz = 1 / lz;
		var t1 = (-1 - a.x) * dx;
		var t2 = (1 - a.x) * dx;
		var t3 = (-1 - a.y) * dy;
		var t4 = (1 - a.y) * dy;
		var t5 = (0 - a.z) * dz;
		var t6 = (1 - a.z) * dz;
		var tmin = Math.max(Math.max(Math.min(t1, t2), Math.min(t3, t4)), Math.min(t5, t6));
		var tmax = Math.min(Math.min(Math.max(t1, t2), Math.max(t3, t4)), Math.max(t5, t6));
		return !(tmax < 0 || tmin > tmax);
	}

	/**
	 * 检测射线是否与 AABB 包围盒相交
	 * 使用 Slab 方法（分离轴测试）
	 * @param b AABB 包围盒
	 * @return 是否相交
	 */
	public inline function collide( b : Bounds ) : Bool {
		var dx = 1 / lx;
		var dy = 1 / ly;
		var dz = 1 / lz;
		var t1 = (b.xMin - px) * dx;
		var t2 = (b.xMax - px) * dx;
		var t3 = (b.yMin - py) * dy;
		var t4 = (b.yMax - py) * dy;
		var t5 = (b.zMin - pz) * dz;
		var t6 = (b.zMax - pz) * dz;
		var tmin = Math.max(Math.max(Math.min(t1, t2), Math.min(t3, t4)), Math.min(t5, t6));
		var tmax = Math.min(Math.min(Math.max(t1, t2), Math.max(t3, t4)), Math.max(t5, t6));
		if( tmax < 0 ) {
			return false;
		} else if( tmin > tmax ) {
			return false;
		} else {
			return true;
		}
	}

	/**
	 * 从两个点创建射线
	 * @param p1 起点
	 * @param p2 射线上的另一点（用于确定方向）
	 */
	public static inline function fromPoints( p1 : Point, p2 : Point ) {
		var r = new Ray();
		r.px = p1.x;
		r.py = p1.y;
		r.pz = p1.z;
		r.lx = p2.x - p1.x;
		r.ly = p2.y - p1.y;
		r.lz = p2.z - p1.z;
		r.normalize();
		return r;
	}

	/**
	 * 从数值创建射线
	 * @param x,y,z 起点坐标
	 * @param dx,dy,dz 方向向量
	 */
	public static inline function fromValues( x, y, z, dx, dy, dz ) {
		var r = new Ray();
		r.px = x;
		r.py = y;
		r.pz = z;
		r.lx = dx;
		r.ly = dy;
		r.lz = dz;
		r.normalize();
		return r;
	}

}