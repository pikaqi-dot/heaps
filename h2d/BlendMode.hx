package h2d;

/**
 * 混合模式（Blend Mode）
 *
 * 渲染 Tile/Material 时控制源颜色（Src）与目标颜色（Dst）的混合方式。
 * 混合公式：Out = Src × SrcFactor + Dst × DstFactor
 *
 * - Src：当前绘制的像素颜色
 * - Dst：帧缓冲区中已有的像素颜色
 * - SrcA/Srb：源颜色的 Alpha 通道/RGB 亮度
 */
enum BlendMode {
	/** 不混合：Out = Src（完全不透明） */
	None;
	/** Alpha 透明混合：Out = SrcA×Src + (1-SrcA)×Dst（最常见） */
	Alpha;
	/** 叠加：Out = SrcA×Src + 1×Dst（发光效果） */
	Add;
	/** Alpha 叠加：Out = Src + (1-SrcA)×Dst */
	AlphaAdd;
	/** 柔和叠加：Out = (1-Dst)×Src + 1×Dst */
	SoftAdd;
	/** 相乘：Out = Dst×Src + 0（暗色调效果） */
	Multiply;
	/** Alpha 相乘：Out = Dst×Src + (1-SrcA)×Dst */
	AlphaMultiply;
	/** 擦除：Out = 0×Src + (1-SrcA)×Dst */
	Erase;
	/** 滤色：Out = 1×Src + (1-SrcA)×Dst（亮色调效果） */
	Screen;
	/** 相减：Out = 1×Dst - SrcA×Src */
	Sub;
	/** 取最大值：Out = MAX(Src, Dst) */
	Max;
	/** 取最小值：Out = MIN(Src, Dst) */
	Min;
}
