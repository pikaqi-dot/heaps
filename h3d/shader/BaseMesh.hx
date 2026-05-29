package h3d.shader;

/**
 * 基础网格着色器（Base Mesh Shader）
 *
 * Heaps 引擎中最核心的 HXSL 着色器，所有 3D 网格渲染都基于此着色器。
 * 这是一个 HXSL（Heaps Shading Language）着色器示例，展示了：
 *
 * 1. 全局变量（@global）：相机参数、全局时间、模型视图矩阵等
 * 2. 输入变量（@input）：顶点位置、法线
 * 3. 输出变量：裁剪空间位置、颜色、深度、法线、运动向量
 * 4. 参数（@param）：颜色、高光参数
 * 5. 着色器阶段：vertex（顶点）、fragment（片段）、__init__（初始化）
 *
 * HXSL 语法说明：
 * - Vec3/Vec4/Mat4 等是 HXSL 内置类型
 * - @global 表示全局统一变量（由引擎自动填充）
 * - @param 表示着色器参数（可在 Haxe 代码中设置）
 * - @perObject 表示每个对象的独立数据
 * - @range(min,max) 用于参数范围限制
 */
class BaseMesh extends hxsl.Shader {

	static var SRC = {

		// ===== 全局相机参数 =====
		@global var camera : {
			var view : Mat4;                     // 视图矩阵
			var proj : Mat4;                     // 投影矩阵
			var position : Vec3;                 // 相机世界位置
			var projFlip : Float;                // 投影翻转（OpenGL/DirectX 坐标系差异）
			var projDiag : Vec3;                 // 投影对角线
			var viewProj : Mat4;                 // 视图*投影矩阵（组合矩阵）
			var previousViewProj : Mat4;         // 上一帧的视图*投影矩阵（用于运动向量计算）
			var inverseViewProj : Mat4;          // 视图*投影的逆矩阵
			var zNear : Float;                   // 近裁剪面
			var zFar : Float;                    // 远裁剪面
			@var var dir : Vec3;                 // 相机方向（由 __init__ 计算）
			var jitterOffsets : Vec4;            // 抖动偏移（TAA 抗锯齿用）
		};

		// ===== 全局场景参数 =====
		@global var global : {
			var time : Float;                    // 运行时间
			var pixelSize : Vec2;                // 像素大小
			@perObject var modelView : Mat4;     // 每个对象的模型视图矩阵
			@perObject var modelViewInverse : Mat4;  // 模型视图逆矩阵
			@perObject var previousModelView : Mat4; // 上一帧的模型视图矩阵
		};

		// ===== 顶点输入 =====
		@input var input : {
			var position : Vec3;  // 顶点位置（模型空间）
			var normal : Vec3;    // 顶点法线（模型空间）
		};

		// ===== 渲染输出（MRT 多渲染目标） =====
		var output : {
			var position : Vec4;  // 裁剪空间位置（必须）
			var color : Vec4;     // 最终颜色
			var depth : Float;    // 深度值
			var normal : Vec3;    // 世界空间法线
			var worldDist : Float; // 世界空间距离
			var velocity : Vec2;  // 屏幕空间运动向量（用于运动模糊/TAA）
		};

		// ===== 中间变量 =====
		var relativePosition : Vec3;               // 相对位置
		var transformedPosition : Vec3;            // 变换后的位置（视图空间）
		var previousTransformedPosition : Vec3;    // 上一帧的变换后位置
		var pixelTransformedPosition : Vec3;       // 像素级别的变换后位置
		var transformedNormal : Vec3;              // 变换后的法线
		var projectedPosition : Vec4;              // 投影后的位置（裁剪空间）
		var previousProjectedPosition : Vec4;      // 上一帧的投影后位置
		var pixelColor : Vec4;                     // 像素颜色
		var depth : Float;                         // 深度
		var ndcPosition : Vec2;                    // 归一化设备坐标
		var previousNdcPosition : Vec2;            // 上一帧的归一化设备坐标
		var screenUV : Vec2;                       // 屏幕 UV 坐标
		var specPower : Float;                     // 高光强度
		var specColor : Vec3;                      // 高光颜色
		var worldDist : Float;                     // 世界距离
		var pixelVelocity : Vec2;                  // 像素速度（运动向量）
		var prevModelView : Mat3x4;                // 上一帧的模型视图矩阵（3x4）

		// ===== 着色器参数（可在 Haxe 中设置） =====
		@param var color : Vec4;                   // 基础颜色（RGBA）
		@range(0,100) @param var specularPower : Float;    // 高光强度（范围 0-100）
		@range(0,10) @param var specularAmount : Float;     // 高光量（范围 0-10）
		@param var specularColor : Vec3;           // 高光颜色

		/**
		 * 顶点初始化阶段
		 * 计算所有顶点级别的数值：
		 * - 模型空间 -> 视图空间 -> 裁剪空间的变换
		 * - 法线变换
		 * - 前一帧的运动信息
		 * - 基础颜色和高光参数
		 *
		 * __init__ 中的表达式基于依赖关系自动排序（非顺序执行）
		 */
		function __init__() {
			relativePosition = input.position;
			transformedPosition = relativePosition * global.modelView.mat3x4();
			projectedPosition = vec4(transformedPosition, 1) * camera.viewProj;
			prevModelView = global.previousModelView.mat3x4();
			previousTransformedPosition = relativePosition * prevModelView;
			previousProjectedPosition = vec4(previousTransformedPosition, 1) * camera.previousViewProj;
			transformedNormal = (input.normal * global.modelView.mat3()).normalize();
			camera.dir = (camera.position - transformedPosition).normalize();
			pixelColor = color;
			specPower = specularPower;
			specColor = specularColor * specularAmount;
			screenUV = screenToUv(projectedPosition.xy / projectedPosition.w);
			depth = projectedPosition.z / projectedPosition.w;
			worldDist = length(transformedPosition - camera.position) / camera.zFar;
		}

		/**
		 * 片段初始化阶段
		 * 在片段着色器中计算数值（减少 varyings 插值数量）
		 * 计算屏幕空间的运动向量（用于 TAA/运动模糊）
		 */
		function __init__fragment() {
			transformedNormal = transformedNormal.normalize();
			// 在片段着色器中重新计算，减少 varyings 数量
			ndcPosition = projectedPosition.xy / projectedPosition.w;
			previousNdcPosition = previousProjectedPosition.xy / previousProjectedPosition.w;
			screenUV = screenToUv(ndcPosition);
			depth = projectedPosition.z / projectedPosition.w; // 避免屏幕空间插值
			specPower = specularPower;
			specColor = specularColor * specularAmount;
			ndcPosition -= camera.jitterOffsets.xy;
			previousNdcPosition -= camera.jitterOffsets.zw;
			pixelVelocity = ( previousNdcPosition - ndcPosition ) * vec2(0.5, -0.5);
		}

		/**
		 * 顶点着色器
		 * 输出裁剪空间位置，反转 Y 轴（适配 OpenGL/DirectX 差异）
		 */
		function vertex() {
			output.position = projectedPosition * vec4(1, camera.projFlip, 1, 1);
			pixelTransformedPosition = transformedPosition;
		}

		/**
		 * 片段着色器
		 * 输出颜色、深度、法线、世界距离和运动向量到 MRT
		 * 支持低精度法线打包模式
		 */
		function fragment() {
			output.color = pixelColor;
			output.depth = depth;
			output.normal = #if MRT_low packNormal(transformedNormal).rgb #else transformedNormal #end;
			output.worldDist = worldDist;
			output.velocity = pixelVelocity;
		}

	};

	public function new() {
		super();
		color.set(1, 1, 1);           // 默认白色
		specularColor.set(1, 1, 1);   // 默认白色高光
		specularPower = 50;            // 默认高光强度 50
		specularAmount = 1;            // 默认高光量 1
	}

}
