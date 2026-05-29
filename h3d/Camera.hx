package h3d;

/**
 * 3D 相机类
 *
 * 使用左手坐标系（Left-Handed Coordinate System），更适合 2D 游戏：
 * - X 正方向朝右
 * - Y 正方向朝下（屏幕左上角为 [0,0]）
 * - Z 正方向朝向用户（屏幕外）
 *
 * 管理：
 * - 视口变换（View Matrix）：将世界空间变换到相机空间
 * - 投影变换（Projection Matrix）：将相机空间变换到裁剪空间
 * - FOV（视场角）
 * - 视锥体裁剪
 */
class Camera {

	/** 缩放倍数 */
	public var zoom : Float;

	/** 屏幕宽高比（Width/Height） */
	public var screenRatio : Float;

	/**
	 * 垂直视场角（FOV），单位：度
	 * 使用垂直 FOV 而不是水平 FOV 的原因是：
	 * 水平 FOV 会随屏幕比例变化（如 4:3 和 16:9 的水平 FOV 不同），
	 * 而垂直 FOV 保持不变。
	 * 使用 setFovX() 可根据水平 FOV 和屏幕比例初始化 fovY
	 */
	public var fovY : Float;
	
	/** 近裁剪面距离 */
	public var zNear : Float;
	
	/** 远裁剪面距离 */
	public var zFar : Float;

	/** 正交投影的包围盒边界（设置后使用正交投影而非透视投影） */
	public var orthoBounds : h3d.col.Bounds;

	/** 是否使用右手坐标系 */
	public var rightHanded : Bool;

	public var mproj : Matrix;  // 投影矩阵
	public var mcam : Matrix;   // 相机视图矩阵
	public var m : Matrix;      // 最终变换矩阵 = mcam * mproj

	public var pos : Vector;    // 相机位置
	
	/**
	 * up 向量用于构建 lookAt 矩阵
	 * 注意：这不是相机实际的向上轴
	 * 请使用 getUp() 获取实际的向上方向
	 */
	public var up : Vector;
	
	/** 相机注视目标点 */
	public var target : Vector;

	/** 视口偏移 X */
	public var viewX : Float = 0.;
	
	/** 视口偏移 Y */
	public var viewY : Float = 0.;

	/** 跟随模式：相机位置和目标跟随场景对象 */
	public var follow : { pos : h3d.scene.Object, target : h3d.scene.Object };

	/** 视锥体（用于裁剪和可见性检测） */
	public var frustum(default, null) : h3d.col.Frustum;

	/** 抖动偏移 X（用于 TAA 等） */
	public var jitterOffsetX : Float = 0.;
	
	/** 抖动偏移 Y */
	public var jitterOffsetY : Float = 0.;

	/** 是否使用反向深度缓冲（提升远距离精度） */
	public var reverseDepth = false;

	// 缓存矩阵（惰性求值）
	var minv : Matrix;      // 视图*投影的逆矩阵
	var mcamInv : Matrix;   // 视图矩阵的逆矩阵
	var mprojInv : Matrix;  // 投影矩阵的逆矩阵
	var directions : Matrix; // 方向矩阵（前/右/上方向）

	// 初始化标记位掩码（用于缓存失效）
	inline static final invMask = 1 << 0;           // minv 缓存
	inline static final invCamMask = 1 << 1;        // mcamInv 缓存
	inline static final invProjMask = 1 << 2;       // mprojInv 缓存
	inline static final directionsMask = 1 << 3;    // directions 缓存
	inline function isInit(mask) : Bool return initFlag & mask == 0;
	inline function markInit(mask) initFlag |= mask;
	var initFlag : Int = 0;  // 位掩码，0=需要重新计算

	public function new( fovY = 25., zoom = 1., screenRatio = 1.333333, zNear = 0.02, zFar = 4000., rightHanded = false ) {
		this.fovY = fovY;
		this.zoom = zoom;
		this.screenRatio = screenRatio;
		this.zNear = zNear;
		this.zFar = zFar;
		this.rightHanded = rightHanded;
		pos = new Vector(2, 3, 4);
		up = new Vector(0, 0, 1);
		target = new Vector(0, 0, 0);
		m = new Matrix();
		mcam = new Matrix();
		mproj = new Matrix();
		frustum = new h3d.col.Frustum();
		update();
	}

