package hxsl;

/**
 * HXSL 着色器系统中使用的类型别名
 * 将 Heaps 引擎中的实际类型映射为 HXSL 着色器域中的类型名称
 */

/** 三维向量（浮点） */
typedef Vec = h3d.Vector;
/** 四维向量（浮点） */
typedef Vec4 = h3d.Vector4;
/** 整数向量（使用 Array<Int> 实现） */
typedef IVec = Array<Int>;
/** 布尔向量（使用 Array<Bool> 实现） */
typedef BVec = Array<Bool>;
/** 4x4 矩阵 */
typedef Matrix = h3d.Matrix;
/** 2D 纹理 */
typedef Texture = h3d.mat.Texture;
/** 纹理数组 */
typedef TextureArray = h3d.mat.TextureArray;
/** 纹理通道（与 Texture 相同类型，语义上表示单通道） */
typedef TextureChannel = h3d.mat.Texture;
/** 纹理句柄（用于采样器） */
typedef TextureHandle = h3d.mat.TextureHandle;
/** 顶点/索引缓冲 */
typedef Buffer = h3d.Buffer;

/**
 * 通道工具类
 * 提供与纹理通道格式相关的辅助方法
 */
class ChannelTools {
	/**
	 * 检查纹理是否为原生压缩格式
	 * 原生格式使用特殊的打包方式存储法线/浮点数据
	 */
	public static inline function isPackedFormat( c : TextureChannel ) {
		return c.format == h3d.mat.Texture.nativeFormat;
	}
}