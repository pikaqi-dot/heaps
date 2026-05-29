package h3d;
import h3d.mat.Data;

/**
 * 渲染目标栈的临时节点（私有类，对象池复用）
 * 用于管理多层渲染目标（MRT）的压栈/出栈操作
 */
private class TargetTmp {
	public var t : h3d.mat.Texture;          // 目标纹理
	public var textures : Array<h3d.mat.Texture>;  // MRT 多纹理目标
	public var next : TargetTmp;             // 链表中的下一个节点
	public var layer : Int;                  // 纹理层（数组纹理或立方体贴图的面）
	public var mipLevel : Int;               // Mip 层级
	public var depthBinding : DepthBinding;  // 深度缓冲绑定模式
	public function new(t, n, l, m, db) {
		this.t = t;
		this.next = n;
		this.layer = l;
		this.mipLevel = m;
		this.depthBinding = db;
	}
}

/**
 * 深度缓冲绑定模式
 * 控制渲染目标中深度缓冲的访问方式
 */
enum DepthBinding {
	ReadWrite;  // 可读写（默认模式）
	ReadOnly;   // 只读深度
	DepthOnly;  // 仅深度（不绑定颜色缓冲）
	NotBound;   // 不绑定深度缓冲
}

/**
 * 3D 渲染引擎核心类
 * Heaps 引擎的主渲染入口，管理：
 * - 图形驱动（DirectX/OpenGL/Vulkan）
 * - 渲染管线状态
 * - 渲染目标栈
 * - 帧生命周期（begin/end）
 * - 性能统计（FPS、DrawCall、三角形数）
 */
class Engine {
	#if multidriver
	static var ID = 0;
	public var id(default, null) : Int;  // 多驱动模式下的唯一标识
	#end

	/** 底层图形驱动接口（DirectX/OpenGL/Vulkan） */
	public var driver(default,null) : h3d.impl.Driver;

	/** GPU 内存管理器（管理缓冲区和纹理生命周期） */
	public var mem(default,null) : h3d.impl.MemoryManager;

	public var hardware(default, null) : Bool;  // 是否硬件加速
	public var width(default, null) : Int;       // 当前视口宽度
	public var height(default, null) : Int;      // 当前视口高度
	public var debug(default, set) : Bool;       // 调试模式

	// 性能统计
	public var drawTriangles(default, null) : Float;  // 本帧绘制的三角形数
	public var drawCalls(default, null) : Int;         // 本帧的绘制调用次数
	public var dispatches(default, null) : Int;        // 本帧的计算调度次数
	public var shaderSwitches(default, null) : Int;    // 本帧的着色器切换次数

	public var backgroundColor : Null<Int> = 0xFF000000;  // 背景色（ARGB，默认黑色）
	public var autoResize : Bool;           // 是否自动调整大小
	public var fullScreen(default, set) : Bool;  // 全屏模式

	public var fps(get, never) : Float;  // 当前帧率（只读）

	var realFps : Float;        // 实际帧率（平滑后的值）
	var lastTime : Float;       // 上一帧时间戳
	var antiAlias : Int;        // 抗锯齿级别
	var tmpVector = new h3d.Vector4();  // 临时向量，用于颜色转换
	var window : hxd.Window;    // 窗口实例

	// 渲染目标栈管理
	var targetTmp : TargetTmp;           // 目标栈节点对象池
	var targetStack : TargetTmp;         // 当前渲染目标栈顶
	var currentTargetTex : h3d.mat.Texture;  // 当前绑定的渲染目标纹理
	var currentTargetLayer : Int;        // 当前渲染目标层
	var currentTargetMip : Int;          // 当前渲染目标 mip 级别
	var currentDepthBinding : DepthBinding;  // 当前深度绑定模式
	var needFlushTarget : Bool;          // 是否需要刷新渲染目标
	var nullTexture : h3d.mat.Texture;   // 空纹理标记（用于 MRT 模式）
	var textureColorCache = new Map<Int,h3d.mat.Texture>();  // 纯色纹理缓存
	var inRender = false;                // 是否正在渲染帧
	public var ready(default,null) = false;  // 引擎是否已就绪
	@:allow(hxd.res) var resCache = new Map<{},Dynamic>();  // 资源缓存

