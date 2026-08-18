ObjC.import("AppKit");
ObjC.import("Foundation");

function hashHue(value) {
  let hash = 5381;
  for (let index = 0; index < value.length; index += 1) {
    hash = ((hash * 33) + value.charCodeAt(index)) >>> 0;
  }
  return (hash % 360) / 360.0;
}

function run(argv) {
  if (argv.length < 3) {
    throw new Error("Usage: render-icon.js SOURCE_OR_DASH OUTPUT LETTER");
  }

  const sourcePath = argv[0];
  const outputPath = argv[1];
  const letter = (argv[2] || "W").substring(0, 1).toUpperCase();
  const size = 1024;
  const canvas = $.NSImage.alloc.initWithSize($.NSMakeSize(size, size));

  canvas.lockFocus;
  $.NSGraphicsContext.currentContext.imageInterpolation = $.NSImageInterpolationHigh;
  $.NSColor.clearColor.setFill;
  $.NSRectFill($.NSMakeRect(0, 0, size, size));

  const container = $.NSMakeRect(72, 72, 880, 880);
  const path = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius(container, 210, 210);
  path.addClip;

  let source = null;
  if (sourcePath !== "-") {
    source = $.NSImage.alloc.initWithContentsOfFile(sourcePath);
  }

  if (source && source.isValid) {
    $.NSColor.whiteColor.setFill;
    $.NSRectFill(container);

    const sourceSize = source.size;
    const maximum = $.NSMakeRect(217, 217, 590, 590);
    const scale = Math.min(maximum.size.width / Math.max(sourceSize.width, 1), maximum.size.height / Math.max(sourceSize.height, 1));
    const width = sourceSize.width * scale;
    const height = sourceSize.height * scale;
    const destination = $.NSMakeRect(
      maximum.origin.x + ((maximum.size.width - width) / 2),
      maximum.origin.y + ((maximum.size.height - height) / 2),
      width,
      height
    );
    source.drawInRectFromRectOperationFraction(destination, $.NSZeroRect, $.NSCompositingOperationSourceOver, 1.0);
  } else {
    const background = $.NSColor.colorWithCalibratedHueSaturationBrightnessAlpha(hashHue(letter), 0.62, 0.72, 1.0);
    background.setFill;
    $.NSRectFill(container);

    const attributes = $.NSMutableDictionary.dictionary;
    attributes.setObjectForKey($.NSFont.systemFontOfSizeWeight(470, $.NSFontWeightSemibold), $.NSFontAttributeName);
    attributes.setObjectForKey($.NSColor.whiteColor, $.NSForegroundColorAttributeName);
    const text = $(letter);
    const textSize = text.sizeWithAttributes(attributes);
    const textPoint = $.NSMakePoint(
      512 - (textSize.width / 2),
      512 - (textSize.height / 2) + 35
    );
    text.drawAtPointWithAttributes(textPoint, attributes);
  }

  canvas.unlockFocus;

  const tiff = canvas.TIFFRepresentation;
  const bitmap = $.NSBitmapImageRep.imageRepWithData(tiff);
  const png = bitmap.representationUsingTypeProperties($.NSBitmapImageFileTypePNG, $.NSDictionary.dictionary);
  if (!png.writeToFileAtomically(outputPath, true)) {
    throw new Error("Could not write rendered icon.");
  }
  return outputPath;
}
