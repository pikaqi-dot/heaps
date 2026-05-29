package h3d;
import hxd.Math;

// 颜色调整参数类型定义
// 用于图像后处理的颜色调整参数，包含饱和度、亮度、色相、对比度和增益
typedef ColorAdjust = {
	?saturation : Float,  // 饱和度调整 (-1 ~ 1)
	?lightness : Float,   // 亮度调整
	?hue : Float,         // 色相偏移（弧度）
	?contrast : Float,    // 对比度调整 (-1 ~ 1)
	?gain : { color : Int, alpha : Float },  // 颜色增益（颜色值和透明度混合）
};

/**
 * 4x4 矩阵实现类
 * Heaps 引擎的核心数学组件，用于表示 3D 变换（平移、旋转、缩放、投影）
 * 采用列主序存储：_RC 表示第 R 行第 C 列
 * 矩阵布局：
 * [ _11 _12 _13 _14 ]  行0
 * [ _21 _22 _23 _24 ]  行1
 * [ _31 _32 _33 _34 ]  行2
 * [ _41 _42 _43 _44 ]  行3（平移量在最后一行）
 */
class MatrixImpl {

	// 临时矩阵对象，用于避免频繁分配内存
	static var tmp = new Matrix();

	// 4x4 矩阵的 16 个元素
	public var _11 : Float;  // 行0列0 - 旋转/缩放 X 分量
	public var _12 : Float;  // 行0列1
	public var _13 : Float;  // 行0列2
	public var _14 : Float;  // 行0列3 - 透视投影相关
	public var _21 : Float;  // 行1列0
	public var _22 : Float;  // 行1列1 - 旋转/缩放 Y 分量
	public var _23 : Float;  // 行1列2
	public var _24 : Float;  // 行1列3 - 透视投影相关
	public var _31 : Float;  // 行2列0
	public var _32 : Float;  // 行2列1
	public var _33 : Float;  // 行2列2 - 旋转/缩放 Z 分量
	public var _34 : Float;  // 行2列3 - 透视投影相关
	public var _41 : Float;  // 行3列0 - 平移 X 分量
	public var _42 : Float;  // 行3列1 - 平移 Y 分量
	public var _43 : Float;  // 行3列2 - 平移 Z 分量
	public var _44 : Float;  // 行3列3 - 齐次坐标缩放

	// 便捷访问平移分量的属性
	public var tx(get, set) : Float;  // X 轴平移量（等同于 _41）
	public var ty(get, set) : Float;  // Y 轴平移量（等同于 _42）
	public var tz(get, set) : Float;  // Z 轴平移量（等同于 _43）

	inline public function new() {
	}

	// 平移分量 getter/setter 实现
	inline function get_tx() return _41;
	inline function get_ty() return _42;
	inline function get_tz() return _43;
	inline function set_tx(v) return _41 = v;
	inline function set_ty(v) return _42 = v;
	inline function set_tz(v) return _43 = v;

	/**
	 * 比较两个矩阵是否完全相等（逐元素比较）
	 */
	public function equal( other : Matrix ) {
		return	_11 == other._11 && _12 == other._12 && _13 == other._13 && _14 == other._14
			&& 	_21 == other._21 && _22 == other._22 && _23 == other._23 && _24 == other._24
			&& 	_31 == other._31 && _32 == other._32 && _33 == other._33 && _34 == other._34
			&& 	_41 == other._41 && _42 == other._42 && _43 == other._43 && _44 == other._44;
	}

	/**
	 * 将矩阵所有元素设为零
	 */
	public function zero() {
		_11 = 0.0; _12 = 0.0; _13 = 0.0; _14 = 0.0;
		_21 = 0.0; _22 = 0.0; _23 = 0.0; _24 = 0.0;
		_31 = 0.0; _32 = 0.0; _33 = 0.0; _34 = 0.0;
		_41 = 0.0; _42 = 0.0; _43 = 0.0; _44 = 0.0;
	}

	/**
	 * 设置为单位矩阵
	 * 单位矩阵是对角线为1，其余为0的矩阵，相当于没有变换
	 */
	public function identity() {
		_11 = 1.0; _12 = 0.0; _13 = 0.0; _14 = 0.0;
		_21 = 0.0; _22 = 1.0; _23 = 0.0; _24 = 0.0;
		_31 = 0.0; _32 = 0.0; _33 = 1.0; _34 = 0.0;
		_41 = 0.0; _42 = 0.0; _43 = 0.0; _44 = 1.0;
	}

	/**
	 * 检查是否为精确的单位矩阵
	 */
	public function isIdentity() {
		if( _41 != 0 || _42 != 0 || _43 != 0 )
			return false;
		if( _11 != 1 || _22 != 1 || _33 != 1 )
			return false;
		if( _12 != 0 || _13 != 0 || _14 != 0 )
			return false;
		if( _21 != 0 || _23 != 0 || _24 != 0 )
			return false;
		if( _31 != 0 || _32 != 0 || _34 != 0 )
			return false;
		return _44 == 1;
	}

	/**
	 * 在指定容差范围内检查是否为单位矩阵
	 * @param e 容差范围（epsilon）
	 */
	public function isIdentityEpsilon( e : Float ) {
		if( Math.abs(_41) > e || Math.abs(_42) > e || Math.abs(_43) > e )
			return false;
		if( Math.abs(_11-1) > e || Math.abs(_22-1) > e || Math.abs(_33-1) > e )
			return false;
		if( Math.abs(_12) > e || Math.abs(_13) > e || Math.abs(_14) > e )
			return false;
		if( Math.abs(_21) > e || Math.abs(_23) > e || Math.abs(_24) > e )
			return false;
		if( Math.abs(_31) > e || Math.abs(_32) > e || Math.abs(_34) > e )
			return false;
		return Math.abs(_44 - 1) <= e;
	}