	/**
	 * 根据水平 FOV 设置垂直 FOV
	 * @param fovX 水平 FOV（度）
	 * @param withRatio 屏幕宽高比
	 */
	public function setFovX( fovX : Float, withRatio : Float ) {
		var degToRad = Math.PI / 180;
		fovY = 2 * Math.atan( Math.tan(fovX * 0.5 * degToRad) / withRatio ) / degToRad;
	}

	/** 获取当前水平 FOV（度） */
	public function getFovX() {
		var degToRad = Math.PI / 180;
		var halfFovX = Math.atan( Math.tan(fovY * 0.5 * degToRad) * screenRatio );
		var fovX = halfFovX * 2 / degToRad;
		return fovX;
	}

	/** 克隆相机 */
	public function clone() {
		var c = new Camera(fovY, zoom, screenRatio, zNear, zFar, rightHanded);
		c.pos = pos.clone();
		c.up = up.clone();
		c.target = target.clone();
		c.update();
		return c;
	}

	/**
	 * 获取视图*投影的逆矩阵
	 * 结果缓存直到下一次 update()
	 */
	public function getInverseViewProj() {
		if( minv == null ) minv = new h3d.Matrix();
		if( isInit(invMask) ) {
			minv.initInverse(m);
			markInit(invMask);
		}
		return minv;
	}

	/**
	 * 获取投影矩阵的逆矩阵
	 * 结果缓存直到下一次 update()
	 */
	public function getInverseProj() {
		if( mprojInv == null ) mprojInv = new h3d.Matrix();
		if( isInit(invProjMask) ) {
			mprojInv.initInverse(mproj);
			markInit(invProjMask);
		}
		return mprojInv;
	}

	/**
	 * 获取视图矩阵的逆矩阵
	 * 结果缓存直到下一次 update()
	 */
	public function getInverseView() {
		if( mcamInv == null ) mcamInv = new h3d.Matrix();
		if( isInit(invCamMask) ) {
			mcamInv.initInverse(mcam);
			markInit(invCamMask);
		}
		return mcamInv;
	}

	/** 计算相机的前/右/上方向向量 */
	function calcDirections() {
		var cameraForward = ( target - pos ).normalized();
		var cameraRight = up.cross(cameraForward).normalized();
		var cameraUp = cameraForward.cross(cameraRight);

		directions._11 = cameraForward.x;
		directions._12 = cameraForward.y;
		directions._13 = cameraForward.z;

		directions._21 = cameraRight.x;
		directions._22 = cameraRight.y;
		directions._23 = cameraRight.z;

		directions._31 = cameraUp.x;
		directions._32 = cameraUp.y;
		directions._33 = cameraUp.z;

		directions._44 = 1;
		markInit(directionsMask);
	}

	/** 获取相机的朝向向量。结果缓存直到下一次 update() */
	inline public function getForward() : h3d.Vector {
		var forward = new h3d.Vector();
		if ( directions == null ) directions = new h3d.Matrix();
		if ( isInit(directionsMask) )
			calcDirections();
		forward.x = directions._11;
		forward.y = directions._12;
		forward.z = directions._13;
		return forward;
	}

	/** 获取相机的右方向向量。结果缓存直到下一次 update() */
	inline public function getRight() : h3d.Vector {
		var right = new h3d.Vector();
		if ( directions == null ) directions = new h3d.Matrix();
		if ( isInit(directionsMask) )
			calcDirections();
		right.x = directions._21;
		right.y = directions._22;
		right.z = directions._23;
		return right;
	}

	/** 获取相机的上方向向量。结果缓存直到下一次 update() */
	inline public function getUp() : h3d.Vector {
		var up = new h3d.Vector();
		if ( directions == null ) directions = new h3d.Matrix();
		if ( isInit(directionsMask) )
			calcDirections();
		up.x = directions._31;
		up.y = directions._32;
		up.z = directions._33;
		return up;
	}

	/**
	 * 设置相机以渲染立方体贴图的指定面
	 * @param face 面索引（0=+X, 1=-X, 2=+Y, 3=-Y, 4=+Z, 5=-Z）
	 * @param position 可选的世界空间位置
	 */
	public function setCubeMap( face : Int, ?position : h3d.Vector ) {
		var dx = 0, dy = 0, dz = 0;
		switch( face ) {
		case 0: dx = 1; up.set(0,1,0);  // +X
		case 1: dx = -1; up.set(0,1,0); // -X
		case 2: dy = 1; up.set(0,0,-1); // +Y
		case 3: dy = -1; up.set(0,0,1); // -Y
		case 4: dz = 1; up.set(0,1,0);  // +Z
		case 5: dz = -1; up.set(0,1,0); // -Z
		}
		if( position != null )
			pos.load(position);
		target.set(pos.x + dx, pos.y + dy, pos.z + dz);
	}

