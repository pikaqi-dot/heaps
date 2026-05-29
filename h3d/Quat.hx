package h3d;
using hxd.Math;

/**
 * 四元数（Quaternion）
 *
 * 用于表示 3D 旋转，比欧拉角/Euler Angles 更稳定：
 * - 无万向锁（Gimbal Lock）问题
 * - 插值平滑（SLERP）
 * - 组合旋转效率高
 *
 * 格式：q = w + xi + yj + zk，其中 w 为实部，(x,y,z) 为虚部
 * 单位四元数表示一个旋转：q = cos(θ/2) + sin(θ/2)(uxi + uyj + uzk)
 *
 * Heaps 使用左手坐标系（Left-Handed Coordinate System）
 */
@:noDebug
class Quat {

	public var x : Float;  // 虚部 i 分量
	public var y : Float;  // 虚部 j 分量
	public var z : Float;  // 虚部 k 分量
	public var w : Float;  // 实部（标量部分）

	public inline function new( x = 0., y = 0., z = 0., w = 1. ) {
		this.x = x;
		this.y = y;
		this.z = z;
		this.w = w;
	}

	public inline function set(x, y, z, w) {
		this.x = x;
		this.y = y;
		this.z = z;
		this.w = w;
	}

	/** 设置单位四元数（无旋转） */
	public inline function identity() {
		x = y = z = 0;
		w = 1;
	}

	public inline function lengthSq() {
		return x * x + y * y + z * z + w * w;
	}

	public inline function length() {
		return lengthSq().sqrt();
	}

	public inline function load( q : Quat ) {
		this.x = q.x;
		this.y = q.y;
		this.z = q.z;
		this.w = q.w;
	}

	public inline function clone() {
		return new Quat(x, y, z, w);
	}

	/**
	 * 初始化从 from 方向到 to 方向的旋转四元数
	 *
	 * 算法：
	 *   H = Normalize(From + To)
	 *   Q = (From × H, From · H)
	 *
	 * 注意：当 From·To 接近 -1（即方向相反）时，
	 * From×To 会很小，导致数值不稳定
	 */
	public function initMoveTo( from : Vector, to : Vector ) {
		var hx = from.x + to.x;
		var hy = from.y + to.y;
		var hz = from.z + to.z;
		x = from.y * hz - from.z * hy;
		y = from.z * hx - from.x * hz;
		z = from.x * hy - from.y * hx;
		w = from.x * hx + from.y * hy + from.z * hz;
		normalize();
	}

	/**
	 * 根据法线方向初始化旋转四元数
	 * 使物体朝向给定法线方向，可选绕法线旋转
	 * @param dir 目标方向
	 * @param rotate 绕法线轴的额外旋转角度
	 */
	public function initNormal( dir : h3d.col.Point, rotate : Float = 0.0 ) {
		var dir = dir.normalized();
		if( dir.x*dir.x+dir.y*dir.y < Math.EPSILON2 )
			initDirection(new h3d.Vector(1,0,0));
		else {
			var ay = new h3d.col.Point(dir.x, dir.y, 0).normalized();
			var az = dir.cross(ay);
			var ax = dir.cross(az).toVector();
			if (dir.z < 0.0)
				initDirection(ax, new Vector(0.0, 0.0, -1.0));
			else
				initDirection(ax);
		}
		if ( rotate != 0.0) {
			var quat = new Quat();
			quat.initRotateAxis(dir.x, dir.y, dir.z, rotate);
			multiply(quat, this);
		}
	}