	/**
	 * 初始化为绕 X 轴的旋转矩阵
	 * @param a 旋转角度（弧度）
	 * 矩阵形式：
	 * [ 1    0      0   0 ]
	 * [ 0  cos(a) sin(a) 0 ]
	 * [ 0 -sin(a) cos(a) 0 ]
	 * [ 0    0      0   1 ]
	 */
	public function initRotationX( a : Float ) {
		var cos = Math.cos(a);
		var sin = Math.sin(a);
		_11 = 1.0; _12 = 0.0; _13 = 0.0; _14 = 0.0;
		_21 = 0.0; _22 = cos; _23 = sin; _24 = 0.0;
		_31 = 0.0; _32 = -sin; _33 = cos; _34 = 0.0;
		_41 = 0.0; _42 = 0.0; _43 = 0.0; _44 = 1.0;
	}

	/**
	 * 初始化为绕 Y 轴的旋转矩阵
	 * @param a 旋转角度（弧度）
	 * 矩阵形式：
	 * [  cos(a) 0 -sin(a) 0 ]
	 * [    0    1   0    0 ]
	 * [  sin(a) 0  cos(a) 0 ]
	 * [    0    0   0    1 ]
	 */
	public function initRotationY( a : Float ) {
		var cos = Math.cos(a);
		var sin = Math.sin(a);
		_11 = cos; _12 = 0.0; _13 = -sin; _14 = 0.0;
		_21 = 0.0; _22 = 1.0; _23 = 0.0; _24 = 0.0;
		_31 = sin; _32 = 0.0; _33 = cos; _34 = 0.0;
		_41 = 0.0; _42 = 0.0; _43 = 0.0; _44 = 1.0;
	}

	/**
	 * 初始化为绕 Z 轴的旋转矩阵
	 * @param a 旋转角度（弧度）
	 * 矩阵形式：
	 * [ cos(a) sin(a) 0 0 ]
	 * [-sin(a) cos(a) 0 0 ]
	 * [   0      0    1 0 ]
	 * [   0      0    0 1 ]
	 */
	public function initRotationZ( a : Float ) {
		var cos = Math.cos(a);
		var sin = Math.sin(a);
		_11 = cos; _12 = sin; _13 = 0.0; _14 = 0.0;
		_21 = -sin; _22 = cos; _23 = 0.0; _24 = 0.0;
		_31 = 0.0; _32 = 0.0; _33 = 1.0; _34 = 0.0;
		_41 = 0.0; _42 = 0.0; _43 = 0.0; _44 = 1.0;
	}

	/**
	 * 初始化为平移矩阵
	 * 将物体沿 x/y/z 方向移动指定距离
	 * 矩阵形式：
	 * [ 1 0 0 0 ]
	 * [ 0 1 0 0 ]
	 * [ 0 0 1 0 ]
	 * [ x y z 1 ]
	 */
	public function initTranslation( x = 0., y = 0., z = 0. ) {
		_11 = 1.0; _12 = 0.0; _13 = 0.0; _14 = 0.0;
		_21 = 0.0; _22 = 1.0; _23 = 0.0; _24 = 0.0;
		_31 = 0.0; _32 = 0.0; _33 = 1.0; _34 = 0.0;
		_41 = x; _42 = y; _43 = z; _44 = 1.0;
	}

	/**
	 * 初始化为缩放矩阵
	 * 沿 x/y/z 轴方向缩放指定倍数
	 * 矩阵形式：
	 * [ x 0 0 0 ]
	 * [ 0 y 0 0 ]
	 * [ 0 0 z 0 ]
	 * [ 0 0 0 1 ]
	 */
	public function initScale( x = 1., y = 1., z = 1. ) {
		_11 = x; _12 = 0.0; _13 = 0.0; _14 = 0.0;
		_21 = 0.0; _22 = y; _23 = 0.0; _24 = 0.0;
		_31 = 0.0; _32 = 0.0; _33 = z; _34 = 0.0;
		_41 = 0.0; _42 = 0.0; _43 = 0.0; _44 = 1.0;
	}

	/**
	 * 初始化为绕任意轴的旋转矩阵（Rodrigues' rotation formula）
	 * @param axis 旋转轴向量
	 * @param angle 旋转角度（弧度）
	 * 使用罗德里格斯旋转公式计算绕任意轴的旋转矩阵
	 */
	public inline function initRotationAxis( axis : Vector, angle : Float ) {
		var cos = Math.cos(angle), sin = Math.sin(angle);
		var cos1 = 1 - cos;
		var x = -axis.x, y = -axis.y, z = -axis.z;
		var xx = x * x, yy = y * y, zz = z * z;
		var len = Math.invSqrt(xx + yy + zz);
		x *= len;
		y *= len;
		z *= len;
		var xcos1 = x * cos1, zcos1 = z * cos1;
		_11 = cos + x * xcos1;
		_12 = y * xcos1 - z * sin;
		_13 = x * zcos1 + y * sin;
		_14 = 0.;
		_21 = y * xcos1 + z * sin;
		_22 = cos + y * y * cos1;
		_23 = y * zcos1 - x * sin;
		_24 = 0.;
		_31 = x * zcos1 - y * sin;
		_32 = y * zcos1 + x * sin;
		_33 = cos + z * zcos1;
		_34 = 0.;
		_41 = 0.; _42 = 0.; _43 = 0.; _44 = 1.;
	}

	/**
	 * 初始化为欧拉角旋转矩阵（ZYX 顺序）
	 * 先绕 Z 轴旋转 z，再绕 Y 轴旋转 y，最后绕 X 轴旋转 x
	 */
	public function initRotation( x : Float, y : Float, z : Float ) {
		var cx = Math.cos(x);
		var sx = Math.sin(x);
		var cy = Math.cos(y);
		var sy = Math.sin(y);
		var cz = Math.cos(z);
		var sz = Math.sin(z);
		var cxsy = cx * sy;
		var sxsy = sx * sy;
		_11 = cy * cz;
		_12 = cy * sz;
		_13 = -sy;
		_14 = 0;
		_21 = sxsy * cz - cx * sz;
		_22 = sxsy * sz + cx * cz;
		_23 = sx * cy;
		_24 = 0;
		_31 = cxsy * cz + sx * sz;
		_32 = cxsy * sz - sx * cz;
		_33 = cx * cy;
		_34 = 0;
		_41 = 0;
		_42 = 0;
		_43 = 0;
		_44 = 1;
	}