	public static var SOFTWARE_DRIVER = false;  // 是否使用软件驱动
	public static var ANTIALIASING = 0;         // 默认抗锯齿级别

	/**
	 * 构造函数（私有，通过 hxd.Window 获取实例）
	 * 自动选择可用的图形驱动
	 * 优先级：Vulkan > OpenGL > DirectX12 > DirectX11 > 软件
	 */
	@:access(hxd.Window)
	function new() {
		#if multidriver
		this.id = ID;
		ID++;
		#end
		this.hardware = !SOFTWARE_DRIVER;
		this.antiAlias = ANTIALIASING;
		this.autoResize = true;
		fullScreen = !hxd.System.getValue(IsWindowed);
		window = hxd.Window.getInstance();
		realFps = hxd.System.getDefaultFrameRate();
		lastTime = haxe.Timer.stamp();
		window.addResizeEvent(onWindowResize);
		setCurrent();
		// 根据编译目标选择图形驱动
		#if macro
		driver = new h3d.impl.NullDriver();  // 宏编译时不渲染
		#elseif (js || hlsdl || usegl)
		#if (hlsdl && heaps_vulkan)
		if( hxd.Window.USE_VULKAN )
			driver = new h3d.impl.VulkanDriver();
		else
		#end
		#if js
		driver = js.Browser.supported ? new h3d.impl.GlDriver(antiAlias) : new h3d.impl.NullDriver();
		#else
		driver = new h3d.impl.GlDriver(antiAlias);
		#end
		#elseif (hldx && dx12)
		driver = new h3d.impl.DX12Driver();  // DirectX 12
		#elseif hldx
		driver = new h3d.impl.DirectXDriver();  // DirectX 11
		#elseif usesys
		driver = new haxe.GraphicsDriver(antiAlias);  // 系统图形
		#else
		#if sys Sys.println #else trace #end("没有可用的图形驱动。" #if hl + " 编译时使用 -lib hlsdl 或 -lib hldx" #end);
		#end
	}

	static var CURRENT : Engine = null;  // 当前活动的引擎实例

	/** 设置图形驱动（可在初始化后替换） */
	public function setDriver(d) {
		driver = d;
		if( mem != null ) mem.driver = d;
	}

	/** 获取当前活动的引擎实例 */
	public static inline function getCurrent() {
		return CURRENT;
	}

	/** 设置为当前引擎实例 */
	public inline function setCurrent() {
		CURRENT = this;
		window.setCurrent();
	}

	/** 初始化引擎，创建驱动资源 */
	public function init() {
		driver.init(onCreate, !hardware);
	}

	/** 获取驱动名称 */
	public function driverName(details=false) {
		return driver.getDriverName(details);
	}

	/**
	 * 选择着色器
	 * 如果切换到不同的着色器，会递增着色器切换计数
	 */
	public function selectShader( shader : hxsl.RuntimeShader ) {
		flushTarget();
		if( driver.selectShader(shader) )
			shaderSwitches++;
	}

	/** 选择材质通道 */
	public function selectMaterial( pass : h3d.mat.Pass ) {
		driver.selectMaterial(pass);
	}

	/**
	 * 上传实例着色器缓冲
	 * 将所有类型的缓冲（参数、纹理、通用缓冲）批量上传到 GPU
	 */
	public function uploadInstanceShaderBuffers(buffers) {
		driver.flushShaderBuffers();
		driver.uploadShaderBuffers(buffers, Params);
		driver.uploadShaderBuffers(buffers, Textures);
		driver.uploadShaderBuffers(buffers, Buffers);
	}

	/** 上传指定类型的着色器缓冲 */
	public function uploadShaderBuffers(buffers, which) {
		driver.uploadShaderBuffers(buffers, which);
	}

	/** 选择顶点缓冲区（内部方法） */
	function selectBuffer( buf : Buffer ) {
		if( buf.isDisposed() )
			return false;
		flushTarget();
		driver.selectBuffer(buf);
		return true;
	}

