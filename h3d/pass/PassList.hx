package h3d.pass;

/**
 * PassList 迭代器
 * 遍历 PassObject 链表
 */
class PassListIterator {
	var o : PassObject;
	public inline function new(o) {
		this.o = o;
	}
	public inline function hasNext() {
		return o != null;
	}
	public inline function next() {
		var tmp = o;
		o = @:privateAccess o.next;
		return tmp;
	}
}

/**
 * 渲染通道列表（Pass List）
 *
 * 管理物体的渲染通道（Pass）链表，支持：
 * - 通道过滤和排序
 * - 临时丢弃通道并恢复（save/load 机制）
 * - 惰性求值（通过 SortByMaterial 排序器）
 *
 * 工作流程：
 * 1. 物体注册渲染通道到 PassList
 * 2. 根据材质对通道进行排序
 * 3. 遍历排序后的通道执行渲染
 * 4. 不支持当前帧的通道被丢弃（放入 discarded 列表）
 * 5. 下一帧通过 reset() 恢复丢弃的通道
 */
@:access(h3d.pass.PassObject)
class PassList {

	var current : PassObject;   // 当前链表的头节点
	var discarded : PassObject; // 被丢弃的通道链表头
	var lastDisc : PassObject;  // 被丢弃的通道链表尾

	public function new(?current) {
		init(current);
	}

	/**
	 * 初始化通道列表，清空丢弃列表
	 */
	public inline function init(pass) {
		current = pass;
		discarded = lastDisc = null;
	}

	/**
	 * 将丢弃的通道恢复回通道列表
	 * 用于下一帧的渲染
	 */
	public inline function reset() {
		if( discarded != null ) {
			lastDisc.next = current;
			current = discarded;
			discarded = lastDisc = null;
		}
	}

	/** 返回通道数量 */
	public inline function count() {
		var c = current;
		var n = 0;
		while( c != null ) {
			n++;
			c = c.next;
		}
		return n;
 	}

	/**
	 * 保存当前状态（记录丢弃列表的末尾）
	 * 允许进行一些过滤操作后，通过 load() 恢复
	 */
	public inline function save() {
		return lastDisc;
	}

	/**
	 * 恢复到之前 save() 保存的状态
	 */
	public inline function load( p : PassObject ) {
		if( lastDisc != p ) {
			lastDisc.next = current;
			if( p == null ) {
				current = discarded;
				discarded = null;
			} else {
				current = p.next;
				p.next = null;
			}
			lastDisc = p;
		}
	}

	/** 判断通道列表是否为空 */
	public inline function isEmpty() {
		return current == null;
	}

	/**
	 * 将所有通道移动到丢弃列表
	 */
	public function clear() {
		if( current == null )
			return;
		if( discarded == null )
			discarded = current;
		else
			lastDisc.next = current;
		var p = current;
		while( p.next != null ) p = p.next;
		lastDisc = p;
		current = null;
	}

	/**
	 * 对当前通道列表进行排序
	 * @param f 比较函数（类似标准的比较器）
	 */
	public inline function sort( f : PassObject -> PassObject -> Int ) {
		current = haxe.ds.ListSort.sortSingleLinked(current, f);
	}

	/**
	 * 过滤当前通道列表
	 * 满足条件的通道保留在当前列表，不满足的移动到丢弃列表
	 * @param f 过滤函数（返回 true 表示保留）
	 */
	public inline function filter( f : PassObject -> Bool ) {
		var head = null;
		var prev = null;
		var disc = discarded;
		var discQueue = lastDisc;
		var cur = current;
		while( cur != null ) {
			if( f(cur) ) {
				// 保留在当前列表
				if( head == null )
					head = prev = cur;
				else {
					prev.next = cur;
					prev = cur;
				}
			} else {
				// 移动到丢弃列表
				if( disc == null )
					disc = discQueue = cur;
				else {
					discQueue.next = cur;
					discQueue = cur;
				}
			}
			cur = cur.next;
		}
		if( prev != null )
			prev.next = null;
		if( discQueue != null )
			discQueue.next = null;
		current = head;
		discarded = disc;
		lastDisc = discQueue;
	}

	/** 获取迭代器，用于遍历当前通道列表 */
	public inline function iterator() {
		return new PassListIterator(current);
	}

	/**
		* 遍历所有被丢弃的通道元素
	**/
	public inline function getFiltered() {
		return new PassListIterator(discarded);
	}

}