	/**
	 * 在当前变换后附加平移（后乘平移矩阵）
	 * 相当于在局部坐标系中移动
	 */
	public function translate( x = 0., y = 0., z = 0. ) {
		_11 += x * _14;
		_12 += y * _14;
		_13 += z * _14;
		_21 += x * _24;
		_22 += y * _24;
		_23 += z * _24;
		_31 += x * _34;
		_32 += y * _34;
		_33 += z * _34;
		_41 += x * _44;
		_42 += y * _44;
		_43 += z * _44;
	}

	/**
	 * 在当前变换后附加缩放（后乘缩放矩阵）
	 * 相当于在局部坐标系中缩放
	 */
	public function scale( x = 1., y = 1., z = 1. ) {
		_11 *= x;
		_21 *= x;
		_31 *= x;
		_41 *= x;
		_12 *= y;
		_22 *= y;
		_32 *= y;
		_42 *= y;
		_13 *= z;
		_23 *= z;
		_33 *= z;
		_43 *= z;
	}

	/**
	 * 在当前变换后附加旋转（后乘欧拉角旋转矩阵）
	 */
	public function rotate( x, y, z ) {
		var tmp = tmp;
		tmp.initRotation(x,y,z);
		multiply(this, tmp);
	}

	/**
	 * 在当前变换后附加绕任意轴旋转
	 */
	public function rotateAxis( axis, angle ) {
		var tmp = tmp;
		tmp.initRotationAxis(axis, angle);
		multiply(this, tmp);
	}

	/**
	 * 获取矩阵的平移分量（位置向量）
	 */
	public inline function getPosition() {
		var v = new Vector();
		v.set(_41,_42,_43);
		return v;
	}

	/**
	 * 设置矩阵的平移分量（位置向量）
	 */
	public inline function setPosition( v : Vector ) {
		_41 = v.x;
		_42 = v.y;
		_43 = v.z;
	}

	/**
	 * 在当前变换前附加平移（前乘平移矩阵）
	 * 相当于在世界坐标系中移动
	 */
	public function prependTranslation( x = 0., y = 0., z = 0. ) {
		var vx = _11 * x + _21 * y + _31 * z + _41;
		var vy = _12 * x + _22 * y + _32 * z + _42;
		var vz = _13 * x + _23 * y + _33 * z + _43;
		var vw = _14 * x + _24 * y + _34 * z + _44;
		_41 = vx;
		_42 = vy;
		_43 = vz;
		_44 = vw;
	}

	/**
	 * 获取矩阵的缩放分量
	 * 通过计算每列前三个元素的向量长度得到各轴缩放值
	 * 如果行列式为负（镜像变换），则缩放值为负
	 */
	public inline function getScale() {
		var v = new Vector();
		v.x = Math.sqrt(_11 * _11 + _12 * _12 + _13 * _13);
		v.y = Math.sqrt(_21 * _21 + _22 * _22 + _23 * _23);
		v.z = Math.sqrt(_31 * _31 + _32 * _32 + _33 * _33);
		if( getDeterminant() < 0 ) {
			v.x *= -1;
			v.y *= -1;
			v.z *= -1;
		}
		return v;
	}

	/**
	 * 在当前变换前附加旋转（前乘欧拉角旋转矩阵）
	 */
	public function prependRotation( x, y, z ) {
		var tmp = tmp;
		tmp.initRotation(x,y,z);
		multiply(tmp, this);
	}

	/**
	 * 在当前变换前附加绕任意轴旋转
	 */
	public function prependRotationAxis( axis, angle ) {
		var tmp = tmp;
		tmp.initRotationAxis(axis, angle);
		multiply(tmp, this);
	}

	/**
	 * 在当前变换前附加缩放（前乘缩放矩阵）
	 */
	public function prependScale( sx = 1., sy = 1., sz = 1. ) {
		var tmp = tmp;
		tmp.initScale(sx,sy,sz);
		multiply(tmp, this);
	}

	/**
	 * 3x4 矩阵乘法（不带调试信息）
	 * 假设第4行是 [0,0,0,1]，简化了计算
	 * 结果也是 3x4 变换（_14=_24=_34=0, _44=1）
	 */
	@:noDebug
	public function multiply3x4( a : Matrix, b : Matrix ) {
		multiply3x4inline(a, b);
	}

	/**
	 * 内联版 3x4 矩阵乘法
	 * 假设矩阵是仿射变换（最后一行 [0,0,0,1]），跳过第4列/行的完整计算
	 */
	public inline function multiply3x4inline( a : Matrix, b : Matrix ) {
		var m11 = a._11; var m12 = a._12; var m13 = a._13;
		var m21 = a._21; var m22 = a._22; var m23 = a._23;
		var a31 = a._31; var a32 = a._32; var a33 = a._33;
		var a41 = a._41; var a42 = a._42; var a43 = a._43;
		var b11 = b._11; var b12 = b._12; var b13 = b._13;
		var b21 = b._21; var b22 = b._22; var b23 = b._23;
		var b31 = b._31; var b32 = b._32; var b33 = b._33;
		var b41 = b._41; var b42 = b._42; var b43 = b._43;

		_11 = m11 * b11 + m12 * b21 + m13 * b31;
		_12 = m11 * b12 + m12 * b22 + m13 * b32;
		_13 = m11 * b13 + m12 * b23 + m13 * b33;
		_14 = 0;

		_21 = m21 * b11 + m22 * b21 + m23 * b31;
		_22 = m21 * b12 + m22 * b22 + m23 * b32;
		_23 = m21 * b13 + m22 * b23 + m23 * b33;
		_24 = 0;

		_31 = a31 * b11 + a32 * b21 + a33 * b31;
		_32 = a31 * b12 + a32 * b22 + a33 * b32;
		_33 = a31 * b13 + a32 * b23 + a33 * b33;
		_34 = 0;

		_41 = a41 * b11 + a42 * b21 + a43 * b31 + b41;
		_42 = a41 * b12 + a42 * b22 + a43 * b32 + b42;
		_43 = a41 * b13 + a42 * b23 + a43 * b33 + b43;
		_44 = 1;
	}