	/** 使用预分配的三角形索引渲染缓冲区 */
	public inline function renderTriBuffer( b : Buffer, start = 0, max = -1 ) {
		return renderBuffer(b, mem.getTriIndexes(b.vertices), 3, start, max);
	}

	/** 使用预分配的四边形索引渲染缓冲区 */
	public inline function renderQuadBuffer( b : Buffer, start = 0, max = -1 ) {
		return renderBuffer(b, mem.getQuadIndexes(b.vertices), 2, start, max);
	}

	/**
	 * 通用缓冲区渲染（使用预分配索引）
	 * 预分配的索引存储在内存管理器中，避免重复创建索引缓冲
	 */
	function renderBuffer( b : Buffer, indexes : Indexes, vertPerTri : Int, startTri = 0, drawTri = -1 ) {
		if( indexes.isDisposed() )
			return;
		var ntri = Std.int(b.vertices / vertPerTri);
		if( drawTri < 0 )
			drawTri = ntri - startTri;
		if( startTri < 0 || drawTri < 0 || startTri + drawTri > ntri )
			throw "顶点数无效";
		if( drawTri > 0 && selectBuffer(b) ) {
			// 乘以 3 是因为索引始终以 3 的倍数寻址
			driver.draw(indexes, startTri * 3, drawTri);
			drawTriangles += drawTri;
			drawCalls++;
		}
	}

	/**
	 * 使用自定义索引渲染
	 * 三角形数 = 索引数 / 3
	 */
	public function renderIndexed( b : Buffer, indexes : Indexes, startTri = 0, drawTri = -1 ) {
		if( indexes.isDisposed() )
			return;
		var maxTri = Std.int(indexes.count / 3);
		if( drawTri < 0 ) drawTri = maxTri - startTri;
		if( drawTri > 0 && selectBuffer(b) ) {
			driver.draw(indexes, startTri * 3, drawTri);
			drawTriangles += drawTri;
			drawCalls++;
		}
	}

	/**
	 * 渲染多缓冲区（多顶点流）
	 * 用于需要多个不同格式的顶点缓冲区的场景
	 */
	public function renderMultiBuffers( format : hxd.BufferFormat.MultiFormat, buffers : Array<Buffer>, indexes : Indexes, startTri = 0, drawTri = -1 ) {
		var maxTri = Std.int(indexes.count / 3);
		if( maxTri <= 0 ) return;
		flushTarget();
		driver.selectMultiBuffers(format, buffers);
		if( indexes.isDisposed() )
			return;
		if( drawTri < 0 ) drawTri = maxTri - startTri;
		if( drawTri > 0 ) {
			driver.draw(indexes, startTri * 3, drawTri);
			drawTriangles += drawTri;
			drawCalls++;
		}
	}

	/**
	 * 实例化渲染（Instanced Rendering）
	 * 使用间接绘制命令高效渲染大量相同几何体的实例
	 */
	public function renderInstanced( indexes : Indexes, commands : h3d.impl.InstanceBuffer ) {
		if( indexes.isDisposed() )
			return;
		if( commands.commandCount > 0 ) {
			driver.drawInstanced(indexes, commands);
			drawTriangles += commands.triCount;
			drawCalls++;
		}
	}

	function set_debug(d) {
		debug = d;
		driver.setDebug(debug);
		return d;
	}

	/**
	 * 驱动创建完成回调
	 * @param disposed 是否因上下文丢失而重新创建
	 */
	function onCreate( disposed ) {
		setCurrent();
		if( autoResize ) {
			width = window.width;
			height = window.height;
		}
		if( disposed ) {
			// 上下文丢失后的恢复
			hxd.impl.Allocator.get().onContextLost();
			mem.onContextLost();
		} else {
			mem = new h3d.impl.MemoryManager(driver);
			mem.init();
			nullTexture = new h3d.mat.Texture(0, 0, [NoAlloc]);
		}
		hardware = driver.hasFeature(HardwareAccelerated);
		set_debug(debug);
		set_fullScreen(fullScreen);
		resize(width, height);
		if( disposed )
			onContextLost();
		else
			onReady();
		ready = true;
	}

