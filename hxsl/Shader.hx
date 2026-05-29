package hxsl;
using hxsl.Ast;

/**
 * 着色器参数缓冲类型
 * HL 目标使用 hl.BytesAccess<hl.F32>（高效字节访问）
 * 其他目标使用 ShaderBufferData（通用着色器缓冲数据）
 */
typedef ShaderParamBuffer = #if hl hl.BytesAccess<hl.F32> #else h3d.shader.Buffers.ShaderBufferData #end;

/**
 * 着色器基类
 *
 * Heaps 着色器系统的核心类。所有自定义着色器都继承自此类。
 * 使用 `@:autoBuild(hxsl.Macros.buildShader())` 在编译时自动生成着色器代码。
 *
 * 工作流程：
 * 1. 宏在编译时解析 HXSL 着色器源代码（SRC）
 * 2. 生成共享的 SharedShader 实例（包含编译后的着色器数据）
 * 3. 每个 Shader 实例管理自身参数和常量状态
 * 4. 通过 constBits 位掩码实现高效常量状态跟踪
 */
@:autoBuild(hxsl.Macros.buildShader())
class Shader {

	/** 着色器优先级（用于排序），应在添加到材质前设置 */
	public var priority(default,null) : Int = 0;
	
	var shader : SharedShader;           // 共享着色器数据（编译后的 HXSL）
	var instance : SharedShader.ShaderInstance;  // 当前常量的着色器实例
	var constBits : Int;                 // 常量位掩码（跟踪哪些常量已修改）
	var constModified : Bool;            // 常量是否已修改标志

	public function new() {
		initialize();
	}

	/**
	 * 初始化着色器
	 * 从运行时类中查找编译时生成的 SharedShader
	 * 如果未找到，则从 SRC 编译新着色器
	 */
	function initialize() {
		constModified = true;
		if( shader != null )
			return;
		var cl : Dynamic = std.Type.getClass(this);
		shader = cl._SHADER;
		if( shader == null ) {
			var curClass : Dynamic = cl;
			while( curClass != null && curClass.SRC == null )
				curClass = std.Type.getSuperClass(curClass);
			if( curClass == null )
				throw std.Type.getClassName(cl) + " 没有着色器源代码";
			shader = curClass._SHADER;
			if( shader == null ) {
				shader = new SharedShader(curClass.SRC, curClass._MODULE);
				curClass._SHADER = shader;
			}
		}
	}

	/**
	 * 设置着色器优先级
	 * 优先级应在着色器添加到材质之前设置
	 */
	public function setPriority(v) {
		priority = v;
	}

	/**
	 * 获取着色器参数值（按索引）
	 * 将在子类中自动生成实现
	 */
	public function getParamValue( index : Int ) : Dynamic {
		throw "assert"; // 将在子类着色器中自动实现
		return null;
	}

	/**
	 * 获取浮点参数值（按索引）
	 * 将在子类中自动生成实现
	 */
	public function getParamFloatValue( index : Int ) : Float {
		throw "assert";
		return 0.;
	}

	/**
	 * 设置着色器参数值（按索引）
	 * 将在子类中自动生成实现
	 */
	public function setParamIndexValue( index : Int, val : Dynamic ) {
		throw "assert";
	}

	/**
	 * 设置浮点参数值（按索引）
	 * 将在子类中自动生成实现
	 */
	public function setParamIndexFloatValue( index : Int, val : Float ) {
		throw "assert";
	}

	/**
	 * 将着色器参数写入参数缓冲
	 * @param index 参数索引
	 * @param type 参数类型
	 * @param out 输出缓冲
	 * @param pos 写入位置
	 */
	public function writeParam( index : Int, type : hxsl.Ast.Type, out : ShaderParamBuffer, pos : Int ) {
		h3d.impl.RenderContext.fillRec(getParamValue(index), type, out, pos);
	}

	/**
	 * 更新着色器全局常量
	 * 将在子类中自动生成实现
	 */
	public function updateConstants( globals : Globals ) {
		throw "assert";
	}

	/**
	 * 最终的常量更新实现
	 * 计算 constBits 位掩码，获取对应的着色器实例
	 *
	 * 常量类型处理：
	 * - TInt：整数常量，偏移后存储到 constBits
	 * - TBool：布尔常量，直接存储位
	 * - TChannel：纹理通道选择，编码纹理 ID 和通道选择
	 */
	function updateConstantsFinal( globals : Globals ) {
		var c = shader.consts;
		while( c != null ) {
			if( c.globalId == 0 ) {
				c = c.next;
				continue;
			}
			var v : Dynamic = globals.fastGet(c.globalId);
			switch( c.v.type ) {
			case TInt:
				var v : Int = v;
				if( v >>> c.bits != 0 ) throw "常量 " + c.v.name + " 超出范围 (" + v + " > " + ((1 << c.bits) - 1) + ")";
				constBits |= v << c.pos;
			case TBool:
				var v : Bool = v;
				if( v ) constBits |= 1 << c.pos;
			case TChannel(count):
				if( v == null ) {
					c = c.next;
					continue;
				}
				var v : hxsl.ChannelTexture = v;
				var sel = v.channel;
				if( v.texture == null )
					sel = Unknown
				else if( sel == null || sel == Unknown ) {
					switch( count ) {
					case 1 if( hxsl.Types.ChannelTools.isPackedFormat(v.texture) ): sel = PackedFloat;
					case 3 if( hxsl.Types.ChannelTools.isPackedFormat(v.texture) ): sel = PackedNormal;
					default:
						throw "常量 " + c.v.name + " 未定义通道选择值";
					}
				}
				constBits |= ((globals.allocChannelID(v.texture) << 3) | sel.getIndex()) << c.pos;
			default:
				throw "assert";
			}
			c = c.next;
		}
		instance = shader.getInstance(constBits);
	}

	/**
	 * 克隆着色器
	 * 默认返回自身（共享实例），需要深拷贝的子类应重写此方法
	 */
	public function clone() : Shader {
		return this;
	}

	/** 返回着色器的类名 */
	public function toString() {
		return std.Type.getClassName(std.Type.getClass(this));
	}

}