	/**
	 * 完整的 4x4 矩阵乘法
	 * 计算 this = a * b
	 * 适用于包含投影矩阵的通用情况
	 */
	public function multiply( a : Matrix, b : Matrix ) {
		var a11 = a._11; var a12 = a._12; var a13 = a._13; var a14 = a._14;
		var a21 = a._21; var a22 = a._22; var a23 = a._23; var a24 = a._24;
		var a31 = a._31; var a32 = a._32; var a33 = a._33; var a34 = a._34;
		var a41 = a._41; var a42 = a._42; var a43 = a._43; var a44 = a._44;
		var b11 = b._11; var b12 = b._12; var b13 = b._13; var b14 = b._14;
		var b21 = b._21; var b22 = b._22; var b23 = b._23; var b24 = b._24;
		var b31 = b._31; var b32 = b._32; var b33 = b._33; var b34 = b._34;
		var b41 = b._41; var b42 = b._42; var b43 = b._43; var b44 = b._44;

		_11 = a11 * b11 + a12 * b21 + a13 * b31 + a14 * b41;
		_12 = a11 * b12 + a12 * b22 + a13 * b32 + a14 * b42;
		_13 = a11 * b13 + a12 * b23 + a13 * b33 + a14 * b43;
		_14 = a11 * b14 + a12 * b24 + a13 * b34 + a14 * b44;

		_21 = a21 * b11 + a22 * b21 + a23 * b31 + a24 * b41;
		_22 = a21 * b12 + a22 * b22 + a23 * b32 + a24 * b42;
		_23 = a21 * b13 + a22 * b23 + a23 * b33 + a24 * b43;
		_24 = a21 * b14 + a22 * b24 + a23 * b34 + a24 * b44;

		_31 = a31 * b11 + a32 * b21 + a33 * b31 + a34 * b41;
		_32 = a31 * b12 + a32 * b22 + a33 * b32 + a34 * b42;
		_33 = a31 * b13 + a32 * b23 + a33 * b33 + a34 * b43;
		_34 = a31 * b14 + a32 * b24 + a33 * b34 + a34 * b44;

		_41 = a41 * b11 + a42 * b21 + a43 * b31 + a44 * b41;
		_42 = a41 * b12 + a42 * b22 + a43 * b32 + a44 * b42;
		_43 = a41 * b13 + a42 * b23 + a43 * b33 + a44 * b43;
		_44 = a41 * b14 + a42 * b24 + a43 * b34 + a44 * b44;
	}

	/**
	 * 矩阵乘以标量值
	 * 所有 16 个元素都乘以指定值
	 */
	public function multiplyValue( v : Float ) {
		_11 *= v;
		_12 *= v;
		_13 *= v;
		_14 *= v;
		_21 *= v;
		_22 *= v;
		_23 *= v;
		_24 *= v;
		_31 *= v;
		_32 *= v;
		_33 *= v;
		_34 *= v;
		_41 *= v;
		_42 *= v;
		_43 *= v;
		_44 *= v;
	}

	/**
	 * 原地求逆：计算当前矩阵的逆矩阵并替换自身
	 */
	public inline function invert() {
		initInverse(this);
	}

	/**
	 * 获取当前矩阵的逆矩阵（返回新矩阵）
	 * @param m 可选，如果提供了矩阵对象则复用该对象存储结果
	 */
	public function getInverse( ?m : h3d.Matrix ) {
		if( m == null ) m = new h3d.Matrix();
		m.initInverse(this);
		return m;
	}

	/**
	 * 计算矩阵的行列式（仅 3x3 部分）
	 * 用于判断矩阵是否可逆
	 */
	public inline function getDeterminant() {
		return _11 * (_22*_33 - _23*_32) + _12 * (_23*_31 - _21*_33) + _13 * (_21*_32 - _22*_31);
	}

	/**
	 * 计算 3x4 仿射变换矩阵的逆矩阵
	 * 假设矩阵形式为 [R|t]（旋转+平移），没有投影变换
	 * 逆矩阵为 [R^T | -R^T * t]
	 * 比完整 4x4 求逆更高效
	 */
	public function inverse3x4( m : Matrix ) {
		var m11 = m._11, m12 = m._12, m13 = m._13;
		var m21 = m._21, m22 = m._22, m23 = m._23;
		var m31 = m._31, m32 = m._32, m33 = m._33;
		var m41 = m._41, m42 = m._42, m43 = m._43;
		// 计算旋转部分的转置（因为旋转矩阵的逆 = 转置）
		_11 = m22*m33 - m23*m32;
		_12 = m13*m32 - m12*m33;
		_13 = m12*m23 - m13*m22;
		_14 = 0;
		_21 = m23*m31 - m21*m33;
		_22 = m11*m33 - m13*m31;
		_23 = m13*m21 - m11*m23;
		_24 = 0;
		_31 = m21*m32 - m22*m31;
		_32 = m12*m31 - m11*m32;
		_33 = m11*m22 - m12*m21;
		_34 = 0;
		// 计算平移部分的逆：-R^T * t
		_41 = -m21 * m32 * m43 + m21 * m33 * m42 + m31 * m22 * m43 - m31 * m23 * m42 - m41 * m22 * m33 + m41 * m23 * m32;
		_42 = m11 * m32 * m43 - m11 * m33 * m42 - m31 * m12 * m43 + m31 * m13 * m42 + m41 * m12 * m33 - m41 * m13 * m32;
		_43 = -m11 * m22 * m43 + m11 * m23 * m42 + m21 * m12 * m43 - m21 * m13 * m42 - m41 * m12 * m23 + m41 * m13 * m22;
		_44 = m11 * m22 * m33 - m11 * m23 * m32 - m21 * m12 * m33 + m21 * m13 * m32 + m31 * m12 * m23 - m31 * m13 * m22;
		_44 = 1;
		var det = m11 * _11 + m12 * _21 + m13 * _31;
		if(	Math.abs(det) < Math.EPSILON ) {
			zero();
			return;
		}
		var invDet = 1.0 / det;
		_11 *= invDet; _12 *= invDet; _13 *= invDet;
		_21 *= invDet; _22 *= invDet; _23 *= invDet;
		_31 *= invDet; _32 *= invDet; _33 *= invDet;
		_41 *= invDet; _42 *= invDet; _43 *= invDet;
	}