	/** 上下文丢失回调（动态函数，可覆盖） */
	public dynamic function onContextLost() {
	}

	/** 引擎就绪回调（动态函数，可覆盖） */
	public dynamic function onReady() {
	}

	/** 窗口大小变化事件处理 */
	function onWindowResize() {
		if( autoResize && !driver.isDisposed() ) {
			var w = window.width, h = window.height;
			if( w != width || h != height )
				resize(w, h);
			onResized();
		}
	}

	function set_fullScreen(v) {
		fullScreen = v;
		if( mem != null && hxd.System.getValue(IsWindowed) ) {
			window.displayMode = v ? Borderless : Windowed;
		}
		return v;
	}

	/** 窗口大小改变回调（动态函数，可覆盖） */
	public dynamic function onResized() {
	}

	/** 调整渲染分辨率 */
	public function resize(width, height) {
		if( width < 32 ) width = 32;
		if( height < 32 ) height = 32;
		this.width = width;
		this.height = height;
		if( !driver.isDisposed() ) driver.resize(width, height);
	}

	/**
	 * 开始新帧
	 * 重置性能计数器，清空渲染目标栈，清空背景色
	 * @return 如果驱动已销毁则返回 false
	 */
	public function begin() {
		if( driver.isDisposed() )
			return false;
		inRender = true;
		drawTriangles = 0;
		shaderSwitches = 0;
		drawCalls = 0;
		dispatches = 0;
		targetStack = null;
		needFlushTarget = currentTargetTex != null;
		#if (usesys && !macro)
		haxe.System.beginFrame();
		#end
		mem.beginFrame();
		driver.begin(hxd.Timer.frameCount);
		if( backgroundColor != null ) clear(backgroundColor, 1, 0);
		return true;
	}

	/** 检查驱动是否支持指定功能 */
	public function hasFeature(f) {
		return driver.hasFeature(f);
	}

	/** 结束当前帧 */
	public function end() {
		inRender = false;
		driver.end();
	}

	/** 获取当前渲染目标的纹理（栈顶） */
	public function getCurrentTarget() {
		return targetStack == null ? null : targetStack.t == nullTexture ? targetStack.textures[0] : targetStack.t;
	}

	/**
	 * 压入渲染目标
	 * @param tex 目标纹理
	 * @param layer 纹理层/面索引
	 * @param mipLevel mip 级别
	 * @param depthBinding 深度绑定模式
	 */
	public function pushTarget( tex : h3d.mat.Texture, layer = 0, mipLevel = 0, depthBinding = ReadWrite ) {
		var c = targetTmp;
		if( c == null )
			c = new TargetTmp(tex, targetStack, layer, mipLevel, depthBinding);
		else {
			// 从对象池中重用节点
			targetTmp = c.next;
			c.t = tex;
			c.next = targetStack;
			c.mipLevel = mipLevel;
			c.layer = layer;
			c.depthBinding = depthBinding;
		}
		targetStack = c;
		updateNeedFlush();
	}

	/** 检查是否需要刷新渲染目标状态 */
	function updateNeedFlush() {
		var t = targetStack;
		if( t == null )
			needFlushTarget = currentTargetTex != null;
		else
			needFlushTarget = currentTargetTex != t.t || currentTargetLayer != t.layer || currentTargetMip != t.mipLevel || t.textures != null || currentDepthBinding != t.depthBinding;
	}

	/**
	 * 压入多个渲染目标（MRT - Multiple Render Targets）
	 * 用于同时渲染到多个颜色缓冲
	 */
	public function pushTargets( textures : Array<h3d.mat.Texture>, depthBinding = ReadWrite ) {
		pushTarget(nullTexture, depthBinding);
		targetStack.textures = textures;
		needFlushTarget = true;
	}

	/** 仅绑定深度缓冲（用于深度渲染通道） */
	public function pushDepth( depthBuffer : h3d.mat.Texture ) {
		pushTarget(depthBuffer, DepthOnly);
	}

