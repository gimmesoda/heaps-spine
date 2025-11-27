package spine.heaps;

import h2d.Object;
import h2d.RenderContext;
import h2d.Tile;
import h2d.Drawable;
import h2d.impl.BatchDrawState;
import spine.animation.AnimationStateData;
import spine.animation.AnimationState;
import spine.attachments.MeshAttachment;
import spine.attachments.RegionAttachment;
import spine.Color;
import spine.atlas.TextureAtlasRegion;
import spine.Slot;
import spine.SkeletonData;
import spine.Skeleton;
import h3d.Indexes;
import hxd.BufferFormat;
import h3d.Buffer;
import h3d.Engine;
import hxd.IndexBuffer;
import hxd.FloatBuffer;

private class SpriteContent {
	public var vertexCount(default, null):Int = 0;
	public var indexCount(default, null):Int = 0;

	private var vertexBuffer:FloatBuffer;
	private var indexBuffer:IndexBuffer;

	private var uploadedVertices:Int = 0;
	private var uploadedIndices:Int = 0;

	public var buffer:Buffer;
	public var indexes:Indexes;
	private var state:BatchDrawState;

	public function new() {
		vertexBuffer = new FloatBuffer();
		indexBuffer = new IndexBuffer();

		state = new BatchDrawState();
	}

	public inline function tset(t:Tile, v:Int) {
		state.setTile(t);
		state.add(v);
	}

	public inline function iadd(i:Int) {
		indexBuffer[indexCount++] = i;
	}

	public inline function vadd(x:Float, y:Float, u:Float, v:Float, r:Float, g:Float, b:Float, a:Float) {
		for (n in [x, y, u, v, r, g, b, a])
			vertexBuffer[vertexCount++] = n;
	}

	private function alloc(engine:Engine) {
		if (indexCount < 1) return;

		buffer = Buffer.ofFloats(vertexBuffer, BufferFormat.H2D, [BufferFlag.Dynamic]);
		indexes = Indexes.alloc(indexBuffer);

		uploadedVertices = vertexCount;
		uploadedIndices = indexCount;
	}

	public function draw(ctx:RenderContext) {
		if (indexCount < 1) return;
		flush();
		state.drawIndexed(ctx, buffer, indexes, 0, Std.int(indexCount / 3));
	}

	public function flush() {
		final gvertex:Bool = vertexCount > uploadedVertices;
		final gindex:Bool = indexCount > uploadedIndices;

		if (gvertex || gindex || buffer?.isDisposed() != false || indexes?.isDisposed() != false) {
			if (buffer?.isDisposed() == false) buffer.dispose();
			if (indexes?.isDisposed() == false) indexes.dispose();
			alloc(Engine.getCurrent());
		}
		else {
			buffer.uploadFloats(vertexBuffer, 0, Std.int(vertexCount / 8));
			indexes.uploadIndexes(indexBuffer, 0, indexCount);
		}
	}

	public inline function reset() {
		vertexCount = indexCount = 0;
		state.clear();
	}

	public function clear() {
		buffer?.dispose();
		buffer = null;

		indexes?.dispose();
		indexes = null;
	}

	public inline function grow(nvertex:Int, nindex:Int) {
		vertexBuffer.grow(nvertex);
		indexBuffer.grow(nindex);
	}
}

class SkeletonSprite extends Drawable {
	public var state(default, null):AnimationState;

	public var pause:Bool = false;

	private var skeleton:Skeleton;
	private var content:SpriteContent;

	private static var worldVerices:Array<Float> = [];
	private static var quadTriangles:Array<Int> = [0, 1, 2, 2, 3, 0];

	public function new(data:SkeletonData, ?parent:Object) {
		super(parent);

		skeleton = new Skeleton(data);
		Bone.yDown = true;
		skeleton.updateWorldTransform(Physics.update);

		content = new SpriteContent();
		skeleton.update(0);

		state = new AnimationState(new AnimationStateData(data));
	}

	override function onRemove() {
		super.onRemove();
		content.clear();
	}

	override function draw(ctx:RenderContext) {
		if (!ctx.beginDrawBatchState(this)) return;
		content.draw(ctx);
	}

	override function sync(ctx:RenderContext) {
		if (!pause) state.update(ctx.elapsedTime);
		state.apply(skeleton);
		skeleton.updateWorldTransform(Physics.update);

		if (!pause) skeleton.update(ctx.elapsedTime);

		super.sync(ctx);
		renderTriangles();
		content.flush();
	}

	private function renderTriangles() {
		var drawOrder:Array<Slot> = skeleton.drawOrder;

		var region:TextureAtlasRegion;
		var color:Color = null;
		var r:Float = 0, g:Float = 0, b:Float = 0, a:Float = 0;

		var triangles:Array<Int> = null;
		var uvs:Array<Float> = null;

		content.reset();
		var verticesLength:Int = 0;
		var indicesLength:Int = 0;

		for (slot in drawOrder) {
			if (slot.attachment == null) continue;
			else if (slot.attachment is RegionAttachment) {
				final region:RegionAttachment = cast slot.attachment;
				if (region.region != null) {
					verticesLength += 4 * 8; // 4 vertices per region, 8 values per vertex
					indicesLength += 6; // 6 indices per region
				}
			}
			else if (slot.attachment is MeshAttachment) {
				final mesh:MeshAttachment = cast slot.attachment;
				if (mesh.region != null) {
					verticesLength += mesh.worldVerticesLength * 4;
					indicesLength += mesh.triangles.length;
				}
			}
			// TODO: other attachments
		}

		content.grow(verticesLength, indicesLength);

		var start:Int = 0;
		for (slot in drawOrder) {
			region = null;
			verticesLength = indicesLength = 0;

			if (slot.attachment == null) continue;
			else if (slot.attachment is RegionAttachment) {
				final att:RegionAttachment = cast slot.attachment;
				att.computeWorldVertices(slot, worldVerices, 0, 2);

				verticesLength = 4;
				indicesLength = 6;

				region = cast att.region;
				color = att.color;

				uvs = att.uvs;
				triangles = quadTriangles;
			}
			else if (slot.attachment is MeshAttachment) {
				final att:MeshAttachment = cast slot.attachment;
				att.computeWorldVertices(slot, 0, att.worldVerticesLength, worldVerices, 0, 2);

				uvs = att.uvs;
				triangles = att.triangles;

				verticesLength = att.worldVerticesLength >> 1;
				indicesLength = triangles.length;

				region = cast att.region;
				color = att.color;
			}
			// TODO: other attachments

			if (region == null) continue;

			r = color.r * skeleton.color.r * slot.color.r;
			g = color.g * skeleton.color.g * slot.color.g;
			b = color.b * skeleton.color.b * slot.color.b;
			a = color.a * skeleton.color.a * slot.color.a;

			content.tset(region.texture, worldVerices.length);

			for (v in 0...verticesLength) {
				final v1:Int = v * 2;
				final v2:Int = v1 + 1;
				content.vadd(worldVerices[v1], worldVerices[v2],
					uvs[v1], uvs[v2],
					r, g, b, a);
			}
			for (i in 0...indicesLength) content.iadd(triangles[i] + start);
			start += verticesLength;
		}
	}
}