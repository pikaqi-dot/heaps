package h3d.col;

/**
 * 碰撞体（Collider）抽象基类
 *
 * 所有碰撞检测形状的基类，定义了统一的碰撞检测接口。
 * 具体实现包括：球体(Sphere)、胶囊体(Capsule)、圆柱体(Cylinder)、
 * 包围盒(Bounds)、多边形(Polygon)等。
 *
 * 功能：
 * - 射线相交检测（拾取）
 * - 点包含检测
 * - 视锥体裁剪
 * - 球体相交检测
 * - 最近点计算
 */
abstract class Collider {

	/**
	 * 计算射线与碰撞体的相交距离
	 * @param r 射线
	 * @param bestMatch 是否查找最近的交点（true=精确最近点，false=仅判断有无相交）
	 * @return 相交距离（负值表示无相交）
	 */
	public abstract function rayIntersection( r : Ray, bestMatch : Bool ) : Float;
	
	/** 判断点是否在碰撞体内部 */
	public abstract function contains( p : Point ) : Bool;
	
	/** 判断碰撞体是否在视锥体内部（用于视锥体裁剪优化） */
	public abstract function inFrustum( f : Frustum, ?localMatrix : h3d.Matrix ) : Bool;
	
	/** 判断碰撞体是否与球体相交 */
	public abstract function inSphere( s : Sphere ) : Bool;
	
	/** 获取碰撞体的特征尺寸（用于空间划分） */
	public abstract function dimension() : Float;
	
	/** 获取碰撞体表面上离给定点最近的点 */
	public abstract function closestPoint( p : Point) : Point;

	#if !macro
	/** 创建调试可视化对象 */
	public abstract function makeDebugObj() : h3d.scene.Object;
	#end
}

/**
 * 优化碰撞体（Optimized Collider）
 *
 * 包含两个碰撞体 a 和 b，其中 a 作为快速粗略检测（如包围盒），
 * b 作为精确检测。只有当 a 检测到相交时，才进行 b 的精确检测。
 * 这可以大幅提高检测性能（先粗筛再精测的经典优化策略）。
 *
 * 可选 checkInside 模式：允许从内部检测
 */
class OptimizedCollider extends Collider {

	public var a : Collider;          // 粗略碰撞体（快速检测）
	public var b : Collider;          // 精确碰撞体
	public var checkInside : Bool;    // 是否检查点位于 a 内部的情况

	public function new(a, b) {
		this.a = a;
		this.b = b;
	}

	/**
	 * 优化射线检测：先检测粗略碰撞体 a
	 * 如果 a 检测通过（或 checkInside 启用且点在 a 内部），
	 * 再进行精确碰撞体 b 的检测
	 */
	public function rayIntersection( r : Ray, bestMatch : Bool ) : Float {
		if( a.rayIntersection(r, false) < 0 ) {
			if( !checkInside )
				return -1;
			if( !a.contains(r.getPoint(0)) )
				return -1;
		}
		return b.rayIntersection(r, bestMatch);
	}

	public function contains( p : Point ) {
		return a.contains(p) && b.contains(p);
	}

	public function inFrustum( f : Frustum, ?m : h3d.Matrix ) {
		return a.inFrustum(f, m) && b.inFrustum(f, m);
	}

	public function inSphere( s : Sphere ) {
		return a.inSphere(s) && b.inSphere(s);
	}

	public function dimension() {
		return Math.max(a.dimension(), b.dimension());
	}

	public function closestPoint( p : h3d.col.Point ) {
		return b.closestPoint(p);
	}

	#if !macro
	public function makeDebugObj() : h3d.scene.Object {
		var bobj = b.makeDebugObj();
		var aobj = a.makeDebugObj();
		if( aobj == null && bobj == null )
			return null;
		var ret = new h3d.scene.Object();
		if( aobj != null )
			ret.addChild(aobj);
		if( bobj != null )
			ret.addChild(bobj);
		return ret;
	}
	#end

}

/**
 * 组合碰撞体（Group Collider）
 *
 * 将多个碰撞体组合成一个集合，进行批量检测。
 * - 射线检测：返回最近的相交距离
 * - 点包含检测：任何一个包含即返回 true
 * - 视锥体/球体检测：任何一个通过即返回 true
 */
class GroupCollider extends Collider {

	public var colliders : Array<Collider>;

	public function new(colliders) {
		this.colliders = colliders;
	}

	/**
	 * 在所有子碰撞体中查找最近的射线交点
	 * bestMatch=true 时返回最近交点，否则返回第一个交点
	 */
	public function rayIntersection( r : Ray, bestMatch : Bool ) : Float {
		var best = -1.;
		for( c in colliders ) {
			var d = c.rayIntersection(r, bestMatch);
			if( d >= 0 ) {
				if( !bestMatch ) return d;
				if( best < 0 || d < best ) best = d;
			}
		}
		return best;
	}

	public function contains( p : Point ) {
		for( c in colliders )
			if( c.contains(p) )
				return true;
		return false;
	}

	public function inFrustum( f : Frustum, ?m : h3d.Matrix) {
		for( c in colliders )
			if( c.inFrustum(f, m) )
				return true;
		return false;
	}

	public function inSphere( s : Sphere ) {
		for( c in colliders )
			if( c.inSphere(s) )
				return true;
		return false;
	}

	public function dimension() {
		var d = Math.NEGATIVE_INFINITY;
		for ( c in colliders ) {
			d = Math.max(d, c.dimension());
		}
		return d;
	}

	/** 在所有子碰撞体中查找距离给定点最近的点 */
	public function closestPoint( p : h3d.col.Point ) {
		var result = null;
		var lengthSq = Math.POSITIVE_INFINITY;
		for ( c in colliders ) {
			var closest = c.closestPoint(p);
			var lSq = closest.distanceSq(p);
			if ( lSq < lengthSq ) {
				result = closest;
				lengthSq = lSq;
			}
		}
		return result;
	}

	#if !macro
	public function makeDebugObj() : h3d.scene.Object {
		var ret : h3d.scene.Object = null;
		for( c in colliders ) {
			var toAdd = c.makeDebugObj();
			if( toAdd == null )
				continue;
			if( ret == null )
				ret = new h3d.scene.Object();
			ret.addChild(toAdd);
		}
		return ret;
	}
	#end

}