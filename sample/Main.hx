import spine.heaps.SkeletonSprite;
import spine.SkeletonData;
import spine.attachments.AtlasAttachmentLoader;
import spine.SkeletonJson;
import spine.atlas.TextureAtlas;
import spine.heaps.HeapsTextureLoader;
import hxd.Res;
import hxd.App;

class Main extends App {
	private static function main() {
		new Main();
	}

	override function init() {
		Res.initLocal();

		final loader:HeapsTextureLoader = new HeapsTextureLoader('');
		final atlasSource:String = Res.load('alien.atlas').toText();
		final atlas:TextureAtlas = new TextureAtlas(atlasSource, loader);

		final json:SkeletonJson = new SkeletonJson(new AtlasAttachmentLoader(atlas));

		final skeletonData:SkeletonData = json.readSkeletonData(Res.load('alien.json').toText());
		final skel:SkeletonSprite = new SkeletonSprite(skeletonData, s2d);

		skel.state.setAnimationByName(0, 'death', true);
		skel.scale(0.4);
		skel.setPosition(s2d.width / 2, s2d.height);
	}
}