	/**
	 * 从方向向量初始化旋转四元数
	 * 内联版的 initRotationMatrix(Matrix.lookAtX(dir))
	 * 从 3x3 旋转矩阵转换为四元数
	 *
	 * 使用迹（trace）方法，根据迹的大小选择不同的分支以提高数值稳定性
	 */
	public function initDirection( dir : Vector, ?up : Vector ) {
		var ax = dir.clone().normalized();
		var ay = new Vector(-ax.y, ax.x, 0);
		if( up != null )
			ay.load(up.cross(ax));
		ay.normalize();
		if( ay.lengthSq() < Math.EPSILON2 ) {
			ay.x = ax.y;
			ay.y = ax.z;
			ay.z = ax.x;
		}
		var az = ax.cross(ay);
		var tr = ax.x + ay.y + az.z;
		if( tr > 0 ) {
			var s = (tr + 1.0).sqrt() * 2;
			var ins = 1 / s;
			x = (ay.z - az.y) * ins;
			y = (az.x - ax.z) * ins;
			z = (ax.y - ay.x) * ins;
			w = 0.25 * s;
		} else if( ax.x > ay.y && ax.x > az.z ) {
			var s = (1.0 + ax.x - ay.y - az.z).sqrt() * 2;
			var ins = 1 / s;
			x = 0.25 * s;
			y = (ay.x + ax.y) * ins;
			z = (az.x + ax.z) * ins;
			w = (ay.z - az.y) * ins;
		} else if( ay.y > az.z ) {
			var s = (1.0 + ay.y - ax.x - az.z).sqrt() * 2;
			var ins = 1 / s;
			x = (ay.x + ax.y) * ins;
			y = 0.25 * s;
			z = (az.y + ay.z) * ins;
			w = (az.x - ax.z) * ins;
		} else {
			var s = (1.0 + az.z - ax.x - ay.y).sqrt() * 2;
			var ins = 1 / s;
			x = (az.x + ax.z) * ins;
			y = (az.y + ay.z) * ins;
			z = 0.25 * s;
			w = (ax.y - ay.x) * ins;
		}
	}

	/**
	 * 初始化绕任意轴旋转的四元数
	 * 公式：q = cos(θ/2) + sin(θ/2) * (xi + yj + zk)
	 * 其中 (x,y,z) 是归一化的旋转轴，θ 是旋转角度
	 * 支持非单位长度的轴向量
	 */
	public function initRotateAxis( x : Float, y : Float, z : Float, a : Float ) {
		var sin = (a / 2).sin();
		var cos = (a / 2).cos();
		this.x = x * sin;
		this.y = y * sin;
		this.z = z * sin;
		this.w = cos * (x * x + y * y + z * z).sqrt(); // 允许非归一化轴
		normalize();
	}

	/**
	 * 从旋转矩阵初始化四元数
	 * 使用迹（trace）方法进行数值稳定转换
	 * 选择迹最大或对角线元素最大的分支
	 */
	public function initRotateMatrix( m : Matrix ) {
		var tr = m._11 + m._22 + m._33;
		if( tr > 0 ) {
			var s = (tr + 1.0).sqrt() * 2;
			var ins = 1 / s;
			x = (m._23 - m._32) * ins;
			y = (m._31 - m._13) * ins;
			z = (m._12 - m._21) * ins;
			w = 0.25 * s;
		} else if( m._11 > m._22 && m._11 > m._33 ) {
			var s = (1.0 + m._11 - m._22 - m._33).sqrt() * 2;
			var ins = 1 / s;
			x = 0.25 * s;
			y = (m._21 + m._12) * ins;
			z = (m._31 + m._13) * ins;
			w = (m._23 - m._32) * ins;
		} else if( m._22 > m._33 ) {
			var s = (1.0 + m._22 - m._11 - m._33).sqrt() * 2;
			var ins = 1 / s;
			x = (m._21 + m._12) * ins;
			y = 0.25 * s;
			z = (m._32 + m._23) * ins;
			w = (m._31 - m._13) * ins;
		} else {
			var s = (1.0 + m._33 - m._11 - m._22).sqrt() * 2;
			var ins = 1 / s;
			x = (m._31 + m._13) * ins;
			y = (m._32 + m._23) * ins;
			z = 0.25 * s;
			w = (m._12 - m._21) * ins;
		}
	}

	/**
	 * 四元数归一化
	 * 确保它是单位四元数（长度为1）
	 * 零四元数会被重置为单位四元数
	 */
	public function normalize() {
		var len = x * x + y * y + z * z + w * w;
		if( len < hxd.Math.EPSILON2 ) {
			x = y = z = 0;
			w = 1;
		} else {
			var m = len.invSqrt();
			x *= m;
			y *= m;
			z *= m;
			w *= m;
		}
	}

