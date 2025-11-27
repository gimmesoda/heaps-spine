package spine.heaps;

import haxe.io.Path;
import spine.atlas.*;
import hxd.Res;

class HeapsTextureLoader implements TextureLoader {
	private var basePath:String;

	public function new(prefix:String) {
		if (prefix.length == 0) basePath = '';
		else basePath = Path.addTrailingSlash(prefix);
	}

	public function loadPage(page:TextureAtlasPage, path:String) {
		page.texture = Res.load('$basePath$path').toTile();
	}

	public function loadRegion(region:TextureAtlasRegion) {
		region.texture = region.page.texture;
	}

	public function unloadPage(page:TextureAtlasPage) {
		page.texture = null;
	}
}