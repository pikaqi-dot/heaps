package h3d.mat;
import h3d.mat.Data;
import h3d.mat.Pass;

/**
 * 材质基类（Base Material）
 *
 * 材质是渲染状态和着色器的组合。一个材质包含多个 Pass（通道），
 * 每个 Pass 包含一个或多个 Shader。
 *
 * 材质 → Pass(es) → Shader(s) → GPU 渲染
 *
 * Pass 使用链表（nextPass）连接，材质维护头节点。
 * 继承自 hxd.impl.AnyProps，支持任意属性（通过 props 动态访问）。
 */
class BaseMaterial extends hxd.impl.AnyProps {

	var passes : Pass;           // Pass 链表头
	public var name : String;    // 材质名称
	public var mainPass(get, never) : Pass;  // 主通道（链表头）

	/**
	 * 创建材质
	 * @param shader 可选，初始着色器
	 */
	function new(?shader:hxsl.Shader) {
		if( shader != null )
			addPass(new Pass("default", null)).addShader(shader);
	}

	/**
	 * 添加渲染通道
	 * 按顺序添加到链表末尾
	 */
	public function addPass<T:Pass>( p : T ) : T {
		var prev = null, cur = passes;
		while( cur != null ) {
			prev = cur;
			cur = cur.nextPass;
		}
		if( prev == null )
			passes = p;
		else
			prev.nextPass = p;
		p.nextPass = null;
		return p;
	}

	/**
	 * 移除渲染通道
	 * 从链表中删除指定 Pass
	 */
	public function removePass( p : Pass ) {
		var prev : Pass = null, cur = passes;
		while( cur != null ) {
			if( cur == p ) {
				if( prev == null )
					passes = p.nextPass;
				else
					prev.nextPass = p.nextPass;
				p.nextPass = null;
				return true;
			}
			prev = cur;
			cur = cur.nextPass;
		}
		return false;
	}

	inline function get_mainPass() {
		return passes;
	}

	/** 获取所有 Pass */
	public function getPasses() {
		var p = passes;
		var out = [];
		while( p != null ) {
			out.push(p);
			p = p.nextPass;
		}
		return out;
	}

	/** 按名称查找 Pass */
	public function getPass( name : String ) : Pass {
		var p = passes;
		while( p != null ) {
			if( p.name == name )
				return p;
			p = p.nextPass;
		}
		return null;
	}

	/**
	 * 分配或获取指定名称的 Pass
	 * 如果不存在则创建新的
	 * @param inheritMain 是否继承主通道的属性
	 */
	public function allocPass( name : String, ?inheritMain = true ) : Pass {
		var p = getPass(name);
		if( p != null ) return p;
		var p = new Pass(name, null, inheritMain ? mainPass : null);
		if( inheritMain && mainPass != null ) p.batchMode = mainPass.batchMode;
		addPass(p);
		return p;
	}

	/**
	 * 克隆材质
	 * @param m 可选的目标材质（复用已有对象）
	 */
	public function clone( ?m : BaseMaterial ) : BaseMaterial {
		if( m == null ) m = new BaseMaterial();
		m.mainPass.load(mainPass);
		// 注意：不克隆 Pass，由子类负责重建 Pass 和着色器
		m.name = name;
		m.props = props;
		return m;
	}

}