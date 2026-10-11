extends RefCounted

const OBJECTS = preload("res://art/atelier-realiste.png")
const ACCESSORIES = preload("res://art/accessoires-realistes.png")
const CROPS = preload("res://art/cultures-realistes.png")
const INTERFACE = preload("res://art/interface-realiste.png")
static var cache: Dictionary = {}

static func region(texture: Texture2D, rect: Rect2, key: String) -> AtlasTexture:
	if cache.has(key): return cache[key]
	var result := AtlasTexture.new()
	result.atlas = texture
	result.region = rect
	result.filter_clip = true
	cache[key] = result
	return result

static func object(index: int) -> AtlasTexture:
	var rects := [Rect2(20,20,300,300), Rect2(326,20,303,294), Rect2(635,117,318,196), Rect2(970,40,284,260), Rect2(15,322,309,303), Rect2(326,329,299,289), Rect2(635,330,324,292), Rect2(969,334,283,253), Rect2(28,627,297,258), Rect2(331,638,291,247), Rect2(641,608,306,306), Rect2(974,584,264,322), Rect2(60,885,229,341), Rect2(347,927,290,280), Rect2(641,944,316,220), Rect2(974,917,280,316)]
	return region(OBJECTS, rects[index], "object_%d" % index)

static func food(index: int) -> AtlasTexture:
	if index>=6 and index<=8:
		return region(preload("res://art/drink_ingredients.svg"),Rect2((index-6)*256,0,256,256),"drink_ingredient_%d" % index)
	return object(4 + index if index < 6 else 10)

static func crop(index: int) -> AtlasTexture:
	var rects := [Rect2(0,170,565,323),Rect2(572,16,451,480),Rect2(1025,100,510,395),Rect2(10,504,550,481),Rect2(572,513,451,468),Rect2(1025,498,509,482)]
	return region(CROPS, rects[index], "crop_%d" % index)

static func accessory(index: int) -> AtlasTexture:
	var rects := [Rect2(0,40,418,350), Rect2(418,60,418,340), Rect2(836,50,418,345), Rect2(0,400,418,418), Rect2(418,425,418,370), Rect2(836,523,418,205), Rect2(0,876,418,258), Rect2(418,850,418,300)]
	return region(ACCESSORIES, rects[index], "accessory_%d" % index)

static func interface(index: int) -> AtlasTexture:
	var rects := [Rect2(50,30,530,530), Rect2(618,168,618,290), Rect2(18,605,590,600), Rect2(636,568,600,653)]
	return region(INTERFACE, rects[index], "interface_%d" % index)

static func frame(tint: Color = Color.WHITE, inset: float = 12) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = interface(1)
	style.modulate_color = tint
	style.set_content_margin_all(inset)
	return style

static func panel_frame(tint: Color = Color.WHITE, inset: float = 18) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = object(14)
	style.modulate_color = tint
	style.texture_margin_left = 28
	style.texture_margin_right = 28
	style.texture_margin_top = 22
	style.texture_margin_bottom = 22
	style.set_content_margin_all(inset)
	return style