	/**
	 * 计算完整的 4x4 逆矩阵（使用代数余子式法）
	 * @param m 要求逆的矩阵
	 * 如果矩阵奇异（行列式为0），则将矩阵置零
	 * 使用伴随矩阵法：A^(-1) = adj(A) / det(A)
	 */
	public function initInverse( m : Matrix ) {
		var m11 = m._11; var m12 = m._12; var m13 = m._13; var m14 = m._14;
		var m21 = m._21; var m22 = m._22; var m23 = m._23; var m24 = m._24;
		var m31 = m._31; var m32 = m._32; var m33 = m._33; var m34 = m._34;
		var m41 = m._41; var m42 = m._42; var m43 = m._43; var m44 = m._44;

		_11 = m22 * m33 * m44 - m22 * m34 * m43 - m32 * m23 * m44 + m32 * m24 * m43 + m42 * m23 * m34 - m42 * m24 * m33;
		_12 = -m12 * m33 * m44 + m12 * m34 * m43 + m32 * m13 * m44 - m32 * m14 * m43 - m42 * m13 * m34 + m42 * m14 * m33;
		_13 = m12 * m23 * m44 - m12 * m24 * m43 - m22 * m13 * m44 + m22 * m14 * m43 + m42 * m13 * m24 - m42 * m14 * m23;
		_14 = -m12 * m23 * m34 + m12 * m24 * m33 + m22 * m13 * m34 - m22 * m14 * m33 - m32 * m13 * m24 + m32 * m14 * m23;
		_21 = -m21 * m33 * m44 + m21 * m34 * m43 + m31 * m23 * m44 - m31 * m24 * m43 - m41 * m23 * m34 + m41 * m24 * m33;
		_22 = m11 * m33 * m44 - m11 * m34 * m43 - m31 * m13 * m44 + m31 * m14 * m43 + m41 * m13 * m34 - m41 * m14 * m33;
		_23 = -m11 * m23 * m44 + m11 * m24 * m43 + m21 * m13 * m44 - m21 * m14 * m43 - m41 * m13 * m24 + m41 * m14 * m23;
		_24 =  m11 * m23 * m34 - m11 * m24 * m33 - m21 * m13 * m34 + m21 * m14 * m33 + m31 * m13 * m24 - m31 * m14 * m23;
		_31 = m21 * m32 * m44 - m21 * m34 * m42 - m31 * m22 * m44 + m31 * m24 * m42 + m41 * m22 * m34 - m41 * m24 * m32;
		_32 = -m11 * m32 * m44 + m11 * m34 * m42 + m31 * m12 * m44 - m31 * m14 * m42 - m41 * m12 * m34 + m41 * m14 * m32;
		_33 = m11 * m22 * m44 - m11 * m24 * m42 - m21 * m12 * m44 + m21 * m14 * m42 + m41 * m12 * m24 - m41 * m14 * m22;
		_34 =  -m11 * m22 * m34 + m11 * m24 * m32 + m21 * m12 * m34 - m21 * m14 * m32 - m31 * m12 * m24 + m31 * m14 * m22;
		_41 = -m21 * m32 * m43 + m21 * m33 * m42 + m31 * m22 * m43 - m31 * m23 * m42 - m41 * m22 * m33 + m41 * m23 * m32;
		_42 = m11 * m32 * m43 - m11 * m33 * m42 - m31 * m12 * m43 + m31 * m13 * m42 + m41 * m12 * m33 - m41 * m13 * m32;
		_43 = -m11 * m22 * m43 + m11 * m23 * m42 + m21 * m12 * m43 - m21 * m13 * m42 - m41 * m12 * m23 + m41 * m13 * m22;
		_44 = m11 * m22 * m33 - m11 * m23 * m32 - m21 * m12 * m33 + m21 * m13 * m32 + m31 * m12 * m23 - m31 * m13 * m22;

		var det = m11 * _11 + m12 * _21 + m13 * _31 + m14 * _41;
		if(	Math.abs(det) < Math.EPSILON ) {
			zero();
			return;
		}

		det = 1.0 / det;
		_11 *= det;
		_12 *= det;
		_13 *= det;
		_14 *= det;
		_21 *= det;
		_22 *= det;
		_23 *= det;
		_24 *= det;
		_31 *= det;
		_32 *= det;
		_33 *= det;
		_34 *= det;
		_41 *= det;
		_42 *= det;
		_43 *= det;
		_44 *= det;
	}


	public function initInverse3x3( m : Matrix ) {
		var m11 = m._11; var m12 = m._12; var m13 = m._13;
		var m21 = m._21; var m22 = m._22; var m23 = m._23;
		var m31 = m._31; var m32 = m._32; var m33 = m._33;

		_11 = m22 * m33 - m32 * m23;
		_12 = -m12 * m33 + m32 * m13;
		_13 = m12 * m23 - m22 * m13;
		_21 = -m21 * m33 + m31 * m23;
		_22 = m11 * m33 - m31 * m13;
		_23 = -m11 * m23 + m21 * m13;
		_31 = m21 * m32 - m31 * m22;
		_32 = -m11 * m32 + m31 * m12;
		_33 = m11 * m22 - m21 * m12;

		var det = m11 * _11 + m12 * _21 + m13 * _31;
		if(	Math.abs(det) < Math.EPSILON ) {
			zero();
			return;
		}

		det = 1.0 / det;
		_11 *= det;
		_12 *= det;
		_13 *= det;
		_14 = 0;
		_21 *= det;
		_22 *= det;
		_23 *= det;
		_24 = 0;
		_31 *= det;
		_32 *= det;
		_33 *= det;
		_34 = 0;
		_41 = 0;
		_42 = 0;
		_43 = 0;
		_44 = 1;
	}

	public inline function front() {
        var v = new h3d.Vector(_11, _12, _13);
        v.normalize();
        return v;
    }

    public inline function right() {
        var v = new h3d.Vector(_21, _22, _23);
        v.normalize();
        return v;
    }

    public inline function up() {
        var v = new h3d.Vector(_31, _32, _33);
        v.normalize();
        return v;
    }

