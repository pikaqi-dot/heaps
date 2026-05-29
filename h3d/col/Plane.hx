package h3d.col;
import hxd.Math;

/**
 * 平面（Plane）
 *
 * 由法向量 (nx,ny,nz) 和距离 d 定义的无限平面。
 * 平面方程：nx·X + ny·Y + nz·Z - d = 0
 *
 * 法向量指向平面的"正面"。
 * 点到平面的有符号距离：distance(p) = n·p - d
 * - 正数：点在平面正面
 * - 负数：点在平面背面
 * - 零：点在平面上
 *
 * 主要用于视锥体裁剪（6 个平面构成视锥体）
 */
@:allow(h3d.col)
class Plane {

	var nx : Float;  // 法向量 X
	var ny : Float;  // 法向量 Y
	var nz : Float;  // 法向量 Z
	var d : Float;   // 距离（平面到原点的有符号距离）

	public inline function new(nx, ny, nz, d) {
		this.nx = nx;
		this.ny = ny;
		this.nz = nz;
		this.d = d;
	}

	/** 获取平面法向量 */
	public inline function getNormal() {
		return new Point(nx, ny, nz);
	}

	/** 获取平面距离 */
	public inline function getNormalDistance() {
		return d;
	}

	public inline function load( p : Plane ) {
		nx = p.nx;
		ny = p.ny;
		nz = p.nz;
		d = p.d;
	}

	/**
	 * 用矩阵变换平面
	 * 使用逆矩阵的转置（Inverse Transpose）进行变换
	 * 这是正确的平面变换方式（法向量变换需要用逆转置）
	 */
	public function transform( m : h3d.Matrix ) {
		var m2 = new h3d.Matrix();
		m2.initInverse(m);
		m2.transpose();
		transformInverseTranspose(m2);
	}

	/** 用 3x3 矩阵变换平面（不含平移） */
	public function transform3x3( m : h3d.Matrix ) {
		var m2 = new h3d.Matrix();
		m2.initInverse3x3(m);
		m2.transpose();
		transformInverseTranspose(m2);
	}

	/** 逆转置变换（平面变换核心算法） */
	inline function transformInverseTranspose(m:h3d.Matrix) {
		var v = new h3d.Vector4(nx, ny, nz, -d);
		v.transform(m);
		nx = v.x;
		ny = v.y;
		nz = v.z;
		d = -v.w;
	}

	/**
	 * 归一化平面
	 * 归一化后才能使用 distance() 获取正确有符号距离
	 */
	public inline function normalize() {
		var len = Math.invSqrt(nx * nx + ny * ny + nz * nz);
		nx *= len;
		ny *= len;
		nz *= len;
		d *= len;
	}

	public function toString() {
		return "Plane{" + getNormal()+","+ hxd.Math.fmt(d) + "}";
	}

	/**
	 * 计算点到平面的有符号距离
	 * 需要平面已归一化
	 * 负值表示点在平面"背面"
	 */
	public inline function distance( p : Point ) {
		return nx * p.x + ny * p.y + nz * p.z - d;
	}

	/** 判断点是否在平面正面（或平面上） */
	public inline function side( p : Point ) {
		return distance(p) >= 0;
	}

	/** 将点投影到平面上 */
	public inline function project( p : Point ) : Point {
		var d = distance(p);
		return new Point(p.x - d * nx, p.y - d * ny, p.z - d * nz);
	}

	/** 将点投影到平面上（写入指定输出） */
	public inline function projectTo( p : Point, out : Point ) {
		var d = distance(p);
		out.x = p.x - d * nx;
		out.y = p.y - d * ny;
		out.z = p.z - d * nz;
	}

	/** 从三个点构造平面（p0→p1 和 p0→p2 的叉积为法线） */
	public static inline function fromPoints( p0 : Point, p1 : Point, p2 : Point ) {
		var d1 = p1.sub(p0);
		var d2 = p2.sub(p0);
		var n = d1.cross(d2).normalized();
		return new Plane(n.x,n.y,n.z,n.dot(p0));
	}

	/** 从法向量和点构造平面 */
	public static inline function fromNormalPoint( n : Point, p : Point ) {
		return new Plane(n.x,n.y,n.z,n.dot(p));
	}

	/** 创建 X 轴平面（法线朝 X 正方向） */
	public static inline function X(v:Float=0.0) {
		return new Plane( 1, 0, 0, v );
	}

	/** 创建 Y 轴平面（法线朝 Y 正方向） */
	public static inline function Y(v:Float=0.0) {
		return new Plane( 0, 1, 0, v );
	}

	/** 创建 Z 轴平面（法线朝 Z 正方向） */
	public static inline function Z(v:Float=0.0) {
		return new Plane( 0, 0, 1, v );
	}

	// ===== 以下静态方法从 MVP 矩阵提取视锥体 6 个平面 =====
	// 从投影矩阵的行组合提取每个平面的方程系数

	public static inline function frustumLeft( mvp : Matrix ) {
		return new Plane(mvp._14 + mvp._11, mvp._24 + mvp._21 , mvp._34 + mvp._31, -(mvp._44 + mvp._41));
	}

	public static inline function frustumRight( mvp : Matrix ) {
		return new Plane(mvp._14 - mvp._11, mvp._24 - mvp._21 , mvp._34 - mvp._31, mvp._41 - mvp._44);
	}

	public static inline function frustumBottom( mvp : Matrix ) {
		return new Plane(mvp._14 + mvp._12, mvp._24 + mvp._22 , mvp._34 + mvp._32, -(mvp._44 + mvp._42));
	}

	public static inline function frustumTop( mvp : Matrix ) {
		return new Plane(mvp._14 - mvp._12, mvp._24 - mvp._22 , mvp._34 - mvp._32, mvp._42 - mvp._44);
	}

	public static inline function frustumNear( mvp : Matrix ) {
		return new Plane(mvp._13, mvp._23, mvp._33, -mvp._43);
	}

	public static inline function frustumFar( mvp : Matrix ) {
		return new Plane(mvp._14 - mvp._13, mvp._24 - mvp._23, mvp._34 - mvp._33, mvp._43 - mvp._44);
	}

}