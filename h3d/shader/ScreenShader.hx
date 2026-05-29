package h3d.shader;

/**
 * 全屏着色器（Screen Shader / Full-Screen Quad Shader）
 *
 * 用于全屏后处理效果的基础着色器。
 * 渲染一个覆盖整个屏幕的四边形，通常与 h3d.pass.ScreenFx 配合使用。
 *
 * 应用场景：
 * - 后期处理（Bloom、ToneMapping、FXAA）
 * - 颜色校正
 * - 全屏模糊
 * - 混合多个渲染目标
 *
 * flipY 参数用于处理 OpenGL（需要翻转 Y）和 DirectX 的坐标系差异。
 */
class ScreenShader extends hxsl.Shader {

	static var SRC = {
		@input var input : {
			position : Vec2,  // 全屏四边形顶点位置
			uv : Vec2,        // 纹理 UV 坐标
		};

		@param var flipY : Float;  // Y 翻转（OpenGL=1, DirectX=-1）

		var output : {
			position : Vec4,  // 裁剪空间位置
			color : Vec4,     // 输出颜色
		};

		var pixelColor : Vec4;     // 像素颜色（由子类设置）
		var calculatedUV : Vec2;   // 计算后的 UV

		function __init__() {
			output.color = pixelColor;
			calculatedUV = input.uv;
		}

		function vertex() {
			output.position = vec4(input.position.x, input.position.y * flipY, 0, 1);
		}
	};

}