	public function transpose() {
		var tmp;
		tmp = _12; _12 = _21; _21 = tmp;
		tmp = _13; _13 = _31; _31 = tmp;
		tmp = _14; _14 = _41; _41 = tmp;
		tmp = _23; _23 = _32; _32 = tmp;
		tmp = _24; _24 = _42; _42 = tmp;
		tmp = _34; _34 = _43; _43 = tmp;
	}

	public function clone() {
		var m = new Matrix();
		m._11 = _11; m._12 = _12; m._13 = _13; m._14 = _14;
		m._21 = _21; m._22 = _22; m._23 = _23; m._24 = _24;
		m._31 = _31; m._32 = _32; m._33 = _33; m._34 = _34;
		m._41 = _41; m._42 = _42; m._43 = _43; m._44 = _44;
		return m;
	}

	public function load( m : Matrix ) {
		_11 = m._11; _12 = m._12; _13 = m._13; _14 = m._14;
		_21 = m._21; _22 = m._22; _23 = m._23; _24 = m._24;
		_31 = m._31; _32 = m._32; _33 = m._33; _34 = m._34;
		_41 = m._41; _42 = m._42; _43 = m._43; _44 = m._44;
	}

	public function loadValues( a : Array<Float> ) {
		_11 = a[0]; _12 = a[1]; _13 = a[2]; _14 = a[3];
		_21 = a[4]; _22 = a[5]; _23 = a[6]; _24 = a[7];
		_31 = a[8]; _32 = a[9]; _33 = a[10]; _34 = a[11];
		_41 = a[12]; _42 = a[13]; _43 = a[14]; _44 = a[15];
	}

	public function getFloats() {
		return [_11, _12, _13, _14, _21, _22, _23, _24, _31, _32, _33, _34, _41, _42, _43, _44];
	}

	public function getDirection() {
		var q = new h3d.Quat();
		q.initRotateMatrix(this);
		q.normalize();
		return q.getDirection();
	}

	/**
		Extracts Euler rotation angles from rotation matrix
	**/
	public function getEulerAngles() {
		var m = this.clone();
		var s = this.getScale();
		m.prependScale(1.0 / s.x, 1.0 / s.y, 1.0 / s.z);
		var cy = hxd.Math.sqrt(m._11 * m._11 + m._12 * m._12);
		if(cy > 0.01) {
			var v1 = new h3d.Vector(
				hxd.Math.atan2(m._23, m._33),
				hxd.Math.atan2(-m._13, cy),
				hxd.Math.atan2(m._12, m._11));

			var v2 = new h3d.Vector(
				hxd.Math.atan2(-m._23, -m._33),
				hxd.Math.atan2(-m._13, -cy),
				hxd.Math.atan2(-m._12, -m._11));

			return v1.lengthSq() < v2.lengthSq() ? v1 : v2;
		}
		else {
			return new h3d.Vector(
				hxd.Math.atan2(-m._32, m._22),
				hxd.Math.atan2(-m._13, cy),
				0.0);
		}
	}

	public function toString() {
		return "MAT=[\n" +
			"  [ " + Math.fmt(_11) + ", " + Math.fmt(_12) + ", " + Math.fmt(_13) + ", " + Math.fmt(_14) + " ]\n" +
			"  [ " + Math.fmt(_21) + ", " + Math.fmt(_22) + ", " + Math.fmt(_23) + ", " + Math.fmt(_24) + " ]\n" +
			"  [ " + Math.fmt(_31) + ", " + Math.fmt(_32) + ", " + Math.fmt(_33) + ", " + Math.fmt(_34) + " ]\n" +
			"  [ " + Math.fmt(_41) + ", " + Math.fmt(_42) + ", " + Math.fmt(_43) + ", " + Math.fmt(_44) + " ]\n" +
		"]";
	}

	// ==================== 颜色矩阵函数 ====================
	// 这些函数用于颜色调整，广泛应用于图像后处理
	// 使用 3x4 矩阵实现颜色空间的线性变换

	// 亮度（Luminance）系数，用于将 RGB 转换为灰度
	// 基于人眼对不同颜色敏感度的标准权重
	static inline var lumR = 0.212671;  // 红色通道亮度权重
	static inline var lumG = 0.71516;   // 绿色通道亮度权重（人眼最敏感）
	static inline var lumB = 0.072169;  // 蓝色通道亮度权重

	static inline var SQ13 = 0.57735026918962576450914878050196; // sqrt(1/3)

	/**
	 * 色相旋转（Hue Rotation）
	 * 在 RGB 颜色空间中绕中性轴旋转，通过将颜色投影到 RG 平面实现
	 * @param hue 色相偏移角度（弧度）
	 */
	public function colorHue( hue : Float ) {
		if( hue == 0. )
			return;

		var cosA = Math.cos(-hue);
		var sinA = Math.sin(-hue);
		var ch = (1 - cosA) / 3;

		var tmp = tmp;
		tmp._11 = cosA + ch;
		tmp._12 = ch - SQ13 * sinA;
		tmp._13 = ch + SQ13 * sinA;
		tmp._21 = ch + SQ13 * sinA;
		tmp._22 = cosA + ch;
		tmp._23 = ch - SQ13 * sinA;
		tmp._31 = ch - SQ13 * sinA;
		tmp._32 = ch + SQ13 * sinA;
		tmp._33 = cosA + ch;

		tmp._34 = 0;
		tmp._41 = 0;
		tmp._42 = 0;
		tmp._43 = 0;
		multiply3x4(this, tmp);
	}

	/**
	 * 饱和度调整（Saturation）
	 * @param sat 饱和度偏移量（-1 ~ 0 ~ 正数，0为原始饱和度）
	 * 通过线性插值在原始颜色和灰度之间切换
	 */
	public function colorSaturate( sat : Float ) {
		sat += 1;
		var ins = 1 - sat;
		var r = ins * lumR;
		var g = ins * lumG;
		var b = ins * lumB;
		var tmp = tmp;
		tmp._11 = r + sat;
		tmp._12 = r;
		tmp._13 = r;
		tmp._21 = g;
		tmp._22 = g + sat;
		tmp._23 = g;
		tmp._31 = b;
		tmp._32 = b;
		tmp._33 = b + sat;
		tmp._41 = 0;
		tmp._42 = 0;
		tmp._43 = 0;
		multiply3x4(this, tmp);
	}