	/**
	 * 将 2D 屏幕坐标反投影到 3D 空间
	 *
	 * screenX 和 screenY 必须在 [-1,1] 范围（归一化设备坐标）
	 * camZ 表示视锥体中的归一化 Z 值，范围 [0,1]
	 *
	 * 通过使用两个不同的 camZ 值可以得到从相机位置到屏幕位置的射线。
	 * 例如：unproject(0,0,0) 和 unproject(0,0,1) 之间的射线就是视锥体的中心轴
	 */
	public function unproject( screenX : Float, screenY : Float, camZ ) {
		var p = new h3d.Vector(screenX, screenY, camZ);
		p.project(getInverseViewProj());
		return p;
	}

	/**
	 * 从屏幕像素坐标创建 3D 射线（用于拾取检测）
	 * @param pixelX 像素 X 坐标
	 * @param pixelY 像素 Y 坐标
	 * @param sceneWidth 场景宽度（默认使用引擎当前宽度）
	 * @param sceneHeight 场景高度
	 */
	public function rayFromScreen( pixelX : Float, pixelY : Float, sceneWidth = -1, sceneHeight = -1 ) {
		var engine = h3d.Engine.getCurrent();
		if( sceneWidth < 0 ) sceneWidth = engine.width;
		if( sceneHeight < 0 ) sceneHeight = engine.height;
		var rx = (pixelX / sceneWidth - 0.5) * 2;
		var ry = (0.5 - pixelY / sceneHeight) * 2;
		return h3d.col.Ray.fromPoints(unproject(rx, ry, 0), unproject(rx, ry, 1));
	}

	/**
	 * 更新相机矩阵
	 * 重新计算相机视图矩阵和投影矩阵，并更新视锥体
	 * 同时处理跟随模式和 FOV 动画
	 */
	public function update() {
		if( follow != null ) {
			var fpos = follow.pos.localToGlobal();
			var ftarget = follow.target.localToGlobal();
			pos.set(fpos.x, fpos.y, fpos.z);
			target.set(ftarget.x, ftarget.y, ftarget.z);
			// FOV 动画
			if( follow.pos.name != null ) {
				var p = follow.pos;
				while( p != null ) {
					if( p.currentAnimation != null ) {
						var v = p.currentAnimation.getPropValue(follow.pos.name, "FOVY");
						if( v != null ) {
							fovY = v;
							break;
						}
					}
					p = p.parent;
				}
			}
		}
		makeCameraMatrix(mcam);
		makeFrustumMatrix(mproj);

		m.multiply(mcam, mproj);

		initFlag = 0;  // 清除所有缓存标记

		frustum.loadMatrix(m);
	}

	/** 获取视锥体的 8 个角点 */
	public function getFrustumCorners(zMax=1., zMin=0.) : Array<h3d.Vector> {
		return [
			unproject(-1, 1, zMin), unproject(1, 1, zMin), unproject(1, -1, zMin), unproject(-1, -1, zMin),
			unproject(-1, 1, zMax), unproject(1, 1, zMax), unproject(1, -1, zMax), unproject(-1, -1, zMax)
		];
	}

	/**
	 * 检查 up 向量是否丢失（与位置方向平行）
	 * 当 up 与位置方向几乎平行时返回 true
	 */
	public function lostUp() {
		var p2 = pos.clone();
		p2.normalize();
		return Math.abs(p2.dot(up)) > 0.999;
	}

	/**
	 * 获取视图空间中的方向向量
	 * 将给定偏移量通过相机矩阵变换到视图空间
	 */
	public function getViewDirection( dx : Float, dy : Float, dz = 0. ) {
		var a = new h3d.col.Point(dx,dy,dz);
		a.transform3x3(mcam);
		a.normalize();
		return a;
	}

	/**
	 * 在视图空间中移动相机位置
	 * 将偏移量通过相机矩阵变换后再应用
	 */
	public function movePosAxis( dx : Float, dy : Float, dz = 0. ) {
		var p = new h3d.col.Point(dx, dy, dz);
		p.transform3x3(mcam);
		pos.x += p.x;
		pos.y += p.y;
		pos.z += p.z;
	}

