package h3d.col;

/**
 * 视锥体（Frustum）
 *
 * 由 6 个平面（左/右/顶/底/近/远）围成的平截头体。
 * 用于视锥体裁剪（Frustum Culling），判断对象是否在相机视野内。
 *
 * 每个平面对应相机空间中的一个裁剪边界。
 * 平面方程：P = { n | n·X - d = 0 }
 * 点在平面正面（视野内）：n·X - d >= 0
 *
 * 从 MVP 矩阵提取平面的方法（Gribb-Hartmann 算法）：
 * 左平面 = 第4行 + 第1行
 * 右平面 = 第4行 - 第1行
 * 底平面 = 第4行 + 第2行
 * 顶平面 = 第4行 - 第2行
 * 近平面 = 第3行
 * 远平面 = 第4行 - 第3行
 */
class Frustum {

	public var pleft : Plane;    // 左平面
	public var pright : Plane;   // 右平面
	public var ptop : Plane;     // 顶平面
	public var pbottom : Plane;  // 底平面
	public var pnear : Plane;    // 近平面
	public var pfar : Plane;     // 远平面
	public var checkNearFar : Bool = true;  // 是否检查近/远平面

	public function new( ?mvp : h3d.Matrix ) {
		pleft = Plane.X();
		pright = Plane.X();
		ptop = Plane.X();
		pbottom = Plane.X();
		pnear = Plane.X();
		pfar = Plane.X();
		if(mvp != null)
			loadMatrix(mvp);
	}

	public function clone() {
		var f = new Frustum();
		f.pleft.load(pleft);
		f.pright.load(pright);
		f.ptop.load(ptop);
		f.pbottom.load(pbottom);
		f.pnear.load(pnear);
		f.pfar.load(pfar);
		f.checkNearFar = checkNearFar;
		return f;
	}

	/**
	 * 从 MVP 矩阵加载视锥体平面
	 * 从矩阵的行组合提取 6 个平面的方程系数
	 */
	public function loadMatrix( mvp : h3d.Matrix ) {
		pleft.load(Plane.frustumLeft(mvp));
		pright.load(Plane.frustumRight(mvp));
		ptop.load(Plane.frustumTop(mvp));
		pbottom.load(Plane.frustumBottom(mvp));
		pnear.load(Plane.frustumNear(mvp));
		pfar.load(Plane.frustumFar(mvp));
		pleft.normalize();
		pright.normalize();
		ptop.normalize();
		pbottom.normalize();
		pnear.normalize();
		pfar.normalize();
	}

	/**
	 * 用矩阵对视锥体进行变换
	 * 使用逆矩阵的转置（Inverse Transpose）变换每个平面
	 */
	public function transform( m : h3d.Matrix ) @:privateAccess {
		var m2 = new h3d.Matrix();
		m2.initInverse(m);
		m2.transpose();

		pleft.transformInverseTranspose(m2);
		pright.transformInverseTranspose(m2);
		ptop.transformInverseTranspose(m2);
		pbottom.transformInverseTranspose(m2);
		pfar.transformInverseTranspose(m2);
		pnear.transformInverseTranspose(m2);

		pleft.normalize();
		pright.normalize();
		ptop.normalize();
		pbottom.normalize();
		pnear.normalize();
		pfar.normalize();
	}

	/** 用 3x3 矩阵变换视锥体（不含平移） */
	public function transform3x3( m : h3d.Matrix ) @:privateAccess {
		var m2 = new h3d.Matrix();
		m2.initInverse3x3(m);
		m2.transpose();

		pleft.transformInverseTranspose(m2);
		pright.transformInverseTranspose(m2);
		ptop.transformInverseTranspose(m2);
		pbottom.transformInverseTranspose(m2);
		pfar.transformInverseTranspose(m2);
		pnear.transformInverseTranspose(m2);

		pleft.normalize();
		pright.normalize();
		ptop.normalize();
		pbottom.normalize();
		pnear.normalize();
		pfar.normalize();
	}

	/**
	 * 检测点是否在视锥体内
	 * 点在所有 6 个平面的正面才算在视锥体内
	 */
	public function hasPoint( p : Point ) {
		if( pleft.distance(p) < 0 ) return false;
		if( pright.distance(p) < 0 ) return false;
		if( ptop.distance(p) < 0 ) return false;
		if( pbottom.distance(p) < 0 ) return false;
		if( checkNearFar ) {
			if( pnear.distance(p) < 0 ) return false;
			if( pfar.distance(p) < 0 ) return false;
		}
		return true;
	}

	public function hasSphere( s : Sphere ) {
		var p = s.getCenter();
		if( pleft.distance(p) < -s.r ) return false;
		if( pright.distance(p) < -s.r ) return false;
		if( ptop.distance(p) < -s.r ) return false;
		if( pbottom.distance(p) < -s.r ) return false;
		if( checkNearFar ) {
			if( pnear.distance(p) < -s.r ) return false;
			if( pfar.distance(p) < -s.r ) return false;
		}
		return true;
	}

	public function hasBounds( b : Bounds ) @:privateAccess {
		if( b.testPlane(pleft) < 0 )
			return false;
		if( b.testPlane(pright) < 0 )
			return false;
		if( b.testPlane(ptop) < 0 )
			return false;
		if( b.testPlane(pbottom) < 0 )
			return false;
		if ( checkNearFar ) {
			if( b.testPlane(pnear) < 0 )
				return false;
			if( b.testPlane(pfar) < 0 )
				return false;
		}
		return true;
	}

	public function hasOrientedBounds( b : OrientedBounds ) @:privateAccess {
		if( b.testPlane(pleft) < 0 )
			return false;
		if( b.testPlane(pright) < 0 )
			return false;
		if( b.testPlane(ptop) < 0 )
			return false;
		if( b.testPlane(pbottom) < 0 )
			return false;
		if ( checkNearFar ) {
			if( b.testPlane(pnear) < 0 )
				return false;
			if( b.testPlane(pfar) < 0 )
				return false;
		}
		return true;
	}

	inline function intersectPlanes( p1 : Plane, p2 : Plane, p3 : Plane ) : h3d.Vector {
		var n2 = new h3d.Vector(p2.nx, p2.ny, p2.nz);
		var n3 = new h3d.Vector(p3.nx, p3.ny, p3.nz);
		var n1 = new h3d.Vector(p1.nx, p1.ny, p1.nz);
		var d1 = p1.d;
		var d2 = p2.d;
		var d3 = p3.d;

		var c12 = n1.cross(n2);
		var c23 = n2.cross(n3);
		var c31 = n3.cross(n1);

		var denom = n1.dot(c23);
		var v = d1 * c23 + d2 * c31 + d3 * c12;
		return new h3d.Vector(v.x / denom, v.y / denom, v.z / denom);
	}

	public function getBounds( m : h3d.Matrix, ?out : Bounds ) : Bounds {
		if( out == null ) out = new Bounds();
		else out.empty();
		inline function addCorner( p1 : Plane, p2 : Plane, p3 : Plane ) {
			var p = intersectPlanes(p1, p2, p3) * m;
			out.addPos(p.x, p.y, p.z);
		}
		addCorner(pnear, pleft,  pbottom);
		addCorner(pnear, pright, pbottom);
		addCorner(pnear, pleft,  ptop);
		addCorner(pnear, pright, ptop);
		addCorner(pfar,  pleft,  pbottom);
		addCorner(pfar,  pright, pbottom);
		addCorner(pfar,  pleft,  ptop);
		addCorner(pfar,  pright, ptop);
		return out;
	}
}