	/**
	 * 对比度调整（Contrast）
	 * @param contrast 对比度偏移量（-1 ~ 0 ~ 1）
	 * 在原始图像和纯灰色（中点）之间插值
	 */
	public function colorContrast( contrast : Float ) {
		var tmp = tmp;
		var v = contrast + 1;
		tmp._11 = v;
		tmp._12 = 0;
		tmp._13 = 0;
		tmp._21 = 0;
		tmp._22 = v;
		tmp._23 = 0;
		tmp._31 = 0;
		tmp._32 = 0;
		tmp._33 = v;
		tmp._41 = -contrast*0.5;
		tmp._42 = -contrast*0.5;
		tmp._43 = -contrast*0.5;
		multiply3x4(this, tmp);
	}

	/**
	 * 亮度调整（Lightness）
	 * 简单地在 RGB 三个通道上添加偏移量
	 * @param lightness 亮度偏移量
	 */
	public function colorLightness( lightness : Float ) {
		_41 += lightness;
		_42 += lightness;
		_43 += lightness;
	}

	/**
	 * 颜色增益（Color Gain）
	 * 在原始颜色和目标颜色之间插值
	 * @param color 目标颜色值（ARGB 格式）
	 * @param alpha 混合系数
	 */
	public function colorGain( color : Int, alpha : Float ) {
		var tmp = tmp;
		tmp._11 = 1 - alpha;
		tmp._12 = 0;
		tmp._13 = 0;
		tmp._21 = 0;
		tmp._22 = 1 - alpha;
		tmp._23 = 0;
		tmp._31 = 0;
		tmp._32 = 0;
		tmp._33 = 1 - alpha;
		tmp._41 = (((color >> 16) & 0xFF) / 255) * alpha;
		tmp._42 = (((color >> 8) & 0xFF) / 255) * alpha;
		tmp._43 = ((color & 0xFF) / 255) * alpha;
		multiply3x4(this, tmp);
	}

	/**
	 * 颜色位通道映射（Color Bits Channel Mapping）
	 * 从 9-bit 位掩码构建 3x3 颜色通道置换矩阵
	 * @param bits 9-bit 掩码，每位表示一个输出通道是否使用对应的输入通道
	 * @param blend 混合系数（0=原始，1=完全置换）
	 */
	public function colorBits( bits : Int, blend : Float ) {
		var t11 = 0., t12 = 0., t13 = 0.;
		var t21 = 0., t22 = 0., t23 = 0.;
		var t31 = 0., t32 = 0., t33 = 0.;
		var c = bits;
		if( c & 1 == 1 ) t11 = 1; c >>= 1;
		if( c & 1 == 1 ) t12 = 1; c >>= 1;
		if( c & 1 == 1 ) t13 = 1; c >>= 1;
		if( c & 1 == 1 ) t21 = 1; c >>= 1;
		if( c & 1 == 1 ) t22 = 1; c >>= 1;
		if( c & 1 == 1 ) t23 = 1; c >>= 1;
		if( c & 1 == 1 ) t31 = 1; c >>= 1;
		if( c & 1 == 1 ) t32 = 1; c >>= 1;
		if( c & 1 == 1 ) t33 = 1; c >>= 1;
		var r = t11 + t21 + t31;
		var g = t12 + t22 + t32;
		var b = t13 + t23 + t33;
		if( r > 1 ) { t11 /= r; t21 /= r; t31 /= r; }
		if( g > 1 ) { t12 /= g; t22 /= g; t32 /= g; }
		if( b > 1 ) { t13 /= b; t23 /= b; t33 /= b; }

		// 将 3x3 置换矩阵乘到当前矩阵上
		var b11 = _11 * t11 + _12 * t21 + _13 * t31;
		var b12 = _11 * t12 + _12 * t22 + _13 * t32;
		var b13 = _11 * t13 + _12 * t23 + _13 * t33;

		var b21 = _21 * t11 + _22 * t21 + _23 * t31;
		var b22 = _21 * t12 + _22 * t22 + _23 * t32;
		var b23 = _21 * t13 + _22 * t23 + _23 * t33;

		var b31 = _31 * t11 + _32 * t21 + _33 * t31;
		var b32 = _31 * t12 + _32 * t22 + _33 * t32;
		var b33 = _31 * t13 + _32 * t23 + _33 * t33;

		// 与原始颜色矩阵混合
		var ik = blend, k = 1 - ik;
		_11 = _11 * k + b11 * ik;
		_12 = _12 * k + b12 * ik;
		_13 = _13 * k + b13 * ik;
		_21 = _21 * k + b21 * ik;
		_22 = _22 * k + b22 * ik;
		_23 = _23 * k + b23 * ik;
		_31 = _31 * k + b31 * ik;
		_32 = _32 * k + b32 * ik;
		_33 = _33 * k + b33 * ik;
	}

	/**
	 * 颜色加法：将指定颜色值的 RGB 分量加到平移分量上
	 * @param c ARGB 颜色值
	 */
	public inline function colorAdd( c : Int ) {
		_41 += ((c >> 16) & 0xFF) / 255;
		_42 += ((c >> 8) & 0xFF) / 255;
		_43 += (c & 0xFF) / 255;
	}

	/**
	 * 设置纯色矩阵：将矩阵设置为单一颜色
	 * @param c ARGB 颜色值
	 * @param alpha 透明度
	 */
	public inline function colorSet( c : Int, alpha = 1. ) {
		zero();
		_44 = alpha;
		colorAdd(c);
	}

	/**
	 * 综合颜色调整函数
	 * 按顺序应用色相、饱和度、对比度、亮度和增益调整
	 */
	public function adjustColor( col : ColorAdjust ) {
		if( col.hue != null ) colorHue(col.hue);
		if( col.saturation != null ) colorSaturate(col.saturation);
		if( col.contrast != null ) colorContrast(col.contrast);
		if( col.lightness != null ) colorLightness(col.lightness);
		if( col.gain != null ) colorGain(col.gain.color, col.gain.alpha);
	}