	/**
	 * 在视图空间中移动相机目标
	 */
	public function moveTargetAxis( dx : Float, dy : Float, dz = 0. ) {
		var p = new h3d.col.Point(dx, dy, dz);
		p.transform3x3(mcam);
		target.x += p.x;
		target.y += p.y;
		target.z += p.z;
	}

	/**
	 * 相机前进（朝向目标方向移动）
	 * @param speed 移动速度系数
	 */
	public function forward(speed = 1.) {
		var c = 1 - 0.025 * speed;
		pos.set(
			target.x + (pos.x - target.x) * c,
			target.y + (pos.y - target.y) * c,
			target.z + (pos.z - target.z) * c
		);
	}

	/**
	 * 相机后退（远离目标方向移动）
	 * @param speed 移动速度系数
	 */
	public function backward(speed = 1.) {
		var c = 1 + 0.025 * speed;
		pos.set(
			target.x + (pos.x - target.x) * c,
			target.y + (pos.y - target.y) * c,
			target.z + (pos.z - target.z) * c
		);
	}

	/**
	 * 构建相机视图矩阵（LookAt 矩阵的转置版本）
	 *
	 * 在左手坐标系中 Z 轴为正，右手坐标系中为负。
	 * 构建的矩阵确保 [ax, ay, -az] 与世界坐标系保持相同的手性。
	 *
	 * 这是 Matrix.lookAt 的转置版本，因为 Heaps 使用行主序矩阵
	 */
	function makeCameraMatrix( m : Matrix ) {
		var az = target.sub(pos);  // Z 轴：从相机指向目标
		if( rightHanded ) az.scale(-1);
		az.normalize();
		var ax = up.cross(az);     // X 轴：up 与 Z 的叉积
		ax.normalize();
		if( ax.length() == 0 ) {
			// 如果 up 与 az 平行，使用备用向量
			ax.x = az.y;
			ax.y = az.z;
			ax.z = az.x;
		}
		var ay = az.cross(ax);     // Y 轴：Z 与 X 的叉积
		m._11 = ax.x;
		m._12 = ay.x;
		m._13 = az.x;
		m._14 = 0;
		m._21 = ax.y;
		m._22 = ay.y;
		m._23 = az.y;
		m._24 = 0;
		m._31 = ax.z;
		m._32 = ay.z;
		m._33 = az.z;
		m._34 = 0;
		m._41 = -ax.dot(pos);  // 平移：-R * pos
		m._42 = -ay.dot(pos);
		m._43 = -az.dot(pos);
		m._44 = 1;
	}

	/**
	 * 从变换矩阵设置相机位置和目标
	 * 从矩阵的平移分量获取位置，从方向获取目标
	 */
	public function setTransform( m : Matrix ) {
		pos.set(m._41, m._42, m._43);
		target.load(pos.add(m.getDirection()));
	}

	/**
	 * 构建投影矩阵（透视或正交）
	 *
	 * 处理宽高比，并将 Z 值归一化到 [0,1]（除以 w 后）。
	 * 投影矩阵需要满足：
	 *   P * [x,y,-zNear,1]^T => [sx/zNear, sy/zNear, 0, 1]
	 *   P * [x,y,-zFar,1]^T  => [sx/zFar, sy/zFar, 1, 1]
	 *
	 * 将宽高比应用到高度上，使 FOV 变为水平 FOV，
	 * 这样屏幕放大时无需调整 FOV。
	 * 支持：
	 * - 透视投影（默认）
	 * - 正交投影（设置 orthoBounds 时）
	 * - 反向深度缓冲（reverseDepth）
	 * - 抖动偏移（用于 TAA）
	 */
	function makeFrustumMatrix( m : Matrix ) {
		m.zero();

		var bounds = orthoBounds;
		if( bounds != null ) {
			// 正交投影矩阵
			var w = 1 / (bounds.xMax - bounds.xMin);
			var h = 1 / (bounds.yMax - bounds.yMin);
			var d = 1 / (bounds.zMax - bounds.zMin);

			m._11 = 2 * w;
			m._22 = 2 * h;
			m._33 = d;
			m._41 = -(bounds.xMin + bounds.xMax) * w;
			m._42 = -(bounds.yMin + bounds.yMax) * h;
			m._43 = -bounds.zMin * d;
			m._44 = 1;

		} else {
			// 透视投影矩阵
			var degToRad = (Math.PI / 180);
			var halfFovX = Math.atan( Math.tan(fovY * 0.5 * degToRad) * screenRatio );
			var scale = zoom / Math.tan(halfFovX);
			m._11 = scale;
			m._22 = scale * screenRatio;
			// Z 映射：反向深度使用 [1,0]，正向使用 [0,1]
			m._33 = reverseDepth ? -zNear / (zFar - zNear) : zFar / (zFar - zNear);
			m._34 = 1;
			m._43 = reverseDepth ? (zNear * zFar) / (zFar - zNear) : -(zNear * zFar) / (zFar - zNear);

			m._31 = jitterOffsetX;  // TAA 抖动偏移
			m._32 = jitterOffsetY;
		}

		// 应用视口偏移
		m._11 += viewX * m._14;
		m._21 += viewX * m._24;
		m._31 += viewX * m._34;
		m._41 += viewX * m._44;

		m._12 += viewY * m._14;
		m._22 += viewY * m._24;
		m._32 += viewY * m._34;
		m._42 += viewY * m._44;

		// 右手坐标系中 Z 为负
		if( rightHanded ) {
			m._33 *= -1;
			m._34 *= -1;
		}
	}

