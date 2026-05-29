package h2d.col;

/**
 * 2D 碰撞体基类
 *
 * 2D 形状的通用接口，用于鼠标点击测试或空间碰撞检测。
 *
 * 具体实现包括：
 * - `h2d.col.Circle`：圆形
 * - `h2d.col.Bounds`：AABB 包围盒
 * - `h2d.col.Polygon`：多边形
 * - `h2d.col.Segment`：线段
 */
abstract class Collider {

	/** 测试点 p 是否在碰撞体内部 */
	public abstract function contains( p : Point ) : Bool;
	
	/** 检测是否与圆形碰撞 */
	public abstract function collideCircle( c : Circle ) : Bool;
	
	/** 检测是否与 AABB 包围盒碰撞 */
	public abstract function collideBounds( b : Bounds ) : Bool;

}