	/** 弹出渲染目标 */
	public function popTarget() {
		var c = targetStack;
		if( c == null )
			throw "popTarget() 没有匹配的 pushTarget()";
		targetStack = c.next;
		updateNeedFlush();
		// 回收节点到对象池
		c.t = null;
		c.textures = null;
		c.next = targetTmp;
		targetTmp = c;
	}

	/** 惰性刷新渲染目标（只在需要时执行） */
	inline function flushTarget() {
		if( needFlushTarget ) doFlushTarget();
	}

	/** 执行渲染目标刷新 */
	function doFlushTarget() {
		var t = targetStack;
		if( t == null ) {
			driver.setRenderTarget(null);  // 恢复到默认帧缓冲
			currentTargetTex = null;
		} else {
			if ( t.depthBinding == DepthOnly )
				driver.setDepth(t.t);
			else if( t.textures != null )
				driver.setRenderTargets(t.textures, t.depthBinding);
			else
				driver.setRenderTarget(t.t, t.layer, t.mipLevel, t.depthBinding);
			currentTargetTex = t.t;
			currentTargetLayer = t.layer;
			currentTargetMip = t.mipLevel;
			currentDepthBinding = t.depthBinding;
		}
		needFlushTarget = false;
	}

	/**
	 * 清屏（使用浮点颜色值）
	 * @param color RGBA 浮点颜色
	 * @param depth 深度缓冲清除值
	 * @param stencil 模板缓冲清除值
	 */
	public function clearF( color : h3d.Vector4, ?depth : Float, ?stencil : Int ) {
		flushTarget();
		driver.clear(color, depth, stencil);
	}

	/**
	 * 清屏（使用整数颜色值）
	 * @param color ARGB 颜色值
	 * @param depth 深度缓冲清除值
	 * @param stencil 模板缓冲清除值
	 */
	public function clear( ?color : Int, ?depth : Float, ?stencil : Int ) {
		if( color != null )
			tmpVector.setColor(color);
		flushTarget();
		driver.clear(color == null ? null : tmpVector, depth, stencil);
	}

	/**
	 * 设置裁剪区域（Scissor Test）
	 * 只渲染指定矩形区域内的像素
	 * 调用时不给参数则重置为完整视口
	 */
	public function setRenderZone( x = 0, y = 0, width = -1, height = -1 ) : Void {
		flushTarget();
		driver.setRenderZone(x, y, width, height);
	}

	/**
	 * 渲染一帧
	 * @param obj 包含 render 方法的渲染对象
	 * @return 是否成功
	 */
	public function render( obj : { function render( engine : Engine ) : Void; } ) {
		if( !begin() ) return false;
		obj.render(this);
		end();

		// 更新 FPS 计算（指数平滑）
		var delta = haxe.Timer.stamp() - lastTime;
		lastTime += delta;
		if( delta > 0 ) {
			var curFps = 1. / delta;
			if( curFps > realFps * 2 ) curFps = realFps * 2 else if( curFps < realFps * 0.5 ) curFps = realFps * 0.5;
			var f = delta / .5;
			if( f > 0.3 ) f = 0.3;
			realFps = realFps * (1 - f) + curFps * f;
		}
		return true;
	}

	/** 设置深度钳制（用于阴影渲染等） */
	public function setDepthClamp( enabled : Bool ) {
		driver.setDepthClamp(enabled);
	}

	/** 设置深度偏移（用于阴影映射等，防止自阴影） */
	public function setDepthBias( depthBias : Float, slopeScaledBias : Float ) {
		driver.setDepthBias( depthBias, slopeScaledBias );
	}

	/** 释放引擎资源 */
	public function dispose() {
		driver.dispose();
		window.removeResizeEvent(onWindowResize);
		if ( mem != null )
			mem.dispose();
		#if multidriver
		for ( r in resCache ) {
			var resource = Std.downcast(r, hxd.res.Resource);
			if ( resource != null ) {
				resource.entry.unwatch(id);
			}
		}
		#end
	}

	/** 获取经过平滑的 FPS 值 */
	function get_fps() {
		return Math.ceil(realFps * 100) / 100;
	}

}