	/**
	 * 将 3D 点投影到 2D 屏幕坐标（内联版本）
	 * 使用当前的 m = mcam * mproj 矩阵
	 * @param snapToPixel 是否吸附到像素（防止模糊）
	 */
	inline public function projectInline( x : Float, y : Float, z : Float, screenWidth : Float, screenHeight : Float, snapToPixel = true ) {
		var p = new h3d.Vector();
		p.set(x, y, z);
		p.project(m);
		p.x = (p.x + 1) * 0.5 * screenWidth;
		p.y = (-p.y + 1) * 0.5 * screenHeight;
		if( snapToPixel ) {
			p.x = Math.round(p.x);
			p.y = Math.round(p.y);
		}
		return p;
	}

	/**
	 * 将 3D 点投影到 2D 屏幕坐标（通用版本，可复用向量）
	 */
	public function project( x : Float, y : Float, z : Float, screenWidth : Float, screenHeight : Float, snapToPixel = true, ?p: h3d.Vector) {
		if(p == null)
			p = new h3d.Vector();
		p.set(x, y, z);
		p.project(m);
		p.x = (p.x + 1) * 0.5 * screenWidth;
		p.y = (-p.y + 1) * 0.5 * screenHeight;
		if( snapToPixel ) {
			p.x = Math.round(p.x);
			p.y = Math.round(p.y);
		}
		return p;
	}

	/**
	 * 将世界空间距离转换为深度缓冲值
	 * 用于深度比较和阴影映射
	 */
	public function distanceToDepth( dist : Float ) {
		var invDist = 1.0 / hxd.Math.clamp(dist, zNear, zFar);
		var fDivN = zFar / zNear;
		var a = reverseDepth ? fDivN - 1 : 1 - fDivN;
		var b = reverseDepth ? 1.0 / zFar : 1.0 / zNear;
		return (zFar / a) * (invDist - b);
	}

	/**
	 * 将深度缓冲值转换为世界空间距离
	 * `distanceToDepth` 的逆操作
	 */
	public function depthToDistance( depth : Float ) {
		var d = hxd.Math.clamp(depth);
		var fDivN = zFar/zNear;
		var a = reverseDepth ? fDivN - 1 : 1 - fDivN;
		var b = reverseDepth ? 1.0 / zFar : 1.0 / zNear;
		return 1.0 / (a / zFar * d + b);
	}

	/**
	 * 从另一个相机加载所有参数并更新
	 */
	public function load( cam : Camera ) {
		pos.load(cam.pos);
		target.load(cam.target);
		up.load(cam.up);
		if( cam.orthoBounds != null ) {
			orthoBounds = new h3d.col.Bounds();
			orthoBounds.load(cam.orthoBounds);
		} else
			orthoBounds = null;
		fovY = cam.fovY;
		screenRatio = cam.screenRatio;
		zoom = cam.zoom;
		zNear = cam.zNear;
		zFar = cam.zFar;
		if( cam.follow != null )
			follow = { pos : cam.follow.pos, target : cam.follow.target };
		else
			follow = null;
		viewX = cam.viewX;
		viewY = cam.viewY;
		rightHanded = cam.rightHanded;
		reverseDepth = cam.reverseDepth;
		update();
	}

}