	/**
	 * 从欧拉角初始化四元数（XYZ 顺序）
	 * 分别计算绕三个轴旋转的半角，然后组合
	 */
	public function initRotation( ax : Float, ay : Float, az : Float ) {
		var sinX = ( ax * 0.5 ).sin();
		var cosX = ( ax * 0.5 ).cos();
		var sinY = ( ay * 0.5 ).sin();
		var cosY = ( ay * 0.5 ).cos();
		var sinZ = ( az * 0.5 ).sin();
		var cosZ = ( az * 0.5 ).cos();
		var cosYZ = cosY * cosZ;
		var sinYZ = sinY * sinZ;
		x = sinX * cosYZ - cosX * sinYZ;
		y = cosX * sinY * cosZ + sinX * cosY * sinZ;
		z = cosX * cosY * sinZ - sinX * sinY * cosZ;
		w = cosX * cosYZ + sinX * sinYZ;
	}

	/**
	 * 四元数乘法（组合旋转）
	 * this = q1 * q2（先应用 q2，再应用 q1）
	 * 使用 Hamilton 积
	 */
	public function multiply( q1 : Quat, q2 : Quat ) {
		var x2 = q1.x * q2.w + q1.w * q2.x + q1.y * q2.z - q1.z * q2.y;
		var y2 = q1.w * q2.y - q1.x * q2.z + q1.y * q2.w + q1.z * q2.x;
		var z2 = q1.w * q2.z + q1.x * q2.y - q1.y * q2.x + q1.z * q2.w;
		var w2 = q1.w * q2.w - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z;
		x = x2;
		y = y2;
		z = z2;
		w = w2;
	}

	/** 将四元数转为欧拉角 */
	public function toEuler() {
		return toMatrix().getEulerAngles();
	}

	/**
	 * 线性插值（LERP）
	 * @param nearest 如果为 true，选择最短路径（处理负点积的情况）
	 * LERP 比 SLERP 快但不保证恒定角速度
	 */
	public inline function lerp( q1 : Quat, q2 : Quat, v : Float, nearest = false ) {
		var v2 = 1 - v;
		if( nearest && q1.dot(q2) < 0 )
			v = -v;
		var x = q1.x * v2 + q2.x * v;
		var y = q1.y * v2 + q2.y * v;
		var z = q1.z * v2 + q2.z * v;
		var w = q1.w * v2 + q2.w * v;
		this.x = x;
		this.y = y;
		this.z = z;
		this.w = w;
	}

	/**
	 * 球面线性插值（SLERP）
	 * 在两个四元数之间沿测地线平滑插值，保证恒定角速度
	 * 当夹角很小时自动回退到 LERP 避免数值不稳定
	 */
	public function slerp( q1 : Quat, q2 : Quat, v : Float ) {
		var cosom = q1.dot(q2);
		var to1: Quat = q2.clone();

		// 取最短路径
		if (cosom < 0.0) {
			cosom = -cosom;
			to1.negate();
		}

		var scale0: Float;
		var scale1: Float;

		if ((1.0 - cosom) > 0.0001) {
			// 标准 SLERP
			var omega = Math.acos(cosom);
			var sinom = Math.sin(omega);
			scale0 = Math.sin((1.0 - v) * omega) / sinom;
			scale1 = Math.sin(v * omega) / sinom;
		} else {
			// 夹角很小，用 LERP 代替
			scale0 = 1.0 - v;
			scale1 = v;
		}
		this.x = scale0 * q1.x + scale1 * to1.x;
		this.y = scale0 * q1.y + scale1 * to1.y;
		this.z = scale0 * q1.z + scale1 * to1.z;
		this.w = scale0 * q1.w + scale1 * to1.w;
	}

	/**
	 * 共轭四元数
	 * 单位四元数的共轭等于其逆（表示反向旋转）
	 * conjugate(q) = (w, -x, -y, -z)
	 */
	public inline function conjugate() {
		x = -x;
		y = -y;
		z = -z;
	}

	/**
	 * 四元数的幂运算
	 * 将单位四元数提升到指定幂次
	 * 实现：先取对数（ln），乘以幂次 v，再取指数（exp）
	 * 可用于控制旋转速度/量
	 */
	public inline function pow( v : Float ) {
		// ln()：取自然对数
		var r = Math.sqrt(x*x+y*y+z*z);
		var t = r > Math.EPSILON ? Math.atan2(r,w)/r : 0;
		w = 0.5 * hxd.Math.log(w*w+x*x+y*y+z*z);
		x *= t;
		y *= t;
		z *= t;
		// 乘以标量
		x *= v;
		y *= v;
		z *= v;
		w *= v;
		// exp()：取自然指数
		var r = Math.sqrt(x*x+y*y+z*z);
		var et = hxd.Math.exp(w);
		var s = r > Math.EPSILON ? et * Math.sin(r)/r : 0;
		w = et * Math.cos(r);
		x *= s;
		y *= s;
		z *= s;
	}