	/**
	 * 将 3D 矩阵转换为 2D 仿射变换矩阵
	 * 用于 2D 渲染系统中的变换
	 */
	public inline function toMatrix2D( ?m : h2d.col.Matrix ) {
		if( m == null ) m = new h2d.col.Matrix();
		m.a = _11;
		m.b = _12;
		m.c = _21;
		m.d = _22;
		m.x = tx;
		m.y = ty;
		return m;
	}

	// ==================== 动画辅助函数 ====================

	/**
	 * 分解变换矩阵为缩放 + 旋转（四元数）+ 平移
	 * 将旋转部分以四元数形式存储在 [_12,_13,_21,_23] 位置
	 * 缩放存储在对角线 [_11,_22,_33]
	 * 平移存储在 [_41,_42,_43]
	 * 用于动画插值，避免旋转和缩放混合
	 */
	public function decomposeMatrix(inMatrix: h3d.Matrix) {
		this.load(inMatrix);
		var scale = inline this.getScale();
		this.prependScale(1.0/scale.x, 1.0/scale.y, 1.0/scale.z);
		var quat = inline new h3d.Quat();
		inline quat.initRotateMatrix(this);

		this._11 = scale.x;
		this._12 = quat.x;
		this._13 = quat.y;
		this._14 = 0.0;

		this._21 = quat.z;
		this._22 = scale.y;
		this._23 = quat.w;
		this._24 = 0.0;

		this._31 = 0.0;
		this._32 = 0.0;
		this._33 = scale.z;
		this._34 = 0.0;

		this.tx = inMatrix.tx;
		this.ty = inMatrix.ty;
		this.tz = inMatrix.tz;
		this._44 = 1.0;
	}

	/**
	 * 重组变换矩阵：`decomposeMatrix` 的逆操作
	 * 将分解后的矩阵（缩放+四元数+平移）恢复为正常的变换矩阵
	 */
	public function recomposeMatrix(inMatrix: h3d.Matrix) {
		var copy = inline new h3d.Matrix(); // 复制以避免 this 和 inMatrix 重叠
		inline copy.load(inMatrix);

		var quat = inline new h3d.Quat(inMatrix._12, inMatrix._13, inMatrix._21, inMatrix._23);
		inline quat.toMatrix(this);

		this._11 *= copy._11;
		this._12 *= copy._11;
		this._13 *= copy._11;
		this._21 *= copy._22;
		this._22 *= copy._22;
		this._23 *= copy._22;
		this._31 *= copy._33;
		this._32 *= copy._33;
		this._33 *= copy._33;

		this._41 = copy._41;
		this._42 = copy._42;
		this._43 = copy._43;

		this._14 = copy._14;
		this._24 = copy._24;
		this._34 = copy._34;
	}
}


/**
 * 4x4 矩阵的抽象类型
 * 使用 `@:forward` 将所有方法代理到 `MatrixImpl`
 * 这样可以实现值类型语义（轻量级包装），同时支持运算符重载
 */
@:forward abstract Matrix(MatrixImpl) from MatrixImpl to MatrixImpl {

	public inline function new() {
		this = new MatrixImpl();
	}

	// 运算符重载：a * b 执行矩阵乘法
	@:op(a * b) public inline function multiplied( m : Matrix ) {
		var mout = new Matrix();
		mout.multiply(this, m);
		return mout;
	}

	// ==================== 静态工厂方法 ====================

	/** 创建单位矩阵（Identity） */
	public static function I() {
		var m = new Matrix();
		m.identity();
		return m;
	}

	/** 从浮点数数组加载矩阵（Load） */
	public static function L( a : Array<Float> ) {
		var m = new Matrix();
		m.loadValues(a);
		return m;
	}

	/** 创建平移矩阵（Translation） */
	public static function T( x = 0., y = 0., z = 0. ) {
		var m = new Matrix();
		m.initTranslation(x, y, z);
		return m;
	}

	/** 创建欧拉角旋转矩阵（Rotation） */
	public static function R(x,y,z) {
		var m = new Matrix();
		m.initRotation(x,y,z);
		return m;
	}

	/** 创建缩放矩阵（Scale） */
	public static function S( x = 1., y = 1., z = 1.0 ) {
		var m = new Matrix();
		m.initScale(x, y, z);
		return m;
	}

	/**
	 * 构建 Look-At 旋转矩阵
	 * 使 X 轴指向目标方向，Z 轴为 Up 方向（默认 [0,0,1]）
	 * 内联版本，要求所有参数非空
	 * @param dir 目标方向向量（X 轴）
	 * @param up 上方向向量（Z 轴）
	 * @param m 输出矩阵
	 */
	public static inline function lookAtXInline( dir : Vector, up : Vector, m : Matrix ) {
		var ax = dir.normalized();
		var ay = up.cross(ax).normalized();
		if( ay.lengthSq() < Math.EPSILON2 ) {
			// 如果 up 与 dir 平行（叉积为零向量），使用备用向量
			ay.x = ax.y;
			ay.y = ax.z;
			ay.z = ax.x;
		}
		var az = ax.cross(ay);
		m._11 = ax.x;
		m._12 = ax.y;
		m._13 = ax.z;
		m._14 = 0;
		m._21 = ay.x;
		m._22 = ay.y;
		m._23 = ay.z;
		m._24 = 0;
		m._31 = az.x;
		m._32 = az.y;
		m._33 = az.z;
		m._34 = 0;
		m._41 = 0;
		m._42 = 0;
		m._43 = 0;
		m._44 = 1;
		return m;
	}

	/**
	 * 构建 Look-At 旋转矩阵（带可选参数版本）
	 */
	public static function lookAtX( dir : Vector, ?up : Vector, ?m : Matrix ) {
		if( up == null ) up = new Vector(0, 0, 1);
		if( m == null ) m = new Matrix();
		return lookAtXInline(dir, up, m);
	}

	// 分解形式的单位矩阵常量（用于动画系统）
	public static final IDENTITY_DECOMPOSED = h3d.Matrix.L([
		1, 0, 0, 0,
		0, 1, 1, 0,
		0, 0, 1, 0,
		0, 0, 0, 1,
	]);
}