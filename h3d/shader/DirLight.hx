package h3d.shader;

/**
 * 方向光着色器（Directional Light）
 *
 * 模拟来自无穷远方向的平行光（如太阳光）。
 * 所有光线平行，不考虑光源位置。
 *
 * 光照计算（Phong 模型）：
 * 漫反射：diff = N · (-L)
 * 高光：spec = pow(max(R·V, 0), specPower)
 * 最终：color × (diff + specColor × spec)
 *
 * 支持：
 * - 漫反射光照
 * - 可选镜面高光（@const enableSpecular）
 * - 颜色和方向参数
 */
class DirLight extends hxsl.Shader {

	static var SRC = {
		@param var color : Vec3;          // 光源颜色（RGB）
		@param var direction : Vec3;       // 光源方向（指向光源）
		@const var enableSpecular : Bool;  // 是否启用高光
		@global var camera : {
			var position : Vec3;           // 相机位置（用于高光计算）
		};

		var lightColor : Vec3;             // 顶点光照颜色
		var lightPixelColor : Vec3;        // 像素光照颜色
		var transformedNormal : Vec3;      // 变换后的法线
		var transformedPosition : Vec3;    // 变换后的位置
		var specPower : Float;             // 高光强度
		var specColor : Vec3;              // 高光颜色

		/**
		 * 光照计算函数
		 * @return 最终光照颜色
		 *
		 * 漫反射：dot(N, -L)，约束到 [0, ∞)
		 * 高光（可选）：反射向量 R 与视线 V 的点积
		 */
		function calcLighting() : Vec3 {
			var diff = transformedNormal.dot(-direction).max(0.);
			if( !enableSpecular )
				return color * diff;
			var r = reflect(direction, transformedNormal).normalize();
			var specValue = r.dot((camera.position - transformedPosition).normalize()).max(0.);
			return color * (diff + specColor * pow(specValue, specPower));
		}

		function vertex() {
			lightColor.rgb += calcLighting();
		}

		function fragment() {
			lightPixelColor.rgb += calcLighting();
		}

	}

	public function new() {
		super();
		color.set(1, 1, 1);  // 默认白色光源
	}

}