	/**
	 * 取反四元数（所有分量取反）
	 * 注意：这不会改变实际的旋转角度（q 和 -q 表示相同的旋转）
	 * 要获得反向旋转，请使用 conjugate()
	 */
	public inline function negate() {
		x = -x;
		y = -y;
		z = -z;
		w = -w;
	}

	/** 四元数点积 */
	public inline function dot( q : Quat ) {
		return x * q.x + y * q.y + z * q.z + w * q.w;
	}

	/**
	 * 获取四元数对应的前方向向量
	 * 将单位向量 [1,0,0] 通过四元数旋转
	 */
	public inline function getDirection() {
		return new h3d.Vector(1 - 2 * ( y * y + z * z ), 2 * ( x * y + z * w ), 2 * ( x * z - y * w ));
	}

	/**
	 * 获取四元数对应的上方向向量
	 */
	public inline function getUpAxis() {
		return new h3d.Vector(2 * ( x*z + y*w ),2 * ( y*z - x*w ), 1 - 2 * ( x*x + y*y ));
	}

	/**
	 * 获取四元数对应的右方向向量
	 */
	public inline function getRightAxis() {
		return new h3d.Vector(2 * ( x*y - z*w ), 1 - 2 * ( x*x + z*z ), 2 * ( y*z + x*w ));
	}
	
	/**
	 * 将四元数转换为左手坐标系下的 3x3 旋转矩阵
	 */
	public function toMatrix( ?m : h3d.Matrix ) {
		if( m == null ) m = new h3d.Matrix();
		var xx = x * x;
		var xy = x * y;
		var xz = x * z;
		var xw = x * w;
		var yy = y * y;
		var yz = y * z;
		var yw = y * w;
		var zz = z * z;
		var zw = z * w;
		m._11 = 1 - 2 * ( yy + zz );
		m._12 = 2 * ( xy + zw );
		m._13 = 2 * ( xz - yw );
		m._14 = 0;
		m._21 = 2 * ( xy - zw );
		m._22 = 1 - 2 * ( xx + zz );
		m._23 = 2 * ( yz + xw );
		m._24 = 0;
		m._31 = 2 * ( xz + yw );
		m._32 = 2 * ( yz - xw );
		m._33 = 1 - 2 * ( xx + yy );
		m._34 = 0;
		m._41 = 0;
		m._42 = 0;
		m._43 = 0;
		m._44 = 1;
		return m;
	}

	public function toString() {
		return '{${x.fmt()},${y.fmt()},${z.fmt()},${w.fmt()}}';
	}

	/**
	 * 加权混合多个四元数
	 * 用于骨骼动画中多个骨骼旋转的混合
	 *
	 * 算法来源：https://theorangeduck.com/page/quaternion-weighted-average
	 * @param sourceQuats 源四元数组
	 * @param weights 权重数组（与四元数一一对应）
	 * @param referenceQuat 参考旋转（如骨骼的默认旋转）
	 */
	public function weightedBlend(sourceQuats: Array<Quat>, weights: Array<Float>, referenceQuat: Quat) {
		this.set(0,0,0,0);

		var mulRes = inline new h3d.Quat();
		var invRef = inline referenceQuat.clone();
		inline invRef.conjugate();

		for (index => rotation in sourceQuats) {
			var weight = weights[index];

			inline mulRes.multiply(invRef, rotation);
			if (mulRes.w < 0) inline mulRes.negate();
			mulRes.w *= weight;
			mulRes.x *= weight;
			mulRes.y *= weight;
			mulRes.z *= weight;

			this.w += mulRes.w;
			this.x += mulRes.x;
			this.y += mulRes.y;
			this.z += mulRes.z;
		}

		inline this.normalize();
		inline this.multiply(referenceQuat, this);
		if (this.w < 0) inline this.negate();
	}

}
