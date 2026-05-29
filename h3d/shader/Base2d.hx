package h3d.shader;

/**
 * 基础 2D 着色器（Base 2D Shader）
 *
 * 用于 2D 精灵渲染的 HXSL 着色器。
 * 支持：
 * - 相对/绝对坐标系
 * - 纹理采样
 * - 颜色乘法
 * - UV 偏移和缩放
 * - 像素对齐（防止模糊）
 * - Alpha 裁剪
 * - 视口变换
 *
 * 与 BaseMesh（3D）不同，Base2d 使用 Vec2 顶点位置，
 * 通过 3x3 仿射矩阵进行 2D 变换。
 */
class Base2d extends hxsl.Shader {

	static var SRC = {

		// ===== 顶点输入 =====
		@input var input : {
			var position : Vec2;  // 2D 顶点位置（屏幕空间或局部）
			var uv : Vec2;        // 纹理 UV 坐标
			var color : Vec4;     // 顶点颜色
		};

		// ===== 渲染输出 =====
		var output : {
			var position : Vec4;  // 裁剪空间位置
			var color : Vec4;     // 最终颜色
		};

		// ===== 全局变量 =====
		@global var time : Float;        // 全局时间
		@param var zValue : Float;       // Z 深度值（用于排序）
		@param var texture : Sampler2D;  // 纹理采样器

		// ===== 中间变量 =====
		var spritePosition : Vec4;       // 精灵位置（含 Z）
		var absolutePosition : Vec4;     // 绝对位置
		var pixelColor : Vec4;           // 像素颜色
		var textureColor : Vec4;         // 纹理采样颜色
		@var var calculatedUV : Vec2;    // 计算后的 UV（可在片段间插值）

		// ===== 常量参数（编译时确定） =====
		@const var isRelative : Bool;            // 是否使用相对坐标
		@param var color : Vec4;                 // 全局颜色叠加
		@param var absoluteMatrixA : Vec3;       // 相对→绝对变换矩阵 A 行
		@param var absoluteMatrixB : Vec3;       // 相对→绝对变换矩阵 B 行
		@param var filterMatrixA : Vec3;         // 滤镜矩阵 A 行
		@param var filterMatrixB : Vec3;         // 滤镜矩阵 B 行
		@const var hasUVPos : Bool;              // 是否有 UV 位置偏移
		@param var uvPos : Vec4;                 // UV 偏移/缩放 (offset.xy, scale.zw)

		@const var killAlpha : Bool;             // 是否裁剪透明像素
		@const var pixelAlign : Bool;            // 是否像素对齐
		@param var halfPixelInverse : Vec2;      // 半像素偏移倒数
		@param var viewportA : Vec3;             // 视口变换 A 行
		@param var viewportB : Vec3;             // 视口变换 B 行

		var outputPosition : Vec4;               // 最终输出位置

		/**
		 * 顶点初始化
		 * - 计算相对→绝对位置变换
		 * - 计算 UV
		 * - 混合颜色
		 * - 采样纹理
		 */
		function __init__() {
			spritePosition = vec4(input.position, zValue, 1);
			if( isRelative ) {
				absolutePosition.x = vec3(spritePosition.xy,1).dot(absoluteMatrixA);
				absolutePosition.y = vec3(spritePosition.xy,1).dot(absoluteMatrixB);
				absolutePosition.zw = spritePosition.zw;
			} else
				absolutePosition = spritePosition;
			calculatedUV = hasUVPos ? input.uv * uvPos.zw + uvPos.xy : input.uv;
			pixelColor = isRelative ? color * input.color : input.color;
			textureColor = texture.get(calculatedUV);
			pixelColor *= textureColor;
		}

		/**
		 * 顶点着色器
		 * 将全局坐标通过滤镜矩阵和视口矩阵变换到裁剪空间
		 * 可选像素对齐防止纹理模糊
		 */
		function vertex() {
			var tmp = vec3(absolutePosition.xy, 1);
			tmp = vec3(tmp.dot(filterMatrixA), tmp.dot(filterMatrixB), 1);
			outputPosition = vec4(
				tmp.dot(viewportA),
				tmp.dot(viewportB),
				absolutePosition.zw
			);
			// 半像素偏移补偿（DirectX 要求）
			// 参考：http://msdn.microsoft.com/en-us/library/windows/desktop/bb219690
			if( pixelAlign ) outputPosition.xy -= halfPixelInverse;
			output.position = outputPosition;
		}

		/**
		 * 片段着色器
		 * 可选裁剪透明度极低的像素（killAlpha）
		 */
		function fragment() {
			if( killAlpha && pixelColor.a < 0.001 ) discard;
			output.color = pixelColor;
		}

	};

}